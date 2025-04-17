import SwiftUI
import MapKit

struct NavigationMapView: UIViewRepresentable {
    let destination: CLLocationCoordinate2D
    let pickup: CLLocationCoordinate2D  // Add pickup coordinate
    @Binding var userLocation: CLLocationCoordinate2D?
    @Binding var route: MKRoute?
    @Binding var userHeading: Double
    let followsUserLocation: Bool
    @Binding var isRouteCompleted: Bool
    let geofenceRadius: CLLocationDistance = 50.0 // Increased from 200m to 500m for better visibility
    
    // For updating ETA and distance
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onRouteDeviation: (() -> Void)?  // Add callback for route deviation
    
    // Add variables for route deviation detection
    private let routeDeviationThreshold: Double = 50.0  // Meters
    
    class MapAnnotation: NSObject, MKAnnotation {
        let coordinate: CLLocationCoordinate2D
        let title: String?
        let subtitle: String?
        let type: AnnotationType
        
        enum AnnotationType {
            case source
            case pickup
            case destination
            case completed
        }
        
        init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String? = nil, type: AnnotationType) {
            self.coordinate = coordinate
            self.title = title
            self.subtitle = subtitle
            self.type = type
        }
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        // Disable automatic tracking - we'll handle it manually
        mapView.userTrackingMode = .none
        
        // Set map type to standard for better visibility of buildings and blocks
        mapView.mapType = .standard
        
        // Configure map features
        mapView.showsBuildings = true
        mapView.showsTraffic = true
        mapView.pointOfInterestFilter = .includingAll
        
        // Apply custom map styling for better building and block visibility
        let mapConfiguration = MKStandardMapConfiguration()
        mapConfiguration.pointOfInterestFilter = .includingAll
        mapConfiguration.showsTraffic = true
        mapConfiguration.emphasisStyle = .muted
        mapView.preferredConfiguration = mapConfiguration
        
        // Initial camera setup
        let camera = MKMapCamera()
        camera.centerCoordinate = destination
        camera.centerCoordinateDistance = 500
        camera.pitch = 0
        camera.heading = 0
        mapView.camera = camera
        
        // Add destination annotation
        let destinationAnnotation = MapAnnotation(
            coordinate: destination,
            title: "Destination",
            subtitle: "Your delivery point",
            type: .destination
        )
        mapView.addAnnotation(destinationAnnotation)
        
        #if targetEnvironment(simulator)
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        mapView.addGestureRecognizer(panGesture)
        #endif
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove existing overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        // Add pickup annotation and geofence
        let pickupAnnotation = MapAnnotation(
            coordinate: pickup,
            title: "Pickup",
            subtitle: "Pickup location",
            type: .pickup
        )
        mapView.addAnnotation(pickupAnnotation)
        
        // Add pickup geofence circle
        let pickupGeofence = MKCircle(center: pickup, radius: geofenceRadius)
        mapView.addOverlay(pickupGeofence, level: .aboveRoads)
        
        // Add destination annotation and geofence
        let destinationAnnotation = MapAnnotation(
            coordinate: destination,
            title: "Destination",
            subtitle: "Your delivery point",
            type: .destination
        )
        mapView.addAnnotation(destinationAnnotation)
        
        // Add destination geofence circle
        let destinationGeofence = MKCircle(center: destination, radius: geofenceRadius)
        mapView.addOverlay(destinationGeofence, level: .aboveRoads)
        
        // Add route overlay if available
        if let route = route {
            mapView.addOverlay(route.polyline)
            
            // Show entire route if not following user
            if !followsUserLocation && !context.coordinator.isUpdatingCamera {
                let routeRect = route.polyline.boundingMapRect
                // Add padding to the route rect
                let paddedRect = routeRect.insetBy(
                    dx: -routeRect.width * 0.1,
                    dy: -routeRect.height * 0.1
                )
                let region = mapView.regionThatFits(
                    MKCoordinateRegion(paddedRect)
                )
                
                context.coordinator.queueCameraUpdate {
                    UIView.animate(withDuration: 1.0) {
                        mapView.setRegion(region, animated: false)
                    } completion: { _ in
                        context.coordinator.isUpdatingCamera = false
                    }
                }
            }
        }
        
        // Update user location and camera
        if let userLocation = userLocation {
            // Check for route deviation and trigger recalculation
            if let route = route, !isRouteCompleted {
                let location = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                if context.coordinator.checkRouteDeviation(userLocation: location, route: route) {
                    // Notify parent about deviation to recalculate route
                    onRouteDeviation?()
                }
            }
            
            if followsUserLocation && !context.coordinator.isUpdatingCamera {
                context.coordinator.queueCameraUpdate {
                    let camera = MKMapCamera(
                        lookingAtCenter: userLocation,
                        fromDistance: 500,
                        pitch: 45,
                        heading: userHeading
                    )
                    
                    UIView.animate(withDuration: 1.0, delay: 0, options: .curveEaseInOut) {
                        mapView.camera = camera
                    } completion: { _ in
                        context.coordinator.isUpdatingCamera = false
                    }
                }
            }
            
            // Update source annotation
            context.coordinator.updateSourceAnnotation(
                at: userLocation,
                on: mapView,
                heading: userHeading
            )
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: NavigationMapView
        var lastLocation: CLLocation?
        var currentRouteId: Int?
        var sourceAnnotation: MapAnnotation?
        var simulatedSpeed: Double = 5.0
        var updateCount: Int = 0
        var lastUpdateTime: Date = Date()
        var isUpdatingCamera: Bool = false
        var updateTimer: Timer?
        var pendingCameraUpdate: (() -> Void)?
        var lastRouteDeviation: Date?
        var completedPathCoordinates: [CLLocationCoordinate2D] = []
        var remainingPolyline: MKPolyline?
        private let minimumUpdateInterval: TimeInterval = 15.0 // 15 seconds between updates
        
        init(_ parent: NavigationMapView) {
            self.parent = parent
            super.init()
            setupUpdateTimer()
        }
        
        deinit {
            updateTimer?.invalidate()
        }
        
        private func setupUpdateTimer() {
            // Set timer to fire every 15 seconds
            updateTimer = Timer.scheduledTimer(withTimeInterval: minimumUpdateInterval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if !self.isUpdatingCamera, let pendingUpdate = self.pendingCameraUpdate {
                    self.isUpdatingCamera = true
                    DispatchQueue.main.async {
                        pendingUpdate()
                        self.pendingCameraUpdate = nil
                        self.isUpdatingCamera = false
                    }
                }
            }
        }
        
        func queueCameraUpdate(_ update: @escaping () -> Void) {
            // Only queue update if enough time has passed
            let now = Date()
            if now.timeIntervalSince(lastUpdateTime) >= minimumUpdateInterval {
                pendingCameraUpdate = update
                lastUpdateTime = now
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            guard let customAnnotation = annotation as? MapAnnotation else {
                return nil
            }
            
            let identifier = "CustomPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: customAnnotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = customAnnotation
            }
            
            switch customAnnotation.type {
            case .source:
                annotationView?.markerTintColor = .systemBlue
                annotationView?.glyphImage = UIImage(systemName: "location.fill")
            case .destination:
                annotationView?.markerTintColor = .systemRed
                annotationView?.glyphImage = UIImage(systemName: "flag.fill")
            case .completed:
                annotationView?.markerTintColor = .systemGreen
                annotationView?.glyphImage = UIImage(systemName: "checkmark.circle.fill")
            case .pickup:
                annotationView?.markerTintColor = .systemGreen
                annotationView?.glyphImage = UIImage(systemName: "location.fill")
            }
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 5
                return renderer
            } else if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                
                // Check if this is the pickup or destination geofence
                if circle.coordinate.latitude == parent.pickup.latitude && 
                   circle.coordinate.longitude == parent.pickup.longitude {
                    // Pickup geofence (green)
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
                    renderer.strokeColor = UIColor.systemGreen
                } else {
                    // Destination geofence (red)
                    renderer.fillColor = UIColor.systemRed.withAlphaComponent(0.2)
                    renderer.strokeColor = UIColor.systemRed
                }
                
                renderer.lineWidth = 4
                renderer.lineDashPattern = [30, 20]
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // For simulator testing
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            #if targetEnvironment(simulator)
            guard let mapView = gesture.view as? MKMapView else { return }
            
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            // Update user location
            if gesture.state == .changed {
                parent.userLocation = coordinate
                
                // Simulate heading based on movement
                if let lastCoord = lastLocation?.coordinate {
                    let heading = calculateHeading(from: lastCoord, to: coordinate)
                    parent.userHeading = heading
                }
                
                // Update location
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                lastLocation = location
                parent.onLocationUpdate?(location)
            }
            #endif
        }
        
        private func calculateHeading(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
            let deltaLong = to.longitude - from.longitude
            let deltaLat = to.latitude - from.latitude
            let heading = (atan2(deltaLong, deltaLat) * 180.0 / .pi + 360.0).truncatingRemainder(dividingBy: 360.0)
            return heading
        }
        
        func updateSourceAnnotation(at coordinate: CLLocationCoordinate2D, on mapView: MKMapView, heading: Double) {
            // Remove old source annotation if it exists
            if let oldAnnotation = sourceAnnotation {
                mapView.removeAnnotation(oldAnnotation)
            }
            
            // Create new source annotation with distance info
            let distanceString = lastLocation.map { loc -> String in
                let distance = loc.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                return String(format: "Moved %.0f meters", distance)
            } ?? "Starting point"
            
            let newAnnotation = MapAnnotation(
                coordinate: coordinate,
                title: "Current Location",
                subtitle: distanceString,
                type: .source
            )
            sourceAnnotation = newAnnotation
            
            // Add new annotation with animation
            UIView.animate(withDuration: 0.3) {
                mapView.addAnnotation(newAnnotation)
            }
            
            // Update location for distance calculations
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if lastLocation?.distance(from: location) ?? 0 > 5 { // Only update if moved more than 5 meters
                lastLocation = location
                parent.onLocationUpdate?(location)
                
                // Update the completed path
                if !parent.isRouteCompleted, let route = parent.route {
                    updateCompletedPath(currentLocation: location, route: route, mapView: mapView)
                }
            }
        }
        
        // Add method to update completed path segments
        func updateCompletedPath(currentLocation: CLLocation, route: MKRoute, mapView: MKMapView) {
            let polyline = route.polyline
            let pointCount = polyline.pointCount
            let points = polyline.points()
            
            // Find the closest point on the route
            var closestPointIndex = 0
            var closestDistance = Double.greatestFiniteMagnitude
            
            for i in 0..<pointCount {
                let polylinePoint = points[i]
                let coordinate = CLLocationCoordinate2D(
                    latitude: CLLocationDegrees(polylinePoint.x),
                    longitude: CLLocationDegrees(polylinePoint.y)
                )
                
                let routeLocation = CLLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                
                let distance = currentLocation.distance(from: routeLocation)
                if distance < closestDistance {
                    closestDistance = distance
                    closestPointIndex = i
                }
            }
            
            // Only update if we're close to the route
            if closestDistance <= parent.routeDeviationThreshold {
                // Create array of remaining coordinates (from closest point to end)
                var remainingCoordinates: [CLLocationCoordinate2D] = []
                
                // Add current point plus all remaining points
                for i in closestPointIndex..<pointCount {
                    let point = points[i]
                    let coordinate = CLLocationCoordinate2D(
                        latitude: CLLocationDegrees(point.x),
                        longitude: CLLocationDegrees(point.y)
                    )
                    remainingCoordinates.append(coordinate)
                }
                
                // Create new polyline for remaining route
                if remainingCoordinates.count >= 2 {
                    // Remove old polyline
                    if let oldPolyline = remainingPolyline {
                        mapView.removeOverlay(oldPolyline)
                    }
                    
                    // Create and add new polyline
                    let newPolyline = MKPolyline(coordinates: remainingCoordinates, count: remainingCoordinates.count)
                    remainingPolyline = newPolyline
                    
                    // Remove all overlays and add the new one
                    mapView.removeOverlays(mapView.overlays)
                    mapView.addOverlay(newPolyline)
                    
                    print("Updated route: \(pointCount - closestPointIndex) points remaining")
                }
                
                // Store completed coordinates for potential rendering
                completedPathCoordinates = []
                for i in 0..<closestPointIndex {
                    let point = points[i]
                    let coordinate = CLLocationCoordinate2D(
                        latitude: CLLocationDegrees(point.x),
                        longitude: CLLocationDegrees(point.y)
                    )
                    completedPathCoordinates.append(coordinate)
                }
            }
        }
        
        // Update map region change monitoring
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let now = Date()
            // Only log updates that occur after minimum interval
            if now.timeIntervalSince(lastUpdateTime) >= minimumUpdateInterval {
                lastUpdateTime = now
                updateCount += 1
                
                #if DEBUG
                let span = mapView.region.span
                print("Map Update #\(updateCount)")
                print("New zoom levels - Latitude span: \(span.latitudeDelta), Longitude span: \(span.longitudeDelta)")
                print("Center coordinate: \(mapView.region.center)")
                print("Camera altitude: \(mapView.camera.altitude)")
                print("-------------------")
                #endif
            }
        }
        
        func updateUserLocation(_ mapView: MKMapView) {
            guard parent.followsUserLocation,
                  let userLocation = parent.userLocation,
                  CLLocationCoordinate2DIsValid(userLocation) else { return }
            
            let now = Date()
            // Only update user location if enough time has passed
            if now.timeIntervalSince(lastUpdateTime) >= minimumUpdateInterval {
                let region = MKCoordinateRegion(
                    center: userLocation,
                    latitudinalMeters: 1000,
                    longitudinalMeters: 1000
                )
                DispatchQueue.main.async {
                    mapView.setRegion(mapView.regionThatFits(region), animated: true)
                    self.lastUpdateTime = now
                }
            }
        }
        
        // Add method to check for route deviation
        func checkRouteDeviation(userLocation: CLLocation, route: MKRoute) -> Bool {
            guard let closestPoint = findClosestPointOnRoute(userLocation: userLocation, route: route) else {
                return false
            }
            
            let distanceFromRoute = userLocation.distance(from: closestPoint)
            return distanceFromRoute > parent.routeDeviationThreshold
        }
        
        private func findClosestPointOnRoute(userLocation: CLLocation, route: MKRoute) -> CLLocation? {
            var closestPoint: CLLocation?
            var minDistance = Double.infinity
            
            let routePoints = route.polyline.points()
            let pointCount = route.polyline.pointCount
            
            for i in 0..<pointCount {
                let point = routePoints[i]
                let location = CLLocation(
                    latitude: CLLocationDegrees(point.x),
                    longitude: CLLocationDegrees(point.y)
                )
                let distance = userLocation.distance(from: location)
                
                if distance < minDistance {
                    minDistance = distance
                    closestPoint = location
                }
            }
            
            return closestPoint
        }
    }
} 
