# 3.1.2 - Portal Configuration Panel UI Hardening
Two ways the portal configuration panel could dead-end are fixed; both are ported from the upstream mod's later "UI Interaction Hardening" release.
* **The panel can no longer be made unclickable by another UI (`UI/PortalConfigurationPanel.cs`)**
  * The panel's `UIGroupHandler.m_groupPriority` is now `100`. Vanilla's `UIGroupHandler.Update()` forces `CanvasGroup.interactable` from the highest active group priority, so with the previous default of `0` any background HUD or third-party mod panel active at a higher priority silently switched the panel's interactivity off: it still rendered, but every click, toggle, text box and button - Cancel included - was ignored. This is what made the panel feel locked near the world spawn, where other UI groups are active, while an area without them behaved normally.
* **Escape always closes the panel and releases input (`UI/PortalConfigurationPanel.cs`)**
  * `PortalConfigurationPanel.HandleInput()` now checks `Input.GetKeyDown(KeyCode.Escape)` / `ZInput.GetKeyDown(KeyCode.Escape)` first and closes the panel, so the escape hatch no longer depends on the affected `UIGroupHandler` / `UIGamePad` interactive state. Closing the panel releases `GUIManager.BlockInput(false)`, which is what previously left the game input-blocked with no way back to the escape menu (the panel has to be closed before the game's own Escape menu can open again while it holds the input block).

# 3.1.1 - Documentation Presentation & Asset Cleanup
The docs now show the mod with a single hero screenshot, and every image they hot-link lives in this repository. The images nothing referenced any more are gone with them.
* **One hero screenshot instead of three (`README.md`)**
  * The three stacked UI screenshots - "Portal Configuration UI", "Network Selection Window" and "Destination Network Selection" - are replaced by a single "Opposing Tribe Views" image, `images/split-tribe-view.png`. They were three separate windows of the same feature, and the README reads better with one picture that shows it in use on both sides of a network restriction.
* **No image is hot-linked from another repository (`README.md`, `Docs/Modules/20Features.t4`, `Docs/Modules/11HeaderGitHub.t4`, `Docs/SolutionDir/README.md` and the tracked mirrors)**
  * Two images were being served out of repositories belonging to someone else: the Advanced Portals illustration in the generated docs (from `SpikeHimself/XPortal`) and the Thunderstore badge on the store README (from `SpikeHimself/resources`). Both are gone - the Advanced Portals paragraph simply ends where its picture was, and "Where to Download" keeps its existing Thunderstore bullet, which is what the badge linked to anyway.
  * The keyhints screenshot in the generated docs points at this repository's own `images/ui-keyhints-small.png`, which was already committed here, instead of another project's copy of the same image.
  * This is about images, not links: the credits, the original mod, Jotunn, BepInEx, Advanced Portals and the Nexus pages are all still linked exactly as they were, and the GitHub profile avatar next to the Vapok Gaming credit is untouched.
* **Images nothing references any more are deleted (`images/`)**
  * 15 files, about 2.1 MB: the three superseded UI screenshots, both Advanced Portals illustrations, the retired Nexus "buy me a coffee" and Survival Servers banners, and the older single-shot UI images (`configuration.png`, `defaultportal.png`, `dropdown.png`, `hover.png`, `pingmapdisabled.png`, `showonmap.png`, `ui-keyhints.png`, `connect-explore-header.jpeg`, `xportal networks icon.jpeg`).
  * What is left is what the docs actually use: `controller.gif`, `icon.png`, `ui-keyhints-small.png`, and the new `split-tribe-view.png` hero image.
* Docs and repository assets only: no code, config or behaviour change.

# 3.1.0 - Usable-Portal Removal Restriction
* **`RestrictPortalRemovalToCreator` - the existing rule, renamed and now on by default (`XPortalNetworksConfig.cs`, `Patches/Piece.cs`)**
  * On its own it restricts removing a portal with the hammer to the player who placed it. That is its whole rule: it never looks at portal networks, and it only ever affects the hammer - other removal such as structural damage is unaffected.
  * It is renamed from `RestrictPortalRemoval`, so the two removal rules read as a pair (`RestrictPortalRemovalToCreator` / `RestrictPortalRemovalToUsable`), and it now defaults to enabled where it used to default to off.
  * An existing value is carried over: the old key is read straight from the config file before the new key is bound and becomes the new key's default (`XPortalNetworksConfig.MigrateRenamedBool`), so a server that had `RestrictPortalRemoval = false` keeps `false` instead of silently picking up the new default. The old line stays behind as an inert key that is no longer read and can be deleted, and one log line reports the rename when a value is carried over.
  * Like every other server-owned entry it carries `IsAdminOnly` plus the shared "owned by the server" description, so it is synchronized to every client and can only be changed by server admins - including in game through ConfigurationManager.
* **`RestrictPortalRemovalToUsable` - the new rule (`XPortalNetworksConfig.cs`, `Patches/Piece.cs`)**
  * On its own it restricts removing a portal with the hammer to portals the player is allowed to use, reusing the rule that already gates the portal configuration panel (`XPortalNetworks.OnPortalRequestText`): the portal's **own** network must be the Global network, an unrestricted network, or a network the player is a member of, and a **private** portal may only be removed by its owner (its creator, or the player a personal network belongs to).
  * The portal's own network and privacy are used, never its destination's - so a portal that can be opened and configured can also be removed, and one that shows the "restricted network" message cannot.
  * It defaults to enabled, and it is server-owned in exactly the same way as the rule above.
* **How the two rules combine**
  * They are cumulative: every enabled rule has to be satisfied, so enabling one never loosens the other. With both enabled - the default - a player may only remove a portal they placed **and** may still use.
  * Neither rule hands the host or server admins a free pass by itself: the privileged bypass is the same gated notion the rest of the mod uses, `CustomNetworks.IsLocalPlayerNetworkPrivileged()` (`AdminsSeeAllNetworks` AND admin/host/portal-network-admin) - exactly what `CustomNetworks.IsLocalPlayerAllowed` already applies for the configuration panel. With `AdminsSeeAllNetworks` disabled, the default, they are treated like normal players by both rules, so "cannot use it" also means "cannot hammer it"; enabling `AdminsSeeAllNetworks` restores unconditional admin removal. This narrows the creator rule's "or a server admin" exemption the same way, and the descriptions of both settings now say so.
  * Neither rule affects other removal such as structural damage, and both leave the piece's environmental wear behaviour alone (see below).
* **Implementation notes (`Patches/Piece.cs`, `Patches/WearNTear.cs`, `Patches/Patcher.cs`, `CustomNetworks.cs`)**
  * The rules extend the existing `Piece.CanBeRemoved` postfix - the method `Player.RemovePiece` consults to decide whether the hammer may remove a piece (it is what produces vanilla's "can't remove now" message). Each rule can only ever deny, which is what makes the cumulative behaviour above hold.
  * Vanilla also calls that method from the owner-side wear simulation: `WearNTear.UpdateWear` asks `WearNTear.CanBeRemoved()` -> `Piece.CanBeRemoved()` whether environmental wear may destroy the piece, and when it may not, the piece never decays at all. "May this player hammer it" is a different question, so a new `WearNTear_CanBeRemoved` postfix answers that owner-side question with `true` for portals (`Patches/WearNTear.cs`, registered in `Patches/Patcher.cs`). The two rules are therefore independent, no unconditional admin/server short-circuit is needed on the player-facing side, and portals still decay exactly as before.
  * `WearNTear.UpdateWear` is the only caller of `WearNTear.CanBeRemoved`, and the hammer goes through `Player.RemovePiece` directly, so that postfix cannot hand anyone removal rights.
  * Portal network membership and privacy are read from the portal's own ZDO through the existing helpers (`CustomNetworks.IsLocalPlayerAllowed`, `ZdoTools.GetNetworkOwnerPlayerId`, `ZdoTools.GetIsPrivate`, `ZDOVars.s_creator`), so no new data has to be stored anywhere.
  * Removal stays client-driven: vanilla's `WearNTear.RPC_Remove` runs on the ZDO owner and performs no permission check, so this - like the creator-only rule before it - is a gameplay rule, not an anti-cheat guarantee.
* **Docs**: documented in `Docs/Modules/25Configuration.t4` and its tracked mirrors (`Docs/README.Nexus.bbcode`, `Docs/SolutionDir/Package/Release/README.md`), and in both hand-maintained READMEs.

# 3.0.4 - Live Store Links
The mod is now published, so the docs point at the real listings instead of the "not currently available" placeholder.
* **Live locations linked (`README.md`, `Docs/SolutionDir/README.md`, `REFERENCES.md`)**
  * The root README gains a **Where to Download** section, and its installation section drops the stale "Automatic (Not currently available)" heading in favour of a recommended automatic install that names the live [Thunderstore](https://thunderstore.io/c/valheim/p/NorCal_Nerds/XPortalNetworksTribesPins/) listing alongside [GitHub Releases](https://github.com/ghstwhl/XPortalNetworksTribesPins/releases).
  * `Docs/SolutionDir/README.md`'s "Where to Download" section now lists both the Thunderstore page (badge + link) and the GitHub releases page, and its manual-install step finally drops the leftover "Nexus Mods" (this fork has no Nexus page) in favour of the two live sources.
  * `REFERENCES.md` records both publication locations next to the project's GitHub home.
* **Generated install links updated (`Docs/_Header.t4`, `Docs/Modules/11HeaderGitHub.t4` and the mirrored outputs)**
  * `urlThisModThunderstore` now builds the current `https://thunderstore.io/c/valheim/p/<team>/<package>/` URL instead of the legacy `valheim.thunderstore.io/package/...` host, and the GitHub header template's "Where to download" section also offers the GitHub releases page. The tracked mirrors (`Docs/README.Nexus.bbcode`, `Docs/SolutionDir/Package/Release/README.md`) are updated to match.
* Docs only: no code, config or behaviour change.

# 3.0.3 - Documentation Naming Consistency
The docs mixed two names for the mod. There is now one rule, applied everywhere: **`XPortalNetworksTribesPins`** is the technical identity (plugin name, Thunderstore/GitHub/repository name), and **"XPortal Networks Tribes Pins"** is the human name used in prose.
* **Display name added to the code (`ModInfo.cs`, `Docs/_Header.t4`)**
  * `Mod.Info.HumanName` ("XPortal Networks Tribes Pins") is added next to `Mod.Info.Name`, and `_Header.t4` exposes it to the templates as `thisModHumanName`. The plugin `Name`, `GUID` and `LegacyName` are unchanged, so the plugin identity, the ZDO key prefix, the RPC names and the store/repository name are all unaffected.
* **Templates use the human name for prose (`Docs/Modules/*.t4`, the issue-template `.tt` sources)**
  * `10Header`, `11HeaderGitHub`, `20Features`, `25Configuration`, `30Installation`, `40Bugs` and `90InstallationDev` now write `thisModHumanName` in headings and sentences. The technical values are untouched: store/GitHub links keep `thisModPackageName` / `thisModGitHubRepo`, and the config path keeps `thisModGUID`. `thisModName` stays declared for anything that genuinely needs the plugin identity.
* **Tracked generated docs refreshed to match (`Docs/README.Nexus.bbcode`, `Docs/SolutionDir/Package/Release/README.md`, `.github/ISSUE_TEMPLATE/*` and the `Docs/SolutionDir/.github/ISSUE_TEMPLATE/` mirrors)**
  * They still carried the pre-3.0.0 names (`XPortalNetworks`, and `XPortal` in the issue templates). Their prose now reads "XPortal Networks Tribes Pins" while store/repository references keep `XPortalNetworksTribesPins`. These are design-time T4 outputs, and the standalone `TextTransform.exe` cannot compile the templates (it rejects the nested `\"` inside the interpolated `mf.Link(...)` call in `20Features.t4`, at `HEAD` as well), so they are mirrored by hand as usual.
* **Hand-maintained docs corrected (`README.md`, `Docs/SolutionDir/README.md`, `REFERENCES.md`)**
  * Prose uses "XPortal Networks Tribes Pins"; the ConfigurationManager path (`ConfigurationManager -> XPortalNetworksTribesPins -> Portal Networks`), the mod-manager search term, and the store/repository links use the technical `XPortalNetworksTribesPins`.
* **Deliberately left alone**
  * Historical entries that describe the 3.0.0 rename (where the old name is the *point*), the `Vapok/XPortalNetworks` and SpikeHimself credits (different, original projects), and every `XPortalNetworks*` code identifier - the config class, the `XPortalNetworks/XPortalNetworks.csproj` paths, the legacy ZDO keys, `XPortalNetworks.dll` and the `XPortalNetworks-<version>.zip` artifacts.
* The only code change is the new `Mod.Info.HumanName` constant: no config or behaviour change.

# 3.0.2 - Portal Network Docs Correction
* **Custom network wording fixed (`README.md`, `Docs/SolutionDir/README.md`)**
  * The "Public, Private & Custom Networks" list still said custom networks were "defined in `xportal_networks.json`". That has not been true since 2.4.0, so both hand-maintained READMEs now describe the current workflow: networks (up to 15) are admin-defined in this mod's own config file and can be added, renamed or restricted on the fly - in-game with tools like ConfigurationManager, or by editing the `[Portal Network <n>]` sections by hand.
  * The bullet also spells out what `Permitted` is for: it takes the player ids allowed to use that network, which is what restricts a portal network to a specific Tribe or faction on a multiplayer server.
  * Wording only - no code, config or behaviour change. Historical changelog entries that describe the old JSON file are deliberately left as they are, and the "Custom Named Networks (config)" sections below the list already described the config workflow correctly.
* **Product name corrected (`README.md`, `Docs/SolutionDir/README.md`, `CHANGELOG.md`)**
  * Both READMEs wrote the mod's name as "XPortal Networks **Teams** Pins" in their titles, headings and prose, while the plugin name, the manifest, the repository and the Thunderstore package all say **Tribes**: it is now spelled "XPortal Networks Tribes Pins" everywhere, and the historical 2.0.0 entry was corrected the same way.
  * Typos fixed in the same files: "re-woprk" -> "re-work", "[Valpok]" -> "[Vapok]", "[XPortalNetwork]" -> "[XPortalNetworks]", "private Triibe" -> "private Tribe", "Author of the the expanded" -> "Author of the expanded", and the "Teams Pinss" instances that came with the wrong name.
* **Stale `README copy.md` references removed (`Docs/PATCHNOTES.md`, `CHANGELOG.md`)**
  * The 3.0.1 notes described mirroring changes into a `README copy.md` that is not part of the repository; those mentions are gone and the lines now name only the files that exist.

# 3.0.1 - Lime Green Pins & Nexus Reference Removed
* **Lime green portal pins (`PortalMapPins.cs`)**
  * Portal map pins are now tinted **lime green** (`#32CD32`, i.e. `new Color(0.196f, 0.804f, 0.196f, 1f)`) instead of the bright blue (`0.4, 0.8, 1`) of the standalone XPortal Shared Map Pins mod that inspired them (an inspiration only - no code from that project is used here), so this fork's pins are recognisable at a glance. Nothing else about the pins changes: the same dedicated `Minimap.PinType`, the same marker sprite (the game's own portal map icon, or the generated white ring), the same access rules, and the colour is still re-applied after every `Minimap.UpdatePins` pass because the game re-tints all markers itself.
* **Fallback marker re-expressed (`PortalMapPins.cs`)**
  * `CreateFallbackPortalIcon` - the white ring used only when the map icon list has no portal sprite - now builds the texture differently: the pixels are walked by buffer index and measured against the texture's centre, instead of a nested x/y loop with `Vector2.Distance`, and the texture's properties are assigned after construction instead of through an object initialiser.
  * The result is unchanged - the same 32x32 RGBA32 texture, the same centre at 15.5/15.5, the same 9.5 pixel ring radius and the same alpha ramp `clamp01((0.9 - |radius - 9.5|) * 4)` - and it removes the last lines this re-implementation shared textually with the source of the mod that inspired the feature. What the two now have in common are bare C# keywords (`try`, `return;`, `continue;`), which no rewrite can remove.
* **No Nexus ID (`ModInfo.cs`, `XPortalNetworksConfig.cs`)**
  * `Mod.Info.NexusId` and the `General/NexusID` config key are gone: this fork has no Nexus page of its own, and the ID they carried (`3719`) was the **upstream** mod's listing - so the key only ever pointed aedenthorn's [Nexus Update Check](https://www.nexusmods.com/valheim/mods/102) (and the README badges) at a page that is not this mod, and it would have reported the upstream mod's version.
  * Nothing breaks: the value was never read by this mod, and BepInEx simply ignores the retired key left behind in an existing config file. The `[General]` section and every other setting are unchanged.
* **Docs no longer advertise a Nexus listing**
  * `Docs/_Header.t4` drops `thisModNexusId` / `urlThisModNexus` (with a comment saying why, so the URL is not "restored" later), and the modules built on it follow: the `11HeaderGitHub.t4` badge row and the `30Installation.t4` download step now name Thunderstore and the GitHub releases page only.
  * The tracked generated outputs (`Docs/README.Nexus.bbcode`, `Docs/SolutionDir/Package/Release/README.md`) and the hand-maintained `Docs/SolutionDir/README.md` are mirrored to match, and the latter no longer links to Nexus ID 2239, which is not this project's page at all.
  * Third-party Nexus links (Jötunn, Vortex, AnyPortal, Advanced Portals, ...) and the upstream credits are untouched, and `REFERENCES.md` replaces the row that documented the ID with one recording the removal.
* No portal behaviour or localization changes: the pin colour stays an internal constant rather than a setting, and the only config entry removed was the inert `General/NexusID` metadata key.

* **Attribution clarified (docs, `REFERENCES.md`, `PortalMapPins.cs`, `Patches/Minimap.cs`)**
  * buldosik's [XPortal Shared Map Pins](https://github.com/buldosik/valheim-mods/tree/master/XPortalSharedMapPins) is now described everywhere as the **inspiration only** for the portal map pins: the implementation is this mod's own re-implementation against the vanilla `Minimap` API and it **contains no code from that project**.
  * The `PortalMapPins` class comment no longer calls the feature "ported" (it names the standalone mod as the inspiration instead), and the note is repeated wherever that mod is named: the pin-feature sections and the compatibility/credits lists of `README.md` and `Docs/SolutionDir/README.md`, the `20Features.t4` template with its tracked generated mirrors (`Docs/README.Nexus.bbcode` and the package README), and `REFERENCES.md` (referenced-mods table, source-availability note and attribution section).
  * Wording only - no code, config or behaviour change, and buldosik stays credited exactly as before.

# 3.0.0 - Independent Plugin Identity
* **New plugin GUID (`ModInfo.cs`)**
  * The plugin GUID is now `ghostwheel.mods.xportalnetworkstribespins` (was `vapok.mods.xportalnetworks`), so this fork no longer registers itself under the upstream author's namespace: BepInEx, Jotunn and any mod that inspects plugin metadata now see a mod of its own. `HarmonyGUID` follows the change automatically.
  * The old GUID is kept as `Mod.Info.LegacyGUID` and is used for exactly one thing - carrying an existing config file over to its new name (below). It is deliberately not used as a plugin GUID any more.
  * `Mod.Info.Name` carries the rename too: it is now `XPortalNetworksTribesPins` (was `XPortalNetworks`), which is the name BepInEx/Jotunn display and what the portal ZDO keys (`XPortalNetworksTribesPins_TargetId`, ...) and the RPC names (`XPortalNetworksTribesPins_SyncPortal`, ...) are derived from.
  * The previous name is kept as `Mod.Info.LegacyName`, and the portal data on existing portals is carried over read-side (`ZdoTools`, `XPortalNetworks.LegacyKey_*`): every read prefers the new key and falls back to the `XPortalNetworks_*` key a world saved by 2.6.0 or older carries, and every write updates both. Because the legacy key keeps mirroring the current value, a portal that is deliberately reset - Global network, not private, cleared name - cannot resurrect its earlier value, and the legacy keys can simply be dropped in a later cleanup.
  * The names of the UI GameObjects this mod creates (`XPortalNetworksTribesPins_MainPanel`, ...) and the RPC names follow the new Name. Both are per-session, so nothing persisted depends on them. The one-time `xportal_networks.json` import also still looks in the old folder (`BepInEx/config/XPortalNetworks/`), not just the new one.
* **Config file renamed to match the GUID (`XPortalNetworksConfig.cs`)**
  * BepInEx names the plugin's config file after the GUID, so it is now `BepInEx/config/ghostwheel.mods.xportalnetworkstribespins.cfg`. Everything lives there as before: `General/NexusID`, the server-owned `Portal Networks` sections with their `Name`/`Permitted` keys, `DefaultPortal`, and the `[General]` + `[Local Config]` toggles.
  * `XPortalNetworksConfig.MigrateLegacyConfigFile` runs before any setting is bound: if `vapok.mods.xportalnetworks.cfg` exists and the new file does not hold settings yet, the old file is copied to the new name and reloaded, so an upgrade keeps its networks, allow lists and preferences. A log line reports the migration and the old file can then be deleted. A new config file that already contains settings is never overwritten, and a failed copy is logged together with the target path so it can be redone by hand.
* **Vapok splash screen and telemetry removed (`ModInfo.cs`, `XPortalNetworks.cs`, `XPortalNetworksConfig.cs`)**
  * The mod no longer registers with Vapok.Valheim.Common's `ModSplashManager`, so it takes no part in that library's startup splash modal, its `ModSplashDossier` metadata, or its `TelemetryManager` (anonymous `mod_launch` / `mod_heartbeat` / `world_session_start` events and error reporting to the library's endpoint). `IPluginInfo` and its `PluginId` / `DisplayName` / `Version` / `Instance` members existed only for that registration and are gone with it.
  * Removing the code paths is deliberate, rather than switching them off: the library keeps its opt-in and error-report flags in shared Unity PlayerPrefs (`Vapok_Telemetry_OptIn`, `Vapok_Telemetry_ErrorReports_Enabled` - error reports default to *enabled*) and installs process-wide Harmony and `AppDomain.UnhandledException` hooks when its type is initialised. None of that is touched now, so this mod cannot influence another Vapok mod's telemetry settings, and a stored opt-in cannot switch anything back on for us. The library's endpoint is a compile-time constant, so it can be neither re-pointed nor overridden from a mod - which is another reason not to participate at all.
  * The three `[Local Config]` entries that only existed for that integration are removed with it: `Show Splash on Startup`, `Enable Anonymous Telemetry` and `Send Error Reports`. `Show Portal Map Pins` and `Show Network In Pin Name` become the remaining local preferences. Config files keep the retired keys, which BepInEx simply ignores.
  * The `Vapok.Valheim.Common` dependency is then dropped outright - `<Reference>`, `packages.config` entry and the ILRepack merge of it - so the shipped DLL contains no Vapok code at all. The last thing it was still used for, `Vapok.Common.Shared.ConfigurationManagerAttributes` on the two local preferences, now uses Jotunn's `ConfigurationManagerAttributes` (the class the server-owned entries already use for `IsAdminOnly`); only its `Order` field was ever needed there, and since the ConfigurationManager resolves that attribute by type name and copies matching fields, the ordering is unchanged. ILRepack goes with it: the project no longer imports its targets and `ILRepack.targets` / `ILRepack.Config.props` are deleted, leaving a plain single-assembly MSBuild build. The DLL shrinks from 552,960 to 118,784 bytes and the release zip from 339,969 to 176,874 bytes, and the `System.Net.Http` / `UnityEngine.UnityWebRequestModule` references - which came from the library's telemetry HTTP pipeline - disappear from the assembly too.
  * Docs updated to match: the configuration sections of `Docs/Modules/25Configuration.t4` and the mirrored tracked outputs (`Docs/README.Nexus.bbcode`, package README), the settings tables of `README.md` and `Docs/SolutionDir/README.md`, and the README privacy section, which is now a plain "this mod collects and sends nothing" statement without telemetry toggles, the in-game privacy-policy overlay, or opt-in/opt-out bullets.
* **Breaking for mixed-version multiplayer (`MAJOR`)**
  * Because the plugin identity changed, Jotunn's `NetworkCompatibility` and ServerSync see 3.0.0 as a different mod: the server and every client must be updated together. A 2.6.0 peer on a 3.0.0 server (or the reverse) counts as not having the mod installed.
  * Mods that hard-depend on `vapok.mods.xportalnetworks` - the standalone XPortal Shared Map Pins mod does, and it is the inspiration for our map pins (no code from it is used here) - refer to the upstream mod and no longer resolve against this one. The map-pin feature is built in here, so 3.0.0 replaces that mod as before: do not install both.
  * Existing worlds keep their portal links, networks and private flags through the legacy ZDO keys described above; what changes is the key prefix and the RPC names.
* **2.6.0 superseded**: 2.6.0 was uploaded to Thunderstore but its listing was rejected, so it never became public - and Thunderstore refuses the same namespace/name/version twice, so the version had to move past it regardless.
* **Docs**: every place that names the config file was updated - `README.md`, `Docs/SolutionDir/README.md`, the tracked generated `Docs/README.Nexus.bbcode` and package README (the `25Configuration.t4` template derives the path from `Mod.Info.GUID`, so it only needed re-mirroring) - the `CustomNetworks` doc comment names the new file, and `REFERENCES.md` records the GUID and Name change. The Nexus reference (`Mod.Info.NexusId`, ID 3719) is deliberately left as the upstream mod's page - it is an external identifier, not part of the plugin identity being renamed, and this fork has no Nexus upload of its own.

# 2.6.0 - Portal Map Pins
* **Project home moved (`ModInfo.cs`, both manifests, docs)**
  * The project now lives at **[ghstwhl/XPortalNetworksTribesPins](https://github.com/ghstwhl/XPortalNetworksTribesPins)**: `ModInfo.GitHubRepo` (which drives the generated GitHub links/issue templates), both `manifest.json` files (Thunderstore `name` + `website_url`) and the packaged README/CHANGELOG all point there.
  * **[Vapok/XPortalNetworks](https://github.com/Vapok/XPortalNetworks) stays credited** as the base this project is built upon: the README credits it explicitly (`Based On`), `Docs/SolutionDir/README.md` links it as the base, and `ModInfo.GitHubRepo` carries a comment naming it.
  * **No identity change where it matters:** the plugin `GUID` (`vapok.mods.xportalnetworks`), the plugin `Name` (`XPortalNetworks` - the portal ZDO keys are derived from it, e.g. `XPortalNetworks_TargetId`) and the config file name are unchanged, so existing worlds, settings and multiplayer compatibility are unaffected.
  * **New publishing identity:** `Mod.Info.Author` is now `ghstwhl`, and the Thunderstore team/package (`NorCal_Nerds` / `XPortalNetworksTribesPins`) is declared once in `ModInfo.cs` (`ThunderstoreTeam` / `ThunderstorePackage`). `Docs/_Header.t4` builds the generated install links from it, and `tools/Build.ps1` names the package staging folder after it (`Release/NorCal_Nerds-XPortalNetworksTribesPins`, handed to MSBuild as `/p:PackageFolder` - the csproj `Copy` target now uses a `PackageFolder` property instead of a hard-coded `-Vapok` suffix).
  * `Mod.Info.Description` is synced with the manifest description. Still outstanding: `Mod.Info.NexusId` (and the README/README-Nexus Nexus links) point at the upstream mod's Nexus page until this fork has one of its own.
* **Portal map pins (`PortalMapPins.cs`)** - new feature
  * The standalone [XPortal Shared Map Pins](https://github.com/buldosik/valheim-mods/tree/master/XPortalSharedMapPins) mod by buldosik is the inspiration for this feature - **no code from that project is used here**; the pins are this mod's own implementation - and they are built into XPortal Networks Tribes Pins now, so no companion mod is needed: every known portal you are allowed to use is drawn as a pin on your own map.
  * The pins are local map data - nothing is written to the world, nothing is sent over the network, vanilla player pins are untouched, and the pins are never saved to your map file (they are added with `save: false`, `ownerID: 0`).
  * Pins use a dedicated `Minimap.PinType` registered right after the vanilla enum (`Minimap.m_icons` + `Minimap.m_visibleIconTypes`), so they do not clash with - or toggle - the vanilla pin categories in the map legend.
  * The marker is the game's own portal map icon, located in `Minimap.m_icons` by sprite name (a sprite whose `Sprite.name` contains `portal`) exactly how the standalone mod found it, tinted with that mod's bright blue (`0.4, 0.8, 1`). The standalone mod's generated white ring is kept as the fallback when the icon list has no portal sprite (the "no portal icon found" case logs the icon names at debug level). The game's wood-toned portal *build* icon is not used - a tint only darkened it. buldosik's mod is the inspiration for every one of these choices, and no code from that project is used here.
  * `Minimap.UpdatePins` re-tints every marker itself (white when the pin has no owner), so `Patches/Minimap.cs` adds a postfix that re-applies the colour after each pass - the patch the standalone mod needed as well (inspiration only: no code from that project is used here).
* **Pins only for portals you are allowed to use (`PortalMapPins.IsVisibleToLocalPlayer`)**
  * A portal is pinned when it sits on the Global network, on a tribe network you are a member of (or may bypass as an admin - controlled by `AdminsSeeAllNetworks`), on a personal network (public portals there are usable by anyone), or when it is your own private portal.
  * Portals on someone else's private/personal network and on restricted tribe networks are never pinned. This mirrors the filtering the destination dropdown applies, and it is evaluated locally against the same synchronized network definitions the UI uses. The standalone mod's `IncludePrivatePortals` option is gone (inspiration only - no code from that project is used here): permission now decides.
* **Two new `[Local Config]` settings (`XPortalNetworksConfig.cs`)**
  * `Show Portal Map Pins` (default on) - turns the pins off again; disabling removes only this mod's pins.
  * `Show Network In Pin Name` (default off) - prefixes a portal's pin with its network name, e.g. `[Trade Hub] North Base`.
  * Both are client-local preferences (not synchronized); they are listed after the other `[Local Config]` toggles.
  * A server that asks to be played without a map (`PingMapDisabled`) also gets no portal pins, so the no-map intent is respected.
* **Pins stay up to date (`PortalMapPins.Reconcile`)**
  * Pins are reconciled every 5 seconds, and immediately whenever the portal list changes (`KnownPortalsManager.AddOrUpdate` / `Remove` / `Reset`) or a setting changes (network list, `PingMapDisabled`, the pin toggles, admin status). Renamed or moved portals get their pin recreated, destroyed portals lose theirs, and pins the player deletes on the map are restored.
  * The minimap instance is tracked, so loading another world re-registers the pin type and rebuilds the pins instead of leaking stale ones.
* **Build tooling (`tools/Build.ps1`)**
  * A Release build now writes **two** artifacts: the existing `Release/XPortalNetworks-release.zip` and a copy named after the version being built (`Release/XPortalNetworks-<version>.zip`, e.g. `XPortalNetworks-2.6.0.zip`), so a release can be pinned to an exact build while the unversioned name stays the stable "latest" download.
  * `tools/README.md` documents both outputs (the zip is copied straight after `Compress-Archive` creates it, so the two files are always identical).
* **Docs**: `Docs/Modules/25Configuration.t4`, `Docs/Modules/20Features.t4` and the hand-maintained READMEs (mirrored into the tracked generated `README.Nexus.bbcode` and package README) document the new settings and the map-pin feature, and call out that the standalone XPortal Shared Map Pins mod (the inspiration for the feature - no code from that project is used here) has to be removed to avoid duplicate pins. buldosik is credited in the READMEs' *Credits & Acknowledgements* section, linked to the standalone mod's [Thunderstore page](https://thunderstore.io/c/valheim/p/buldosik/XPortalSharedMapPins/).
* **References (`REFERENCES.md`)**
  * Added the [XPortal Shared Map Pins](https://github.com/buldosik/valheim-mods/tree/master/XPortalSharedMapPins) source - the inspiration for the map-pin feature (credited as an inspiration only: no code from that project is used here) - to the referenced-mods table and to the attribution section (the upstream repository declares **no licence**, so it is credited explicitly).
  * Recorded that the BepInEx Valheim uses - and the one this mod compiles and ships against - is **not** built from upstream `BepInEx/BepInEx` (EOL 5.x), but from the maintenance branch **`v5-lts`** at <https://github.com/AzumattDev/BepInEx>: the pack's `5.4.2350` is assembly `5.4.23.5`, and our `BepInEx.dll` carries that fork's commit `ef506e0a` (*"Bump ThunderStore version to 5.4.2350"*), which does not exist upstream. The note also records the fork's `HarmonyX` 2.9.0 pin.
  * Documented the source-availability route for this work (shell `api.github.com` / `raw.githubusercontent.com`, since the local fetch server refuses GitHub `tree`/`blob` pages) and the Mono.Cecil-verified `Minimap` map-pin API facts.
* **Terminology**: shared portal networks are now called **tribe** networks (was: team networks) throughout the code comments and documentation - a wording change only, with no behaviour, config-key or localization change. Entries for already-released versions below keep their original wording.

# 2.5.0 - Portal Network Config Sections
* **Per-Network Config Sections (`XPortalNetworksConfig.cs`)**
  * Networks are now bound as `[Portal Network <n>]` sections with `Name` and `Permitted` keys (was: one `[Portal Networks]` section with `Network <n> Name` / `Network <n> Allow List`). Sections are bound 1-15 so the UI lists them numerically; within a section `Name` carries the higher `ConfigurationManagerAttributes.Order` (2 vs 1) because ConfigurationManager sorts by Order **descending** (`ConfigurationManager.cs`: `OrderByDescending(set => set.Order).ThenBy(set => set.DispName)`), which is also why the previous layout showed "Allow List" above "Name" (both Order 0, so the alphabetical display-name tie-break decided it).
  * Added `MigrateLegacyNetworkSections()`: on load, values left in the old `[Portal Networks]` section are read straight from the config file (`ConfigFile.OrphanedEntries` is not accessible in BepInEx 5) and copied into the new sections where those are still empty. The old keys are deliberately left in the file as an inert section - they are no longer bound, so they do not appear in the ConfigurationManager UI.
  * `CustomNetworks` is unchanged apart from documentation/log wording: it reads the same `GetNetworkName()` / `GetNetworkAllowList()` accessors.
* **Local Config Ordering (`XPortalNetworksConfig.cs`)**
  * `Show Splash on Startup` and `Enable Anonymous Telemetry` used `Order` 4 and 5, so ConfigurationManager (which sorts descending) listed telemetry first; the values are swapped (`Order = 5` for splash, `4` for telemetry) so the splash toggle is listed first.
* **Docs**: `25Configuration.t4`, the generated Nexus/package READMEs and the README configuration lists now document the per-network layout.

# 2.4.0 - Portal Networks in the Server Config
* **Config-Owned Networks (`XPortalNetworksConfig.cs`, `CustomNetworks.cs`)**
  * Portal networks are now defined by the `Portal Networks` config section: `Network <n> Name` and `Network <n> Allow List` (ids 1-15, empty name = unused slot, empty list = open to everyone). Both are tagged `ConfigurationManagerAttributes.IsAdminOnly`, so ServerSync distributes them and only server admins (or the host) can change them.
  * `RebuildFromConfig()` replaces the JSON load path and runs on every `SettingChanged`; `ResetSession()` now rebuilds instead of clearing, so the list survives a session reset.
* **Legacy Import (`CustomNetworks.cs`)**
  * `InitializeServer()` imports a pre-2.4.0 `BepInEx/config/XPortalNetworks/xportal_networks.json` into the config when no network is defined yet (re-using the old parser, now reachable only from `ImportLegacyJsonIfNeeded()`), then logs that the file is obsolete.
* **Removed RPC (`RPC/RPCManager.cs`, `RPC/ClientEvents.cs`, `RPC/ServerEvents.cs`, `RPC/SendToClient.cs`, `RPC/SendToServer.cs`)**
  * Dropped `RPC_CustomNetworks` / `RPC_RequestCustomNetworks`, the queued re-send helpers and `SendToClient.CustomNetworks` / `SendToServer.RequestCustomNetworks`; `CustomNetworks.PackForClient` / `ApplyFromServer` / `BroadcastToAllPeers` are gone too.
* **Hot-Reload Machinery Removed (`CustomNetworks.cs`, `XPortalNetworks.cs`)**
  * The `FileSystemWatcher`, `ServerTick()` polling, debounce state, `EnsureDefaultConfigExists` and the embedded JSON template were all deleted; `xportal_networks.json` is no longer an embedded resource in `XPortalNetworks.csproj`, and `tools/Build.ps1` no longer validates it.
* **Docs**: The README configuration sections describe the in-game workflow, and the setting lists are complete again - `Docs/Modules/25Configuration.t4` (plus the generated Nexus and package READMEs) now document `DefaultPrivatePortal`, `RestrictPortalRemoval`, `AdminsSeeAllNetworks`, the `Portal Networks` entries and the two `[Local Config]` toggles, and the README settings table gained the matching rows.
* **Doc Templates (`Docs/Modules/*.t4`, `Docs/Docs.csproj`)**
  * Removed the hard-coded self-references that had been by-passing the assembly-derived variables: `10Header.t4` / `11HeaderGitHub.t4` / `20Features.t4` / `25Configuration.t4` / `90InstallationDev.t4` now use `thisModName` (and `thisModGitHubRepo` for the banner image) instead of the literal `XPortal` and the original `SpikeHimself/XPortal` image URL, so a regeneration no longer re-introduces the pre-rename branding. Links that intentionally point at the original mod (`00Urls.t4`) and the historical changelog entries (`52Changelogs-previous.t4`) were left as-is.
  * Removed `Docs/SolutionDir/README.tt`: `Docs/SolutionDir/README.md` is a hybrid of generated and hand-written sections (the configuration and installation sections exist in no template), so regenerating it would have deleted hand-authored content. The file is now explicitly hand-maintained, and `tools/README.md` documents which files are generated and how to regenerate them.

# 2.3.2 - Offline-Capable Research Tooling
* **Local Web Access (`/.vscode/mcp.json`)**
  * Added a locally-hosted MCP fetch server (`docker run -i --rm mcp/fetch`, MCP `2024-11-05` / `mcp-fetch` 1.23.0). MCP servers run locally, so agent web retrieval no longer depends on GitHub-hosted tools (which are gated by a Copilot entitlement and were refusing every request during this work).
  * Verified end-to-end by fetching the previously-failing `https://github.com/BepInEx/BepInEx.ConfigurationManager`.
  * Added a second locally-hosted server, `mcp/brave-search` (keyword web search); the API key is supplied through VS Code's secure `${input:...}` prompt (`password: true`) instead of being written into the repo.
* **Documentation (`REFERENCES.md`)**
  * Section 7 now distinguishes the GitHub-tool outage from the restored local MCP path, so the source provenance record stays accurate.
  * Section 2 now records the verified ConfigurationManager contract: it resolves an attributes class **by type name** (`SettingEntryBase.cs`) and copies only same-named fields, its own class is `internal sealed` with no admin concept, and `IsAdminOnly`/`IsUnlocked` belong to the sync library (Jötunn). It also corrects the earlier claim that non-admin players see server-owned settings locked in the ConfigurationManager window - they do not; enforcement is via ServerSync.
* **No mod changes**: version bump only (tooling + docs = PATCH per `.github/copilot-instructions.md`); `ModInfo.cs`, `manifest.json` and `Docs/SolutionDir/Package/Release/manifest.json` kept in sync.

# 2.3.1 - Reference Documentation
* **New Source Inventory (`REFERENCES.md`)**
  * Documents every external source used for this mod: game assemblies and exact versions (Valheim 1.0.16 / Unity 6000.0.75f1), modding framework and libraries (BepInEx 5.4.2350, HarmonyX 2.9.0, Jötunn 2.30.2, Vapok.Valheim.Common 3.21.1015, BepInEx ConfigurationManager contract), build/analysis tooling (AssemblyPublicizer, ILRepack 2.0.44.1, Mono.Cecil, nuget.exe, .NET Framework reference assemblies), the offline XML-doc/NuGet/IL sources used for verification, in-repo prior art, referenced third-party mods, and attribution/licensing notes.
  * Records which facts came from which source, including the `AdminOnlyStrictness` semantics quoted from `Jotunn.xml` and the decompilation-verified ServerSync data path.
* **No code changes**: version bump only (documentation is a PATCH per `.github/copilot-instructions.md`); `ModInfo.cs`, `manifest.json` and `Docs/SolutionDir/Package/Release/manifest.json` kept in sync.

# 2.3.0 - Server-Owned Config via Jotunn ServerSync
* **ServerSync Opt-In (`XPortalNetworks.cs`)**
  * Added `[SynchronizationMode(AdminOnlyStrictness.Always)]` to the plugin, which registers its config file with Jotunn's `SynchronizationManager` (ServerSync).
* **Server-Owned Entries (`XPortalNetworksConfig.cs`)**
  * `PingMapDisabled`, `DoublePortalCosts`, `HidePortalDistance`, `RestrictPortalRemoval` and `AdminsSeeAllNetworks` now carry `ConfigurationManagerAttributes.IsAdminOnly`, so ServerSync pushes the server's values into every client's config file, unlocks the entries for server admins/host in the ConfigurationManager window and locks them for everyone else.
  * Removed the `Server` settings mirror and `TrackServerConfig()`: synced entries hold the server's values in the local config, so the cached settings are read from `Local` (`CustomNetworks.cs`, `Patches/Piece.cs`, `UI/PortalConfigurationPanel.cs`, `XPortalNetworks.cs`).
  * Removed `PackLocalConfig()`/`ReceiveServerConfig()` and the now unused `System.IO`/`XPortalNetworks.RPC` usings.
* **Retired Config RPC (`RPC/RPCManager.cs`, `RPC/ClientEvents.cs`, `RPC/ServerEvents.cs`, `RPC/SendToClient.cs`, `RPC/SendToServer.cs`)**
  * Dropped `RPC_Config`/`RPC_ConfigRequest` and the `SendToClient.Config`/`SendToServer.ConfigRequest` helpers (server-to-client only). `LocalConfigChanged` on the server still re-broadcasts the per-client portal network lists, so `AdminsSeeAllNetworks` changes still take effect immediately.
* **Docs**
  * Configuration sections now describe the server-owned settings as synchronized and admin-editable instead of "enforced (but not overwritten) by the server".

# 2.2.1 - Admin Bypass Live Toggle Fix
* **Server Config Aliasing (`XPortalNetworksConfig.cs`, `XPortalNetworks.cs`)**
  * Re-assert `Server = Local` whenever the config reloads and at server session start (`TrackServerConfig`), so server-enforced settings (incl. `AdminsSeeAllNetworks`) are read correctly even though the plugin loads before `ZNet` exists.
* **Live Network Re-Push (`XPortalNetworksConfig.cs`)**
  * On a server config change, re-broadcast each client's permitted network list and refresh the local UI, so toggling `AdminsSeeAllNetworks` takes effect immediately.

# 2.2.0 - Admin Network Bypass Option
* **New Config Option (`XPortalNetworksConfig.cs`)**
  * Added `AdminsSeeAllNetworks` (General section, default `false`, server-enforced). When disabled, server admins/host are treated like normal players for portal-network allow lists; when enabled, they can see and use every network.
* **Consistent Gating (`CustomNetworks.cs`, `XPortalNetworks.cs`, `RPC/ServerEvents.cs`)**
  * Per-client network push, client-side visibility (dropdowns + hover), portal interaction, teleport gating, and server-side portal edit/link validation now all honour the setting through a single `AdminsBypassNetworks` gate.

# 2.1.2 - Valheim 1.0.16 Alignment
* **Game References (`Directory.Build.props`, `XPortalNetworks/XPortalNetworks.csproj`, `tools/*`)**:
  * Re-publicized the Valheim 1.0.16 game assemblies and regenerated the reference layout.
  * Added `ValheimGameVersion` to `Directory.Build.props` as the single source of truth; `VALHEIM_INSTALL` and the reference `HintPath`s (now `$(VALHEIM_INSTALL)`/`$(BEPINEX_PATH)`) plus the `tools/` scripts all derive from it, so future game updates are a one-line change.
* **Build**: Verified the mod compiles against the 1.0.16 assemblies (no source changes required).

# 2.1.1 - Config Hot-Reload Resilience
* **Hot-Reload Poll (`CustomNetworks.cs`)**:
  * `DetectFileChange` now treats the config file disappearing as a change, so deleting `xportal_networks.json` while the server is running reliably re-seeds it from the embedded default and reloads (previously this depended on a `FileSystemWatcher` delete event; the polling fallback ignored the file being absent).
  * Added a warning log when the file is found missing and recreated.
  * `UpdateFileBaseline` now records the "missing" state explicitly, and the reload re-baselines after reading so the just-read file isn't flagged again on the next poll.

# 2.1.0 - Team Portal Networks
* **Team Networks via `allow_list` (`CustomNetworks.cs`, `PortalNetwork.cs`)**:
  * Network entries in `xportal_networks.json` now accept an optional `"allow_list"` of player ids (e.g. `Steam_12345678901234567`); the parser was rewritten to support the new object form (`id` / `name` / `allow_list`).
  * Only players on a network's allow list can see the network in the configuration UI, edit its portals, or step through them. An omitted or empty `allow_list` keeps the network open to everyone.
* **Server-Authoritative Network Policy (`CustomNetworks.cs`, `RPC/ServerEvents.cs`, `RPC/ClientEvents.cs`, `RPC/SendToClient.cs`, `NetPeerUtility.cs`)**:
  * The server now sends each client only the networks that client is permitted to use (id + name only); allow lists never leave the server.
  * Portal add/update requests are rejected when they assign a network, edit a restricted portal, or link to a portal on a team network the requester cannot access.
  * Added `NetPeerUtility` helpers to resolve a player's platform id (`Steam_...`) for allow-list matching.
* **Client Privacy (`XPortalNetworks.cs`, `UI/PortalConfigurationPanel.cs`)**:
  * Portals on a restricted network the player is not a member of are hidden from hover text and from the network/destination dropdowns, and show a localized "cannot access" message on interaction.
* **Config Hot-Reload Hardening (`CustomNetworks.cs`, `XPortalNetworks.cs`)**:
  * `xportal_networks.json` reloads now run on the game's main thread (via the frame update pump) instead of a background thread.
  * Added a file-timestamp polling fallback so edits are picked up even when `FileSystemWatcher` events are missed, with debounced coalescing of rapid saves.
* **Localization**:
  * Added `hud_xportal_network_restricted` to the shipped translations.

# 2.0.10 - Portal Connection Fix
* **Portal Reconnection & Target Resolution (`Patches/ZDOMan.cs`)**:
  * Resolved cross-session portal scrambling in `ZDOMan_ConnectPortals` by eliminating premature current-session ID collision check (`GetZDO(targetId)`).
  * Built an $O(1)$ dictionary lookup (`portalsByPreviousId`) to resolve previous session target IDs directly against each portal's loaded `Key_PreviousId`.
  * Expanded portal enumeration to `ZDOMan.instance.GetPortalList()` supplemented with `ZDOExtraData` connection IDs to ensure all loaded portals are captured.
  * Ensured unresolvable targets are safely cleared (`ZDOID.None`) rather than attaching to mismatched runtime entities.

# 2.0.9 - Dedicated Server UI Patch Hardening & Dependency Updates
* **Dedicated Server Isolation (`Environment.cs`, `Patches/Patcher.cs`, `Patches/Dropdown.cs`)**:
  * Switched headless detection to `Jotunn.Managers.GUIManager.IsHeadless()` directly, removing `SystemInfo.graphicsDeviceType` in compliance with repository invariants.
  * Added early returns in `Dropdown_*` patches and guarded UI patch registrations in `Patcher.Patch()` when running on headless servers.
* **Portal Reconnection & Identity (`Patches/ZDOMan.cs`, `KnownPortal.cs`, `KnownPortalsManager.cs`)**:
  * Fixed ZDOID type mismatch in `ZDOMan_ConnectPortals` where `Key_PreviousId` was checked via `GetString()` instead of `GetZDOID()`, avoiding spurious fallback lookup on session load.
  * Implemented `IEquatable<KnownPortal>`, `Equals`, and `GetHashCode` based on `ZDOID` on `KnownPortal`.
  * Updated `KnownPortalsManager.UpdateFromList` to reconcile using `HashSet<ZDOID>`, eliminating object reference mismatch during network resync.
* **Placement & State Hardening (`Patches/Piece.cs`, `Patches/WearNTear.cs`, `Patches/Player.cs`)**:
  * Eliminated static `m_WearNTear` field in `Piece_SetCreator`, scoped check strictly to portal pieces, and passed instance via `QueuedAction` state.
  * Added null safety guards on `Piece`, `piece.m_name`, and `ZNetView` in `WearNTear_OnPlaced.Postfix`, resolving `XPORTALNETWORKS-9`.
  * Removed dead `Patches/Player.cs` stub.
* **RPC & Server Hardening (`RPC/ServerEvents.cs`, `RPC/XPortalNetworksAdminSync.cs`, `NetPeerUtility.cs`, `RPC/RPCManager.cs`)**:
  * Guarded `peer.m_socket != null` before `GetHostName()` in `RPC_RequestAdminSync` and `NetPeerUtility.IsPeerPrivilegedForPortalNetwork`.
  * Protected `UserInfo.GetLocalUser()` with try-catch in `XPortalNetworksAdminSync.IsLocalPortalNetworkAdmin()`.
  * Guarded `ZRoutedRpc.instance == null` in `RPCManager.Register()`.
* **Unity Lifecycle & Code Hygiene (`UI/PortalConfigurationPanel.cs`, `XPortalNetworks.cs`)**:
  * Replaced `?.` on Unity objects (`Dropdown`, `ScrollRect`, `Component`, `GameObject`) with explicit `!= null` checks adhering to Unity lifecycle semantics.
  * Removed legacy XML summary blocks across codebase.
* **Ecosystem Compatibility**:
  * Noted that an issue in [ValheimCommunityPatch](https://thunderstore.io/c/valheim/p/MidnightMods/ValheimCommunityPatch/) prevented portal network connections; resolved in ValheimCommunityPatch 0.29.0.
* **Dependency Updates**:
  * Updated internalized `Vapok.Valheim.Common` to 3.19.1015.
  * Updated `JotunnLib` dependency to 2.30.2.

# 2.0.8 - Valheim 1.0.15 Alignment & Internalized Dependency Updates
* **Valheim 1.0.15 Alignment**:
  * Aligned publicized game assembly and UnityEngine references to Valheim 1.0.15.
  * Updated internalized `Vapok.Valheim.Common` dependency to 3.13.1015.
* **Transpiler & Patch Hardening**:
  * Added index bounds validation (`i + 2 < instrs.Count`) and null-safe operand equality checks (`Equals(instrs[i+2].operand, mTargetFound)`) in `TeleportWorld_UpdatePortal_Transpiler`.
  * Added safety guards against unresolvable target members (`m_target_found` and `IsUsablePortal`) to prevent Harmony `ArgumentException` during patch initialization.
* **Stability & Localization**:
  * Synchronized all 35 game localizations for splash screen and configuration registry.
  * Audited network RPCs, ZDO portal mappings, and headless UI isolation against game version 1.0.15.

# 2.0.7 - Scene Transition & Portal Target Exception Hardening
* **Scene Transition Exception Resolution**:
  * Fixed `ArgumentException: The scene is invalid` thrown by `Environment.IsHeadless` when queried during active scene loading and logout transitions.
  * Cached headless state in `Environment.IsHeadless` and implemented a protected fallback to `SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null`.
  * Updated `PortalConfigurationPanel.InitialiseUI()` to reference the cached `Environment.IsHeadless` property rather than querying `GUIManager.IsHeadless()` directly.
* **Portal Lookup Null-Safety & Dictionary Resilience**:
  * Replaced unsafe dictionary indexer (`knownPortals[id]`) in `KnownPortalsManager.GetKnownPortalById(ZDOID id)` with `knownPortals.TryGetValue(id, out var portal) ? portal : null` to avoid `KeyNotFoundException`.
  * Added null guards across all callers (`KnownPortal.GetFriendlyTargetName()`, `XPortalNetworks.OnPrePortalHover()`, `XPortalNetworks.OnPortalRequestText()`, `XPortalNetworks.OnPortalDestroyed()`, `ServerEvents.RPC_AddOrUpdateRequest()`, and `PortalConfigurationPanel.ResolveInitialDestinationNetworkOwnerId()`).
* **Map Ping Hardening**:
  * Guarded `SendToClient.PingMap()` against null `ZRoutedRpc.instance` and null `UserInfo.GetLocalUser()` instances.
  * Added exception handling and fallback name string assignment to prevent UI cancellation during map ping requests.

# 2.0.6 - Splash Window Updates & Valheim 1.0.14 Alignment
* **Splash Window Updates**:
  * Updated telemetry default to unchecked on first launch (Opt-In).
  * Added Send Error Logs toggle (Opt-Out) to capture anonymous crash diagnostics and error reports.
  * Added in-game scrollable Privacy Policy overlay with responsive mouse wheel support.
  * Added interactive tooltip data disclaimers on checkbox hover.
* **Valheim 1.0.14 Alignment**:
  * Aligned publicized game assembly and UnityEngine references to Valheim 1.0.14.
  * Updated internalized Vapok.Valheim.Common dependency to 3.12.1014.

# 2.0.5 - Jewelcrafting Font Compatibility
* **Compatibility Fix**: Fixed issue where Jewelcrafting packages its own font which was overriding part of a vanilla font, causing the Splash screen to appear blank.
* **Vapok.Common Dependency Bump**: Updated internalized dependency to `Vapok.Valheim.Common` 3.11.1012.

# 2.0.4 - Updated README with Telemetry Information
* **Documentation Update**: Updated the README.md with Anonymous Telemetry and Privacy section per request of mod stores.
* **Vapok.Common Dependency Bump**: Updated internalized dependency to `Vapok.Valheim.Common` 3.9.1012.

# 2.0.3 - Unified Splash Screen & Telemetry Controls
* **Unified Startup Splash Screen & Telemetry**:
  * Updated `Vapok.Valheim.Common` dependency reference to `v3.5.1012`.
  * Registered mod metadata with centralized `ModSplashManager`.
  * Added `ShowSplashOnStartup` and `Enable Anonymous Telemetry` configuration bindings to `ConfigRegistry`.

# 2.0.1 - Dependency & Compatibility Maintenance
* **Runtime & Dependency Updates**:
  * Synchronized package manifest and project references with Jotunn `2.30.0` and BepInEx `5.4.2350`.
  * Verified build pipeline and ILRepack bundling with `Vapok.Valheim.Common` `3.2.1012`.
* **Compatibility & Documentation**:
  * Validated portal destination selection UI and network configuration hot-reloading against current Valheim 1.0 builds.
  * Standardized mod documentation, changelog tiers, and release staging.

# 2.0.0 - Portal Networks & Valheim 1.0+ Overhaul
* **Portal Networks Architecture**:
  * Overhauled portal mechanics to introduce an expansive multi-tier **Portal Networks** system:
    * **Global / Public Network**: Accessible to all players on the server without restriction.
    * **Player Networks & Private Portals**: Dedicated per-player network channels with private portal protection to restrict unauthorized access.
    * **Custom Named Networks**: Dynamic support for up to 15 server-defined custom networks configured in `xportal_networks.json` with live hot-reloading support.
* **Server Administration & Permission Controls**:
  * Implemented permission checks restricting portal deconstruction and destruction to the original creator or authenticated server admins.
  * Synchronized portal network configurations and permission sets strictly across dedicated servers via Jotunn ServerSync.
* **Valheim 1.0 Compatibility & Core Updates**:
  * Updated assembly references for Valheim 1.0 (`1.0.12`), BepInEx 5.4.2350, and Jotunn 2.30.0.
  * Rebuilt on .NET Framework 4.8.
  * Bundled `Vapok.Valheim.Common` 3.2.1012 via ILRepack.
* **UI, Gamepad & Networking Fixes**:
  * Resolved controller legend rendering artifacts and gamepad input focus issues in portal configuration dialogs.
  * Fixed dedicated server admin portal destruction permission validation.
  * Improved ZDO network key synchronization and portal pairing resolution to eliminate connection dropouts under high network load.

# 1.0.0 - Initial Portal Management Release
* Initial release of portal grouping and tag management mechanics.
