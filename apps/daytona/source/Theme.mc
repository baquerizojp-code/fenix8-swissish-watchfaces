import Toybox.Graphics;
import Toybox.Lang;

//! Color and styling definitions for the Rolex Cosmograph Daytona watch face.
class Theme {

    // Dial Styles
    static const STYLE_PANDA = 1;      // White dial, black azurage subdials (126500LN-0001)
    static const STYLE_BLACK = 2;      // Black dial, steel azurage subdials (126500LN-0002)
    static const STYLE_SPARK = 3;      // Anthracite dial, Spark Orange subdials

    // Brand Colors
    static const COLOR_BLACK        = 0x000000;
    static const COLOR_WHITE        = 0xFFFFFF;
    static const COLOR_SPARK_ORANGE = 0xF39520;
    static const COLOR_RACE_RED     = 0xE02020;
    static const COLOR_STEEL_LIGHT  = 0xE8ECF0;
    static const COLOR_STEEL_MID    = 0xB0B8C0;
    static const COLOR_STEEL_DARK   = 0x485058;
    static const COLOR_CHROMALIGHT  = 0x00E5FF;
    static const COLOR_DARK_GROOVE  = 0x1A1A1A;

    static const COLOR_PANDA_NEEDLE = 0x1A1C20;
    static const COLOR_PANDA_TEXT   = 0x15181C;
    static const COLOR_CHROMALIGHT_WHITE = 0xFFFFFF;

    // Subdial Radius and Needle Length
    static const SUB_RADIUS = 50.0;
    static const SUB_NEEDLE_LEN = 51.0;

    //! Returns exact calibrated subdial center coordinates for each dial style [Sub9, Sub6, Sub3]
    //! Guaranteed subpixel alignment with printed dial hubs.
    static function getSubdialCenters(style as Number) as Array<Array<Float> > {
        if (style == STYLE_PANDA) {
            return [
                [118.0, 218.5], // Sub 9 (Battery)
                [226.5, 335.0], // Sub 6 (Steps)
                [335.0, 218.5]  // Sub 3 (HR)
            ];
        } else if (style == STYLE_BLACK) {
            return [
                [123.0, 215.5],
                [226.5, 331.5],
                [330.0, 215.5]
            ];
        } else { // STYLE_SPARK
            return [
                [119.5, 212.5],
                [227.0, 330.0],
                [334.5, 212.5]
            ];
        }
    }

    // AOD Dimming factor (keep under 10% luminance limit)
    static const AOD_DIM_PERCENT = 0.28;

    //! Dims a 24-bit RGB color by a given factor [0.0 - 1.0] for AMOLED AOD protection.
    //! @param color 24-bit 0xRRGGBB color
    //! @param factor 0.0 (black) to 1.0 (full brightness)
    //! @return Dimmed color
    static function dim(color as Number, factor as Float) as Number {
        var r = (((color >> 16) & 0xFF) * factor).toNumber();
        var g = (((color >> 8) & 0xFF) * factor).toNumber();
        var b = ((color & 0xFF) * factor).toNumber();
        return (r << 16) | (g << 8) | b;
    }
}
