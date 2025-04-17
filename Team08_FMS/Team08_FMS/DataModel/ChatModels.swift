import Foundation
import SwiftUI

// Message status enum matching our database
enum MessageStatus: String, Codable {
    case sent
    case delivered
    case read
}

// Message model
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let fleet_manager_id: UUID
    let recipient_id: UUID
    let recipient_type: String
    let message_text: String
    var status: MessageStatus
    let created_at: Date
    var updated_at: Date
    var is_deleted: Bool
    let attachment_url: String?
    let attachment_type: String?
    
    // Additional UI properties - not stored in database
    var isFromCurrentUser: Bool = false
    var isFromFleetManager: Bool {
        // If the recipient_type is "driver", then the message is from fleet manager
        // If the recipient_type is "maintenance", then the message is from maintenance
        recipient_type == "driver"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case fleet_manager_id
        case recipient_id
        case recipient_type
        case message_text
        case status
        case created_at
        case updated_at
        case is_deleted
        case attachment_url
        case attachment_type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fleet_manager_id = try container.decode(UUID.self, forKey: .fleet_manager_id)
        recipient_id = try container.decode(UUID.self, forKey: .recipient_id)
        recipient_type = try container.decode(String.self, forKey: .recipient_type)
        message_text = try container.decode(String.self, forKey: .message_text)
        status = try container.decode(MessageStatus.self, forKey: .status)
        created_at = try container.decode(Date.self, forKey: .created_at)
        updated_at = try container.decode(Date.self, forKey: .updated_at)
        is_deleted = try container.decode(Bool.self, forKey: .is_deleted)
        attachment_url = try container.decodeIfPresent(String.self, forKey: .attachment_url)
        attachment_type = try container.decodeIfPresent(String.self, forKey: .attachment_type)
    }
    
    init(id: UUID, fleet_manager_id: UUID, recipient_id: UUID, recipient_type: String, 
         message_text: String, status: MessageStatus, created_at: Date, updated_at: Date, 
         is_deleted: Bool, attachment_url: String?, attachment_type: String?, isFromCurrentUser: Bool) {
        self.id = id
        self.fleet_manager_id = fleet_manager_id
        self.recipient_id = recipient_id
        self.recipient_type = recipient_type
        self.message_text = message_text
        self.status = status
        self.created_at = created_at
        self.updated_at = updated_at
        self.is_deleted = is_deleted
        self.attachment_url = attachment_url
        self.attachment_type = attachment_type
        self.isFromCurrentUser = isFromCurrentUser
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fleet_manager_id, forKey: .fleet_manager_id)
        try container.encode(recipient_id, forKey: .recipient_id)
        try container.encode(recipient_type, forKey: .recipient_type)
        try container.encode(message_text, forKey: .message_text)
        try container.encode(status, forKey: .status)
        try container.encode(created_at, forKey: .created_at)
        try container.encode(updated_at, forKey: .updated_at)
        try container.encode(is_deleted, forKey: .is_deleted)
        try container.encodeIfPresent(attachment_url, forKey: .attachment_url)
        try container.encodeIfPresent(attachment_type, forKey: .attachment_type)
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// View model for chat bubble animation
struct ChatBubbleAnimation {
    static let springAnimation = Animation.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)
    static let messageAppearance = Animation.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)
    static let typing = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
}

// Chat Theme Colors
struct ChatThemeColors {
    static let primary = Color.blue
    static let secondary = Color.gray.opacity(0.2)
    static let text = Color.primary
    static let timestamp = Color.gray
    static let emergency = Color.red
} 