struct NavigationMapView: UIViewRepresentable {
    let destination: CLLocationCoordinate2D
    @Binding var userLocation: CLLocationCoordinate2D?
    @Binding var route: MKRoute?
    @Binding var userHeading: Double
    let followsUserLocation: Bool
    @Binding var isRouteCompleted: Bool
    let geofenceRadius: CLLocationDistance = 50.0 // Add geofence radius property
    
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
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove existing overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        // Add destination annotation and geofence
        let destinationAnnotation = MapAnnotation(
            coordinate: destination,
            title: "Destination",
            subtitle: "Your delivery point",
            type: .destination
        )
        mapView.addAnnotation(destinationAnnotation)
        
        // Add geofence circle for destination
        let geofenceCircle = MKCircle(center: destination, radius: geofenceRadius)
        mapView.addOverlay(geofenceCircle)
        
        // Add route overlay if available
        if let route = route {
            mapView.addOverlay(route.polyline)
        }
        
        // Update camera position based on user location and following mode
        if let userLocation = userLocation, followsUserLocation && !context.coordinator.isUpdatingCamera {
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
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        // ... existing coordinator code ...
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 5
                return renderer
            } else if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                // Light green fill with very low opacity
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.1)
                // Dashed green border
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2
                // Create dashed pattern
                renderer.lineDashPattern = [10, 10]
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // ... rest of existing coordinator code ...
    }
} 