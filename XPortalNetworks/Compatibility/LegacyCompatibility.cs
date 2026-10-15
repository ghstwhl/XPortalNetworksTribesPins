using BepInEx;
using BepInEx.Bootstrap;
using HarmonyLib;

namespace XPortalNetworks.Compatibility
{
    // Neutralises older XPortal plugins when one is loaded alongside this mod, so two copies of the
    // portal UI cannot both patch the same methods and fight over the same pieces, menus and ZDO keys.
    //
    // Targets:
    //  * `yay.spikehimself.xportal`    - the original mod this whole lineage descends from (the same
    //    target the upstream mod neutralises since its v2.0.12 "Legacy Mod Coexistence" release).
    //  * `vapok.mods.xportalnetworks`  - the upstream mod this fork is based on, and the plugin id this
    //    fork itself registered under until 3.0.0 (see Mod.Info.LegacyGUID). A player running the
    //    upstream mod and this fork together would otherwise get two portal menus.
    //
    // "Neutralise" = disable the legacy plugin instance and remove its Harmony patches. Both ids are
    // declared as soft BepInDependencies on the plugin class, so BepInEx loads this plugin *after* them
    // and their instances exist by the time this runs. The work is idempotent and, when neither legacy
    // plugin is installed, does nothing.
    internal static class LegacyCompatibility
    {
        public const string LegacyXPortalPluginGuid = "yay.spikehimself.xportal";
        public const string UpstreamXPortalPluginGuid = "vapok.mods.xportalnetworks";

        private const string LegacyXPortalHarmonyGuid = "yay.spikehimself.xportal.harmony";
        private const string UpstreamXPortalHarmonyGuid = "vapok.mods.xportalnetworks.harmony";

        private static bool _neutralized;

        public static void NeutralizeLegacyXPortal()
        {
            if (_neutralized)
            {
                return;
            }

            Neutralize(LegacyXPortalPluginGuid, LegacyXPortalHarmonyGuid);
            Neutralize(UpstreamXPortalPluginGuid, UpstreamXPortalHarmonyGuid);

            _neutralized = true;
        }

        private static void Neutralize(string pluginGuid, string harmonyGuid)
        {
            if (!Chainloader.PluginInfos.TryGetValue(pluginGuid, out PluginInfo legacyPlugin))
            {
                return;
            }

            if (legacyPlugin != null && legacyPlugin.Instance != null)
            {
                legacyPlugin.Instance.enabled = false;
            }

            Harmony.UnpatchID(harmonyGuid);

            Log.Warning($"Detected legacy XPortal plugin '{pluginGuid}'. Disabled it and removed its patches to prevent conflicts with {Mod.Info.Name}.");
        }
    }
}
