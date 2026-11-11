import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Lightweight drawable used by the Garmin on-device watch face editor
//! to identify, bound, and highlight subdial slots when customizing complications.
class SubdialSlotDrawable extends WatchUi.Drawable {
    private var _slotId as Number;
    private var _locX as Number;
    private var _locY as Number;
    private var _w as Number;
    private var _h as Number;

    function initialize(slotId as Number, cx as Numeric, cy as Numeric, radius as Numeric) {
        var x = (cx - radius).toNumber();
        var y = (cy - radius).toNumber();
        var size = (radius * 2.0).toNumber();
        Drawable.initialize({
            :locX => x,
            :locY => y,
            :width => size,
            :height => size,
            :identifier => slotId
        });
        _slotId = slotId;
        _locX = x;
        _locY = y;
        _w = size;
        _h = size;
    }

    function getSlotId() as Number {
        return _slotId;
    }

    function getBoundingBox() as Graphics.BoundingBox {
        var bb = new Graphics.BoundingBox();
        bb.addRectangle(_locX, _locY, _w, _h);
        return bb;
    }

    function containsPoint(x as Number, y as Number) as Boolean {
        var bb = getBoundingBox();
        return bb.includesPoint(x, y);
    }

    function draw(dc as Graphics.Dc) as Void {
        // Passive drawable for the on-device editor to locate and pulse around the subdial
    }
}
