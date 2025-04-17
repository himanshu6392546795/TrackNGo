import SwiftUI
import CoreLocation
import Supabase
import Combine
import UserNotifications

enum TripError: Error, Equatable {
    case fetchError(String)
    case decodingError(String)
    case vehicleError(String)
    case updateError(String)
    case locationError(String)
    
    static func == (lhs: TripError, rhs: TripError) -> Bool {
        switch (lhs, rhs) {
        case (.fetchError(let l), .fetchError(let r)): return l == r
        case (.decodingError(let l), .decodingError(let r)): return l == r
        case (.vehicleError(let l), .vehicleError(let r)): return l == r
        case (.updateError(let l), .updateError(let r)): return l == r
        case (.locationError(let l), .locationError(let r)): return l == r
        default: return false
        }
    }
}

class TripDataController: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = TripDataController()
    
    @Published var currentTrip: Trip?
    @Published var upcomingTrips: [Trip] = []
    @Published var recentDeliveries: [DeliveryDetails] = []
    @Published var error: TripError?
    @Published var isLoading = false
    @Published var isInSourceRegion = false
    @Published var isInDestinationRegion = false
    @Published var canStartTrip = false
    @Published var tripStartTime: Date?
    @Published var estimatedArrivalTime: Date?
    
    @Published var allTrips: [Trip] = []
    
    private var locationManager = CLLocationManager()
    private let geofenceRadius: CLLocationDistance = 50.0 // 100 meters
    private var driverId: UUID?
    private var tripTimer: Timer?
    private let maxTripDuration: TimeInterval = 3600 // 1 hour in seconds
    
    private let supabaseController = SupabaseDataController.shared
    
    private override init() {
        super.init()
        setupLocationManager()
        setupNotifications()
        // Start fetching data immediately
//        Task {
//            await refreshTrips()
//        }
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 50 // Update only when moving 50m
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.activityType = .automotiveNavigation
        
        // Request authorization first
        locationManager.requestAlwaysAuthorization()
        
        // Only enable background updates after authorization is granted
//        if locationManager.authorizationStatus == .authorizedAlways {
//            locationManager.allowsBackgroundLocationUpdates = true
//            locationManager.showsBackgroundLocationIndicator = true
//        }
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func startMonitoringRegions() {
//        stopMonitoringRegions() // Clean up before starting new regions
        
        // Filter out trips that are in progress from your data source (e.g., allTrips)
        guard let currentTrip = currentTrip else {
                    print("DEBUG: Cannot start monitoring regions - no current trip")
            return
        }
        
        if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            print("DEBUG: Geofencing is available on this device")
            
            let sourceRegion = CLCircularRegion(
                            center: currentTrip.sourceCoordinate,
                            radius: geofenceRadius,
                            identifier: "sourceRegion"
                        )
            sourceRegion.notifyOnEntry = true
            sourceRegion.notifyOnExit = true
            
            let destinationRegion = CLCircularRegion(
                center: currentTrip.destinationCoordinate,
                radius: geofenceRadius,
                identifier: "destinationRegion"
            )
            destinationRegion.notifyOnEntry = true
            destinationRegion.notifyOnExit = true
            
            print("DEBUG: Source region center: \(sourceRegion.center.latitude), \(sourceRegion.center.longitude)")
            print("DEBUG: Destination region center: \(destinationRegion.center.latitude), \(destinationRegion.center.longitude)")
            print("DEBUG: Geofence radius: \(geofenceRadius) meters")
            
            [sourceRegion, destinationRegion].forEach { region in
                if !locationManager.monitoredRegions.contains(where: { $0.identifier == region.identifier }) {
                    locationManager.startMonitoring(for: region)
                    print("DEBUG: Started monitoring region: \(region.identifier)")
                } else {
                    print("DEBUG: Region \(region.identifier) is already being monitored")
                }
            }
            
            // Ensure the location manager is actively updating location
            locationManager.startUpdatingLocation()
            print("DEBUG: Started updating location")
            
            // Optionally, start a trip timer for each trip if needed
            startTripTimer()
        } else {
            print("DEBUG: Geofencing is not supported on this device")
        }
    }

    private func startTripTimer() {
        tripTimer?.invalidate()
        tripStartTime = Date()
        
        // Calculate estimated arrival time based on trip distance
        if let currentTrip = currentTrip {
            // Convert distance string (e.g., "8.5 km") to Double
            let distanceString = currentTrip.distance.replacingOccurrences(of: " km", with: "")
            if let distance = Double(distanceString) {
                // Assume average speed of 40 km/h for estimation
                let estimatedHours = distance / 40.0
                estimatedArrivalTime = Date().addingTimeInterval(estimatedHours * 3600)
            } else {
                // Fallback to default 1 hour if distance parsing fails
                estimatedArrivalTime = Date().addingTimeInterval(maxTripDuration)
            }
        } else {
            estimatedArrivalTime = Date().addingTimeInterval(maxTripDuration)
        }
        
        tripTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkTripDuration()
        }
    }
    
    private func checkTripDuration() {
//        guard let startTime = tripStartTime,
//              let estimatedArrival = estimatedArrivalTime else { return }
//        
//        let currentTime = Date()
//        let elapsedTime = currentTime.timeIntervalSince(startTime)
//        let timeUntilEstimatedArrival = estimatedArrival.timeIntervalSince(currentTime)
        
        // If trip has exceeded max duration
//        if elapsedTime > maxTripDuration {
////            sendNotification(
////                title: "Trip Duration Alert",
////                body: "Trip has exceeded the maximum allowed duration of 1 hour. Please check vehicle status."
////            )
////            // Notify fleet manager through Supabase
////            Task {
////                await notifyFleetManager(message: "Trip duration exceeded for trip \(currentTrip?.id.uuidString ?? "Unknown")")
////            }
//        }
//        
//        // If approaching estimated arrival time (within 15 minutes)
//        if timeUntilEstimatedArrival <= 900 && timeUntilEstimatedArrival > 0 {
////            sendNotification(
////                title: "Approaching Destination",
////                body: "Vehicle should be arriving at destination soon. Current ETA: \(formatTimeRemaining(timeUntilEstimatedArrival))"
////            )
//        }
//        
//        // If past estimated arrival time
//        if timeUntilEstimatedArrival <= 0 {
////            sendNotification(
////                title: "Estimated Arrival Time Reached",
////                body: "Vehicle should have reached the destination by now. Please verify location."
////            )
//            // Notify fleet manager through Supabase
////            Task {
////                await notifyFleetManager(message: "Estimated arrival time reached for trip \(currentTrip?.id.uuidString ?? "Unknown")")
////            }
//        }
    }
    
    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval / 60)
        if minutes < 60 {
            return "\(minutes) minutes"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours) hour\(hours == 1 ? "" : "s") \(remainingMinutes) minutes"
        }
    }
    
    private func notifyFleetManager(message: String) async {
        do {
            // Format the date as ISO8601 string
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            let formattedDate = dateFormatter.string(from: Date())
            
            // Add notification to Supabase notifications table
            try await supabaseController.databaseFrom("notifications")
                .insert([
                    "message": message,
                    "type": "trip_alert",
                    "created_at": formattedDate,
                    "is_read": "false"  // Convert boolean to string
                ])
                .execute()
        } catch {
            print("Error sending fleet manager notification: \(error)")
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            startMonitoringRegions()
        case .denied:
            print("Location permissions denied. Please enable it in settings.")
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .restricted:
            print("Location permissions are restricted.")
        case .authorizedWhenInUse:
            startMonitoringRegions()
        default:
//            stopMonitoringRegions()
            print("Error")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else {
            print("DEBUG: Entered region is not a circular region")
            return
        }
        
        guard let currentTrip = currentTrip else { return }
        
        print("DEBUG: Entered region: \(circularRegion.identifier)")
        print("DEBUG: Current location: \(manager.location?.coordinate.latitude ?? 0), \(manager.location?.coordinate.longitude ?? 0)")
        print("DEBUG: Distance from region center: \(manager.location?.distance(from: CLLocation(latitude: circularRegion.center.latitude, longitude: circularRegion.center.longitude)) ?? 0) meters")
        
        switch circularRegion.identifier {
        case "sourceRegion":
            isInSourceRegion = true
            print("DEBUG: Entered source region")
            let message = "Vehicle: \(currentTrip.vehicleDetails.name) entered source region"
            let event = GeofenceEvents(id: UUID(), tripId: currentTrip.id, message: message)
            supabaseController.insertIntoGeofenceEvents(event: event)
            checkTripStartEligibility()
            
            if !upcomingTrips.isEmpty {
                sendNotification(
                    title: "Ready to Start Trip",
                    body: "You are now in the pickup area. You can start your next trip when ready."
                )
            }
            
        case "destinationRegion":
            isInDestinationRegion = true
            print("DEBUG: Entered destination region")
            let message = "Vehicle: \(currentTrip.vehicleDetails.name) entered destination region"
            let event = GeofenceEvents(id: UUID(), tripId: currentTrip.id, message: message)
            supabaseController.insertIntoGeofenceEvents(event: event)
            tripTimer?.invalidate()
            tripTimer = nil
            
            if let startTime = tripStartTime {
                let duration = Date().timeIntervalSince(startTime)
                let durationString = formatTimeRemaining(duration)
                
                Task {
                    await notifyFleetManager(message: "Vehicle has reached destination for trip \(currentTrip.id.uuidString). Trip duration: \(durationString)")
                }
            }
            
            Task {
                try? await markTripAsDelivered(trip: currentTrip)
            }
            
        default:
            print("DEBUG: Entered unknown region: \(circularRegion.identifier)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else {
            print("DEBUG: Exited region is not a circular region")
            return
        }
        
        guard let currentTrip = currentTrip else { return }
        
        print("DEBUG: Exited region: \(circularRegion.identifier)")
        print("DEBUG: Current location: \(manager.location?.coordinate.latitude ?? 0), \(manager.location?.coordinate.longitude ?? 0)")
        print("DEBUG: Distance from region center: \(manager.location?.distance(from: CLLocation(latitude: circularRegion.center.latitude, longitude: circularRegion.center.longitude)) ?? 0) meters")
        
        switch circularRegion.identifier {
        case "sourceRegion":
            isInSourceRegion = false
            print("DEBUG: Exited source region")
            let message = "Vehicle: \(currentTrip.vehicleDetails.name) exited source region"
            let event = GeofenceEvents(id: UUID(), tripId: currentTrip.id, message: message)
            supabaseController.insertIntoGeofenceEvents(event: event)
            checkTripStartEligibility()
            
        case "destinationRegion":
            isInDestinationRegion = false
            print("DEBUG: Exited destination region")
            let message = "Vehicle: \(currentTrip.vehicleDetails.name) exited destination region"
            let event = GeofenceEvents(id: UUID(), tripId: currentTrip.id, message: message)
            supabaseController.insertIntoGeofenceEvents(event: event)
            
        default:
            print("DEBUG: Exited unknown region: \(circularRegion.identifier)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        if (error as NSError).code == CLError.denied.rawValue {
            print("Location access denied. Ask the user to enable permissions.")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, let currentTrip = currentTrip else { return }
        
        // Print the current location
        print("Current user location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Check if the user is inside any monitored geofenced areas
        for region in manager.monitoredRegions {
            if let circularRegion = region as? CLCircularRegion {
                if circularRegion.contains(location.coordinate) {
                    print("User is in geofenced area: \(circularRegion.identifier)")
                    switch circularRegion.identifier {
                    case "sourceRegion":
                        isInSourceRegion = true
                        print("DEBUG: Entered source region")
                        let message = "Vehicle: \(currentTrip.vehicleDetails.name) is in the source region"
                        let event = GeofenceEvents(id: UUID(), tripId: currentTrip.id, message: message)
                        supabaseController.insertIntoGeofenceEvents(event: event)
                        checkTripStartEligibility()
                        
                        if !upcomingTrips.isEmpty {
                            sendNotification(
                                title: "Ready to Start Trip",
                                body: "You are now in the pickup area. You can start your next trip when ready."
                            )
                        }
                        
                    case "destinationRegion":
                        isInDestinationRegion = true
                        print("DEBUG: Entered destination region")
                        let message = "Vehicle: \(currentTrip.vehicleDetails.name) is i the destination region"
                        let event = GeofenceEvents(id: UUID(), tripId: currentTrip.id, message: message)
                        supabaseController.insertIntoGeofenceEvents(event: event)
                        tripTimer?.invalidate()
                        tripTimer = nil
                        
                        if let startTime = tripStartTime {
                            let duration = Date().timeIntervalSince(startTime)
                            let durationString = formatTimeRemaining(duration)
                            
                            Task {
                                await notifyFleetManager(message: "Vehicle has reached destination for trip \(currentTrip.id.uuidString). Trip duration: \(durationString)")
                            }
                        }
                        
                    default:
                        print("DEBUG: Entered unknown region: \(circularRegion.identifier)")
                        
                    }
                }
            }
        }
        
        // Calculate distances to source and destination
        let sourceLocation = CLLocation(latitude: currentTrip.sourceCoordinate.latitude,
                                        longitude: currentTrip.sourceCoordinate.longitude)
        let destinationLocation = CLLocation(latitude: currentTrip.destinationCoordinate.latitude,
                                             longitude: currentTrip.destinationCoordinate.longitude)
        
        let distanceToSource = location.distance(from: sourceLocation)
        let distanceToDestination = location.distance(from: destinationLocation)
        
        print("Distance from current location to source region: \(distanceToSource) meters")
        print("Distance from current location to destination region: \(distanceToDestination) meters")
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("DEBUG: Successfully started monitoring region: \(region.identifier)")
        if let circularRegion = region as? CLCircularRegion {
            print("DEBUG: Region center: \(circularRegion.center.latitude), \(circularRegion.center.longitude)")
            print("DEBUG: Region radius: \(circularRegion.radius) meters")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didStopMonitoringFor region: CLRegion) {
        print("Stopped monitoring region: \(region.identifier)")
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("DEBUG: Monitoring failed for region: \(region?.identifier ?? "unknown")")
        print("DEBUG: Error: \(error.localizedDescription)")
        if let clError = error as? CLError {
            print("DEBUG: CoreLocation error code: \(clError.code.rawValue)")
            print("DEBUG: CoreLocation error description: \(clError.localizedDescription)")
        }
    }
    
    private func checkTripStartEligibility() {
        // Can only start trip if we're in the source region and there's no current trip
        canStartTrip = isInSourceRegion && currentTrip == nil
        
        // If we're in the source region but can't start trip, notify the user
        if isInSourceRegion && currentTrip != nil {
            sendNotification(
                title: "Trip Start Not Available",
                body: "Cannot start new trip while another trip is in progress."
            )
        }
    }
    
    func stopMonitoringRegions() {
        locationManager.monitoredRegions.forEach { region in
            locationManager.stopMonitoring(for: region)
        }
        print("Stopped monitoring all regions.")
    }
    
    func setDriverId(_ id: UUID) {
        self.driverId = id
        Task {
            await refreshTrips()
        }
    }
    
    // Method to get all trips for fleet manager view
    func getAllTrips() -> [Trip] {
        return allTrips
    }
    
    // Method to refresh all trips without driver filtering
    @MainActor
    func refreshAllTrips() async {
        isLoading = true
        do {
            try await fetchAllTrips()
        } catch {
            print("Error during refresh all trips: \(error)")
            if let tripError = error as? TripError {
                self.error = tripError
            }
        }
        isLoading = false
    }
    
    // Fetch all trips without driver filtering
    @MainActor
    func fetchAllTrips() async throws {
        print("Fetching all trips...")
        do {
            // Create a decoder with custom date decoding strategy
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try parsing with different date formats
                let formats = [
                    // Full timestamps with different variations
                    "yyyy-MM-dd'T'HH:mm:ss",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    // Date-only format (for pollution_expiry, etc.)
                    "yyyy-MM-dd"
                ]
                
                for format in formats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
                
                // If none of the formats work, try removing microseconds
                if let dotIndex = dateString.firstIndex(of: ".") {
                    let truncated = String(dateString[..<dotIndex])
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    if let date = dateFormatter.date(from: truncated) {
                        return date
                    }
                }
                
                print("Failed to decode date string: \(dateString)")
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string: \(dateString)")
            }
            
            // Start building the query for all trips
            let query = supabaseController.supabase
                .from("trips")
                .select("""
                    id,
                    destination,
                    trip_status,
                    has_completed_pre_trip,
                    has_completed_post_trip,
                    vehicle_id,
                    driver_id,
                    secondary_driver_id,
                    start_time,
                    end_time,
                    notes,
                    created_at,
                    updated_at,
                    is_deleted,
                    start_latitude,
                    start_longitude,
                    end_latitude,
                    end_longitude,
                    pickup,
                    estimated_distance,
                    estimated_time,
                    vehicles (
                        id,
                        name,
                        year,
                        make,
                        model,
                        vin,
                        license_plate,
                        vehicle_type,
                        color,
                        body_type,
                        body_subtype,
                        msrp,
                        pollution_expiry,
                        insurance_expiry,
                        status,
                        lastMaintenanceDistance,
                        totalDistance
                    )
                """)
                .eq("is_deleted", value: false)
            
            // Execute the query
            let response = try await query.execute()
            
            // Print raw response for debugging
//            print("Raw response for all trips: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            
            // Define a nested struct to match the joined data structure
            struct JoinedTripData: Codable {
                let id: UUID
                let destination: String
                let trip_status: String
                let has_completed_pre_trip: Bool
                let has_completed_post_trip: Bool
                let vehicle_id: UUID
                let driver_id: UUID?
                let secondary_driver_id: UUID?
                let start_time: Date?
                let end_time: Date?
                let notes: String?
                let created_at: Date
                let updated_at: Date?
                let is_deleted: Bool
                let start_latitude: Double?
                let start_longitude: Double?
                let end_latitude: Double?
                let end_longitude: Double?
                let pickup: String?
                let estimated_distance: Double?
                let estimated_time: Double?
                let vehicles: Vehicle
                
                // Add computed properties to parse distance and fuel cost
                var parsedDistance: String {
                    if let estimatedDistance = estimated_distance {
                        return String(format: "%.1f", estimatedDistance)
                    }
                    guard let notes = notes,
                          let distanceRange = notes.range(of: "Distance: "),
                          let endRange = notes[distanceRange.upperBound...].range(of: "\n") else {
                        return "N/A"
                    }
                    return String(notes[distanceRange.upperBound..<endRange.lowerBound])
                }
                
                var parsedFuelCost: String {
                    guard let notes = notes,
                          let fuelRange = notes.range(of: "Estimated Fuel Cost: "),
                          let endRange = notes[fuelRange.upperBound...].range(of: "\n") else {
                        return "N/A"
                    }
                    print(endRange)
                    let dist = (Double(parsedDistance) ?? 0)*0.5
                    return "\(dist) $"
                }
            }
            
            let joinedData = try decoder.decode([JoinedTripData].self, from: response.data)
            
            // Convert joined data to Trip objects
            let tripsWithVehicles = joinedData.map { data -> Trip in
                let supabaseTrip = SupabaseTrip(
                    id: data.id,
                    destination: data.destination,
                    trip_status: data.trip_status,
                    has_completed_pre_trip: data.has_completed_pre_trip,
                    has_completed_post_trip: data.has_completed_post_trip,
                    vehicle_id: data.vehicle_id,
                    driver_id: data.driver_id,
                    secondary_driver_id: data.secondary_driver_id,
                    start_time: data.start_time,
                    end_time: data.end_time,
                    notes: data.notes,
                    created_at: data.created_at,
                    updated_at: data.updated_at ?? data.created_at,
                    is_deleted: data.is_deleted,
                    start_latitude: data.start_latitude,
                    start_longitude: data.start_longitude,
                    end_latitude: data.end_latitude,
                    end_longitude: data.end_longitude,
                    pickup: data.pickup,
                    estimated_distance: data.estimated_distance,
                    estimated_time: data.estimated_time
                )
                return Trip(from: supabaseTrip, vehicle: data.vehicles)
            }
            
            print("Successfully processed \(tripsWithVehicles.count) all trips")
            
            // Update allTrips property
            self.allTrips = tripsWithVehicles
            
        } catch {
            print("Error fetching all trips: \(error)")
            throw TripError.fetchError("Failed to fetch all trips: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func fetchTrips() async throws {
        print("Fetching trips...")
        do {
            // Create a decoder with custom date decoding strategy
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try parsing with different date formats
                let formats = [
                    // Full timestamps with different variations
                    "yyyy-MM-dd'T'HH:mm:ss",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    // Date-only format (for pollution_expiry, etc.)
                    "yyyy-MM-dd"
                ]
                
                for format in formats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        return date
                    }
                }
                
                // If none of the formats work, try removing microseconds
                if let dotIndex = dateString.firstIndex(of: ".") {
                    let truncated = String(dateString[..<dotIndex])
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    if let date = dateFormatter.date(from: truncated) {
                        return date
                    }
                }
                
                print("Failed to decode date string: \(dateString)")
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string: \(dateString)")
            }

            // Define JoinedTripData struct
            struct JoinedTripData: Codable {
                let id: UUID
                let destination: String
                let trip_status: String
                let has_completed_pre_trip: Bool
                let has_completed_post_trip: Bool
                let vehicle_id: UUID
                let driver_id: UUID?
                let secondary_driver_id: UUID?
                let start_time: Date?
                let end_time: Date?
                let notes: String?
                let created_at: Date
                let updated_at: Date?
                let is_deleted: Bool
                let start_latitude: Double?
                let start_longitude: Double?
                let end_latitude: Double?
                let end_longitude: Double?
                let pickup: String?
                let estimated_distance: Double?
                let estimated_time: Double?
                let vehicles: Vehicle
            }

            var query = supabaseController.supabase
                .from("trips")
                .select("""
                    id,
                    destination,
                    trip_status,
                    has_completed_pre_trip,
                    has_completed_post_trip,
                    vehicle_id,
                    driver_id,
                    secondary_driver_id,
                    start_time,
                    end_time,
                    notes,
                    created_at,
                    updated_at,
                    is_deleted,
                    start_latitude,
                    start_longitude,
                    end_latitude,
                    end_longitude,
                    pickup,
                    estimated_distance,
                    estimated_time,
                    vehicles (
                        id,
                        name,
                        year,
                        make,
                        model,
                        vin,
                        license_plate,
                        vehicle_type,
                        color,
                        body_type,
                        body_subtype,
                        msrp,
                        pollution_expiry,
                        insurance_expiry,
                        status,
                        lastMaintenanceDistance,
                        totalDistance
                    )
                """)
                .eq("is_deleted", value: false)

            // Add driver filter if driverId is set
            if let driverId = driverId {
                query = query.or("driver_id.eq.\(driverId),secondary_driver_id.eq.\(driverId)")
            }

            // Execute the query
            let response = try await query.execute()
            
            let joinedData = try decoder.decode([JoinedTripData].self, from: response.data)
            
            // Convert joined data to Trip objects
            let tripsWithVehicles = joinedData.map { data -> Trip in
                let supabaseTrip = SupabaseTrip(
                    id: data.id,
                    destination: data.destination,
                    trip_status: data.trip_status,
                    has_completed_pre_trip: data.has_completed_pre_trip,
                    has_completed_post_trip: data.has_completed_post_trip,
                    vehicle_id: data.vehicle_id,
                    driver_id: data.driver_id,
                    secondary_driver_id: data.secondary_driver_id,
                    start_time: data.start_time,
                    end_time: data.end_time,
                    notes: data.notes,
                    created_at: data.created_at,
                    updated_at: data.updated_at ?? data.created_at,
                    is_deleted: data.is_deleted,
                    start_latitude: data.start_latitude,
                    start_longitude: data.start_longitude,
                    end_latitude: data.end_latitude,
                    end_longitude: data.end_longitude,
                    pickup: data.pickup,
                    estimated_distance: data.estimated_distance,
                    estimated_time: data.estimated_time
                )
                return Trip(from: supabaseTrip, vehicle: data.vehicles)
            }

            print("Successfully processed \(tripsWithVehicles.count) trips")

            // Update published properties
            await MainActor.run {
                // Find current trip (in progress)
                if let currentTrip = tripsWithVehicles.first(where: { $0.status.rawValue == "current" }) {
                    self.currentTrip = currentTrip
                } else {
                    self.currentTrip = nil
                }

                // Filter upcoming trips (only pending or assigned)
                self.upcomingTrips = tripsWithVehicles.filter { trip in
                    trip.status.rawValue == "pending" || trip.status.rawValue == "assigned"
                }

                // Convert completed/delivered trips to delivery details
                let completedTrips = tripsWithVehicles.filter { trip in 
                    trip.status.rawValue == "delivered"
                }

                self.recentDeliveries = completedTrips.map { trip in
                    DeliveryDetails(
                        id: trip.id,
                        location: trip.destination,
                        date: formatDate(trip.endTime ?? trip.startTime ?? Date()),
                        status: "Delivered",
                        driver: "Current Driver",
                        vehicle: trip.vehicleDetails.licensePlate,
                        notes: trip.notes ?? "No notes available"
                    )
                }

                // Sort recent deliveries by date (newest first)
                self.recentDeliveries.sort { lhs, rhs in
                    let lhsDate = parseDate(lhs.date) ?? Date.distantPast
                    let rhsDate = parseDate(rhs.date) ?? Date.distantPast
                    return lhsDate > rhsDate
                }
            }
        } catch {
            print("Error fetching trips: \(error)")
            throw TripError.fetchError("Failed to fetch trips: \(error.localizedDescription)")
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Try different date formats
        let formats = [
            "Today, h:mm a",
            "Yesterday, h:mm a",
            "MMM d, h:mm a"
        ]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
//        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today, \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Yesterday, \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: date)
        }
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        return formatter.string(from: date)
    }
    
    // Update getCurrentTripData to handle optional currentTrip
    func getCurrentTripData() -> Trip? {
        return currentTrip
    }
    
    // Add a function to get upcomingTrips data
    func getUpcomingTrips() -> [Trip] {
        return upcomingTrips
    }
    
    // Add a function to get filtered trips based on driver availability
    func getAvailabilityFilteredTrips() -> [Trip] {
        let availabilityManager = DriverAvailabilityManager.shared
        return availabilityManager.isAvailable ? upcomingTrips : []
    }
    
    // Add a function to get recentDeliveries data
    func getRecentDeliveries() -> [DeliveryDetails] {
        return recentDeliveries
    }
    
    // Update markTripAsDelivered to throw errors
    @MainActor
    func markTripAsDelivered(trip: Trip) async throws {
        print("Attempting to mark trip \(trip.id) as delivered")
        
        do {
            // First ensure both pre-trip and post-trip inspections are marked as completed in Supabase
            if !trip.hasCompletedPreTrip {
                print("Ensuring pre-trip inspection is marked as completed")
                try await updateTripInspectionStatus(tripId: trip.id, isPreTrip: true, completed: true)
            }
            
            if !trip.hasCompletedPostTrip {
                print("Ensuring post-trip inspection is marked as completed")
                try await updateTripInspectionStatus(tripId: trip.id, isPreTrip: false, completed: true)
            }
            
            // Update trip status in Supabase to delivered
            try await supabaseController.updateTrip(id: trip.id, status: "delivered")
            print("Updated trip status to 'delivered'")
            
            Task {
                let id = await supabaseController.getUserID()
                let totalDistance = Int(trip.vehicleDetails.totalDistance) + (Int(trip.distance) ?? 0)
                await supabaseController.updateVehicleStatus(newStatus: .available, vehicleID: trip.vehicleDetails.id)
                await supabaseController.updateDriverStatus(newStatus: .available, userID: id, id: nil)
                await supabaseController.updateVehicleTotalMaintenance(totalDistance: totalDistance, vehicleID: trip.vehicleDetails.id)
            }
            
            // Update end time in Supabase
            let response = try await supabaseController.databaseFrom("trips")
                .update(["end_time": Date()])
                .eq("id", value: trip.id)
                .execute()
            
            print("Updated trip end_time: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            
            // Update local state - remove from current trip
            if let currentTrip = self.currentTrip, currentTrip.id == trip.id {
                self.currentTrip = nil
                print("Removed trip from current trip")
            }
            
            // Create a DeliveryDetails from the trip and add to recent deliveries
            let newDelivery = DeliveryDetails(
                id: trip.id,
                location: trip.destination,
                date: formatDate(trip.endTime ?? Date()),
                status: "Delivered",
                driver: "Current Driver",
                vehicle: trip.vehicleDetails.licensePlate,
                notes: """
                       Trip Details
                       ---------------
                       Trip: \(trip.id.uuidString)
                       From: \(trip.startingPoint)
                       To: \(trip.destination)
                       Distance: \(trip.distance) km
                       
                       Timing
                       ---------------
                       Start: \(formatFullDate(trip.startTime ?? Date()))
                       End: \(formatFullDate(trip.endTime ?? Date()))
                       
                       Additional Info
                       ---------------
                       Cargo Type: General Cargo
                       \(trip.notes ?? "")
                       """
            )
            
            // Add to recent deliveries - insert at the beginning for newest first
            self.recentDeliveries.insert(newDelivery, at: 0)
            print("Added trip to recent deliveries")
            
            // Refresh trips to ensure everything is in sync with server
            try await fetchTrips()
            print("Trips refreshed after marking as delivered")
        } catch {
            print("Error marking trip as delivered: \(error)")
            throw TripError.updateError("Failed to mark trip as delivered: \(error.localizedDescription)")
        }
    }
    
    // Update startTrip to handle the transition from upcoming to current status
    @MainActor
    func startTrip(trip: Trip) async throws {
        print("Starting trip \(trip.id)")
        
        // Check if there's already a trip in progress
        if self.currentTrip != nil {
            throw TripError.updateError("Cannot start a new trip while another trip is in progress")
        }
        
        do {
            // First update the trip status
            try await supabaseController.updateTrip(id: trip.id, status: "current")
            print("Updated trip status to 'current'")
            
            // Then update the start time in a separate call
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            let formattedDate = dateFormatter.string(from: Date())
            
            let response = try await supabaseController.databaseFrom("trips")
                .update([
                    "start_time": formattedDate,
                    "trip_status": "current"
                ])
                .eq("id", value: trip.id)
                .execute()
            
            print("Updated trip start_time: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            
            // Update local state
            if let index = upcomingTrips.firstIndex(where: { $0.id == trip.id }) {
                var updatedTrip = upcomingTrips[index]
                updatedTrip.status = .inProgress
                self.currentTrip = updatedTrip
                upcomingTrips.remove(at: index)
            }
            
            // Refresh trips to ensure everything is in sync with server
            Task {
                let id = await supabaseController.getUserID()
                await supabaseController.updateVehicleStatus(newStatus: .underMaintenance, vehicleID: trip.vehicleDetails.id)
                await supabaseController.updateDriverStatus(newStatus: .busy, userID: id, id: nil)
            }
            try await fetchTrips()
            print("Trips refreshed after starting trip")
        } catch {
            print("Error starting trip: \(error)")
            throw TripError.updateError("Failed to start trip: \(error.localizedDescription)")
        }
    }
    
    // Update refreshTrips to handle loading state
    @MainActor
    func refreshTrips() async {
        isLoading = true
        do {
            try await fetchTrips()
        } catch {
            print("Error during refresh: \(error)")
            if let tripError = error as? TripError {
                self.error = tripError
            }
        }
        isLoading = false
    }
    
    @MainActor
    func updateTripInspectionStatus(tripId: UUID, isPreTrip: Bool, completed: Bool) async throws {
        do {
            let field = isPreTrip ? "has_completed_pre_trip" : "has_completed_post_trip"
            print("Updating trip \(tripId) with \(field)=\(completed)")
            
            // First update the database
            let response = try await supabaseController.databaseFrom("trips")
                .update([field: completed])
                .eq("id", value: tripId)
                .execute()
            
            print("Update success response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            
            // Then update our local model to reflect changes immediately
            if let currentTrip = self.currentTrip, currentTrip.id == tripId {
                var updatedTrip = currentTrip
                if isPreTrip {
                    updatedTrip.hasCompletedPreTrip = completed
                } else {
                    updatedTrip.hasCompletedPostTrip = completed
                }
                self.currentTrip = updatedTrip
                print("Updated local trip model with \(field)=\(completed)")
            } else {
                print("Warning: Current trip is nil or doesn't match the updated trip ID")
                // Trip might be in upcoming trips
                let index = upcomingTrips.firstIndex(where: { $0.id == tripId })
                if let index = index {
                    var updatedTrip = upcomingTrips[index]
                    if isPreTrip {
                        updatedTrip.hasCompletedPreTrip = completed
                    } else {
                        updatedTrip.hasCompletedPostTrip = completed
                    }
                    upcomingTrips[index] = updatedTrip
                    print("Updated trip in upcoming trips with \(field)=\(completed)")
                }
            }
            
            // Optional: Refresh trips to ensure UI is up-to-date with server state
            // Only do this if you're experiencing synchronization issues
            // Otherwise, the local model update above should be sufficient
            try await fetchTrips()
            
            print("Trips refreshed after inspection update")
        } catch {
            print("Error updating trip inspection status: \(error)")
            throw TripError.updateError("Failed to update trip inspection status: \(error.localizedDescription)")
        }
    }
    
    private func filterTripsByDriver(trips: [Trip]) -> [Trip] {
        // Filter trips by the current driver ID if set
        guard let driverId = driverId else {
            return trips // Return all trips if no driver ID is set
        }
        
        return trips.filter { trip in
            trip.driverId == driverId
        }
    }
    
    /// Deletes a trip by its ID (soft delete)
    /// - Parameter id: The ID of the trip to delete
    /// - Returns: Void
    /// - Throws: Error if the deletion fails
    @MainActor
    func deleteTrip(id: UUID) async throws {
        // Soft delete the trip in the database
        supabaseController.deleteTrip(tripID: id)
        
        // Update local state
        allTrips.removeAll { $0.id == id }
        upcomingTrips.removeAll { $0.id == id }
        if let currentTrip = currentTrip, currentTrip.id == id {
            self.currentTrip = nil
        }
        recentDeliveries.removeAll { $0.id == id }
    }
    
    func generateDeliveryReceipt(for trip: Trip, signature: Data? = nil) throws -> Data {
        guard trip.status == .delivered else {
            throw TripError.updateError("Cannot generate receipt for non-delivered trip")
        }
        
        let driverName = trip.driverId.flatMap { driverId in
            CrewDataController.shared.drivers.first { $0.userID == driverId }?.name
        } ?? "Unassigned"
        
        // Create a PDF document
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            // Set up the content area with margins
            let contentRect = pageRect.insetBy(dx: 50, dy: 50)
            var currentY = contentRect.minY
            
            // Title attributes
            let titleStyle = NSMutableParagraphStyle()
            titleStyle.alignment = .center
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .paragraphStyle: titleStyle,
                .foregroundColor: UIColor.black
            ]
            
            // Header attributes
            let headerStyle = NSMutableParagraphStyle()
            headerStyle.alignment = .left
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
            ]
            
            // Content attributes
            let contentStyle = NSMutableParagraphStyle()
            contentStyle.alignment = .left
            let contentAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
            ]
            
            // Draw title
            let title = "DELIVERY RECEIPT"
            let titleSize = title.size(withAttributes: titleAttributes)
            title.draw(at: CGPoint(x: (pageRect.width - titleSize.width) / 2, y: currentY),
                      withAttributes: titleAttributes)
            currentY += titleSize.height + 20
            
            // Function to draw a field with label
            func drawField(label: String, value: String, at yPos: inout CGFloat) {
                let fieldHeight: CGFloat = 25
                let labelWidth: CGFloat = 150
                
                // Draw border
                let fieldRect = CGRect(x: contentRect.minX, y: yPos, width: contentRect.width, height: fieldHeight)
                let borderPath = UIBezierPath(rect: fieldRect)
                UIColor.black.setStroke()
                borderPath.lineWidth = 0.5
                borderPath.stroke()
                
                // Draw label
                label.draw(at: CGPoint(x: contentRect.minX + 5, y: yPos + 5),
                         withAttributes: headerAttributes)
                
                // Draw value
                value.draw(at: CGPoint(x: contentRect.minX + labelWidth + 5, y: yPos + 5),
                         withAttributes: contentAttributes)
                
                yPos += fieldHeight
            }
            
            // Draw fields
            drawField(label: "Trip ID:", value: trip.id.uuidString, at: &currentY)
            drawField(label: "Status:", value: trip.status.rawValue, at: &currentY)
            drawField(label: "Vehicle:", value: "\(trip.vehicleDetails.make) \(trip.vehicleDetails.model)", at: &currentY)
            drawField(label: "License Plate:", value: trip.vehicleDetails.licensePlate, at: &currentY)
            drawField(label: "Driver:", value: driverName, at: &currentY)
            
            currentY += 20 // Add spacing
            
            drawField(label: "Destination:", value: trip.destination, at: &currentY)
            drawField(label: "Address:", value: trip.address, at: &currentY)
            drawField(label: "Distance:", value: trip.distance, at: &currentY)
            
            currentY += 20 // Add spacing
            
            drawField(label: "Start Time:", value: trip.startTime?.formatted() ?? "N/A", at: &currentY)
            drawField(label: "End Time:", value: trip.endTime?.formatted() ?? "N/A", at: &currentY)
            
            currentY += 20 // Add spacing
            
            let estimatedFuelCost = Double(trip.distance.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0 * 0.5
            let totalRevenue = estimatedFuelCost + 50.0
            
            drawField(label: "Estimated Fuel Cost:", value: "$\(String(format: "%.2f", estimatedFuelCost))", at: &currentY)
            drawField(label: "Total Revenue:", value: "$\(String(format: "%.2f", totalRevenue))", at: &currentY)
            
            if let notes = trip.notes, !notes.isEmpty {
                currentY += 20
                "Notes:".draw(at: CGPoint(x: contentRect.minX, y: currentY),
                            withAttributes: headerAttributes)
                currentY += 20
                
                let notesRect = CGRect(x: contentRect.minX, y: currentY,
                                     width: contentRect.width, height: 60)
                let notesBorder = UIBezierPath(rect: notesRect)
                UIColor.black.setStroke()
                notesBorder.lineWidth = 0.5
                notesBorder.stroke()
                
                notes.draw(in: notesRect.insetBy(dx: 5, dy: 5),
                          withAttributes: contentAttributes)
                currentY += 80
            }
            
            // Draw signature section at the bottom
            let signatureY = contentRect.maxY - 100
            
            // Draw signature header
            "Fleet Manager's Signature:".draw(
                at: CGPoint(x: contentRect.minX, y: signatureY),
                withAttributes: headerAttributes
            )
            
            // Draw signature box
            let signatureRect = CGRect(
                x: contentRect.minX,
                y: signatureY + 20,
                width: 200,
                height: 60
            )
            
            let signatureBox = UIBezierPath(rect: signatureRect)
            UIColor.black.setStroke()
            signatureBox.lineWidth = 0.5
            signatureBox.stroke()
            
            // Draw signature if available
            if let signatureData = signature,
               let signatureImage = UIImage(data: signatureData) {
                signatureImage.draw(in: signatureRect.insetBy(dx: 5, dy: 5))
            }
            
            // Draw date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            let dateString = "Date: \(dateFormatter.string(from: Date()))"
            dateString.draw(
                at: CGPoint(x: contentRect.maxX - 200, y: signatureY + 40),
                withAttributes: contentAttributes
            )
        }
        
        return data
    }
} 


extension TripDataController {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways:
            // Enable background location updates now that we have the proper authorization.
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
            print("Background location updates enabled.")
        case .authorizedWhenInUse:
            // For authorizedWhenInUse, background updates are not enabled.
            manager.allowsBackgroundLocationUpdates = false
            print("Location updates allowed only in the foreground.")
        default:
            // Handle other cases (.denied, .restricted, etc.)
            manager.allowsBackgroundLocationUpdates = false
            print("Location updates are not permitted.")
        }
    }
    
    // You can also implement other delegate methods as needed.
}
