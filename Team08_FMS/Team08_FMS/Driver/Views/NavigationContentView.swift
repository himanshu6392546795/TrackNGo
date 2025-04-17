import SwiftUI
import MapKit
import CoreLocation
import AVFoundation

class NavigationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var userHeading: Double = 0
    @Published var route: MKRoute?
    @Published var currentStep: MKRoute.Step?
    @Published var remainingDistance: CLLocationDistance = 0
    @Published var remainingTime: TimeInterval = 0
    @Published var nextStepDistance: CLLocationDistance = 0
    @Published var alternativeRoutes: [MKRoute] = []
    @Published var recentLocations: [CLLocation] = [] // Track recent locations for smooth animation
    @Published var etaUpdateError: String?
    
    private let locationManager: CLLocationManager
    private let _destination: CLLocationCoordinate2D
    let sourceCoordinate: CLLocationCoordinate2D?  // Changed from private to public
    private let vehicleType: VehicleType
    
    // Track both the last update time and the last location
    private var lastLocationUpdate: Date = Date()
    private(set) var lastLocation: CLLocation?
    private let updateThreshold: TimeInterval = 0.5 // Update every half second for smoother tracking
    private let locationHistoryLimit = 5 // Keep last 5 locations for smooth animation
    
    // Add a force route recalculation flag
    private var shouldRecalculateRoute = false
    
    // Vehicle specifications
    enum VehicleType {
        case truck(height: Double, weight: Double, length: Double)
        case van
        case car
        
        var routingPreference: MKDirectionsTransportType {
            switch self {
            case .truck, .van:
                return .automobile
            case .car:
                return .automobile
            }
        }
        
        var avoidHighways: Bool {
            switch self {
            case .truck, .van:
                return false
            case .car:
                return false
            }
        }
    }
    
    // Public getter for destination
    var destination: CLLocationCoordinate2D {
        _destination
    }
    
    private var lastSpeedUpdateTime: Date?
    private var speedReadings: [(speed: Double, timestamp: Date)] = []
    private let speedHistoryDuration: TimeInterval = 300 // Keep 5 minutes of speed history
    private let minimumSpeedThreshold: Double = 1.0 // Minimum speed in m/s to consider for ETA
    
    init(destination: CLLocationCoordinate2D, sourceCoordinate: CLLocationCoordinate2D? = nil, vehicleType: VehicleType = .truck(height: 4.5, weight: 40000, length: 16.5)) {
        self._destination = destination
        self.sourceCoordinate = sourceCoordinate  // Updated to use the public property
        self.vehicleType = vehicleType
        self.locationManager = CLLocationManager()
        
        super.init()
        
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
        self.locationManager.startUpdatingHeading()
        
        // If we have a source coordinate, calculate the initial route
        if let sourceCoord = sourceCoordinate {
            self.userLocation = sourceCoord
            let location = CLLocation(latitude: sourceCoord.latitude, longitude: sourceCoord.longitude)
            self.lastLocation = location  // Set the lastLocation property
            self.updateRoute(from: location)
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            // Enable background updates if we get always authorization
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        case .authorizedWhenInUse:
            // Disable background updates if we only have when in use authorization
            manager.allowsBackgroundLocationUpdates = false
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              Date().timeIntervalSince(lastLocationUpdate) >= updateThreshold else { return }
        
        lastLocationUpdate = Date()
        lastLocation = location
        userLocation = location.coordinate
        
        // Add to recent locations and maintain history limit
        recentLocations.append(location)
        if recentLocations.count > locationHistoryLimit {
            recentLocations.removeFirst()
        }
        
        // Update route if needed
        updateRoute(from: location)
        
        // Calculate speed and update ETA
        if recentLocations.count >= 2 {
            let speed = calculateCurrentSpeed()
            updateETABasedOnSpeed(speed)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        userHeading = newHeading.trueHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    // MARK: - Route Updates
    
    private func updateRoute(from location: CLLocation, forceRecalculation: Bool = false) {
        // Only update route if we don't have one yet or if we've moved significantly 
        // or if we're forcing recalculation due to deviation
        if route == nil || lastLocation == nil || 
           (lastLocation != nil && location.distance(from: lastLocation!) > 200) || 
           forceRecalculation {
            
            lastLocation = location
            
            let request = MKDirections.Request()
            
            // Always use current location for recalculations on deviation
            if forceRecalculation {
                print("Recalculating route due to deviation")
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
            } else {
                // Use provided source coordinate if available, otherwise use current location
                let sourceCoordinate = self.sourceCoordinate ?? location.coordinate
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: sourceCoordinate))
            }
            
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: _destination))
            request.transportType = vehicleType.routingPreference
            
            // Limit to just one route (primary) for better performance
            request.requestsAlternateRoutes = false
            
            // Add simplified route-specific preferences
            request.tollPreference = .avoid
            
            let directions = MKDirections(request: request)
            directions.calculate { [weak self] response, error in
                guard let self = self,
                      let response = response else {
                    print("Error calculating route: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                if let primaryRoute = response.routes.first {
                    // When recalculating due to deviation, always update the route
                    if forceRecalculation {
                        self.route = primaryRoute
                        
                        // Set default values for current step
                        if !primaryRoute.steps.isEmpty {
                            self.currentStep = primaryRoute.steps[0]
                            self.nextStepDistance = 0
                            
                            // Calculate estimated time and distance
                            self.remainingDistance = primaryRoute.distance
                            self.remainingTime = primaryRoute.expectedTravelTime
                        }
                    } else {
                        // Only replace route if we don't have one, or if it's significantly different
                        if self.route == nil || 
                           abs(self.route!.expectedTravelTime - primaryRoute.expectedTravelTime) > 60 ||
                           abs(self.route!.distance - primaryRoute.distance) > 1000 {
                            self.route = primaryRoute
                            
                            // Set default values for current step
                            if !primaryRoute.steps.isEmpty {
                                self.currentStep = primaryRoute.steps[0]
                                self.nextStepDistance = 0
                                
                                // Calculate estimated time and distance
                                self.remainingDistance = primaryRoute.distance
                                self.remainingTime = primaryRoute.expectedTravelTime
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func filterRoutes(_ routes: [MKRoute]) -> [MKRoute] {
        // Sort routes based on suitability for the vehicle type
        return routes.sorted { route1, route2 in
            let score1 = calculateRouteSuitability(route1)
            let score2 = calculateRouteSuitability(route2)
            return score1 > score2
        }
    }
    
    private func calculateRouteSuitability(_ route: MKRoute) -> Double {
        var score: Double = 0
        
        // Base score on route characteristics
        score += 1.0 / (route.expectedTravelTime / 3600) // Time factor
        score += 1.0 / (route.distance / 1000) // Distance factor
        
        // Check route steps for suitable roads
        for step in route.steps {
            if step.instructions.contains("highway") || step.instructions.contains("motorway") {
                score += 2.0 // Prefer major roads for trucks
            }
            if step.instructions.contains("residential") {
                score -= 1.0 // Penalize residential areas for trucks
            }
        }
        
        return score
    }
    
    private func getTruckRouteWaypoints(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> [MKMapItem]? {
        // This would ideally come from a backend service with known truck routes
        // For demonstration, we'll add some known truck-friendly points
        
        // Example: If route is in Mumbai area, use known truck corridors
        let isMumbaiRoute = isLocationInMumbai(start) || isLocationInMumbai(end)
        
        if isMumbaiRoute {
            // Known truck-friendly points in Mumbai
            let truckPoints: [(CLLocationCoordinate2D, String)] = [
                (CLLocationCoordinate2D(latitude: 19.0895, longitude: 72.8656), "Western Express Highway"),
                (CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777), "Eastern Express Highway")
            ]
            
            return truckPoints.map { coordinate, name in
                let placemark = MKPlacemark(coordinate: coordinate)
                let mapItem = MKMapItem(placemark: placemark)
                mapItem.name = name
                return mapItem
            }
        }
        
        return nil
    }
    
    private func isLocationInMumbai(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // Rough bounding box for Mumbai
        let mumbaiRegion = (
            minLat: 18.8928,
            maxLat: 19.2770,
            minLong: 72.7764,
            maxLong: 72.9864
        )
        
        return coordinate.latitude >= mumbaiRegion.minLat &&
               coordinate.latitude <= mumbaiRegion.maxLat &&
               coordinate.longitude >= mumbaiRegion.minLong &&
               coordinate.longitude <= mumbaiRegion.maxLong
    }
    
    private func isRouteSuitableForVehicle(_ route: MKRoute) -> Bool {
        switch vehicleType {
        case .truck:
            // Check if the route is suitable for trucks
            return !route.steps.contains { step in
                step.instructions.lowercased().contains("restricted") ||
                step.instructions.lowercased().contains("no trucks")
            }
        case .van:
            // Less restrictive checks for vans
            return true
        case .car:
            // All routes are suitable for cars
            return true
        }
    }
    
    func startNavigation() {
        // Request the highest level of authorization available
        locationManager.requestWhenInUseAuthorization()
        
        // Start updates
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    func stopNavigation() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    func updateNavigation(from location: CLLocation) {
        // Update the navigation based on the current location
        updateRoute(from: location)
        
        // Calculate remaining distance and time to destination
        if let route = route {
            let userLocation = location.coordinate
            let destinationLocation = destination
            
            // Approximate the remaining distance
            let directDistance = calculateDistance(from: userLocation, to: destinationLocation)
            remainingDistance = route.distance > directDistance ? route.distance : directDistance
            
            // Estimate remaining time based on average speed
            let averageSpeed = 40.0 // km/h (this can be calculated based on previous speeds)
            remainingTime = remainingDistance / (averageSpeed * 1000 / 3600)
            
            // Find the current step
            if !route.steps.isEmpty {
                let steps = route.steps
                // Find the closest step based on user location
                for (index, step) in steps.enumerated() {
                    if index < steps.count - 1 {
                        let nextStep = steps[index + 1]
                        let nextStepCoord = nextStep.polyline.coordinate
                        let distanceToNextStep = calculateDistance(from: userLocation, to: nextStepCoord)
                        
                        if distanceToNextStep < 500 { // If within 500m of the next maneuver
                            currentStep = nextStep
                            nextStepDistance = distanceToNextStep
                            break
                        } else if index == 0 {
                            currentStep = step
                            nextStepDistance = distanceToNextStep
                        }
                    } else {
                        // Last step
                        currentStep = step
                        nextStepDistance = calculateDistance(from: userLocation, to: destinationLocation)
                    }
                }
            }
        }
    }
    
    func selectRoute(_ route: MKRoute) {
        self.route = route
    }
    
    private func calculateDistance(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> CLLocationDistance {
        let sourceLoc = CLLocation(latitude: source.latitude, longitude: source.longitude)
        let destLoc = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        return sourceLoc.distance(from: destLoc)
    }
    
    func updateRouteWithAlternatives(from location: CLLocation) {
        // Clear existing alternatives first
        alternativeRoutes = []
        
        // Keep track of all requests to be made
        var pendingRequests = 3
        
        // Create base request
        let baseRequest = createRouteRequest(from: location.coordinate, to: _destination)
        baseRequest.requestsAlternateRoutes = true
        calculateRoute(with: baseRequest) { [weak self] routes in
            guard let self = self else { return }
            
            if !routes.isEmpty {
                // Set the first route as primary
                self.route = routes[0]
                // Add routes to alternatives, skipping the primary
                if routes.count > 1 {
                    self.alternativeRoutes.append(contentsOf: routes.dropFirst())
                }
            }
            
            pendingRequests -= 1
            // When all requests complete, sort routes by distance
            if pendingRequests == 0 {
                self.sortAlternativeRoutes()
            }
        }
        
        // Create a request with different toll preference
        let tollRequest = createRouteRequest(from: location.coordinate, to: _destination)
        tollRequest.requestsAlternateRoutes = true
        tollRequest.tollPreference = .any // Different from the default .avoid
        calculateRoute(with: tollRequest) { [weak self] routes in
            guard let self = self else { return }
            
            // Add unique routes
            self.addUniqueRoutes(routes)
            
            pendingRequests -= 1
            if pendingRequests == 0 {
                self.sortAlternativeRoutes()
            }
        }
        
        // Create a request with waypoints to force a different path
        if let waypoints = getAlternativeWaypoints(between: location.coordinate, and: _destination) {
            let waypointRequest = createRouteRequest(from: location.coordinate, to: _destination, 
                                                   via: waypoints)
            calculateRoute(with: waypointRequest) { [weak self] routes in
                guard let self = self else { return }
                
                // Add unique routes
                self.addUniqueRoutes(routes)
                
                pendingRequests -= 1
                if pendingRequests == 0 {
                    self.sortAlternativeRoutes()
                }
            }
        } else {
            pendingRequests -= 1
        }
    }
    
    private func createRouteRequest(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, 
                                  via waypoints: [CLLocationCoordinate2D]? = nil) -> MKDirections.Request {
        let request = MKDirections.Request()
        
        if let waypoints = waypoints, !waypoints.isEmpty {
            // Create a series of waypoints
            var items: [MKMapItem] = [MKMapItem(placemark: MKPlacemark(coordinate: source))]
            
            // Add intermediate waypoints
            for waypoint in waypoints {
                items.append(MKMapItem(placemark: MKPlacemark(coordinate: waypoint)))
            }
            
            // Add destination
            items.append(MKMapItem(placemark: MKPlacemark(coordinate: destination)))
            
            // Set up waypoints
            request.source = items.first
            request.destination = items.last
        } else {
            // Simple direct route
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        }
        
        request.transportType = vehicleType.routingPreference
        request.tollPreference = .avoid // Default
        return request
    }
    
    private func calculateRoute(with request: MKDirections.Request, completion: @escaping ([MKRoute]) -> Void) {
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let response = response, !response.routes.isEmpty else {
                completion([])
                return
            }
            completion(response.routes)
        }
    }
    
    private func getAlternativeWaypoints(between source: CLLocationCoordinate2D, and destination: CLLocationCoordinate2D) -> [CLLocationCoordinate2D]? {
        // Calculate midpoint between source and destination
        let midLat = (source.latitude + destination.latitude) / 2
        let midLng = (source.longitude + destination.longitude) / 2
        
        // Create waypoints that are offset from the midpoint in different directions
        // This forces routes to take different paths
        
        // Calculate distance and bearing between points
        let distance = calculateDistance(from: source, to: destination)
        
        // Only add waypoints for longer trips
        if distance < 5000 { // Less than 5km
            return nil
        }
        
        // For longer trips, create offset waypoints
        let offsetFactor = distance * 0.2 / 111000 // 20% of the distance in degrees (approx)
        
        return [
            // North offset
            CLLocationCoordinate2D(latitude: midLat + offsetFactor, longitude: midLng),
            
            // East offset
            CLLocationCoordinate2D(latitude: midLat, longitude: midLng + offsetFactor),
            
            // South offset
            CLLocationCoordinate2D(latitude: midLat - offsetFactor, longitude: midLng),
            
            // West offset
            CLLocationCoordinate2D(latitude: midLat, longitude: midLng - offsetFactor)
        ]
    }
    
    private func addUniqueRoutes(_ routes: [MKRoute]) {
        // Identify and add only routes that are meaningfully different from existing ones
        for route in routes {
            let isDuplicate = alternativeRoutes.contains { existingRoute in
                // Routes with similar travel time AND distance are likely duplicates
                let timeRatioDiff = abs(route.expectedTravelTime - existingRoute.expectedTravelTime) / existingRoute.expectedTravelTime
                let distanceRatioDiff = abs(route.distance - existingRoute.distance) / existingRoute.distance
                
                // Consider it duplicate if both time and distance are within 10% of each other
                return timeRatioDiff < 0.1 && distanceRatioDiff < 0.1
            }
            
            if !isDuplicate {
                alternativeRoutes.append(route)
            }
        }
    }
    
    private func sortAlternativeRoutes() {
        // Sort routes by distance to show a variety of options
        alternativeRoutes.sort { (route1, route2) -> Bool in
            return route1.distance < route2.distance
        }
        
        // Cap to a reasonable number if we have too many
        if alternativeRoutes.count > 5 {
            alternativeRoutes = Array(alternativeRoutes.prefix(5))
        }
    }
    
    private func calculateCurrentSpeed() -> CLLocationSpeed {
        guard recentLocations.count >= 2 else { return 0 }
        
        let lastTwo = Array(recentLocations.suffix(2))
        let distance = lastTwo[0].distance(from: lastTwo[1])
        let time = lastTwo[1].timestamp.timeIntervalSince(lastTwo[0].timestamp)
        
        // Add error handling for invalid time intervals
        guard time > 0 else {
            etaUpdateError = "Invalid time interval between location updates"
            return 0
        }
        
        let speed = distance / time // meters per second
        
        // Store speed reading with timestamp
        let now = Date()
        speedReadings.append((speed: speed, timestamp: now))
        
        // Remove old speed readings
        speedReadings = speedReadings.filter { now.timeIntervalSince($0.timestamp) <= speedHistoryDuration }
        
        return speed
    }
    
    private func updateETABasedOnSpeed(_ speed: CLLocationSpeed) {
        guard let route = route else {
            etaUpdateError = "No active route"
            return
        }
        
        // Only update if we're moving (speed > minimumSpeedThreshold)
        if speed > minimumSpeedThreshold {
            // Calculate average speed from recent readings
            let recentReadings = speedReadings.filter { 
                Date().timeIntervalSince($0.timestamp) <= 60 // Last minute of readings
            }
            
            if !recentReadings.isEmpty {
                let avgSpeed = recentReadings.map { $0.speed }.reduce(0, +) / Double(recentReadings.count)
                
                // Convert speed to km/h for easier calculation
//                let speedKmh = avgSpeed * 3.6
                
                // Update remaining time based on current speed and remaining distance
                if remainingDistance > 0 {
                    // Add some buffer for traffic lights and intersections
                    let estimatedDelay = calculateEstimatedDelays(for: route)
                    let baseTime = (remainingDistance / avgSpeed) // Base time in seconds
                    remainingTime = baseTime + estimatedDelay
                    
                    // Ensure minimum reasonable ETA
                    let minimumTime = remainingDistance / 30.0 // Assume maximum reasonable speed of 30 m/s
                    remainingTime = max(remainingTime, minimumTime)
                }
            }
        } else {
            // If speed is too low, use route's original ETA with some buffer
            remainingTime = route.expectedTravelTime * 1.1
        }
        
        // Update next step distance if we have a current step
        if let currentStep = currentStep,
           let userLocation = userLocation {
            let stepCoord = currentStep.polyline.coordinate
            nextStepDistance = calculateDistance(from: userLocation, to: stepCoord)
        }
    }
    
    private func calculateEstimatedDelays(for route: MKRoute) -> TimeInterval {
        var totalDelay: TimeInterval = 0
        
        // Count number of turns and traffic signals in remaining steps
        for step in route.steps {
            if step.instructions.contains("turn") || 
               step.instructions.contains("Take") ||
               step.instructions.contains("Exit") {
                totalDelay += 15 // Add 15 seconds for each turn
            }
            
            // Add delay for traffic signals (estimated from step distance)
            let stepDistance = step.distance
            let estimatedSignals = Int(stepDistance / 500) // Assume traffic signal every 500m in urban areas
            totalDelay += TimeInterval(estimatedSignals * 30) // 30 seconds per signal
        }
        
        return totalDelay
    }
    
    // Add force recalculation method
    func recalculateRoute() {
        if let location = lastLocation {
            print("Forcing route recalculation from current location")
            updateRoute(from: location, forceRecalculation: true)
        }
    }
}

struct RealTimeNavigationView: View {
    let destination: String
    let address: String
    let onDismiss: () -> Void
    
    @StateObject private var navigationManager: NavigationManager
    @State private var isFollowingUser = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingAlternativeRoutes = false
    @State private var isRouteCompleted = false  // Add state for route completion
    @State private var isDeviationAlertShown = false  // Add state for deviation alert
    
    init(destination: CLLocationCoordinate2D, destinationName: String, address: String, sourceCoordinate: CLLocationCoordinate2D?, onDismiss: @escaping () -> Void) {
        self.destination = destinationName
        self.address = address
        self.onDismiss = onDismiss
        
        // Initialize with the provided coordinates
        _navigationManager = StateObject(wrappedValue: NavigationManager(
            destination: destination,
            sourceCoordinate: sourceCoordinate
        ))
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval / 3600)
        let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm", minutes)
        } else {
            return "1m" // Show minimum of 1 minute
        }
    }
    
    // Add error handling alert
    private var errorAlert: Alert {
        Alert(
            title: Text("Navigation Update Error"),
            message: Text(navigationManager.etaUpdateError ?? "Unknown error occurred"),
            dismissButton: .default(Text("OK")) {
                navigationManager.etaUpdateError = nil
            }
        )
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Navigation Map
            NavigationMapView(
                destination: navigationManager.destination,
                pickup: navigationManager.sourceCoordinate ?? navigationManager.userLocation ?? navigationManager.destination,  // Use source or current location as pickup
                userLocation: $navigationManager.userLocation,
                route: $navigationManager.route,
                userHeading: $navigationManager.userHeading,
                followsUserLocation: isFollowingUser,
                isRouteCompleted: $isRouteCompleted,
                onLocationUpdate: { location in
                    navigationManager.updateNavigation(from: location)
                    
                    // Check if we've reached the destination
                    if let route = navigationManager.route {
                        print(route)
                        // Calculate distance to the actual destination coordinates
                        let destinationLocation = CLLocation(
                            latitude: navigationManager.destination.latitude,
                            longitude: navigationManager.destination.longitude
                        )
                        let distance = location.distance(from: destinationLocation)
                        
                        if distance < 50 { // Within 50 meters of destination
                            isRouteCompleted = true
                        }
                    }
                },
                onRouteDeviation: {
                    // Handle route deviation
                    isDeviationAlertShown = true
                    // Force recalculation
                    navigationManager.recalculateRoute()
                }
            )
            .ignoresSafeArea()
            
            // Route Information Banner
            VStack(spacing: 0) {
                // Top banner
                HStack(spacing: 16) {
                    Button(action: {
                        navigationManager.stopNavigation()
                        onDismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(destination)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // ETA and Distance Info
                    VStack(alignment: .trailing) {
                        Text(formatTime(navigationManager.remainingTime))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("\(Int(navigationManager.remainingDistance / 1000)) km")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 60) // Add top padding for status bar
                .padding(.bottom, 16)
                .background(Color.blue)
                .edgesIgnoringSafeArea(.top)
                
                // Show instruction only if available
                if let step = navigationManager.currentStep {
                    HStack(spacing: 16) {
                        // Instruction icon (turn direction)
                        DirectionIcon(step: step)
                            .frame(width: 30, height: 30)
                        
                        // Direction text
                        Text(step.instructions)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Distance to next maneuver
                        Text("\(Int(navigationManager.nextStepDistance)) m")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .padding([.horizontal, .bottom])
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
            }
            
            // Bottom Control Panel - Simplified to only essential buttons
            VStack {
                Spacer()
                
                // Alternative Routes Button
                Button(action: {
                    // Force recalculation to get alternatives
                    if let location = navigationManager.lastLocation {
                        navigationManager.updateRouteWithAlternatives(from: location)
                    }
                    showingAlternativeRoutes.toggle()
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.swap")
                        Text("Routes")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .foregroundColor(.blue)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                .padding(.bottom, 16)
                
                // Control buttons
                HStack(alignment: .center, spacing: 0) {
                    // Follow button
                    Button(action: {
                        isFollowingUser.toggle()
                    }) {
                        VStack {
                            Image(systemName: isFollowingUser ? "location.fill" : "location")
                                .font(.system(size: 24))
                                .padding(.bottom, 4)
                            Text("Follow")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.blue)
                    }
                    
                    // End button
                    Button(action: {
                        navigationManager.stopNavigation()
                        onDismiss()
                    }) {
                        VStack {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .padding(.bottom, 4)
                            Text("End")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                .padding(.bottom, 100) // Increased to prevent overlap with tab bar
            }
            
            // Add error handling alert
            .alert(isPresented: .constant(navigationManager.etaUpdateError != nil)) {
                errorAlert
            }
        }
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: 
            Button(action: {
                navigationManager.stopNavigation()
                onDismiss()
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back to Home")
                }
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(20)
            }
        )
        .onAppear {
            navigationManager.startNavigation()
        }
        .onDisappear {
            navigationManager.stopNavigation()
        }
        .alert(isPresented: $isDeviationAlertShown) {
            Alert(
                title: Text("Route Deviation Detected"),
                message: Text("Recalculating route to destination..."),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showingAlternativeRoutes) {
            AlternativeRoutesView(
                routes: navigationManager.alternativeRoutes,
                onSelectRoute: { route in
                    navigationManager.selectRoute(route)
                    showingAlternativeRoutes = false
                },
                onDismiss: {
                    showingAlternativeRoutes = false
                }
            )
        }
    }
}

// Direction icon component
struct DirectionIcon: View {
    let step: MKRoute.Step
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
            
            // Use different icons for different turn types
            if step.instructions.contains("right") {
                Image(systemName: "arrow.turn.up.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
            } else if step.instructions.contains("left") {
                Image(systemName: "arrow.turn.up.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
            } else if step.instructions.contains("Continue") || step.instructions.contains("straight") {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
            } else if step.instructions.contains("U-turn") {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
            } else if step.instructions.contains("Arrive") || step.instructions.contains("destination") {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.red)
            } else {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
            }
        }
    }
}

struct AlternativeRoutesView: View {
    let routes: [MKRoute]
    let onSelectRoute: (MKRoute) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(routes.indices, id: \.self) { index in
                    let route = routes[index]
                    Button(action: {
                        onSelectRoute(route)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Route \(index + 1)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 8) {
                                    Label("\(Int(route.distance / 1000)) km", systemImage: "arrow.left.and.right")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    
                                    Label("\(Int(route.expectedTravelTime / 60)) min", systemImage: "clock")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Alternative Routes")
            .navigationBarItems(trailing: Button("Close") {
                onDismiss()
            })
        }
    }
}

struct NavigationHeader: View {
    let destination: String
    let address: String
    let remainingDistance: CLLocationDistance
    let remainingTime: TimeInterval
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(destination)
                        .font(.system(size: 20, weight: .bold))
                        .lineLimit(1)
                    
                    Text(address)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            HStack {
                Label(formatDistance(remainingDistance), systemImage: "arrow.left.and.right")
                    .font(.system(size: 14))
                Spacer()
                Label(formatTime(remainingTime), systemImage: "clock.fill")
                    .font(.system(size: 14))
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        let kilometers = meters / 1000
        return String(format: "%.1f km", kilometers)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}

struct NextStepView: View {
    let instruction: String
    let distance: CLLocationDistance
    
    var body: some View {
        VStack(spacing: 0) {
            // Divider line
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3))
            
            HStack(spacing: 12) {
                // Direction icon in a blue circle
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: getDirectionIcon(for: instruction))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(instruction)
                        .font(.system(size: 16, weight: .medium))
                        .lineLimit(1)
                    
                    Text(formatDistance(distance))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.08))
        }
    }
    
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }
    
    private func getDirectionIcon(for instruction: String) -> String {
        if instruction.contains("right") {
            return "arrow.turn.right.circle.fill"
        } else if instruction.contains("left") {
            return "arrow.turn.left.circle.fill"
        } else if instruction.contains("Continue") || instruction.contains("Head") {
            return "arrow.up.circle.fill"
        } else if instruction.contains("destination") {
            return "flag.fill"
        } else {
            return "arrow.up.circle.fill"
        }
    }
}

struct AlternativeRouteRow: View {
    let distance: CLLocationDistance
    let time: TimeInterval
    let isRecommendedForTrucks: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "truck.fill")
                            .foregroundColor(isRecommendedForTrucks ? .green : .orange)
                        Text(isRecommendedForTrucks ? "Recommended for trucks" : "Alternative route")
                            .font(.subheadline)
                            .foregroundColor(isRecommendedForTrucks ? .green : .primary)
                    }
                    
                    Text(String(format: "%.1f km • %d min", distance / 1000, Int(time / 60)))
                        .font(.headline)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
}

struct NavigationControls: View {
    @Binding var isFollowingUser: Bool
    @Binding var showingLanes: Bool
    @Binding var showingOverview: Bool
    @Binding var isAudioEnabled: Bool
    @Binding var showingAlternativeRoutes: Bool
    let hasAlternatives: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            if hasAlternatives {
                Button(action: { showingAlternativeRoutes.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 14))
                        Text(showingAlternativeRoutes ? "Hide Routes" : "Routes")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                }
            }
            
            HStack(spacing: 16) {
                ControlButton(
                    icon: isAudioEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    text: "Audio",
                    isActive: isAudioEnabled
                ) {
                    isAudioEnabled.toggle()
                }
                
                ControlButton(
                    icon: "location.fill",
                    text: "Follow",
                    isActive: isFollowingUser
                ) {
                    isFollowingUser.toggle()
                }
                
                ControlButton(
                    icon: "map",
                    text: "Overview",
                    isActive: showingOverview
                ) {
                    withAnimation {
                        showingOverview.toggle()
                        if showingOverview {
                            showingLanes = false
                            isFollowingUser = false
                        }
                    }
                }
                
                Button(action: onDismiss) {
                    VStack {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.red)
                        }
                        
                        Text("Cancel")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(15)
        .shadow(radius: 5)
        .padding(.horizontal, 8)
    }
}

struct ControlButton: View {
    let icon: String
    let text: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isActive ? .blue : .gray)
                Text(text)
                    .font(.system(size: 11))
                    .foregroundColor(isActive ? .blue : .gray)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

extension TimeInterval {
    var formattedDuration: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
} 
