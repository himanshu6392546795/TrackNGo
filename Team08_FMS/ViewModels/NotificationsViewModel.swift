import SwiftUI
import Combine
@preconcurrency import Supabase

enum NotificationType: String, Codable {
    case tripStarted = "trip_started"
    case tripCompleted = "trip_completed"
    case preInspectionIssue = "pre_inspection_issue"
    case postInspectionIssue = "post_inspection_issue"
    case vehicleIssue = "vehicle_issue"
    case tripDelayed = "trip_delayed"
    case locationUpdate = "location_update"
    case issueReportSubmitted = "issue_report_submitted"
    case fuelBillSubmitted = "fuel_bill_submitted"
    case chatMessage = "chat_message"
    case emergency = "emergency"
    case maintenance = "maintenance"
    case arrivedAtPickup = "arrived_at_pickup"
    case leftPickup = "left_pickup"
    case arrivedAtDropoff = "arrived_at_dropoff"
    case leftDropoff = "left_dropoff"
}

struct NotificationMetadata: Codable {
    let start_point: String?
    let end_point: String?
    let start_time: String?
    let end_time: String?
    let distance_km: String?
    let issues: String?
    let inspection_time: String?
    let issue: String?
    let report_time: String?
    let reason: String?
    let delay_time: String?
    let latitude: String?
    let longitude: String?
    let update_time: String?
    let fuel_amount: String?
    let submission_time: String?
}

struct Notification: Identifiable, Codable {
    let id: UUID
    let message: String
    let type: String
    let created_at: Date
    var is_read: Bool
    let metadata: NotificationMetadata?
    let trip_id: UUID?
    let vehicle_id: UUID?
    let fleet_manager_id: UUID?
    let driver_id: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id, message, type, created_at, is_read, metadata
        case trip_id, vehicle_id, fleet_manager_id, driver_id
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        message = try container.decode(String.self, forKey: .message)
        type = try container.decode(String.self, forKey: .type)
        is_read = try container.decode(Bool.self, forKey: .is_read)
        
        // Handle multiple date formats
        let dateString = try container.decode(String.self, forKey: .created_at)
        print("Attempting to parse date: \(dateString)")
        
        // Try different date formats
        if let date = Notification.postgresDateFormatter.date(from: dateString) {
            print("Successfully parsed with postgres formatter")
            created_at = date
        } else if let date = Notification.backupDateFormatter.date(from: dateString) {
            print("Successfully parsed with backup formatter")
            created_at = date
        } else if let date = Notification.iso8601Formatter.date(from: dateString) {
            print("Successfully parsed with ISO8601 formatter")
            created_at = date
        } else {
            print("Failed to parse date with all formatters")
            throw DecodingError.dataCorruptedError(forKey: .created_at,
                  in: container,
                  debugDescription: "Could not parse date string: \(dateString)")
        }
        
        // Decode optional fields
        metadata = try container.decodeIfPresent(NotificationMetadata.self, forKey: .metadata)
        trip_id = try container.decodeIfPresent(UUID.self, forKey: .trip_id)
        vehicle_id = try container.decodeIfPresent(UUID.self, forKey: .vehicle_id)
        fleet_manager_id = try container.decodeIfPresent(UUID.self, forKey: .fleet_manager_id)
        driver_id = try container.decodeIfPresent(UUID.self, forKey: .driver_id)
    }
    
    // Primary Postgres timestamp format (2025-03-31 06:20:09+00)
    private static let postgresDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    // Backup formatter for alternative format (2025-03-31T06:20:09+00:00)
    private static let backupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    // ISO8601 formatter as final fallback
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

@MainActor
final class NotificationsViewModel: ObservableObject {
    // ... existing properties ...
    
    // MARK: - Notification Creation Methods
    
    func sendTripStartedNotification(trip: Trip) async throws {
        let metadata = NotificationMetadata(
            start_point: trip.start_point,
            end_point: trip.end_point,
            start_time: ISO8601DateFormatter().string(from: Date()),
            end_time: nil,
            distance_km: nil,
            issues: nil,
            inspection_time: nil,
            issue: nil,
            report_time: nil,
            reason: nil,
            delay_time: nil,
            latitude: nil,
            longitude: nil,
            update_time: nil
        )
        
        let notification = createNotification(
            type: .tripStarted,
            title: "Trip Started",
            message: "Trip from \(trip.start_point) to \(trip.end_point) has started.",
            tripId: trip.id,
            vehicleId: trip.vehicle_id,
            driverId: trip.driver_id,
            fleetManagerId: trip.fleet_manager_id,
            metadata: metadata
        )
        
        try await insertNotification(notification)
    }
    
    func sendTripCompletedNotification(trip: Trip) async throws {
        let metadata = NotificationMetadata(
            start_point: trip.start_point,
            end_point: trip.end_point,
            start_time: nil,
            end_time: ISO8601DateFormatter().string(from: Date()),
            distance_km: String(format: "%.2f", trip.distance_km ?? 0),
            issues: nil,
            inspection_time: nil,
            issue: nil,
            report_time: nil,
            reason: nil,
            delay_time: nil,
            latitude: nil,
            longitude: nil,
            update_time: nil
        )
        
        let notification = createNotification(
            type: .tripCompleted,
            title: "Trip Completed",
            message: "Trip from \(trip.start_point) to \(trip.end_point) has been completed.",
            tripId: trip.id,
            vehicleId: trip.vehicle_id,
            driverId: trip.driver_id,
            fleetManagerId: trip.fleet_manager_id,
            metadata: metadata
        )
        
        try await insertNotification(notification)
    }
    
    func sendVehicleIssueNotification(trip: Trip, vehicleId: UUID, vehicleRegNumber: String = "", issue: String) async throws {
        let metadata = NotificationMetadata(
            start_point: trip.start_point,
            end_point: trip.end_point,
            start_time: nil,
            end_time: nil,
            distance_km: nil,
            issues: nil,
            inspection_time: nil,
            issue: issue,
            report_time: ISO8601DateFormatter().string(from: Date()),
            reason: nil,
            delay_time: nil,
            latitude: nil,
            longitude: nil,
            update_time: nil
        )
        
        let vehicleIdentifier = vehicleRegNumber.isEmpty ? "Vehicle" : "Vehicle \(vehicleRegNumber)"
        let notification = createNotification(
            type: .vehicleIssue,
            title: "Vehicle Issue Reported",
            message: "\(vehicleIdentifier) issue reported during trip from \(trip.start_point) to \(trip.end_point): \(issue)",
            tripId: trip.id,
            vehicleId: vehicleId,
            driverId: trip.driver_id,
            fleetManagerId: trip.fleet_manager_id,
            metadata: metadata
        )
        
        try await insertNotification(notification)
    }
    
    // MARK: - Helper Methods
    
    private func createNotification(
        type: NotificationType,
        title: String,
        message: String,
        tripId: UUID? = nil,
        vehicleId: UUID? = nil,
        driverId: UUID? = nil,
        fleetManagerId: UUID? = nil,
        metadata: NotificationMetadata? = nil
    ) -> [String: Any] {
        var notification: [String: Any] = [
            "id": UUID().uuidString,
            "type": type.rawValue,
            "message": message,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "is_read": false
        ]
        
        if let tripId = tripId {
            notification["trip_id"] = tripId.uuidString
        }
        if let vehicleId = vehicleId {
            notification["vehicle_id"] = vehicleId.uuidString
        }
        if let driverId = driverId {
            notification["driver_id"] = driverId.uuidString
        }
        if let fleetManagerId = fleetManagerId {
            notification["fleet_manager_id"] = fleetManagerId.uuidString
        }
        if let metadata = metadata {
            let encoder = JSONEncoder()
            if let metadataData = try? encoder.encode(metadata),
               let metadataString = String(data: metadataData, encoding: .utf8) {
                notification["metadata"] = metadataString
            }
        }
        
        return notification
    }
    
    private func insertNotification(_ notification: [String: Any]) async throws {
        do {
            let response = try await supabaseDataController.supabase.database
                .from("notifications")
                .insert(notification)
                .select()
                .single()
                .execute()
            
            print("Notification inserted successfully")
            await loadNotifications()
        } catch {
            print("Error inserting notification: \(error)")
            throw error
        }
    }
    
    // ... rest of the existing code ...
}