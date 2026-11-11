import Toybox.Application.WatchFaceConfig;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

//! Watch face delegate handling on-device editor configuration and touch interactions.
class FaceDelegate extends WatchUi.WatchFaceDelegate {

    private var _view as FaceView;

    function initialize(view as FaceView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    //! The user changed a style, colour, or complication in the on-device editor
    function onWatchFaceConfigEdited(options as {
                :configId as WatchFaceConfig.Id,
                :type as WatchFaceConfigType?,
                :committed as Boolean
            }) as Void {
        var id = options[:configId] as WatchFaceConfig.Id?;
        if (id == null) {
            return;
        }

        var settings = WatchFaceConfig.getSettings(id);
        if (settings != null) {
            _view.applyConfig(settings);
        }
    }

    //! Provides the subdial bounding box and drawable to the Garmin on-device watch face editor
    function getComplicationDrawable(complication as ComplicationRef) as Drawable or ComplicationDrawableRef or Null {
        return _view.getComplication(complication);
    }

    //! Handle tap events by notifying the Garmin system when a complication slot is tapped
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        var selectedSlot = _view.getTappedSlot(coords[0], coords[1]);

        if (selectedSlot != null) {
            try {
                setSelectedComplication(selectedSlot);
                return true;
            } catch (e) {
                return _view.launchSubdialGlance(selectedSlot);
            }
        }
        return false;
    }

    //! Handle touch interactions on watch face subdials or center pinion cap
    function onPress(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        var x = coords[0].toFloat();
        var y = coords[1].toFloat();

        // Check if any of the 3 Daytona subdials was tapped
        var selectedSlot = _view.getTappedSlot(x, y);
        if (selectedSlot != null) {
            return _view.launchSubdialGlance(selectedSlot);
        }

        // Tap near center (pinion cap): cycle Daytona styles (Panda -> Black -> Spark)
        var dxC = x - 227.0;
        var dyC = y - 227.0;
        if ((dxC * dxC + dyC * dyC) <= (35.0 * 35.0)) {
            var nextStyle = (_view.getStyle() % 3) + 1;
            _view.setStyle(nextStyle);
            return true;
        }

        return false;
    }
}
