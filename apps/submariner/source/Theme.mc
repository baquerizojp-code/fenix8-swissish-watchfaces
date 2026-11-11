import Toybox.Lang;

//! Colours and style ids for Rolex Submariner watch face.
//! Style ids must match resources/configs/watchface.xml.
module Theme {

    // Style presets matching watchface.xml
    const STYLE_BLACK        = 1; // 116610LN Classic Black Dial
    const STYLE_HULK         = 2; // 116610LV Sunburst Hulk Green Dial
    const STYLE_POLAR        = 3; // Polar White (Spark Edition)
    const STYLE_SPARK_BLACK  = 4; // Stealth Black (Spark Edition)
    const STYLE_SPARK_ORANGE = 5; // Full Spark Orange Dial

    // Palette: Steel, Metals, Dial, Garmin Spark Orange
    const DIAL_BLACK    = 0x000000;
    const SPARK_ORANGE  = 0xF39520; // Official Garmin Spark Orange
    // 18ct White Gold for Black (116610LN) and Hulk (116610LV)
    const WG_LIGHT       = 0xF5F8FC; // Specular highlight
    const WG_MID         = 0xAFBAC6; // Beveled facet reflection
    const WG_DARK        = 0x464E56; // Shadow facet / dark tone
    const WG_GROOVE      = 0x121416; // Razor-sharp dark perimeter outline

    // Standard Steel tones
    const STEEL_LIGHT    = 0xF0F4F8;
    const STEEL_BRIGHT   = 0xE0E0E0;
    const STEEL_MID      = 0xB0B8C2;
    const STEEL_DARK     = 0x485058;
    const STEEL_SHADOW   = 0x333333;
    const DARK_GROOVE    = 0x181A1C;

    // Phantom Black for Polar White (Style 3) and Full Spark Orange (Style 5)
    const PHANTOM_LIGHT  = 0x34383C;
    const PHANTOM_MID    = 0x1C1E22;
    const PHANTOM_DARK   = 0x080A0C;

    // Stealth Titanium for Stealth Black (Style 4)
    const STEALTH_LIGHT  = 0x8C949C;
    const STEALTH_MID    = 0x4C5258;
    const STEALTH_DARK   = 0x22262A;

    const DATE_BG        = 0xFFFFFF;
    const DATE_TEXT      = 0x000000;
    const CYCLOPS_LENS   = 0x99AACC;

    // Lume colors
    const LUME_WHITE       = 0xFFFFFF; // Pure white
    const LUME_CHROMALIGHT = 0xEEFFFF; // Crisp icy white/cyan Chromalight
    const TEXT_SILVER      = 0xEAEAEA;
    const TEXT_MUTED       = 0x999999;

    // Defaults: Default accent is Garmin Spark Orange
    const ACCENT_DEFAULT = 0xF39520;
    const DATA_DEFAULT   = 0xFFFFFF;

    //! Always-on mode luminosity percentage.
    //! Keeps screen emission well below the 10% AMOLED ceiling.
    const AOD_DIM_PERCENT = 28;

    //! Scale a 0xRRGGBB colour's brightness
    //! @param color The colour
    //! @param percent 0-100
    //! @return The dimmed colour
    function dim(color as Number, percent as Number) as Number {
        var r = ((color >> 16) & 0xFF) * percent / 100;
        var g = ((color >> 8) & 0xFF) * percent / 100;
        var b = (color & 0xFF) * percent / 100;
        return (r << 16) | (g << 8) | b;
    }
}
