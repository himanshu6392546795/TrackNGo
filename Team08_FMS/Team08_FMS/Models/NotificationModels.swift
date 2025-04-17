import SwiftUI

enum NotificationType: String, Codable {
    case tripAlert = "trip_alert"
    case chatMessage = "chat_message"
    case unknown = "unknown"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = NotificationType(rawValue: rawValue) ?? .unknown
    }
    
    var iconName: String {
        switch self {
        case .tripAlert:
            return "exclamationmark.triangle.fill"
        case .chatMessage:
            return "message.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .tripAlert:
            return .red
        case .chatMessage:
            return .blue
        case .unknown:
            return .gray
        }
    }
    
    var shouldShowBanner: Bool {
        switch self {
        case .tripAlert, .chatMessage:
            return true
        case .unknown:
            return false
        }
    }
}

struct NotificationItem: Identifiable, Codable, Equatable {
    let id: UUID
    let message: String
    let type: NotificationType
    let created_at: Date
    var is_read: Bool
    var tripId: UUID?
    
    static func == (lhs: NotificationItem, rhs: NotificationItem) -> Bool {
        lhs.id == rhs.id
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case message
        case type
        case created_at
        case is_read
        case tripId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        id = try container.decode(UUID.self, forKey: .id)
        message = try container.decode(String.self, forKey: .message)
        
        // Handle type field - if decoding fails, use unknown type
        let typeString = try container.decode(String.self, forKey: .type)
        type = NotificationType(rawValue: typeString) ?? .unknown
        
        // Handle nullable timestamp with timezone
        if let dateString = try container.decodeIfPresent(String.self, forKey: .created_at) {
            if let date = Self.iso8601Formatter.date(from: dateString) {
                created_at = date
            } else if let date = Self.postgresDateFormatter.date(from: dateString) {
                created_at = date
            } else {
                created_at = Date()  // Default to current date if parsing fails
            }
        } else {
            created_at = Date()  // Default to current date if timestamp is null
        }
        
        // Handle nullable is_read with default false
        is_read = try container.decodeIfPresent(Bool.self, forKey: .is_read) ?? false
        tripId = try container.decodeIfPresent(UUID.self, forKey: .tripId)
    }
    
    // ISO8601 formatter - try this first for timezone support
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        return formatter
    }()
    
    // Postgres timestamp format with timezone
    private static let postgresDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSZZZZZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
} 