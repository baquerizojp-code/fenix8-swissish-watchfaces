import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Entry point for Rolex Daytona Watch Face on Garmin fēnix 8 AMOLED 47mm.
class FaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    //! Returns initial view and delegate
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new FaceView();
        var delegate = new FaceDelegate(view);
        return [view, delegate];
    }
}
