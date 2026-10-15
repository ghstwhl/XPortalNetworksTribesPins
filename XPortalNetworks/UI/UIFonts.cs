using System;
using Jotunn.Managers;
using TMPro;
using UnityEngine;

namespace XPortalNetworks.UI
{
    // Resolves the game's own AveriaSans font and keeps TextMeshPro's default font pointed at it.
    //
    // Why this exists: creating a TextMeshProUGUI without setting a font makes TMP fall back to
    // TMP_Settings.defaultFontAsset. Valheim ships no LiberationSans SDF, so when the default is
    // still pointed at it every creation logs "The LiberationSans SDF Font Asset was not found".
    // Resolving the game font first (and forcing it into the default) removes those warnings.
    internal static class UIFonts
    {
        private const string AveriaSansFontName = "Valheim-AveriaSansLibre";
        private const string LiberationSansName = "LiberationSans";
        private const string AveriaFallbackToken = "Averia";

        private static TMP_FontAsset _averiaSansFont;

        public static TMP_FontAsset GetAveriaSansFont()
        {
            if (_averiaSansFont != null)
            {
                return _averiaSansFont;
            }

            // Jöttun's cached reference is the cheapest and most reliable source.
            if (GUIManager.Instance != null && GUIManager.Instance.TMP_AveriaSansLibre != null)
            {
                _averiaSansFont = GUIManager.Instance.TMP_AveriaSansLibre;
            }

            // Otherwise borrow the font the HUD is already using.
            if (_averiaSansFont == null && Hud.instance != null && Hud.instance.m_hoverName != null && Hud.instance.m_hoverName.font != null)
            {
                _averiaSansFont = Hud.instance.m_hoverName.font;
            }

            // Fall back to a resource scan: exact name first...
            if (_averiaSansFont == null)
            {
                TMP_FontAsset[] fonts = Resources.FindObjectsOfTypeAll<TMP_FontAsset>();
                for (int i = 0; i < fonts.Length; i++)
                {
                    TMP_FontAsset candidate = fonts[i];
                    if (candidate != null && candidate.name == AveriaSansFontName)
                    {
                        _averiaSansFont = candidate;
                        break;
                    }
                }
            }

            // ...then any font whose name mentions Averia.
            if (_averiaSansFont == null)
            {
                TMP_FontAsset[] fonts = Resources.FindObjectsOfTypeAll<TMP_FontAsset>();
                for (int i = 0; i < fonts.Length; i++)
                {
                    TMP_FontAsset candidate = fonts[i];
                    if (candidate != null && candidate.name.IndexOf(AveriaFallbackToken, StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        _averiaSansFont = candidate;
                        break;
                    }
                }
            }

            if (_averiaSansFont != null)
            {
                EnsureDefaultFont(_averiaSansFont);
            }

            return _averiaSansFont;
        }

        public static void EnsureDefaultFont(TMP_FontAsset font)
        {
            if (font == null)
            {
                return;
            }

            if (TMP_Settings.defaultFontAsset == null ||
                TMP_Settings.defaultFontAsset.name.IndexOf(LiberationSansName, StringComparison.OrdinalIgnoreCase) >= 0)
            {
                TMP_Settings.defaultFontAsset = font;
            }
        }
    }
}
