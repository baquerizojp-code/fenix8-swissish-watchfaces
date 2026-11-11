import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application.WatchFaceConfig;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

//! Rolex Cosmograph Daytona Watch Face for Garmin fēnix 8 AMOLED 47mm (454x454).
//! Features 3 authentic dial variants:
//! - 1: Daytona Panda (126500LN-0001) [White lacquer dial, black azurage subdials]
//! - 2: Daytona Classic Black (126500LN-0002) [Black lacquer dial, steel azurage subdials]
//! - 3: Daytona Spark Orange Racing [Anthracite dial, Garmin Spark Orange 0xF39520 subdials]
//!
//! Subdial Architecture (Option 3 - Hybrid Luxury):
//! - 9 o'clock Subdial: Battery reserve needle (sweeps counter-clockwise as battery drains) + Rolex font ("85%")
//! - 6 o'clock Subdial: Daily steps needle (sweeps clockwise towards daily goal) + Rolex font ("8,420")
//! - 3 o'clock Subdial: Heart rate gauge needle (calibrated dynamic gauge 40-180 bpm) + Rolex font ("72 bpm")
//! Full AMOLED Always-On protection (< 10% screen luminance and burn-in drift).
class FaceView extends WatchUi.WatchFace {

    private const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    private const TWO_PI = 2.0 * Math.PI;

    private var _lowPower as Boolean = false;

    private var _style as Number = Theme.STYLE_PANDA;
    private var _accent as Number = Theme.COLOR_RACE_RED;
    private var _lumeColor as Number = Theme.COLOR_WHITE;

    //! Cached dial background bitmap
    private var _dialBitmap as Graphics.BitmapReference? = null;
    private var _loadedStyle as Number = -1;

    //! Custom Rolex Cosmograph typography font
    private var _rolexFont as Graphics.FontReference? = null;
    //! Scalable vector font for smooth, antialiased curved subdial text
    private var _radialFont as Graphics.VectorFont? = null;

    //! Cached sensor metrics
    private var _cachedSteps as Number = 0;
    private var _cachedHr as Number = 0;
    private var _cachedBattery as Number = -1;

    //! Dynamic Complication IDs for each of the 3 Daytona subdials
    private var _compSlot1Id as Complications.Id = new Complications.Id(Complications.COMPLICATION_TYPE_BATTERY);
    private var _compSlot2Id as Complications.Id = new Complications.Id(Complications.COMPLICATION_TYPE_STEPS);
    private var _compSlot3Id as Complications.Id = new Complications.Id(Complications.COMPLICATION_TYPE_HEART_RATE);

    function initialize() {
        WatchFace.initialize();

        loadRolexFont();

        _style = Theme.STYLE_PANDA;
        _accent = Theme.COLOR_RACE_RED;
        loadDialBitmap();
    }

    //! Lifecycle hook when layout is loaded
    function onLayout(dc as Graphics.Dc) as Void {
        var settings = WatchFaceConfig.getSettings(null);
        if (settings != null) {
            applyConfig(settings);
        }

        if (Toybox has :Complications && Complications has :subscribeToUpdates) {
            try {
                Complications.subscribeToUpdates(_compSlot1Id);
                Complications.subscribeToUpdates(_compSlot2Id);
                Complications.subscribeToUpdates(_compSlot3Id);
                Complications.registerComplicationChangeCallback(method(:onComplicationChanged));
            } catch (e) {
            }
        }
    }

    //! Allows cycling/switching styles
    function setStyle(s as Number) as Void {
        _style = s;
        _accent = (_style == Theme.STYLE_SPARK) ? Theme.COLOR_SPARK_ORANGE : Theme.COLOR_RACE_RED;
        loadDialBitmap();
        WatchUi.requestUpdate();
    }

    //! Returns current style for delegate touch detection
    function getStyle() as Number {
        return _style;
    }

    //! Loads typography fonts (both custom BMFont and scalable vector font)
    private function loadRolexFont() as Void {
        if (_radialFont == null && (Graphics has :getVectorFont)) {
            try {
                var fontOpts = {
                    :face => ["RobotoCondensedBold", "RobotoMedium", "RobotoRegular"],
                    :size => 18
                } as Graphics.VectorFontOptions;
                _radialFont = Graphics.getVectorFont(fontOpts);
            } catch (e) {
                _radialFont = null;
            }
        }
        if (_rolexFont == null) {
            try {
                _rolexFont = WatchUi.loadResource(Rez.Fonts.RolexFont) as Graphics.FontReference;
            } catch (e) {
                _rolexFont = null;
            }
        }
    }

    //! Load appropriate dial background bitmap for current style
    private function loadDialBitmap() as Void {
        if (_dialBitmap == null || _loadedStyle != _style) {
            _dialBitmap = null; // Free previous bitmap before loading new to avoid memory spike
            try {
                if (_style == Theme.STYLE_BLACK) {
                    _dialBitmap = WatchUi.loadResource(Rez.Drawables.DialBlack) as Graphics.BitmapReference;
                } else if (_style == Theme.STYLE_SPARK) {
                    _dialBitmap = WatchUi.loadResource(Rez.Drawables.DialSpark) as Graphics.BitmapReference;
                } else {
                    _dialBitmap = WatchUi.loadResource(Rez.Drawables.DialPanda) as Graphics.BitmapReference;
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
        _style = (styleId != null) ? (styleId as Number) : Theme.STYLE_PANDA;

        var accent = config.accentColor;
        if ((accent != null) && (accent.color != null)) {
            _accent = accent.color as Number;
        } else {
            _accent = (_style == Theme.STYLE_SPARK) ? Theme.COLOR_SPARK_ORANGE : Theme.COLOR_RACE_RED;
        }

        var data = config.complicationColor;
        if ((data != null) && (data.color != null)) {
            _lumeColor = data.color as Number;
        } else {
            _lumeColor = Theme.COLOR_WHITE;
        }

        var complicationSettings = config.complicationSettings;
        if (complicationSettings != null) {
            var size = complicationSettings.size();
            for (var idx = 0; idx < size; ++idx) {
                var comp = complicationSettings[idx];
                var uid = comp.uniqueIdentifier;
                var cid = comp.complicationId;
                if (uid != null && cid != null) {
                    setSubdialComplication(uid, cid);
                }
            }
        }

        loadDialBitmap();
        WatchUi.requestUpdate();
    }

    //! Updates a subdial slot with a newly selected complication ID
    function setSubdialComplication(slotId as Number, newId as Complications.Id) as Void {
        var oldId = null;
        if (slotId == 1) {
            oldId = _compSlot1Id;
            _compSlot1Id = newId;
        } else if (slotId == 2) {
            oldId = _compSlot2Id;
            _compSlot2Id = newId;
        } else if (slotId == 3) {
            oldId = _compSlot3Id;
            _compSlot3Id = newId;
        }

        if (Toybox has :Complications && Complications has :subscribeToUpdates) {
            if (oldId != null && !oldId.equals(newId)) {
                try {
                    Complications.unsubscribeFromUpdates(oldId);
                    Complications.subscribeToUpdates(newId);
                } catch (e) {
                }
            }
        }
    }

    //! Callback when a subscribed complication publishes fresh data
    function onComplicationChanged(id as Complications.Id) as Void {
        WatchUi.requestUpdate();
    }

    //! Returns slot number (1, 2, 3) if touch coordinates fall within a subdial
    function getTappedSlot(x as Numeric, y as Numeric) as Number? {
        var centers = Theme.getSubdialCenters(_style);
        var hitRadiusSq = 55.0 * 55.0;

        for (var i = 0; i < 3; ++i) {
            var dx = x - centers[i][0];
            var dy = y - centers[i][1];
            if ((dx * dx + dy * dy) <= hitRadiusSq) {
                return (i + 1); // 1 = 9h, 2 = 6h, 3 = 3h
            }
        }
        return null;
    }

    //! Launches the native glance/app associated with a subdial complication
    function launchSubdialGlance(slotId as Number) as Boolean {
        if (Toybox has :Complications && Complications has :exitTo) {
            var compId = _compSlot1Id;
            if (slotId == 2) {
                compId = _compSlot2Id;
            } else if (slotId == 3) {
                compId = _compSlot3Id;
            }
            if (compId != null) {
                try {
                    Complications.exitTo(compId);
                    return true;
                } catch (e) {
                }
            }
        }
        return false;
    }

    //! Provides the subdial bounding box and drawable to the on-device editor
    function getComplication(complication as WatchFaceConfig.ComplicationRef) as WatchUi.ComplicationDrawableRef or Null {
        var slotId = complication.uniqueIdentifier;
        if (slotId == null) {
            return null;
        }

        var centers = Theme.getSubdialCenters(_style);
        var center = centers[0];
        if (slotId == 2) {
            center = centers[1];
        } else if (slotId == 3) {
            center = centers[2];
        }

        var drawable = new SubdialSlotDrawable(slotId, center[0], center[1], 45.0);
        return new WatchUi.ComplicationDrawableRef({
            :drawable => drawable,
            :boundingBox => drawable.getBoundingBox()
        });
    }

    //! Main rendering loop
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

        // Low Power (Always-On AMOLED) Mode
        if (_lowPower) {
            drawAlwaysOn(dc, cx, cy, r, clock);
            return;
        }

        // Full Power Mode: Draw authentic dial background
        loadDialBitmap();
        if (_dialBitmap != null) {
            dc.drawBitmap(0, 0, _dialBitmap);
        } else {
            dc.setColor(Theme.COLOR_BLACK, Theme.COLOR_BLACK);
            dc.clear();
        }

        // Update sensor data
        updateSensorData();

        // Render the 3 Daytona Subdials (Option 3: Hybrid Luxury with exact calibrated centers)
        drawSubdials(dc);

        // Calculate Main Hand Angles (12 o'clock is -PI/2)
        var hourAngle = ((clock.hour % 12) + (clock.min / 60.0)) * (TWO_PI / 12.0) - (Math.PI / 2.0);
        var minAngle = (clock.min + (clock.sec / 60.0)) * (TWO_PI / 60.0) - (Math.PI / 2.0);
        var secAngle = clock.sec * (TWO_PI / 60.0) - (Math.PI / 2.0);

        // Main Handset (Exact 1:1 replica of genuine Daytona 126500LN)
        drawDaytonaHourHand(dc, cx, cy, hourAngle, r * 0.58, false);
        drawDaytonaMinuteHand(dc, cx, cy, minAngle, r * 0.88, false);
        drawDaytonaChronoSecHand(dc, cx, cy, secAngle, r * 0.94);
        drawPinionCap(dc, cx, cy, false);
    }

    //! Updates sensor metrics (battery, steps, heart rate) without memory churn
    private function updateSensorData() as Void {
        // Battery
        var stats = System.getSystemStats();
        _cachedBattery = stats.battery.toNumber();

        // Steps
        var actInfo = ActivityMonitor.getInfo();
        _cachedSteps = (actInfo != null && actInfo.steps != null) ? (actInfo.steps as Number) : 0;

        // Heart Rate
        var hr = 0;
        var curActivity = Activity.getActivityInfo();
        if (curActivity != null && curActivity.currentHeartRate != null) {
            hr = curActivity.currentHeartRate as Number;
        } else if (ActivityMonitor has :getHeartRateHistory) {
            var hrHistory = ActivityMonitor.getHeartRateHistory(1, true);
            if (hrHistory != null) {
                var sample = hrHistory.next();
                if (sample != null && sample.heartRate != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                    hr = sample.heartRate as Number;
                }
            }
        }
        _cachedHr = hr;
    }

    //! Formats a number with comma separators (e.g. 8420 -> "8,420")
    private function formatNumberWithCommas(num as Number) as String {
        if (num < 1000) {
            return num.format("%d");
        }
        var thousands = num / 1000;
        var remainder = num % 1000;
        return thousands.format("%d") + "," + remainder.format("%03d");
    }

    //! Safely extracts a Number from an arbitrary object
    private function toNumberVal(val as Object?, defaultVal as Number) as Number {
        if (val != null) {
            if (val instanceof Lang.Number) {
                return val as Number;
            } else if (val instanceof Lang.Float || val instanceof Lang.Double || val instanceof Lang.Long) {
                return (val as Number or Float or Long or Double).toNumber();
            } else if (val instanceof Lang.String) {
                try {
                    var n = (val as String).toNumber();
                    if (n != null) {
                        return n;
                    }
                } catch (e) {
                }
            }
        }
        return defaultVal;
    }

    //! Safely extracts a Float from an arbitrary object
    private function toFloatVal(val as Object?, defaultVal as Float) as Float {
        if (val != null) {
            if (val instanceof Lang.Float) {
                return val as Float;
            } else if (val instanceof Lang.Number || val instanceof Lang.Double || val instanceof Lang.Long) {
                return (val as Number or Float or Long or Double).toFloat();
            } else if (val instanceof Lang.String) {
                try {
                    var f = (val as String).toFloat();
                    if (f != null) {
                        return f;
                    }
                } catch (e) {
                }
            }
        }
        return defaultVal;
    }

    // =========================================================================
    // SUBDIALS (OPTION 3: HYBRID LUXURY WITH CALIBRATED CENTERS)
    // =========================================================================

    //! Renders active needles and micro-digital text on the 3 Daytona subdials
    private function drawSubdials(dc as Graphics.Dc) as Void {
        var needleLen = Theme.SUB_NEEDLE_LEN;
        loadRolexFont();

        // Calibrated subdial centers for current style
        var centers = Theme.getSubdialCenters(_style);
        var s9 = centers[0];
        var s6 = centers[1];
        var s3 = centers[2];

        // Contrast colors tailored for each dial disc
        var textColor = (_style == Theme.STYLE_PANDA) ? Theme.COLOR_PANDA_TEXT : Theme.COLOR_WHITE;
        var needleColor = (_style == Theme.STYLE_PANDA) ? Theme.COLOR_PANDA_NEEDLE : ((_style == Theme.STYLE_SPARK) ? Theme.COLOR_SPARK_ORANGE : Theme.COLOR_STEEL_LIGHT);
        var hubColor = (_style == Theme.STYLE_PANDA) ? 0x2A2E34 : 0x1A1C20;
        var pivotColor = (_style == Theme.STYLE_PANDA) ? Theme.COLOR_STEEL_LIGHT : ((_style == Theme.STYLE_SPARK) ? Theme.COLOR_WHITE : Theme.COLOR_DARK_GROOVE);

        // Render each of the 3 subdials using its user-configured complication
        renderSubdialSlot(dc, s9[0], s9[1], 1, _compSlot1Id, needleLen, needleColor, hubColor, pivotColor, textColor);
        renderSubdialSlot(dc, s6[0], s6[1], 2, _compSlot2Id, needleLen, needleColor, hubColor, pivotColor, textColor);
        renderSubdialSlot(dc, s3[0], s3[1], 3, _compSlot3Id, needleLen, needleColor, hubColor, pivotColor, textColor);
    }

    //! Renders an individual dynamic subdial given its position and complication ID
    private function renderSubdialSlot(dc as Graphics.Dc, cx as Numeric, cy as Numeric,
                                       slotId as Number, compId as Complications.Id,
                                       needleLen as Numeric, needleColor as Number,
                                       hubColor as Number, pivotColor as Number,
                                       textColor as Number) as Void {
        var comp = null;
        if (Toybox has :Complications && Complications has :getComplication) {
            try {
                comp = Complications.getComplication(compId);
            } catch (e) {
                comp = null;
            }
        }

        var type = (comp != null) ? comp.getType() : null;
        var val = (comp != null) ? comp.value : null;
        var ranges = (comp != null) ? comp.ranges : null;
        var rSize = (ranges != null) ? (ranges as Array<Object?>).size() : 0;

        var angle = -Math.PI / 2.0; // Default 12 o'clock
        var text = "";

        // Evaluate according to complication type or slot fallback
        if (type == Complications.COMPLICATION_TYPE_BATTERY || (type == null && slotId == 1)) {
            var batt = toNumberVal(val, _cachedBattery);
            var frac = batt.toFloat() / 100.0;
            if (frac < 0.0) { frac = 0.0; }
            if (frac > 1.0) { frac = 1.0; }
            // Sweeps counter-clockwise as battery drains
            angle = -Math.PI / 2.0 - ((1.0 - frac) * TWO_PI);
            text = batt.format("%d") + "%";

        } else if (type == Complications.COMPLICATION_TYPE_STEPS || (type == null && slotId == 2)) {
            var steps = toNumberVal(val, _cachedSteps);
            var goal = 10000.0;
            if (ranges != null && rSize >= 2) {
                var maxR = (ranges as Array<Object?>)[rSize - 1];
                var rGoal = toFloatVal(maxR, 0.0);
                if (rGoal > 0.0) {
                    goal = rGoal;
                }
            } else {
                var actInfo = ActivityMonitor.getInfo();
                if (actInfo != null) {
                    var sg = actInfo.stepGoal;
                    if (sg != null && (sg as Number) > 0) {
                        goal = (sg as Number).toFloat();
                    }
                }
            }
            var frac = steps.toFloat() / goal;
            if (frac > 1.0) { frac = 1.0; }
            if (frac < 0.0) { frac = 0.0; }
            angle = (frac * TWO_PI) - (Math.PI / 2.0);
            text = formatNumberWithCommas(steps);

        } else if (type == Complications.COMPLICATION_TYPE_HEART_RATE || (type == null && slotId == 3)) {
            var hr = toNumberVal(val, _cachedHr);
            var frac = 0.0;
            if (hr > 40) {
                frac = (hr - 40).toFloat() / 140.0;
                if (frac > 1.0) { frac = 1.0; }
            }
            angle = (frac * 1.5 * Math.PI) + (Math.PI * 0.75);
            text = (hr > 0) ? (hr.format("%d") + " bpm") : "-- bpm";

        } else if (type == Complications.COMPLICATION_TYPE_FLOORS_CLIMBED) {
            var floors = toNumberVal(val, 0);
            var goal = 10.0;
            if (ranges != null && rSize >= 2) {
                var maxR = (ranges as Array<Object?>)[rSize - 1];
                var rGoal = toFloatVal(maxR, 0.0);
                if (rGoal > 0.0) {
                    goal = rGoal;
                }
            }
            var frac = floors.toFloat() / goal;
            if (frac > 1.0) { frac = 1.0; }
            if (frac < 0.0) { frac = 0.0; }
            angle = (frac * TWO_PI) - (Math.PI / 2.0);
            text = floors.format("%d") + " FLR";

        } else if (type == Complications.COMPLICATION_TYPE_CALORIES) {
            var cals = toNumberVal(val, 0);
            var goal = 2000.0;
            if (ranges != null && rSize >= 2) {
                var maxR = (ranges as Array<Object?>)[rSize - 1];
                var rGoal = toFloatVal(maxR, 0.0);
                if (rGoal > 0.0) {
                    goal = rGoal;
                }
            }
            var frac = cals.toFloat() / goal;
            if (frac > 1.0) { frac = 1.0; }
            if (frac < 0.0) { frac = 0.0; }
            angle = (frac * TWO_PI) - (Math.PI / 2.0);
            text = cals.format("%d") + " kcal";

        } else if (type == Complications.COMPLICATION_TYPE_BODY_BATTERY) {
            var bb = toNumberVal(val, 0);
            var frac = bb.toFloat() / 100.0;
            if (frac < 0.0) { frac = 0.0; }
            if (frac > 1.0) { frac = 1.0; }
            angle = (frac * TWO_PI) - (Math.PI / 2.0);
            text = "BB " + bb.format("%d");

        } else if (type == Complications.COMPLICATION_TYPE_STRESS) {
            var stress = toNumberVal(val, 0);
            var frac = stress.toFloat() / 100.0;
            if (frac < 0.0) { frac = 0.0; }
            if (frac > 1.0) { frac = 1.0; }
            angle = (frac * 1.5 * Math.PI) + (Math.PI * 0.75);
            text = "STRS " + stress.format("%d");

        } else if (type == Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE || type == Complications.COMPLICATION_TYPE_CURRENT_WEATHER) {
            // Retrieve authoritative temperature in Celsius directly from Toybox.Weather
            var tempC = null;
            if (Toybox has :Weather && Weather has :getCurrentConditions) {
                try {
                    var wCond = Weather.getCurrentConditions();
                    if (wCond != null && wCond.temperature != null) {
                        tempC = (wCond.temperature as Numeric).toNumber();
                    }
                } catch (e) {
                }
            }

            // If Weather module didn't return, check complication value
            if (tempC == null && val != null) {
                var num = toNumberVal(val, -999);
                if (num != -999) {
                    if (num > 45) {
                        // Value was in Fahrenheit (e.g. 75F), convert to Celsius
                        tempC = Math.round((num.toFloat() - 32.0) * 5.0 / 9.0).toNumber();
                    } else {
                        tempC = num;
                    }
                }
            }

            // Sensible fallback if no weather sync yet
            if (tempC == null) {
                tempC = 22;
            }

            // Calibrated dynamic thermometer gauge (-10C to 40C)
            var frac = (tempC.toFloat() + 10.0) / 50.0;
            if (frac < 0.0) { frac = 0.0; }
            if (frac > 1.0) { frac = 1.0; }
            angle = (frac * 1.5 * Math.PI) + (Math.PI * 0.75);

            // Clean Celsius readout (e.g. "24°C" or "22°C")
            text = tempC.format("%d") + "°C";

        } else if (type == Complications.COMPLICATION_TYPE_PULSE_OX) {
            var spo2 = toNumberVal(val, 98);
            var frac = (spo2 - 80.0) / 20.0;
            if (frac < 0.0) { frac = 0.0; }
            if (frac > 1.0) { frac = 1.0; }
            angle = (frac * TWO_PI) - (Math.PI / 2.0);
            text = spo2.format("%d") + "%";

        } else if (type == Complications.COMPLICATION_TYPE_ALTITUDE) {
            var alt = toNumberVal(val, 0);
            var frac = (alt % 1000).toFloat() / 1000.0;
            angle = (frac * TWO_PI) - (Math.PI / 2.0);
            text = alt.format("%d") + "m";

        } else if (type == Complications.COMPLICATION_TYPE_INTENSITY_MINUTES) {
            var mins = toNumberVal(val, 0);
            var frac = mins.toFloat() / 150.0;
            if (frac > 1.0) { frac = 1.0; }
            angle = (frac * TWO_PI) - (Math.PI / 2.0);
            text = mins.format("%d") + " min";

        } else if (type == Complications.COMPLICATION_TYPE_DATE || type == Complications.COMPLICATION_TYPE_WEEKDAY_MONTHDAY) {
            var now = Time.now();
            var gregInfo = Gregorian.info(now, Time.FORMAT_SHORT);
            var dayNum = gregInfo.day; // Number 1-31 (e.g. 28)

            // Sweep needle proportionally through days of the month (1 at 12h, 15 at 6h, 31 at 12h)
            var frac = (dayNum.toFloat() - 1.0) / 30.0;
            if (frac < 0.0) { frac = 0.0; }
            if (frac > 1.0) { frac = 1.0; }
            angle = (frac * TWO_PI) - (Math.PI / 2.0);

            // Clean, unambiguous date number (e.g. "28" or "28 SEP")
            if (type == Complications.COMPLICATION_TYPE_WEEKDAY_MONTHDAY) {
                var gregMed = Gregorian.info(now, Time.FORMAT_MEDIUM);
                text = dayNum.format("%d") + " " + gregMed.month.toString().toUpper();
            } else {
                text = dayNum.format("%d");
            }

        } else if (type == Complications.COMPLICATION_TYPE_CALENDAR_EVENTS) {
            angle = 0.0; // 3 o'clock position
            if (val != null) {
                var sVal = (val as Object).toString();
                text = (sVal.length() <= 10) ? sVal : sVal.substring(0, 10);
            } else {
                text = "CAL";
            }

        } else if (type == Complications.COMPLICATION_TYPE_SUNRISE || type == Complications.COMPLICATION_TYPE_SUNSET) {
            angle = (type == Complications.COMPLICATION_TYPE_SUNRISE) ? (Math.PI * 0.25) : (Math.PI * 0.75);
            if (val != null) {
                text = (val as Object).toString();
            } else {
                text = (type == Complications.COMPLICATION_TYPE_SUNRISE) ? "AM" : "PM";
            }

        } else if (type == Complications.COMPLICATION_TYPE_NOTIFICATION_COUNT) {
            var notifs = toNumberVal(val, 0);
            var frac = notifs.toFloat() / 10.0;
            if (frac > 1.0) { frac = 1.0; }
            angle = (frac * TWO_PI) - (Math.PI / 2.0);
            text = notifs.format("%d") + " NOTIF";

        } else if (type == Complications.COMPLICATION_TYPE_SLEEP_SCORE) {
            var score = toNumberVal(val, 0);
            var frac = score.toFloat() / 100.0;
            if (frac > 1.0) { frac = 1.0; }
            angle = (frac * TWO_PI) - (Math.PI / 2.0);
            text = "SLP " + score.format("%d");

        } else if (type == Complications.COMPLICATION_TYPE_RECOVERY_TIME) {
            var rec = toNumberVal(val, 0);
            var frac = rec.toFloat() / 72.0;
            if (frac > 1.0) { frac = 1.0; }
            angle = (frac * TWO_PI) - (Math.PI / 2.0);
            text = rec.format("%d") + "h";

        } else {
            // Generic Complication Handling (100% crash-proof)
            var frac = 0.5;
            if (ranges != null && rSize >= 2 && val != null) {
                var minV = toFloatVal((ranges as Array<Object?>)[0], 0.0);
                var maxV = toFloatVal((ranges as Array<Object?>)[rSize - 1], 100.0);
                if (maxV > minV) {
                    var curV = toFloatVal(val, minV);
                    frac = (curV - minV) / (maxV - minV);
                    if (frac < 0.0) { frac = 0.0; }
                    if (frac > 1.0) { frac = 1.0; }
                }
            } else if (val != null) {
                var numV = toFloatVal(val, -999.0);
                if (numV >= 0.0 && numV <= 100.0) {
                    frac = numV / 100.0;
                }
            }
            angle = (frac * TWO_PI) - (Math.PI / 2.0);

            if (val != null) {
                if (val instanceof Lang.Number || val instanceof Lang.Float || val instanceof Lang.Double || val instanceof Lang.Long) {
                    text = toNumberVal(val, 0).format("%d");
                } else {
                    var s = (val as Object).toString();
                    text = (s.length() <= 10) ? s : s.substring(0, 10);
                }
                var cUnit = (comp != null) ? comp.unit : null;
                if (cUnit != null) {
                    var u = (cUnit as Object).toString();
                    if (u.length() <= 4) {
                        text = text + " " + u;
                    }
                }
            } else {
                var sLabel = (comp != null) ? comp.shortLabel : null;
                if (sLabel != null) {
                    var s = (sLabel as Object).toString();
                    text = (s.length() <= 10) ? s : s.substring(0, 10);
                } else {
                    text = "--";
                }
            }
        }

        // Draw the authentic baton subdial needle
        drawSubdialNeedle(dc, cx, cy, angle, needleLen, needleColor, hubColor, pivotColor);

        // Draw the curved micro-text along the inner lower subdial track
        if (text != null && (text as String).length() > 0) {
            drawSubdialCurvedText(dc, cx, cy, text as String, textColor);
        }
    }

    //! Renders micro-digital text smoothly curved along the inner subdial circumference
    private function drawSubdialCurvedText(dc as Graphics.Dc, cx as Numeric, cy as Numeric,
                                          text as String, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (_radialFont != null && (dc has :drawRadialText)) {
            // Angle 270 deg (bottom / 6 o'clock of subdial), radius 35 px for ideal proportions
            // COUNTER_CLOCKWISE keeps characters upright along the bottom curve
            dc.drawRadialText(cx, cy, _radialFont as Graphics.VectorFont,
                              text, Graphics.TEXT_JUSTIFY_CENTER,
                              270, 35, Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);
        } else {
            // High-legibility crisp fallback
            var font = (_rolexFont != null) ? (_rolexFont as Graphics.FontReference) : Graphics.FONT_SYSTEM_XTINY;
            dc.drawText(cx, cy + 18, font, text, CENTER);
        }
    }

    //! Draws an authentic 1:1 replica of the Rolex Daytona subdial baton hand:
    //! - Clean circular center boss collar (no protruding tail, matching genuine Daytona photo)
    //! - Concentric metallic silver rivet with micro dark center axle pin
    //! - Substantial solid baton stem (width 5.2 px, halfW 2.6) matching photo thickness
    //! - Sharp lancet spear tip tapering in the final 7.5 px
    //! - Extends into the chapter ring track
    private function drawSubdialNeedle(dc as Graphics.Dc, cx as Numeric, cy as Numeric,
                                       angle as Numeric, length as Numeric,
                                       needleColor as Number, hubColor as Number, pivotColor as Number) as Void {
        var cosA = Math.cos(angle);
        var sinA = Math.sin(angle);

        // Baton geometry matching genuine Rolex Daytona subdial hand photo
        var tipDist = length;
        var taperStartDist = length - 7.5; // Sharp lancet spear tip over final 7.5 px
        var halfW = 2.6; // 5.2 px wide substantial solid baton stem

        var tip = rotatePoint(cx, cy, tipDist, 0.0, cosA, sinA);
        var taperLeft  = rotatePoint(cx, cy, taperStartDist, -halfW, cosA, sinA);
        var taperRight = rotatePoint(cx, cy, taperStartDist, halfW, cosA, sinA);
        var baseLeft  = rotatePoint(cx, cy, 3.0, -halfW, cosA, sinA);
        var baseRight = rotatePoint(cx, cy, 3.0, halfW, cosA, sinA);

        // 5-point baton polygon with sharp lancet spear tip
        var needlePoly = [baseLeft, taperLeft, tip, taperRight, baseRight];
        dc.setColor(needleColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(needlePoly);

        // Circular center boss hub (clean round collar, matching genuine Daytona photos)
        dc.setColor(hubColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 4.8);
        dc.setColor(needleColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, 4.8);

        // Concentric polished silver center rivet collar
        dc.setColor(pivotColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 2.4);

        // Microscopic dark center axle pin
        dc.setColor(Theme.COLOR_DARK_GROOVE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 1.0);
    }

    // =========================================================================
    // MAIN HANDSET (DAYTONA BATON HANDS & CHRONO SECONDS — EXACT 1:1 REPLICA)
    // =========================================================================

    //! Authentic Daytona Hour Baton Hand with two-zone inlay (black base + Chromalight lume),
    //! 3D faceted bevels, black central crease, and chisel tip.
    private function drawDaytonaHourHand(dc as Graphics.Dc, cx as Numeric, cy as Numeric,
                                         angle as Numeric, length as Numeric, isLowPower as Boolean) as Void {
        var cosA = Math.cos(angle);
        var sinA = Math.sin(angle);

        var stemW = 8.5;
        var halfW = stemW / 2.0;
        var tipDist = length - 6.0;
        var tailDist = -9.0;

        var metalLight = isLowPower ? Theme.dim(Theme.COLOR_STEEL_LIGHT, Theme.AOD_DIM_PERCENT) : Theme.COLOR_STEEL_LIGHT;
        var metalMid   = isLowPower ? Theme.dim(Theme.COLOR_STEEL_MID, Theme.AOD_DIM_PERCENT) : Theme.COLOR_STEEL_MID;
        var lume       = isLowPower ? Theme.dim(_lumeColor, Theme.AOD_DIM_PERCENT) : Theme.COLOR_CHROMALIGHT_WHITE;

        // 1. Outer white gold silhouette with triangular chisel tip and squared tail
        var body = [
            rotatePoint(cx, cy, tailDist, -halfW, cosA, sinA),
            rotatePoint(cx, cy, tipDist, -halfW, cosA, sinA),
            rotatePoint(cx, cy, length, 0.0, cosA, sinA),
            rotatePoint(cx, cy, tipDist, halfW, cosA, sinA),
            rotatePoint(cx, cy, tailDist, halfW, cosA, sinA)
        ];
        dc.setColor(metalLight, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(body);

        // 2. 3D beveled lower half reflection
        if (!isLowPower) {
            var facet = [
                rotatePoint(cx, cy, tailDist, 0.4, cosA, sinA),
                rotatePoint(cx, cy, tipDist, 0.4, cosA, sinA),
                rotatePoint(cx, cy, length, 0.0, cosA, sinA),
                rotatePoint(cx, cy, tipDist, halfW, cosA, sinA),
                rotatePoint(cx, cy, tailDist, halfW, cosA, sinA)
            ];
            dc.setColor(metalMid, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(facet);

            // Crisp dark perimeter outline matching macro photo
            dc.setColor(Theme.COLOR_DARK_GROOVE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            for (var b = 0; b < 5; b++) {
                var nextB = (b + 1) % 5;
                dc.drawLine(body[b][0], body[b][1], body[nextB][0], body[nextB][1]);
            }
        }

        // 3. Two-zone center channel matching genuine Daytona:
        // Zone A: Solid black lacquer base section (from r=5.0 to 33% length)
        // Zone B: Bright white Chromalight lume insert (from 33% to tipDist - 2.5)
        var inlayW = halfW - 1.2;
        var blackStart = 5.0;
        var blackEnd = length * 0.33;
        var lumeEnd = tipDist - 2.5;

        if (!isLowPower) {
            var blackBody = [
                rotatePoint(cx, cy, blackStart, -inlayW, cosA, sinA),
                rotatePoint(cx, cy, blackEnd, -inlayW, cosA, sinA),
                rotatePoint(cx, cy, blackEnd, inlayW, cosA, sinA),
                rotatePoint(cx, cy, blackStart, inlayW, cosA, sinA)
            ];
            dc.setColor(Theme.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(blackBody);
        }

        var lumeBody = [
            rotatePoint(cx, cy, blackEnd + 1.0, -inlayW, cosA, sinA),
            rotatePoint(cx, cy, lumeEnd, -inlayW, cosA, sinA),
            rotatePoint(cx, cy, lumeEnd, inlayW, cosA, sinA),
            rotatePoint(cx, cy, blackEnd + 1.0, inlayW, cosA, sinA)
        ];
        dc.setColor(lume, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(lumeBody);

        // 4. Fine black central crease line down the spine
        if (!isLowPower) {
            var pGroove1 = rotatePoint(cx, cy, blackEnd + 1.0, 0.0, cosA, sinA);
            var pGroove2 = rotatePoint(cx, cy, lumeEnd, 0.0, cosA, sinA);
            dc.setColor(Theme.COLOR_DARK_GROOVE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(pGroove1[0], pGroove1[1], pGroove2[0], pGroove2[1]);
        }
    }

    //! Authentic Daytona Minute Baton Hand with two-zone inlay (black base + Chromalight lume),
    //! 3D faceted bevels, black central crease, and chisel tip.
    private function drawDaytonaMinuteHand(dc as Graphics.Dc, cx as Numeric, cy as Numeric,
                                           angle as Numeric, length as Numeric, isLowPower as Boolean) as Void {
        var cosA = Math.cos(angle);
        var sinA = Math.sin(angle);

        var stemW = 7.4;
        var halfW = stemW / 2.0;
        var tipDist = length - 6.5;
        var tailDist = -9.0;

        var metalLight = isLowPower ? Theme.dim(Theme.COLOR_STEEL_LIGHT, Theme.AOD_DIM_PERCENT) : Theme.COLOR_STEEL_LIGHT;
        var metalMid   = isLowPower ? Theme.dim(Theme.COLOR_STEEL_MID, Theme.AOD_DIM_PERCENT) : Theme.COLOR_STEEL_MID;
        var lume       = isLowPower ? Theme.dim(_lumeColor, Theme.AOD_DIM_PERCENT) : Theme.COLOR_CHROMALIGHT_WHITE;

        // 1. Outer white gold silhouette with pointed chisel tip and squared tail
        var body = [
            rotatePoint(cx, cy, tailDist, -halfW, cosA, sinA),
            rotatePoint(cx, cy, tipDist, -halfW, cosA, sinA),
            rotatePoint(cx, cy, length, 0.0, cosA, sinA),
            rotatePoint(cx, cy, tipDist, halfW, cosA, sinA),
            rotatePoint(cx, cy, tailDist, halfW, cosA, sinA)
        ];
        dc.setColor(metalLight, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(body);

        // 2. 3D beveled lower half reflection
        if (!isLowPower) {
            var facet = [
                rotatePoint(cx, cy, tailDist, 0.4, cosA, sinA),
                rotatePoint(cx, cy, tipDist, 0.4, cosA, sinA),
                rotatePoint(cx, cy, length, 0.0, cosA, sinA),
                rotatePoint(cx, cy, tipDist, halfW, cosA, sinA),
                rotatePoint(cx, cy, tailDist, halfW, cosA, sinA)
            ];
            dc.setColor(metalMid, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(facet);

            // Crisp dark perimeter outline matching macro photo
            dc.setColor(Theme.COLOR_DARK_GROOVE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            for (var b = 0; b < 5; b++) {
                var nextB = (b + 1) % 5;
                dc.drawLine(body[b][0], body[b][1], body[nextB][0], body[nextB][1]);
            }
        }

        // 3. Two-zone center channel matching genuine Daytona:
        // Zone A: Solid black lacquer base section (from r=5.0 to 25% length)
        // Zone B: Bright white Chromalight lume insert (from 25% to tipDist - 2.5)
        var inlayW = halfW - 1.2;
        var blackStart = 5.0;
        var blackEnd = length * 0.25;
        var lumeEnd = tipDist - 2.5;

        if (!isLowPower) {
            var blackBody = [
                rotatePoint(cx, cy, blackStart, -inlayW, cosA, sinA),
                rotatePoint(cx, cy, blackEnd, -inlayW, cosA, sinA),
                rotatePoint(cx, cy, blackEnd, inlayW, cosA, sinA),
                rotatePoint(cx, cy, blackStart, inlayW, cosA, sinA)
            ];
            dc.setColor(Theme.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(blackBody);
        }

        var lumeBody = [
            rotatePoint(cx, cy, blackEnd + 1.0, -inlayW, cosA, sinA),
            rotatePoint(cx, cy, lumeEnd, -inlayW, cosA, sinA),
            rotatePoint(cx, cy, lumeEnd, inlayW, cosA, sinA),
            rotatePoint(cx, cy, blackEnd + 1.0, inlayW, cosA, sinA)
        ];
        dc.setColor(lume, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(lumeBody);

        // 4. Center spine groove
        if (!isLowPower) {
            var pGroove1 = rotatePoint(cx, cy, blackEnd + 1.0, 0.0, cosA, sinA);
            var pGroove2 = rotatePoint(cx, cy, lumeEnd, 0.0, cosA, sinA);
            dc.setColor(Theme.COLOR_DARK_GROOVE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawLine(pGroove1[0], pGroove1[1], pGroove2[0], pGroove2[1]);
        }
    }

    //! Chronograph Central Seconds Needle Hand with acute arrowhead pip & authentic teardrop balance
    private function drawDaytonaChronoSecHand(dc as Graphics.Dc, cx as Numeric, cy as Numeric,
                                              angle as Numeric, length as Numeric) as Void {
        var cosA = Math.cos(angle);
        var sinA = Math.sin(angle);

        // On white dial Panda, default to crisp high-contrast steel/dark needle (unless custom accent chosen)
        var secColor = (_style == Theme.STYLE_PANDA && _accent == Theme.COLOR_RACE_RED)
                     ? Theme.COLOR_STEEL_DARK
                     : ((_style == Theme.STYLE_BLACK && _accent == Theme.COLOR_RACE_RED)
                        ? Theme.COLOR_STEEL_LIGHT
                        : _accent);

        var tip = rotatePoint(cx, cy, length, 0.0, cosA, sinA);
        var tailBase = rotatePoint(cx, cy, -26.5, 0.0, cosA, sinA);

        // 1. Thin central needle shaft
        dc.setColor(secColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(tailBase[0], tailBase[1], tip[0], tip[1]);

        // 2. Triangular Chromalight Arrowhead Pip at ~73% radius
        var pipDist = length * 0.73;
        var pipPoly = [
            rotatePoint(cx, cy, pipDist + 9.5, 0.0, cosA, sinA),
            rotatePoint(cx, cy, pipDist - 4.5, -3.6, cosA, sinA),
            rotatePoint(cx, cy, pipDist - 4.5, 3.6, cosA, sinA)
        ];
        dc.setColor(secColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pipPoly);

        // Pure white Chromalight lume fill inside arrowhead
        var lumePoly = [
            rotatePoint(cx, cy, pipDist + 7.0, 0.0, cosA, sinA),
            rotatePoint(cx, cy, pipDist - 3.0, -2.2, cosA, sinA),
            rotatePoint(cx, cy, pipDist - 3.0, 2.2, cosA, sinA)
        ];
        dc.setColor(Theme.COLOR_CHROMALIGHT_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(lumePoly);

        // 3. Authentic teardrop / leaf counterweight balance matching genuine Daytona photos
        var cwPoly = [
            rotatePoint(cx, cy, -8.0, 0.0, cosA, sinA),
            rotatePoint(cx, cy, -12.0, -1.8, cosA, sinA),
            rotatePoint(cx, cy, -16.0, -3.2, cosA, sinA),
            rotatePoint(cx, cy, -20.0, -3.0, cosA, sinA),
            rotatePoint(cx, cy, -24.0, -1.6, cosA, sinA),
            rotatePoint(cx, cy, -26.5, 0.0, cosA, sinA),
            rotatePoint(cx, cy, -24.0, 1.6, cosA, sinA),
            rotatePoint(cx, cy, -20.0, 3.0, cosA, sinA),
            rotatePoint(cx, cy, -16.0, 3.2, cosA, sinA),
            rotatePoint(cx, cy, -12.0, 1.8, cosA, sinA)
        ];
        dc.setColor(secColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(cwPoly);
    }

    //! Authentic layered center pinion cap matching macro Daytona photos
    private function drawPinionCap(dc as Graphics.Dc, cx as Numeric, cy as Numeric, isLowPower as Boolean) as Void {
        var outerCol = isLowPower ? Theme.dim(0x181A1D, Theme.AOD_DIM_PERCENT) : 0x181A1D;
        var midCol   = isLowPower ? Theme.dim(Theme.COLOR_STEEL_LIGHT, Theme.AOD_DIM_PERCENT) : Theme.COLOR_STEEL_LIGHT;
        var dimpleCol= isLowPower ? Theme.dim(Theme.COLOR_DARK_GROOVE, Theme.AOD_DIM_PERCENT) : Theme.COLOR_DARK_GROOVE;

        // Outer collar boss
        dc.setColor(outerCol, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 5.2);

        // Concentric polished silver center rivet collar
        dc.setColor(midCol, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 2.5);

        // Microscopic dark center axle pinhole
        dc.setColor(dimpleCol, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 1.0);
    }

    // =========================================================================
    // ALWAYS-ON DISPLAY (AOD / LOW POWER MODE - STRICT AMOLED RULES)
    // =========================================================================

    //! Renders low power mode: pure black, dimmed Chromalight batons, anti-burn-in minute drift
    private function drawAlwaysOn(dc as Graphics.Dc, cx as Numeric, cy as Numeric,
                                  r as Numeric, clock as System.ClockTime) as Void {
        // 1. Mandatory pure black background
        dc.setColor(Theme.COLOR_BLACK, Theme.COLOR_BLACK);
        dc.clear();

        // 2. Anti-burn-in drift (shifts static elements up to +-3 px each minute)
        var driftX = (clock.min % 7) - 3;
        var driftY = ((clock.min / 7) % 7) - 3;
        var dcx = cx + driftX;
        var dcy = cy + driftY;

        // 3. Dimmed Chromalight Baton Hour Markers (12 markers around perimeter)
        var aodLume = Theme.dim(Theme.COLOR_CHROMALIGHT, Theme.AOD_DIM_PERCENT);
        var aodSteel = Theme.dim(Theme.COLOR_STEEL_DARK, Theme.AOD_DIM_PERCENT);

        for (var i = 0; i < 12; i++) {
            var markerAngle = i * (TWO_PI / 12.0) - (Math.PI / 2.0);
            var cosM = Math.cos(markerAngle);
            var sinM = Math.sin(markerAngle);

            var distOut = r * 0.88;
            var distIn = r * 0.74;

            var p1 = rotatePoint(dcx, dcy, distIn, -2.0, cosM, sinM);
            var p2 = rotatePoint(dcx, dcy, distOut, -2.0, cosM, sinM);
            var p3 = rotatePoint(dcx, dcy, distOut, 2.0, cosM, sinM);
            var p4 = rotatePoint(dcx, dcy, distIn, 2.0, cosM, sinM);

            var mPoly = [p1, p2, p3, p4];
            dc.setColor(aodSteel, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(mPoly);

            var lp1 = rotatePoint(dcx, dcy, distIn + 2.0, -1.0, cosM, sinM);
            var lp2 = rotatePoint(dcx, dcy, distOut - 2.0, -1.0, cosM, sinM);
            var lp3 = rotatePoint(dcx, dcy, distOut - 2.0, 1.0, cosM, sinM);
            var lp4 = rotatePoint(dcx, dcy, distIn + 2.0, 1.0, cosM, sinM);

            var lmPoly = [lp1, lp2, lp3, lp4];
            dc.setColor(aodLume, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(lmPoly);
        }

        // 4. Subtle dimmed subdial outline circles
        var aodSubCol = Theme.dim(Theme.COLOR_STEEL_DARK, 0.15);
        dc.setColor(aodSubCol, Graphics.COLOR_TRANSPARENT);
        var centers = Theme.getSubdialCenters(_style);
        for (var s = 0; s < 3; s++) {
            var sc = centers[s];
            dc.drawCircle(sc[0] + driftX, sc[1] + driftY, Theme.SUB_RADIUS);
        }

        // 5. Minimalist dimmed AOD Hands (Hour and Minute only)
        var hourAngle = ((clock.hour % 12) + (clock.min / 60.0)) * (TWO_PI / 12.0) - (Math.PI / 2.0);
        var minAngle = (clock.min + (clock.sec / 60.0)) * (TWO_PI / 60.0) - (Math.PI / 2.0);

        drawDaytonaHourHand(dc, dcx, dcy, hourAngle, r * 0.58, true);
        drawDaytonaMinuteHand(dc, dcx, dcy, minAngle, r * 0.88, true);
        drawPinionCap(dc, dcx, dcy, true);
    }

    // =========================================================================
    // GEOMETRIC UTILITIES
    // =========================================================================

    //! Rotates a point (px, py) by angle (cosA, sinA) around (cx, cy)
    private function rotatePoint(cx as Numeric, cy as Numeric, px as Numeric, py as Numeric,
                                cosA as Numeric, sinA as Numeric) as [Numeric, Numeric] {
        return [
            (cx + px * cosA - py * sinA),
            (cy + px * sinA + py * cosA)
        ];
    }

    // =========================================================================
    // LIFECYCLE HOOKS
    // =========================================================================

    function onShow() as Void {
        loadRolexFont();
        loadDialBitmap();
    }

    function onHide() as Void {
        _dialBitmap = null;
    }

    function onEnterSleep() as Void {
        _lowPower = true;
        _dialBitmap = null; // Free flash bitmap in AOD mode
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _lowPower = false;
        loadDialBitmap();
        WatchUi.requestUpdate();
    }
}
