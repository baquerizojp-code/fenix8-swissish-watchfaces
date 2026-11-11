import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Entry point. Hands the system the face, plus an input delegate when the
//! on-device editor launched us.
class FaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    //! @param state Startup arguments
    function onStart(state as Dictionary?) as Void {
    }

    //! @return The face view and its input delegate for touch and editor support
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new FaceView();
        return [ view, new FaceDelegate(view) ];
    }
}
