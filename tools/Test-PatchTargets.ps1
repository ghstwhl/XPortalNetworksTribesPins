<#
.SYNOPSIS
    Verifies that every Harmony patch this mod ships still applies to the Valheim
    assemblies the build targets.

.DESCRIPTION
    A game patch can break a BepInEx mod without breaking its build: a patch target
    renamed or removed, a field the patch receives by name (`___field`) renamed, or
    the body of a method a transpiler pattern-matches changed underneath it. This
    script reads the built mod assembly with Mono.Cecil and checks, against the
    reference assemblies, that:

      1. every `[HarmonyPatch]` target type still exists in the game assemblies,
      2. it still declares at least one method with the patched name, and
      3. every `___field` parameter a patch method asks Harmony to inject still
         exists on that type (or one of its base types).

    It needs no game install, no Unity and no BepInEx runtime, so it can run in CI
    right after a build. It does NOT prove that a patched method's body is unchanged,
    which is what a transpiler cares about - compare the IL with Mono.Cecil for that
    (see `tools/README.md`).

.PARAMETER ReferencesRoot
    Folder holding the publicized reference assemblies. Defaults to
    `<repo>\.references`, or the ReferencesRoot environment variable.

.PARAMETER GameVersion
    Valheim version folder to check against. Defaults to ValheimGameVersion from
    Directory.Build.props (the single source of truth).

.PARAMETER ModDll
    Built mod assembly to check. Defaults to the Release build, then Debug.

.PARAMETER CecilPath
    Path to Mono.Cecil.dll. Defaults to the copy restored with the JotunnLib package.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\tools\Test-PatchTargets.ps1

.OUTPUTS
    One `PASS`/`FAIL` line per patch, a summary, and exit code 0 (all applied) or
    1 (at least one would fail to apply at runtime).
#>
[CmdletBinding()]
param(
    [string]$ReferencesRoot,
    [string]$GameVersion,
    [string]$ModDll,
    [string]$CecilPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot

function Get-ConfiguredValheimVersion {
    $propsPath = Join-Path $RepoRoot 'Directory.Build.props'
    if (Test-Path $propsPath) {
        $match = [regex]::Match((Get-Content $propsPath -Raw), '<ValheimGameVersion[^>]*>([^<]+)</ValheimGameVersion>')
        if ($match.Success) { return $match.Groups[1].Value.Trim() }
    }
    return $null
}

if (-not $ReferencesRoot) { $ReferencesRoot = $env:ReferencesRoot }
if (-not $ReferencesRoot) { $ReferencesRoot = Join-Path $RepoRoot '.references' }
if (-not $GameVersion) { $GameVersion = Get-ConfiguredValheimVersion }
if (-not $GameVersion) { throw "Could not determine the Valheim version - pass -GameVersion." }

if (-not $ModDll) {
    foreach ($candidate in @("XPortalNetworks\bin\Release\XPortalNetworks.dll", "XPortalNetworks\bin\Debug\XPortalNetworks.dll")) {
        $path = Join-Path $RepoRoot $candidate
        if (Test-Path $path) { $ModDll = $path; break }
    }
}
if (-not $ModDll -or -not (Test-Path $ModDll)) {
    throw "Mod assembly not found. Build it first (tools/Build.ps1), or pass -ModDll."
}

if (-not $CecilPath) {
    foreach ($candidate in @(
            (Join-Path $RepoRoot 'packages\JotunnLib.2.30.2\build\Mono.Cecil.dll'),
            (Join-Path $RepoRoot 'tools\.cache\publicizer\AssemblyPublicizer\Mono.Cecil.dll')
        )) {
        if (Test-Path $candidate) { $CecilPath = $candidate; break }
    }
}
if (-not $CecilPath -or -not (Test-Path $CecilPath)) { throw "Mono.Cecil.dll not found - pass -CecilPath." }

Add-Type -Path (Resolve-Path $CecilPath).Path

$gameDir = Join-Path $ReferencesRoot "Valheim\$GameVersion"
if (-not (Test-Path $gameDir)) { throw "Reference assemblies for Valheim $GameVersion not found at '$gameDir'. Run tools/New-ValheimRefs.ps1." }

# The assemblies a patch may target: the publicized game assemblies plus the Unity
# UI module (UnityEngine.UI.Dropdown is patched directly).
$gameAssemblies = New-Object 'System.Collections.Generic.List[string]'
foreach ($name in @('assembly_valheim', 'assembly_utils', 'assembly_guiutils', 'assembly_postprocessing')) {
    $p = Join-Path $gameDir "${name}_publicized.dll"
    if (Test-Path $p) { $gameAssemblies.Add($p) }
}
foreach ($name in @('UnityEngine.UI.dll', 'UnityEngine.CoreModule.dll', 'UnityEngine.dll')) {
    $p = Join-Path $gameDir "Managed\$name"
    if (Test-Path $p) { $gameAssemblies.Add($p) }
}

# typeFullName -> TypeDefinition, so a patch target can be resolved by name across
# all of the game assemblies (the mod never names the assembly, only the type).
$types = @{}
$modules = New-Object 'System.Collections.Generic.List[object]'
foreach ($path in $gameAssemblies) {
    $asm = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($path)
    $modules.Add($asm)
    foreach ($t in $asm.MainModule.GetTypes()) {
        if (-not $types.ContainsKey($t.FullName)) { $types[$t.FullName] = $t }
    }
}

function Find-Field {
    param($TypeDefinition, [string]$Name)
    $t = $TypeDefinition
    while ($null -ne $t) {
        foreach ($f in $t.Fields) { if ($f.Name -ceq $Name) { return $f } }
        if ($null -eq $t.BaseType) { break }
        $t = if ($types.ContainsKey($t.BaseType.FullName)) { $types[$t.BaseType.FullName] } else { $null }
    }
    return $null
}

$mod = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($ModDll)
$failures = 0
$checks = 0

try {
    Write-Host "XPortalNetworks patch-target check"
    Write-Host "    Mod DLL     $ModDll"
    Write-Host "    References  $gameDir"
    Write-Host ""

    foreach ($type in $mod.MainModule.GetTypes()) {
        # Only classes carrying [HarmonyPatch] are patch classes.
        $patchAttrs = @()
        foreach ($ca in $type.CustomAttributes) {
            if ($ca.AttributeType.FullName -ceq 'HarmonyLib.HarmonyPatch') { $patchAttrs += $ca }
        }
        if ($patchAttrs.Count -eq 0) { continue }

        $targetName = $null; $methodName = $null; $argTypes = @()
        foreach ($ca in $patchAttrs) {
            foreach ($arg in $ca.ConstructorArguments) {
                $argTypeName = $arg.Type.FullName
                if ($argTypeName -ceq 'System.Type') {
                    if ($null -eq $targetName) { $targetName = $arg.Value.FullName }
                }
                elseif ($argTypeName -ceq 'System.String') {
                    if ($null -eq $methodName) { $methodName = [string]$arg.Value }
                }
                elseif ($argTypeName -ceq 'System.Type[]') {
                    foreach ($element in $arg.Value) { $argTypes += $element.Value.FullName }
                }
            }
        }
        if (-not $targetName) {
            Write-Host ("FAIL  {0}: no target type in [HarmonyPatch]" -f $type.Name)
            $failures++
            continue
        }

        $target = if ($types.ContainsKey($targetName)) { $types[$targetName] } else { $null }
        if ($null -eq $target) {
            Write-Host ("FAIL  {0}: target type '{1}' no longer exists" -f $type.Name, $targetName)
            $failures++
            continue
        }

        $checks++
        $shape = "$targetName"
        if ($methodName) { $shape += "::$methodName" }
        if ($argTypes.Count -gt 0) { $shape += "(" + ($argTypes -join ',') + ")" }

        if ($methodName) {
            $methods = @($target.Methods | Where-Object { $_.Name -ceq $methodName })
            if ($methods.Count -eq 0) {
                Write-Host ("FAIL  {0}: {1} - no method named '{2}'" -f $type.Name, $shape, $methodName)
                $failures++
                continue
            }
            if ($argTypes.Count -gt 0) {
                $exact = @($methods | Where-Object {
                        $params = @($_.Parameters | ForEach-Object { $_.ParameterType.FullName })
                        ($params -join ',') -ceq ($argTypes -join ',')
                    })
                if ($exact.Count -eq 0) {
                    Write-Host ("FAIL  {0}: {1} - no overload with the patched parameter types" -f $type.Name, $shape)
                    $failures++
                    continue
                }
            }
        }

        # Fields Harmony injects by naming convention: ___field
        $missingFields = @()
        foreach ($method in $type.Methods) {
            foreach ($param in $method.Parameters) {
                if ($param.Name -like '___*') {
                    $fieldName = $param.Name.Substring(3)
                    if ($null -eq (Find-Field -TypeDefinition $target -Name $fieldName)) { $missingFields += $fieldName }
                }
            }
        }
        if ($missingFields.Count -gt 0) {
            Write-Host ("FAIL  {0}: {1} - injected field(s) missing: {2}" -f $type.Name, $shape, ($missingFields -join ','))
            $failures++
            continue
        }

        Write-Host ("PASS  {0}: {1}" -f $type.Name, $shape)
    }
}
finally {
    $mod.Dispose()
    foreach ($m in $modules) { $m.Dispose() }
}

Write-Host ""
if ($failures -gt 0) {
    Write-Host ("PATCH TARGETS FAILED - {0} of {1} patch classes would not apply." -f $failures, $checks)
    exit 1
}
Write-Host ("PATCH TARGETS OK - all {0} patch classes resolve against Valheim {1}." -f $checks, $GameVersion)
exit 0
