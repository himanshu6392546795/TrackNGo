import SwiftUI
import CoreLocation

// Trip Status Enum
enum TripStatus: String, Codable {
    case pending = "upcoming"
    case inProgress = "current"
    case delivered = "delivered"
    case assigned = "assigned"
}

// Trip Model
struct Trip: Identifiable, Equatable {
    let id: UUID
    var destination: String
    var address: String
    var eta: String
    let distance: String
    var status: TripStatus
    var hasCompletedPreTrip: Bool
    var hasCompletedPostTrip: Bool
    let vehicleDetails: Vehicle
    var notes: String?
    let startTime: Date?
    let endTime: Date?
    let sourceCoordinate: CLLocationCoordinate2D
    let destinationCoordinate: CLLocationCoordinate2D
    let startingPoint: String
    let pickup: String?
    let driverId: UUID?
    
    // Computed property for display purposes
    var displayName: String {
        pickup ?? "Trip-\(id.uuidString.prefix(8))"
    }
    
    static func == (lhs: Trip, rhs: Trip) -> Bool {
        return lhs.id == rhs.id &&
               lhs.destination == rhs.destination &&
               lhs.address == rhs.address &&
               lhs.eta == rhs.eta &&
               lhs.distance == rhs.distance &&
               lhs.status == rhs.status &&
               lhs.hasCompletedPreTrip == rhs.hasCompletedPreTrip &&
               lhs.hasCompletedPostTrip == rhs.hasCompletedPostTrip &&
               lhs.vehicleDetails == rhs.vehicleDetails &&
               lhs.notes == rhs.notes &&
               lhs.startTime == rhs.startTime &&
               lhs.endTime == rhs.endTime &&
               lhs.sourceCoordinate.latitude == rhs.sourceCoordinate.latitude &&
               lhs.sourceCoordinate.longitude == rhs.sourceCoordinate.longitude &&
               lhs.destinationCoordinate.latitude == rhs.destinationCoordinate.latitude &&
               lhs.destinationCoordinate.longitude == rhs.destinationCoordinate.longitude &&
               lhs.startingPoint == rhs.startingPoint &&
               lhs.pickup == rhs.pickup &&
               lhs.driverId == rhs.driverId
    }
    
    init(from supabaseTrip: SupabaseTrip, vehicle: Vehicle) {
        self.id = supabaseTrip.id
        self.destination = supabaseTrip.destination
        self.address = supabaseTrip.pickup ?? "N/A"
        self.status = TripStatus(rawValue: supabaseTrip.trip_status) ?? .pending
        self.hasCompletedPreTrip = supabaseTrip.has_completed_pre_trip
        self.hasCompletedPostTrip = supabaseTrip.has_completed_post_trip
        self.vehicleDetails = vehicle
        self.notes = supabaseTrip.notes
        self.startTime = supabaseTrip.start_time
        self.endTime = supabaseTrip.end_time
        self.pickup = supabaseTrip.pickup
        self.driverId = supabaseTrip.driver_id
        
        // Set distance using estimated_distance if available
        if let estimatedDistance = supabaseTrip.estimated_distance {
            self.distance = String(format: "%.1f km", estimatedDistance)
        } else if let notes = supabaseTrip.notes,
                  let distanceRange = notes.range(of: "Estimated Distance: "),
                  let endRange = notes[distanceRange.upperBound...].range(of: "\n") {
            // Try to extract distance from notes as fallback
            let distanceStr = String(notes[distanceRange.upperBound..<endRange.lowerBound])
            self.distance = distanceStr.trimmingCharacters(in: .whitespaces)
        } else {
            self.distance = "N/A"
        }
        
        // Set ETA using estimated_time if available
        if let estimatedTime = supabaseTrip.estimated_time {
            let hours = Int(estimatedTime)
            let minutes = Int((estimatedTime - Double(hours)) * 60)
            if hours > 0 {
                self.eta = "\(hours)h \(minutes)m"
            } else {
                self.eta = "\(minutes) mins"
            }
        } else if let notes = supabaseTrip.notes,
                  let etaRange = notes.range(of: "Estimated Time: "),
                  let endRange = notes[etaRange.upperBound...].range(of: "\n") {
            // Try to extract ETA from notes as fallback
            let etaStr = String(notes[etaRange.upperBound..<endRange.lowerBound])
            self.eta = etaStr.trimmingCharacters(in: .whitespaces)
        } else {
            self.eta = "N/A"
        }
        
        // Set coordinates from the trip data
        self.sourceCoordinate = CLLocationCoordinate2D(
            latitude: supabaseTrip.start_latitude ?? 0,
            longitude: supabaseTrip.start_longitude ?? 0
        )
        self.destinationCoordinate = CLLocationCoordinate2D(
            latitude: supabaseTrip.end_latitude ?? 0,
            longitude: supabaseTrip.end_longitude ?? 0
        )
        self.startingPoint = supabaseTrip.pickup ?? "N/A"
    }
}

// Delivery Details Model
struct DeliveryDetails: Identifiable, Equatable {
    let id: UUID
    let location: String
    let date: String
    let status: String
    let driver: String
    let vehicle: String
    let notes: String
    
    init(id: UUID = UUID(), location: String, date: String, status: String, driver: String, vehicle: String, notes: String) {
        self.id = id
        self.location = location
        self.date = date
        self.status = status
        self.driver = driver
        self.vehicle = vehicle
        self.notes = notes
    }
    
    static func == (lhs: DeliveryDetails, rhs: DeliveryDetails) -> Bool {
        return lhs.id == rhs.id &&
               lhs.location == rhs.location &&
               lhs.date == rhs.date &&
               lhs.status == rhs.status &&
               lhs.driver == rhs.driver &&
               lhs.vehicle == rhs.vehicle &&
               lhs.notes == rhs.notes
    }
}

// Supabase Trip Model
struct SupabaseTrip: Codable, Identifiable {
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
    let created_at: Date?
    let updated_at: Date?
    let is_deleted: Bool
    let start_latitude: Double?
    let start_longitude: Double?
    let end_latitude: Double?
    let end_longitude: Double?
    let pickup: String?
    let estimated_distance: Double?
    let estimated_time: Double?
}

extension TimeInterval {
    var etaString: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) mins"
        }
    }
} 
