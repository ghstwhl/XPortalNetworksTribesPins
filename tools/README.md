# tools

Helper scripts for building XPortalNetworks.

## `Build.ps1` — build, validate, and package (start here)

One command for the whole pipeline: **NuGet restore → validation → MSBuild →
Release packaging (+ zip)**. Runs from any working directory and exits non-zero on failure
(CI/agent friendly).

```powershell
# Release build + package + zip (default)
powershell -ExecutionPolicy Bypass -File .\tools\Build.ps1

# Debug build (compiles only, no packaging)
powershell -ExecutionPolicy Bypass -File .\tools\Build.ps1 -Configuration Debug

# Skip steps you know aren't needed
powershell -ExecutionPolicy Bypass -File .\tools\Build.ps1 -SkipRestore -SkipValidation
```

### What it does

1. **Restore** — `nuget restore` for `packages.config` (auto-downloads `nuget.exe` to
   `tools\.cache` if it isn't on `PATH`).
2. **Validate** — fails the build when:
   - `ModInfo.Version` isn't `MAJOR.MINOR.PATCH`, or
   - it doesn't match `manifest.json` **and** `Docs/SolutionDir/Package/Release/manifest.json`, or
   - any `Translations\**\*.json` file is invalid JSON, or
   - the reference assemblies aren't present at `-ReferencesRoot` (default `<repo>\.references`).
3. **Build** — MSBuild; produces the single mod DLL directly - no assembly merging step.
4. **Package** (Release) — assembles the Thunderstore-style folder and two identical zips:
   `XPortalNetworks-release.zip` (the stable "latest" name) and `XPortalNetworks-<version>.zip`
   (a copy named after the version being built).

### Parameters

| Parameter | Default | Purpose |
|---|---|---|
| `-Configuration` | `Release` | `Release` (packages) or `Debug` (builds only). |
| `-ReferencesRoot` | `<repo>\.references` | Folder with the publicized reference assemblies. |
| `-SkipRestore` | off | Skip the NuGet restore step. |
| `-SkipValidation` | off | Skip the validation checks. |
| `-NoPackage` | off | Build the release folder but don't create the zips. |

### Outputs

```
XPortalNetworks\bin\<Configuration>\XPortalNetworks.dll       the mod DLL
Release\NorCal_Nerds-XPortalNetworksTribesPins\               package (plugins\ + docs), named from ModInfo.cs
Release\XPortalNetworks-release.zip                           Release only
Release\XPortalNetworks-<version>.zip                         Release only (copy of the above)
```

Deploy the package's `plugins` contents to `BepInEx\plugins\` on **both** the server and the
client (same build on each side).

### Exit codes

`0` = success, non-zero = failure. The last line is always `BUILD OK ...` or `BUILD FAILED: ...`.

## Documentation (`Docs/`)

Most README files are **generated** by T4 templates that Visual Studio runs (`TextTemplatingFileGenerator` entries in `Docs/Docs.csproj`). Edit the templates in `Docs/Modules/`, never the generated output:

| Generated file | Template |
|---|---|
| `Docs/README.Nexus.bbcode` | `Docs/README.Nexus.tt` (`Modules/10Header`, `20Features`, `25Configuration`, `30Installation`, `40Bugs`, `60Credits`, `99Footer`) |
| `Docs/SolutionDir/Package/Release/README.md` | `Docs/SolutionDir/Package/Release/README.tt` (same modules) |
| `Docs/SolutionDir/Package/Release/manifest.json` | `Docs/SolutionDir/Package/Release/manifest.tt` |
| `Docs/SolutionDir/Package/Release/CHANGELOG.md`, `Docs/GitHub.Release.md`, the issue templates | their matching `.tt` files |

The templates read the mod identity straight from the built assembly (`Mod.Info` via `Docs/_Header.t4`), so a regeneration picks up the current name, GUID, version and GitHub repo automatically - but it needs `Docs/Docs.csproj` built first.

Two files are **hand-maintained** and must not be regenerated: the repository `README.md`, and `Docs/SolutionDir/README.md` (its template was removed because the file also contains hand-written sections that regeneration would have deleted).

To regenerate, open the solution in Visual Studio and run the custom tool on the `.tt` files (right-click → *Run Custom Tool*).

## `New-ValheimRefs.ps1`

Creates the reference-assembly layout that `XPortalNetworks/XPortalNetworks.csproj`
compiles against (the `$(ReferencesRoot)` folder), using
[CabbageCrow/AssemblyPublicizer](https://github.com/CabbageCrow/AssemblyPublicizer)
to publicize the Valheim game assemblies.

It produces exactly what the csproj expects:

```
<OutputPath>\Valheim\<GameVersion>\
    assembly_valheim_publicized.dll
    assembly_utils_publicized.dll
    assembly_guiutils_publicized.dll
    assembly_postprocessing_publicized.dll
    Managed\                (UnityEngine*.dll, Unity.TextMeshPro.dll, ...)
<OutputPath>\BepInEx\<BepInExVersion>\BepInEx\core\
    BepInEx.dll  BepInEx.Harmony.dll  0Harmony.dll
```

### Prerequisites

- **Valheim** installed (Steam) or `-ValheimPath` provided.
- **BepInEx 5.4.2351** installed into the Valheim folder, or `-BepInExCorePath`
  pointing at a folder containing `BepInEx.dll`.
- **AssemblyPublicizer.exe** — either pass `-PublicizerPath`, or use
  `-BuildPublicizer` (requires Visual Studio / MSBuild, which you need anyway).

### Usage

```powershell
# From the repo root. Builds the publicizer from source if needed.
powershell -ExecutionPolicy Bypass -File .\tools\New-ValheimRefs.ps1 -BuildPublicizer

# Use a downloaded release binary (preferred) and a specific Valheim install:
powershell -ExecutionPolicy Bypass -File .\tools\New-ValheimRefs.ps1 `
    -ValheimPath "D:\Steam\steamapps\common\Valheim" `
    -PublicizerPath "C:\tools\AssemblyPublicizer.exe"

# Write somewhere other than the repo's .references and match a different game version:
powershell -ExecutionPolicy Bypass -File .\tools\New-ValheimRefs.ps1 `
    -OutputPath "C:\ValheimRefs" -GameVersion 0.217.46
```

Default output is `<repo>\.references` (gitignored).

### After running

Point the project at the generated folder by setting `ReferencesRoot`, e.g. add a
`Directory.Build.props` at the repo root:

```xml
<Project>
  <PropertyGroup>
    <ReferencesRoot>C:\ValheimRefs</ReferencesRoot>
  </PropertyGroup>
</Project>
```

Then build in Visual Studio, or:

```powershell
msbuild XPortalNetworks.sln /p:ReferencesRoot="C:\ValheimRefs"
```

> **Note:** If you change `-GameVersion` / `-BepInExVersion`, keep them in sync with
> `VALHEIM_INSTALL` / `BEPINEX_PATH` (or `ReferencesRoot`) in the csproj.

### Legal

Reference assemblies are derived from the game and tooling binaries and are **not**
distributed with this repo. Only publicize assemblies you are entitled to work with.
XPortalNetworks is not affiliated with AssemblyPublicizer.

## `Test-PatchTargets.ps1` - does the mod still patch this game version?

A Valheim patch breaks BepInEx mods in ways that still compile: a patch target gets
renamed or removed, a field a patch receives by name (`___field`) moves, or the body of a
method a transpiler matches changes underneath it. This script checks the first two
against the reference assemblies, so a game update can be assessed without launching
Valheim:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\Build.ps1            # build first
powershell -ExecutionPolicy Bypass -File .\tools\Test-PatchTargets.ps1 # then check
```

It reads the built `XPortalNetworks.dll` with Mono.Cecil and verifies, for every class
carrying `[HarmonyPatch]`, that the target type still exists in the game assemblies
(including `UnityEngine.UI` for the `Dropdown` patches), that it still declares the
patched method, and that every `___field` parameter still resolves on that type or a base
type. It prints one `PASS`/`FAIL` line per patch class and exits non-zero if any patch
would fail to apply.

| Parameter | Default | Purpose |
|---|---|---|
| `-ReferencesRoot` | `<repo>\.references` (or `$env:ReferencesRoot`) | Folder with the publicized reference assemblies. |
| `-GameVersion` | `ValheimGameVersion` from `Directory.Build.props` | Game version folder to check against. |
| `-ModDll` | `XPortalNetworks\bin\Release\XPortalNetworks.dll` (then Debug) | Built assembly to check. |
| `-CecilPath` | `packages\JotunnLib.2.30.2\build\Mono.Cecil.dll` (then the publicizer cache) | Path to Mono.Cecil.dll. |

It does **not** prove that a patched method's *body* is unchanged, which is what the
`TeleportWorld.UpdatePortal` transpiler depends on. For that, dump each patched method's IL
from both the old and the new reference pack with Mono.Cecil and compare them - the
transpiler pattern is `stloc.2`, `ldarg.0`, `ldfld TeleportWorld::m_target_found`.

### Checking a new game version

1. `tools/New-ValheimRefs.ps1` for the new version, then set `ValheimGameVersion` in
   `Directory.Build.props` to match.
2. `tools/Build.ps1` - a rebuild proves every `typeof`/`nameof` patch target still
exists, because those are resolved by the compiler.
3. `tools/Test-PatchTargets.ps1` - proves the string-named targets (`Dropdown.set_value`,
   `TeleportWorld.UpdatePortal`, `ZNet.RPC_PeerInfo`) and the `___field` injections.
4. Diff the IL of the patched methods against the previous reference pack.
