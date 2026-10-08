namespace Mod
{
    public static class Info
    {
        // This is *the* place to edit plugin details. Everywhere else will be generated based on this info.
        public const string GUID = "ghostwheel.mods.xportalnetworkstribespins";
        public const string HarmonyGUID = GUID + ".harmony";
        // The GUID this mod was published under before 3.0.0. BepInEx names the plugin's config file after
        // the GUID (`<GUID>.cfg`), so this is kept only to carry an existing
        // `vapok.mods.xportalnetworks.cfg` over to the new file name - see
        // XPortalNetworksConfig.MigrateLegacyConfigFile. Never reuse it as a plugin GUID.
        public const string LegacyGUID = "vapok.mods.xportalnetworks";
        public const string Author = "ghstwhl";
        // NOTE: Name is the plugin's identity - the portal ZDO keys (XPortalNetworksTribesPins_TargetId, ...)
        // and the RPC names are derived from it.
        public const string Name = "XPortalNetworksTribesPins";
        // The plugin Name (and with it the ZDO key prefix, and the folder the legacy portal-network JSON is
        // looked for in) that this mod used before 3.0.0. Existing world saves still carry those keys, so
        // they are read as a fallback and kept in sync - see ZdoTools. Never reintroduce it as a plugin Name.
        public const string LegacyName = "XPortalNetworks";
        // The human-readable product name. `Name` above is the technical identity (plugin name, ZDO key
        // prefix, Thunderstore/GitHub package name) and stays glued to `ghostwheel.mods.xportalnetworkstribespins`;
        // `HumanName` is what prose should call the mod - README descriptions, the generated store docs and
        // the issue templates. Never use it for ZDO keys, RPC names, URLs, manifests or file names.
        public const string HumanName = "XPortal Networks Tribes Pins";
        // This project's own repository. The original mod it is built upon lives at
        // https://github.com/Vapok/XPortalNetworks and is credited in README.md and REFERENCES.md.
        public const string GitHubRepo = "ghstwhl/XPortalNetworksTribesPins";
        // Thunderstore identity of the published package (the team name differs from the GitHub account).
        // These drive the generated install links and the build's package staging folder.
        public const string ThunderstoreTeam = "NorCal_Nerds";
        public const string ThunderstorePackage = "XPortalNetworksTribesPins";
        public const string Version = "3.1.2";
        public const string Description = "Select portal destination from a list of existing portals with custom networks with private portal and tribe restrictions. No more tag pairing, and no more portal hubs!  Also manages map pins for the portals a player is allowed to use.";
        public const string WebsiteUrl = "https://github.com/" + GitHubRepo;
        public const int NexusId = 4092;
        public const string BepInExPackVersion = "5.4.2350";
        public const string JotunnVersion = Jotunn.Main.Version;
    }
}
