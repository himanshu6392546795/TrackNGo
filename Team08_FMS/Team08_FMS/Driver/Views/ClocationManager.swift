
import CoreLocation
import UserNotifications

class LocationTracker: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var pickupCoordinate: CLLocationCoordinate2D?
    private var dropoffCoordinate: CLLocationCoordinate2D?
    private let proximityRadius: Double = 500.0 // in meters
    
    init(pickup: CLLocationCoordinate2D?, dropoff: CLLocationCoordinate2D?) {
        self.pickupCoordinate = pickup
        self.dropoffCoordinate = dropoff
        super.init()
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last else { return }
        
        if let pickup = pickupCoordinate,
           currentLocation.distance(from: CLLocation(latitude: pickup.latitude, longitude: pickup.longitude)) <= proximityRadius {
            sendAlert(message: "Vehicle is near the Pickup location!")
        }
        
        if let dropoff = dropoffCoordinate,
           currentLocation.distance(from: CLLocation(latitude: dropoff.latitude, longitude: dropoff.longitude)) <= proximityRadius {
            sendAlert(message: "Vehicle is near the Destination location!")
        }
    }
    
    private func sendAlert(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Fleet Manager Alert"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
