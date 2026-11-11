import Toybox.Application.WatchFaceConfig;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Rolex Submariner Date Watch Face for Garmin fēnix 8 AMOLED 47mm (454x454).
//! Features 5 authentic dial variants:
//! - 1: Classic Black (116610LN)
//! - 2: Hulk Green (116610LV)
//! - 3: Polar White (Spark Edition)
//! - 4: Stealth Black (Spark Edition)
//! - 5: Full Spark Orange Dial
//! Includes authentic 2.5x Cyclops date window at 3 o'clock, Mercedes handset,
//! customizable Spark Orange seconds hand, and AMOLED Always-On burn-in protection.
class FaceView extends WatchUi.WatchFace {

    private const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    private const TWO_PI = 2.0 * Math.PI;

    //! True while the watch is in always-on (low power) mode
    private var _lowPower as Boolean = false;

    private var _style as Number = Theme.STYLE_BLACK;
    private var _accent as Number = Theme.ACCENT_DEFAULT;
    private var _lumeColor as Number = Theme.LUME_WHITE;

    //! Cached dial background bitmap
    private var _dialBitmap as Graphics.BitmapReference? = null;
    private var _loadedStyle as Number = -1;

    //! Cached date string to eliminate per-second allocations in onUpdate
    private var _cachedDay as Number = -1;
    private var _cachedDateStr as String = "";

    function initialize() {
        WatchFace.initialize();

        var settings = WatchFaceConfig.getSettings(null);
        if (settings != null) {
            applyConfig(settings);
        } else {
            loadDialBitmap();
        }
    }

    //! Load appropriate dial background bitmap for current style
    private function loadDialBitmap() as Void {
        if (_dialBitmap == null || _loadedStyle != _style) {
            _dialBitmap = null; // Release previous bitmap before loading new one to prevent memory spike
            try {
                if (_style == Theme.STYLE_HULK) {
                    _dialBitmap = WatchUi.loadResource(Rez.Drawables.DialGreen) as Graphics.BitmapReference;
                } else if (_style == Theme.STYLE_POLAR) {
                    _dialBitmap = WatchUi.loadResource(Rez.Drawables.DialPolar) as Graphics.BitmapReference;
                } else if (_style == Theme.STYLE_SPARK_BLACK) {
                    _dialBitmap = WatchUi.loadResource(Rez.Drawables.DialSparkBlack) as Graphics.BitmapReference;
                } else if (_style == Theme.STYLE_SPARK_ORANGE) {
                    _dialBitmap = WatchUi.loadResource(Rez.Drawables.DialSparkOrange) as Graphics.BitmapReference;
                } else {
                    _dialBitmap = WatchUi.loadResource(Rez.Drawables.DialBlack) as Graphics.BitmapReference;
                }
                _loadedStyle = _style;
            } catch (e) {
                _dialBitmap = null;
            }
        }
    }

    //! Apply a configuration from the on-device editor.
    //! @param config The settings to apply
    function applyConfig(config as WatchFaceConfig.Settings) as Void {
        var styleId = config.styleId;
        _style = (styleId != null) ? (styleId as Number) : Theme.STYLE_BLACK;

        var accent = config.accentColor;
        if ((accent != null) && (accent.color != null)) {
            _accent = accent.color as Number;
        } else {
            _accent = Theme.ACCENT_DEFAULT;
        }

        var data = config.complicationColor;
        if ((data != null) && (data.color != null)) {
            _lumeColor = data.color as Number;
        } else {
            _lumeColor = Theme.LUME_WHITE;
        }

        loadDialBitmap();
        WatchUi.requestUpdate();
    }

    //! Render the Submariner Date watch face
    //! @param dc The drawing context
    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2.0;
        var cy = height / 2.0;
        var r = width / 2.0;
        var clock = System.getClockTime();

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        // Cache date string whenever day changes
        updateCachedDate();

        if (_lowPower) {
            drawAlwaysOn(dc, cx, cy, r, clock);
            return;
        }

        // Full Power Mode: Draw authentic dial background
        loadDialBitmap();
        if (_dialBitmap != null) {
            dc.drawBitmap(0, 0, _dialBitmap);
        } else {
            dc.setColor(Theme.DIAL_BLACK, Theme.DIAL_BLACK);
            dc.clear();
        }

        // Render Cyclops Date Window at 3 o'clock
        drawDateWindow(dc, cx, cy);

        // Calculate Hand Angles (12 o'clock is -PI/2)
        var hourAngle = ((clock.hour % 12) + (clock.min / 60.0)) * (TWO_PI / 12.0) - (Math.PI / 2.0);
        var minAngle = (clock.min + (clock.sec / 60.0)) * (TWO_PI / 60.0) - (Math.PI / 2.0);
        var secAngle = clock.sec * (TWO_PI / 60.0) - (Math.PI / 2.0);

        // Hand metal frame: dark phantom on Polar White, polished steel on all other dials
        var handMetal = (_style == Theme.STYLE_POLAR) ? 0x1A1A1A : Theme.STEEL_BRIGHT;

        // Hands proportioned to full 454x454 dial
        drawMercedesHourHand(dc, cx, cy, hourAngle, r * 0.60, false, handMetal);
        drawSwordMinuteHand(dc, cx, cy, minAngle, r * 0.90, false, handMetal);
        // Lollipop second hand uses user accent (default: Spark Orange 0xF39520)
        drawSecondHand(dc, cx, cy, secAngle, r * 0.93);
        drawPinionCap(dc, cx, cy, false, handMetal);
    }

    //! Updates cached date string only when the day changes
    private function updateCachedDate() as Void {
        var now = Time.now();
        var dateInfo = Gregorian.info(now, Time.FORMAT_SHORT);
        if (_cachedDay != dateInfo.day) {
            _cachedDay = dateInfo.day;
            _cachedDateStr = dateInfo.day.format("%d");
        }
    }

    // =========================================================================
    // DATE APERTURE & CYCLOPS MAGNIFIER LENS
    // =========================================================================

    //! Draw authentic Rolex Submariner Date window at 3 o'clock with Cyclops magnifier
    private function drawDateWindow(dc as Graphics.Dc, cx as Numeric, cy as Numeric) as Void {
        var dateX = 380.0;
        var dateY = 231.0;
        var winW = 46.0;
        var winH = 26.0;
        var x0 = dateX - (winW / 2.0);
        var y0 = dateY - (winH / 2.0);

        // White date disc background
        dc.setColor(Theme.DATE_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0, y0, winW, winH);

        // Inner beveled window frame
        dc.setColor(Theme.STEEL_DARK, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x0, y0, winW, winH);

        // Live day of month numeral in bold black (using cached date string)
        dc.setColor(Theme.DATE_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dateX, dateY - 1, Graphics.FONT_TINY, _cachedDateStr, CENTER);

        // Authentic 2.5x Cyclops Magnifying Lens Overlay (raised bubble look)
        var cyclopsW = winW + 10.0;
        var cyclopsH = winH + 12.0;
        var cx0 = dateX - (cyclopsW / 2.0);
        var cy0 = dateY - (cyclopsH / 2.0);

        // Outer soft shadow
        dc.setColor(Theme.STEEL_SHADOW, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cx0 + 1, cy0 + 1, cyclopsW, cyclopsH, 5);

        // Cyclops curved glass refraction border
        dc.setColor(Theme.CYCLOPS_LENS, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(cx0, cy0, cyclopsW, cyclopsH, 5);

        // Upper specular glass reflection highlight
        dc.setColor(0xE8F0FE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx0 + 5, cy0 + 1, cx0 + cyclopsW - 5, cy0 + 1);
        dc.drawLine(cx0 + 1, cy0 + 5, cx0 + 1, cy0 + cyclopsH - 5);
    }

    // =========================================================================
    // HANDSET (MERCEDES, SWORD, LOLLIPOP SECOND)
    // =========================================================================

    //! Authentic Rolex "Mercedes" Hour Hand with 3D beveled 18ct white gold frame,
    //! luminous stem channel, three-pointed star framework, and triangular luminous spear tip.
    private function drawMercedesHourHand(dc as Graphics.Dc, cx as Numeric, cy as Numeric,
                                          angle as Numeric, length as Numeric,
                                          isLowPower as Boolean,
                                          metalColor as Number) as Void {
        var cosA = Math.cos(angle);
        var sinA = Math.sin(angle);

        var stemWidth = 7.6;
        var halfStem = stemWidth / 2.0;
        var discRadius = 18.2;
        var discDist = length * 0.68;

        var metalLight = Theme.WG_LIGHT;
        var metalMid   = Theme.WG_MID;
        var darkGroove = Theme.WG_GROOVE;
        var lume       = _lumeColor;

        if (isLowPower) {
            metalLight = Theme.dim(Theme.WG_LIGHT, Theme.AOD_DIM_PERCENT);
            metalMid   = Theme.dim(Theme.WG_MID, Theme.AOD_DIM_PERCENT);
            darkGroove = Theme.DIAL_BLACK;
            lume       = Theme.dim(_lumeColor, Theme.AOD_DIM_PERCENT);
        } else if (_style == Theme.STYLE_POLAR || _style == Theme.STYLE_SPARK_ORANGE) {
            metalLight = Theme.PHANTOM_LIGHT;
            metalMid   = Theme.PHANTOM_MID;
            darkGroove = Theme.PHANTOM_DARK;
        } else if (_style == Theme.STYLE_SPARK_BLACK) {
            metalLight = Theme.STEALTH_LIGHT;
            metalMid   = Theme.STEALTH_MID;
            darkGroove = Theme.STEALTH_DARK;
        }

        // 1. Base Pinion Eye Collar
        dc.setColor(metalLight, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 9.5);
        if (!isLowPower) {
            dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, 9.5);
        }

        // 2. White Gold Stem Silhouette
        var stemStart = 7.5;
        var stemEnd = discDist - discRadius + 2.0;
        var stemPoly = [
            rotatePoint(cx, cy, stemStart, -halfStem, cosA, sinA),
            rotatePoint(cx, cy, stemEnd, -halfStem, cosA, sinA),
            rotatePoint(cx, cy, stemEnd, halfStem, cosA, sinA),
            rotatePoint(cx, cy, stemStart, halfStem, cosA, sinA)
        ];
        dc.setColor(metalLight, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(stemPoly);

        if (!isLowPower) {
            // Lower half beveled facet reflection
            var stemFacet = [
                rotatePoint(cx, cy, stemStart, 0.4, cosA, sinA),
                rotatePoint(cx, cy, stemEnd, 0.4, cosA, sinA),
                rotatePoint(cx, cy, stemEnd, halfStem, cosA, sinA),
                rotatePoint(cx, cy, stemStart, halfStem, cosA, sinA)
            ];
            dc.setColor(metalMid, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(stemFacet);

            // Razor-sharp dark perimeter outline
            dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            for (var i = 0; i < 4; i++) {
                var p1 = stemPoly[i];
                var p2 = stemPoly[(i + 1) % 4];
                dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
            }
        }

        // 3. Stem Luminous Channel (as observed in user macro photos!)
        var stemLumeW = 2.2;
        var stemLume = [
            rotatePoint(cx, cy, 11.0, -stemLumeW, cosA, sinA),
            rotatePoint(cx, cy, discDist - discRadius - 0.5, -stemLumeW, cosA, sinA),
            rotatePoint(cx, cy, discDist - discRadius - 0.5, stemLumeW, cosA, sinA),
            rotatePoint(cx, cy, 11.0, stemLumeW, cosA, sinA)
        ];
        dc.setColor(lume, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(stemLume);
        if (!isLowPower) {
            dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            for (var i = 0; i < 4; i++) {
                var p1 = stemLume[i];
                var p2 = stemLume[(i + 1) % 4];
                dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
            }
        }

        // 4. Mercedes Outer Disc
        var discCenter = rotatePoint(cx, cy, discDist, 0.0, cosA, sinA);
        dc.setColor(metalLight, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(discCenter[0], discCenter[1], discRadius);
        if (!isLowPower) {
            dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(discCenter[0], discCenter[1], discRadius);
        }

        // 5. Mercedes Chromalight Luminous Core
        var innerR = discRadius - 2.5;
        dc.setColor(lume, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(discCenter[0], discCenter[1], innerR);

        // 6. Authentic Three-Point Mercedes Star Framework
        // Center hub pip
        dc.setColor(metalLight, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(discCenter[0], discCenter[1], 2.4);
        if (!isLowPower) {
            dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(discCenter[0], discCenter[1], 2.4);
        }

        // Ray 1: Forward ray (towards spear tip)
        var tipFwd = rotatePoint(cx, cy, discDist + innerR + 0.5, 0.0, cosA, sinA);
        dc.setPenWidth(3);
        dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(discCenter[0], discCenter[1], tipFwd[0], tipFwd[1]);
        dc.setPenWidth(2);
        dc.setColor(metalLight, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(discCenter[0], discCenter[1], tipFwd[0], tipFwd[1]);

        // Ray 2: 120 degrees counter-clockwise
        var rayAngle2 = angle + (2.0 * Math.PI / 3.0);
        var ray2X = discCenter[0] + innerR * Math.cos(rayAngle2);
        var ray2Y = discCenter[1] + innerR * Math.sin(rayAngle2);
        dc.setPenWidth(3);
        dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(discCenter[0], discCenter[1], ray2X, ray2Y);
        dc.setPenWidth(2);
        dc.setColor(metalLight, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(discCenter[0], discCenter[1], ray2X, ray2Y);

        // Ray 3: 120 degrees clockwise
        var rayAngle3 = angle - (2.0 * Math.PI / 3.0);
        var ray3X = discCenter[0] + innerR * Math.cos(rayAngle3);
        var ray3Y = discCenter[1] + innerR * Math.sin(rayAngle3);
        dc.setPenWidth(3);
        dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(discCenter[0], discCenter[1], ray3X, ray3Y);
        dc.setPenWidth(2);
        dc.setColor(metalLight, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(discCenter[0], discCenter[1], ray3X, ray3Y);
        dc.setPenWidth(1);

        // 7. Faceted Spear Tip with Triangular Luminous Insert
        var spearBase = discDist + discRadius - 2.8;
        var spearPoly = [
            rotatePoint(cx, cy, spearBase, -4.8, cosA, sinA),
            rotatePoint(cx, cy, length, 0.0, cosA, sinA),
            rotatePoint(cx, cy, spearBase, 4.8, cosA, sinA)
        ];
        dc.setColor(metalLight, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(spearPoly);

        if (!isLowPower) {
            var spearFacet = [
                rotatePoint(cx, cy, spearBase, 0.0, cosA, sinA),
                rotatePoint(cx, cy, length, 0.0, cosA, sinA),
                rotatePoint(cx, cy, spearBase, 4.8, cosA, sinA)
            ];
            dc.setColor(metalMid, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(spearFacet);

            dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
            for (var b = 0; b < 3; b++) {
                var nextB = (b + 1) % 3;
                dc.drawLine(spearPoly[b][0], spearPoly[b][1], spearPoly[nextB][0], spearPoly[nextB][1]);
            }
        }

        // Triangular Luminous Insert inside the Spear Tip! (as seen in macro photos)
        var spearLume = [
            rotatePoint(cx, cy, spearBase + 1.2, -2.6, cosA, sinA),
            rotatePoint(cx, cy, length - 3.8, 0.0, cosA, sinA),
            rotatePoint(cx, cy, spearBase + 1.2, 2.6, cosA, sinA)
        ];
        dc.setColor(lume, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(spearLume);
        if (!isLowPower) {
            dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
            for (var s = 0; s < 3; s++) {
                var nextS = (s + 1) % 3;
                dc.drawLine(spearLume[s][0], spearLume[s][1], spearLume[nextS][0], spearLume[nextS][1]);
            }
        }
    }

    //! Sword Minute Hand with 3D beveled frame, chisel tip, and continuous luminous channel.
    private function drawSwordMinuteHand(dc as Graphics.Dc, cx as Numeric, cy as Numeric,
                                         angle as Numeric, length as Numeric,
                                         isLowPower as Boolean,
                                         metalColor as Number) as Void {
        var cosA = Math.cos(angle);
        var sinA = Math.sin(angle);

        var width = 8.2;
        var halfW = width / 2.0;
        var tipDist = length - 8.5;
        var tailDist = -8.0;

        var metalLight = Theme.WG_LIGHT;
        var metalMid   = Theme.WG_MID;
        var darkGroove = Theme.WG_GROOVE;
        var lume       = _lumeColor;

        if (isLowPower) {
            metalLight = Theme.dim(Theme.WG_LIGHT, Theme.AOD_DIM_PERCENT);
            metalMid   = Theme.dim(Theme.WG_MID, Theme.AOD_DIM_PERCENT);
            darkGroove = Theme.DIAL_BLACK;
            lume       = Theme.dim(_lumeColor, Theme.AOD_DIM_PERCENT);
        } else if (_style == Theme.STYLE_POLAR || _style == Theme.STYLE_SPARK_ORANGE) {
            metalLight = Theme.PHANTOM_LIGHT;
            metalMid   = Theme.PHANTOM_MID;
            darkGroove = Theme.PHANTOM_DARK;
        } else if (_style == Theme.STYLE_SPARK_BLACK) {
            metalLight = Theme.STEALTH_LIGHT;
            metalMid   = Theme.STEALTH_MID;
            darkGroove = Theme.STEALTH_DARK;
        }

        // 1. Base Pinion Eye Ring
        dc.setColor(metalLight, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 9.0);
        if (!isLowPower) {
            dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, 9.0);
        }

        // 2. Outer White Gold Hand Silhouette
        var outerHand = [
            rotatePoint(cx, cy, tailDist, -halfW, cosA, sinA),
            rotatePoint(cx, cy, tipDist, -halfW, cosA, sinA),
            rotatePoint(cx, cy, length, 0.0, cosA, sinA),
            rotatePoint(cx, cy, tipDist, halfW, cosA, sinA),
            rotatePoint(cx, cy, tailDist, halfW, cosA, sinA)
        ];
        dc.setColor(metalLight, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(outerHand);

        if (!isLowPower) {
            // 3. 3D Beveled Lower Half Reflection
            var facet = [
                rotatePoint(cx, cy, tailDist, 0.4, cosA, sinA),
                rotatePoint(cx, cy, tipDist, 0.4, cosA, sinA),
                rotatePoint(cx, cy, length, 0.0, cosA, sinA),
                rotatePoint(cx, cy, tipDist, halfW, cosA, sinA),
                rotatePoint(cx, cy, tailDist, halfW, cosA, sinA)
            ];
            dc.setColor(metalMid, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(facet);

            // Crisp dark perimeter outline
            dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            for (var b = 0; b < 5; b++) {
                var nextB = (b + 1) % 5;
                dc.drawLine(outerHand[b][0], outerHand[b][1], outerHand[nextB][0], outerHand[nextB][1]);
            }
        }

        // 4. Continuous Chromalight Luminous Bar (ends with clean perpendicular cut before chisel point)
        var innerW = halfW - 1.6;
        var lumeStart = 16.5;
        var lumeEnd = tipDist - 1.5;
        var innerHand = [
            rotatePoint(cx, cy, lumeStart, -innerW, cosA, sinA),
            rotatePoint(cx, cy, lumeEnd, -innerW, cosA, sinA),
            rotatePoint(cx, cy, lumeEnd, innerW, cosA, sinA),
            rotatePoint(cx, cy, lumeStart, innerW, cosA, sinA)
        ];
        dc.setColor(lume, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(innerHand);
        if (!isLowPower) {
            dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            for (var i = 0; i < 4; i++) {
                var p1 = innerHand[i];
                var p2 = innerHand[(i + 1) % 4];
                dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
            }
        }
    }

    //! Slender Seconds Hand with circular luminous lollipop pip, round counterweight disc,
    //! and calibrated 3D needle thickness (Opción B: 3.6 px base -> 2.2 px tip).
    private function drawSecondHand(dc as Graphics.Dc, cx as Numeric, cy as Numeric,
                                    angle as Numeric, length as Numeric) as Void {
        var cosA = Math.cos(angle);
        var sinA = Math.sin(angle);

        var tailLen = 38.0;
        var lollipopDist = length * 0.70;
        var lollipopRadius = 8.0;

        // Needle color based on dial style and user accent
        var secColor = _accent;
        if (_style == Theme.STYLE_POLAR) {
            secColor = Theme.SPARK_ORANGE; // Signature Rolex Explorer II Polar orange needle
        } else if (_style == Theme.STYLE_SPARK_ORANGE) {
            secColor = Theme.WG_LIGHT; // Silver needle for high contrast on orange dial
        }

        var darkGroove = (_style == Theme.STYLE_POLAR) ? Theme.PHANTOM_DARK : Theme.WG_GROOVE;

        // 1. Calibrated Tapered Needle Body (Opción B: 3.6 px base -> 2.2 px tip)
        var halfSwBase = 1.8;
        var halfSwTip = 1.1;
        var needlePoly = [
            rotatePoint(cx, cy, -tailLen, -halfSwBase, cosA, sinA),
            rotatePoint(cx, cy, length, -halfSwTip, cosA, sinA),
            rotatePoint(cx, cy, length, halfSwTip, cosA, sinA),
            rotatePoint(cx, cy, -tailLen, halfSwBase, cosA, sinA)
        ];
        dc.setColor(secColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(needlePoly);

        // High-contrast dark perimeter outline for razor sharpness on black/light dials
        dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        for (var i = 0; i < 4; i++) {
            var p1 = needlePoly[i];
            var p2 = needlePoly[(i + 1) % 4];
            dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
        }

        // 2. Round Counterweight Disc on tail (matching genuine macro photos!)
        var counterDist = -23.0;
        var counterRadius = 5.2;
        var pCounter = rotatePoint(cx, cy, counterDist, 0.0, cosA, sinA);
        dc.setColor(secColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(pCounter[0], pCounter[1], counterRadius);
        dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(pCounter[0], pCounter[1], counterRadius);

        // 3. Luminous Lollipop Pip
        var pLollipop = rotatePoint(cx, cy, lollipopDist, 0.0, cosA, sinA);
        dc.setColor(secColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(pLollipop[0], pLollipop[1], lollipopRadius);
        dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(pLollipop[0], pLollipop[1], lollipopRadius);

        // Core lume fill
        var lume = (_style == Theme.STYLE_POLAR) ? Theme.LUME_WHITE : _lumeColor;
        dc.setColor(lume, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(pLollipop[0], pLollipop[1], lollipopRadius - 2.2);
    }

    //! Multi-tier polished center pinion cap
    private function drawPinionCap(dc as Graphics.Dc, cx as Numeric, cy as Numeric,
                                   isLowPower as Boolean,
                                   metalColor as Number) as Void {
        var metalLight = Theme.WG_LIGHT;
        var metalMid   = Theme.WG_MID;
        var darkGroove = Theme.WG_GROOVE;

        if (isLowPower) {
            metalLight = Theme.dim(Theme.WG_LIGHT, Theme.AOD_DIM_PERCENT);
            metalMid   = Theme.dim(Theme.WG_MID, Theme.AOD_DIM_PERCENT);
            darkGroove = Theme.DIAL_BLACK;
        } else if (_style == Theme.STYLE_POLAR || _style == Theme.STYLE_SPARK_ORANGE) {
            metalLight = Theme.PHANTOM_LIGHT;
            metalMid   = Theme.PHANTOM_MID;
            darkGroove = Theme.PHANTOM_DARK;
        } else if (_style == Theme.STYLE_SPARK_BLACK) {
            metalLight = Theme.STEALTH_LIGHT;
            metalMid   = Theme.STEALTH_MID;
            darkGroove = Theme.STEALTH_DARK;
        }

        dc.setColor(metalLight, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 8.5);
        if (!isLowPower) {
            dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, 8.5);
            dc.setColor(metalMid, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, 5.5);
            dc.setColor(metalLight, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, 3.2);
            dc.setColor(darkGroove, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, 1.4);
        }
    }

    // =========================================================================
    // ALWAYS-ON MODE (AMOLED LOW-POWER & ANTI-BURN-IN DRIFT)
    // =========================================================================

    //! AMOLED Always-On: Strict <10% luminance, drift against burn-in, zero background image
    private function drawAlwaysOn(dc as Graphics.Dc, cx as Numeric, cy as Numeric,
                                  r as Numeric, clock as System.ClockTime) as Void {
        // Pure black OLED background
        dc.setColor(Theme.DIAL_BLACK, Theme.DIAL_BLACK);
        dc.clear();

        // Pixel drift (±3 px) based on minute to guarantee zero OLED subpixel burn-in
        var dx = (clock.min % 7) - 3;
        var dy = ((clock.min / 7) % 7) - 3;
        var dcx = cx + dx;
        var dcy = cy + dy;

        // Draw dimmed geometric hour markers & AOD date
        drawHourMarkers(dc, dcx, dcy, r, true);

        // Hand angles (hour & minute only)
        var hourAngle = ((clock.hour % 12) + (clock.min / 60.0)) * (TWO_PI / 12.0) - (Math.PI / 2.0);
        var minAngle = clock.min * (TWO_PI / 60.0) - (Math.PI / 2.0);

        // Draw dimmed Mercedes and sword hands
        drawMercedesHourHand(dc, dcx, dcy, hourAngle, r * 0.60, true, Theme.STEEL_BRIGHT);
        drawSwordMinuteHand(dc, dcx, dcy, minAngle, r * 0.90, true, Theme.STEEL_BRIGHT);
        drawPinionCap(dc, dcx, dcy, true, Theme.STEEL_BRIGHT);
    }

    //! Draw geometric Maxi-Dial markers for Always-On mode
    private function drawHourMarkers(dc as Graphics.Dc, cx as Numeric, cy as Numeric,
                                     r as Numeric, isLowPower as Boolean) as Void {
        var rMarker = r * 0.76;
        var metalColor = isLowPower ? Theme.dim(Theme.STEEL_BRIGHT, Theme.AOD_DIM_PERCENT) : Theme.STEEL_BRIGHT;
        var lume = isLowPower ? Theme.dim(_lumeColor, Theme.AOD_DIM_PERCENT) : _lumeColor;

        for (var h = 1; h <= 12; h++) {
            var angle = h * (TWO_PI / 12.0) - (Math.PI / 2.0);
            var mx = cx + rMarker * Math.cos(angle);
            var my = cy + rMarker * Math.sin(angle);

            if (h == 3) {
                // Subtle dimmed date numeral at 3 o'clock in Always-On mode
                dc.setColor(lume, Graphics.COLOR_TRANSPARENT);
                dc.drawText(mx, my, Graphics.FONT_TINY, _cachedDateStr, CENTER);
                continue;
            }

            if (h == 12) {
                // Inverted Equilateral Triangle at 12 o'clock
                drawTriangleMarker(dc, mx, my, metalColor, lume, isLowPower);
            } else if (h == 6 || h == 9) {
                // Rectangular Batons at 6 and 9
                drawBatonMarker(dc, mx, my, angle, metalColor, lume, isLowPower);
            } else {
                // Circular Maxi-Dial Plots (Dots)
                drawDotMarker(dc, mx, my, metalColor, lume, isLowPower);
            }
        }
    }

    //! 12 o'clock Inverted Triangle Hour Marker
    private function drawTriangleMarker(dc as Graphics.Dc, mx as Numeric, my as Numeric,
                                        metalColor as Number, lume as Number,
                                        isLowPower as Boolean) as Void {
        var halfBase = 14.0;
        var height = 24.0;
        var topY = my - (height * 0.45);
        var tipY = my + (height * 0.55);

        var innerTri = [
            [mx - halfBase, topY],
            [mx + halfBase, topY],
            [mx, tipY]
        ];
        dc.setColor(lume, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(innerTri);
    }

    //! 6 and 9 o'clock Rectangular Baton Markers
    private function drawBatonMarker(dc as Graphics.Dc, mx as Numeric, my as Numeric,
                                     angle as Numeric, metalColor as Number, lume as Number,
                                     isLowPower as Boolean) as Void {
        var length = 26.0;
        var width = 11.0;
        var halfL = length / 2.0;
        var halfW = width / 2.0;

        var cosA = Math.cos(angle);
        var sinA = Math.sin(angle);

        var iPoints = [
            rotatePoint(mx, my, -halfL, -halfW, cosA, sinA),
            rotatePoint(mx, my, halfL, -halfW, cosA, sinA),
            rotatePoint(mx, my, halfL, halfW, cosA, sinA),
            rotatePoint(mx, my, -halfL, halfW, cosA, sinA)
        ];
        dc.setColor(lume, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(iPoints);
    }

    //! Circular Maxi-Dial Hour Plots
    private function drawDotMarker(dc as Graphics.Dc, mx as Numeric, my as Numeric,
                                   metalColor as Number, lume as Number,
                                   isLowPower as Boolean) as Void {
        dc.setColor(lume, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx, my, 7.5);
    }

    // =========================================================================
    // UTILITIES
    // =========================================================================

    //! Rotate a 2D offset vector [px, py] around (cx, cy)
    private function rotatePoint(cx as Numeric, cy as Numeric, px as Numeric, py as Numeric,
                                 cosA as Numeric, sinA as Numeric) as [Numeric, Numeric] {
        var rx = cx + px * cosA - py * sinA;
        var ry = cy + px * sinA + py * cosA;
        return [rx, ry];
    }

    //! The watch face is brought to foreground (returning from an app, activity, or glance)
    function onShow() as Void {
        updateCachedDate();
        loadDialBitmap();
        WatchUi.requestUpdate();
    }

    //! The watch face is moving to background (launching an app, activity, or glance)
    function onHide() as Void {
    }

    //! The watch is entering always-on mode
    function onEnterSleep() as Void {
        _lowPower = true;
        WatchUi.requestUpdate();
    }

    //! The user raised the watch
    function onExitSleep() as Void {
        _lowPower = false;
        WatchUi.requestUpdate();
    }
}
