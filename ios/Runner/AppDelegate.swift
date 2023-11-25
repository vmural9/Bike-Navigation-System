import UIKit
import Flutter
import GoogleMaps
// import Firebase

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // FirebaseApp.configure()
    GMSServices.provideAPIKey("AIzaSyDkKbK_K-0WJuhGvvSbmSL5pEoCiBSWNqY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}


// API Key : AIzaSyAOi2s5JHzBniN3p2wMF918IJHFrvqJtVw
