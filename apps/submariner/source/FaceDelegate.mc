import Toybox.Application.WatchFaceConfig;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.WatchUi;

//! Watch face delegate handling both on-device editor configuration and touch interactions.
class FaceDelegate extends WatchUi.WatchFaceDelegate {

    private var _view as FaceView;

    //! @param view The view this delegate drives
    function initialize(view as FaceView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    //! The user changed a style or colour in the editor
    //! @param options The edited configuration
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

    //! Handle touch and hold (long press) on watch face elements.
    //! Pressing the Cyclops Date Window at 3 o'clock opens Garmin Calendar.
    function onPress(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        var x = coords[0];
        var y = coords[1];

        // 3 o'clock Date Window hit area (center at 379, 229)
        if (x >= 355 && x <= 405 && y >= 205 && y <= 255) {
            try {
                if (Toybox has :Complications && Complications has :exitTo) {
                    Complications.exitTo(new Complications.Id(Complications.COMPLICATION_TYPE_CALENDAR_EVENTS));
                    return true;
                }
            } catch (e) {
            }
        }

        // Return false to allow Garmin OS default behavior (e.g. watch face menu)
        return false;
    }
}

