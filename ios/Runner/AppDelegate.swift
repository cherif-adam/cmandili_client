import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The Maps SDK needs its key before any GMSMapView is created, which happens
    // before Dart runs — so this cannot come from dotenv like the Directions calls do.
    // Keep in sync with com.google.android.geo.API_KEY in the Android manifest.
    GMSServices.provideAPIKey("AIzaSyDb7OWrwUqmgV_ZU9EYYFMxBYc_TOHwgy0")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
