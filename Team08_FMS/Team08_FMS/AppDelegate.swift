import SwiftUI
import CoreLocation
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    let locationManager = CLLocationManager()
    var window: UIWindow?
    let fleetManager = FleetManagerTabView() // FleetManager class manages event listening
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Set up Location Manager
        locationManager.delegate = self
        // Request location permissions
        locationManager.requestAlwaysAuthorization()
        // Optionally configure location manager properties
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 50
        
        // Set up Notifications
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        } // Start listening as soon as the app launches
        
        return true
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways:
            manager.allowsBackgroundLocationUpdates = true
            print("Authorized Always – background location updates enabled.")
        case .authorizedWhenInUse:
            manager.allowsBackgroundLocationUpdates = false
            print("Authorized When In Use – background location updates disabled.")
        case .denied, .restricted, .notDetermined:
            manager.allowsBackgroundLocationUpdates = false
            print("Location updates not permitted.")
        @unknown default:
            manager.allowsBackgroundLocationUpdates = false
            print("Unknown location authorization status.")
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // This method will be called when a notification is delivered while your app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification banner even when the app is active.
        completionHandler([.banner, .sound])
    }
}
