class Trip: Identifiable, ObservableObject {
    let id: UUID
    @Published var destination: String
    @Published var status: TripStatus
    @Published var hasCompletedPreTrip: Bool
    @Published var hasCompletedPostTrip: Bool
    @Published var vehicleId: UUID
    @Published var driverId: UUID?
    @Published var secondaryDriverId: UUID?
    @Published var startTime: Date?
    @Published var endTime: Date?
    @Published var notes: String?
    let createdAt: Date
    let updatedAt: Date
    let isDeleted: Bool
    @Published var startLatitude: Double?
    @Published var startLongitude: Double?
    @Published var endLatitude: Double?
    @Published var endLongitude: Double?
    @Published var pickup: String?
    @Published var estimatedDistance: Double?
    @Published var estimatedTime: Double?
    @Published var vehicle: Vehicle?
    
    // Display-related properties
    @Published var address: String
    @Published var eta: String
    @Published var distance: String
    
    // Computed property for display purposes
    var displayName: String {
        pickup ?? "Trip-\(id.uuidString.prefix(8))"
    }
    
    var sourceCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: startLatitude ?? 0,
            longitude: startLongitude ?? 0
        )
    }
    
    var destinationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: endLatitude ?? 0,
            longitude: endLongitude ?? 0
        )
    }
    
    var startingPoint: String {
        pickup ?? "Unknown"
    }

    init(from supabaseTrip: SupabaseTrip, vehicle: Vehicle? = nil) {
        self.id = supabaseTrip.id
        self.destination = supabaseTrip.destination
        self.status = supabaseTrip.trip_status
        self.hasCompletedPreTrip = supabaseTrip.has_completed_pre_trip
        self.hasCompletedPostTrip = supabaseTrip.has_completed_post_trip
        self.vehicleId = supabaseTrip.vehicle_id
        self.driverId = supabaseTrip.driver_id
        self.secondaryDriverId = supabaseTrip.secondary_driver_id
        self.startTime = supabaseTrip.start_time
        self.endTime = supabaseTrip.end_time
        self.notes = supabaseTrip.notes
        self.createdAt = supabaseTrip.created_at
        self.updatedAt = supabaseTrip.updated_at ?? supabaseTrip.created_at
        self.isDeleted = supabaseTrip.is_deleted
        self.startLatitude = supabaseTrip.start_latitude
        self.startLongitude = supabaseTrip.start_longitude
        self.endLatitude = supabaseTrip.end_latitude
        self.endLongitude = supabaseTrip.end_longitude
        self.pickup = supabaseTrip.pickup
        self.estimatedDistance = supabaseTrip.estimated_distance
        self.estimatedTime = supabaseTrip.estimated_time
        self.vehicle = vehicle
        
        // Initialize display-related properties
        self.address = supabaseTrip.pickup ?? "No address provided"
        self.eta = ""  // ETA will be calculated later
        self.distance = String(format: "%.1f km", supabaseTrip.estimated_distance ?? 0.0)
    }
} 