import SwiftUI
import Combine
import UserNotifications
@preconcurrency import Supabase

private struct MessagePayload: Encodable {
    let id: String
    let fleet_manager_id: String
    let recipient_id: String
    let recipient_type: String
    let message_text: String
    let status: String
    let created_at: String
    let updated_at: String
    let is_deleted: Bool
    let attachment_url: String?
    let attachment_type: String?
}

private struct NotificationPayload: Encodable {
    let message: String
    let type: String
    let created_at: String
    let is_read: Bool
}

// Add DatabaseChange struct
private struct DatabaseChange<T: Codable>: Codable {
    let schema: String
    let table: String
    let commit_timestamp: String
    let eventType: String
    let new: T?
    let old: T?
    
    enum CodingKeys: String, CodingKey {
        case schema
        case table
        case commit_timestamp
        case eventType = "type"
        case new
        case old
    }
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var unreadCount: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    private let supabaseDataController = SupabaseDataController.shared
    private let recipientId: UUID
    private let recipientType: RecipientType
    private var realtimeChannel: RealtimeChannel?
    private var refreshTimer: Timer?
    private var hasLoadedMessages = false
    private var lastMessageId: UUID?
    private let storageClient: SupabaseStorageClient
    private let storageBucket = "chat-attachments"
    private var currentLoadTask: Task<Void, Never>?
    private let maxRetries = 3
    
    init(recipientId: UUID, recipientType: RecipientType) {
        self.recipientId = recipientId
        self.recipientType = recipientType
        self.storageClient = supabaseDataController.supabase.storage
        
        Task {
            await requestNotificationPermission()
            
            do {
                try await createStorageBucketIfNeeded()
            } catch {
                print("❌ Error creating storage bucket: \(error)")
                self.error = error
            }
            
            await loadMessages()
            await setupMessageListener()
            updateUnreadCount()
            setupRefreshTimer()
        }
    }
    
    private func requestNotificationPermission() async {
        do {
            let center = UNUserNotificationCenter.current()
            try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("❌ Failed to request notification permission: \(error)")
        }
    }
    
    private func showMessageNotification(_ message: ChatMessage) async {
        guard !message.isFromCurrentUser else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "\(recipientType.displayName) Message"
        content.body = message.message_text
        content.sound = .default
        content.threadIdentifier = "chat_\(recipientId.uuidString)" // Group messages from same chat
        
        // Add custom data
        content.userInfo = [
            "message_id": message.id.uuidString,
            "recipient_id": recipientId.uuidString,
            "recipient_type": recipientType.rawValue
        ]
        
        let request = UNNotificationRequest(
            identifier: message.id.uuidString,
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("❌ Error showing message notification: \(error)")
        }
    }
    
    private func setupMessageListener() async {
        // First, cleanup any existing channel
        realtimeChannel?.unsubscribe()
        
        let channel = supabaseDataController.supabase.realtime
            .channel("chat_messages")
        
        channel.on("postgres_changes", filter: .init(
            event: "*",
            schema: "public",
            table: "chat_messages"
        )) { [weak self] payload in
            guard let self = self else { return }
            
            Task { @MainActor in
                do {
                    if payload.event == "INSERT" {
                        if let data = try? JSONSerialization.data(withJSONObject: payload.payload["record"] ?? [:]),
                           let message = try? JSONDecoder().decode(ChatMessage.self, from: data) {
                            // Show notification for new message
                            await self.showMessageNotification(message)
                        }
                    }
                    await self.fetchNewMessages()
                }
            }
        }
        
        print("🔔 Subscribing to chat messages channel...")
        channel.subscribe()
        self.realtimeChannel = channel
    }
    
    func clearMessages() {
        messages = []
    }
    
    private func setupRefreshTimer() {
        // Cancel existing timer if any
        refreshTimer?.invalidate()
        
        // Create a new timer that refreshes every 5 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchNewMessages()
            }
        }
    }
    
    func loadMessages() async {
        // Cancel any existing load task
        currentLoadTask?.cancel()
        
        // Create new load task
        currentLoadTask = Task { @MainActor in
            guard !hasLoadedMessages else { return }
            
            self.isLoading = true
            var retryCount = 0
            
            while retryCount < maxRetries {
                do {
                    guard let currentUserId = await supabaseDataController.getUserID() else {
                        print("No current user ID found")
                        return
                    }
                    
                    let userRole = supabaseDataController.userRole
                    
                    // Build the query based on user role and recipient type
                    var query = supabaseDataController.supabase
                        .from("chat_messages")
                        .select()
                    
                    // Add the appropriate filters based on user role
                    if userRole == "fleet_manager" {
                        query = query
                            .eq("recipient_type", value: recipientType.rawValue)
                            .or("and(fleet_manager_id.eq.\(currentUserId.uuidString),recipient_id.eq.\(recipientId.uuidString)),and(fleet_manager_id.eq.\(recipientId.uuidString),recipient_id.eq.\(currentUserId.uuidString))")
                    } else {
                        query = query
                            .eq("recipient_type", value: recipientType.rawValue)
                            .or("and(fleet_manager_id.eq.\(recipientId.uuidString),recipient_id.eq.\(currentUserId.uuidString)),and(fleet_manager_id.eq.\(currentUserId.uuidString),recipient_id.eq.\(recipientId.uuidString))")
                    }
                    
                    let response = try await query
                        .order("created_at", ascending: true)
                        .execute()
                    
                    // Check if task was cancelled
                    if Task.isCancelled {
                        print("Load messages task was cancelled")
                        return
                    }
                    
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateString = try container.decode(String.self)
                        
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        
                        if let date = formatter.date(from: dateString) {
                            return date
                        }
                        
                        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                        if let date = formatter.date(from: dateString) {
                            return date
                        }
                        
                        throw DecodingError.dataCorruptedError(
                            in: container,
                            debugDescription: "Cannot decode date string \(dateString)"
                        )
                    }
                    
                    var fetchedMessages = try decoder.decode([ChatMessage].self, from: response.data)
                    
                    // Check if task was cancelled again
                    if Task.isCancelled {
                        print("Load messages task was cancelled during decoding")
                        return
                    }
                    
                    // Update isFromCurrentUser for each message
                    for index in fetchedMessages.indices {
                        var message = fetchedMessages[index]
                        if userRole == "fleet_manager" {
                            message.isFromCurrentUser = message.fleet_manager_id.uuidString == currentUserId.uuidString
                        } else {
                            message.isFromCurrentUser = message.recipient_id.uuidString != currentUserId.uuidString
                        }
                        fetchedMessages[index] = message
                        
                        // Mark as read if needed
                        if message.recipient_id.uuidString == currentUserId.uuidString && message.status == .sent {
                            Task {
                                await self.markMessageAsRead(message.id)
                            }
                        }
                    }
                    
                    self.messages = fetchedMessages
                    self.lastMessageId = fetchedMessages.last?.id
                    self.isLoading = false
                    self.hasLoadedMessages = true
                    break // Success, exit retry loop
                    
                } catch {
                    if Task.isCancelled {
                        print("Load messages task was cancelled during error handling")
                        return
                    }
                    
                    retryCount += 1
                    print("Error loading messages (attempt \(retryCount)/\(maxRetries)): \(error)")
                    
                    if retryCount == maxRetries {
                        self.error = error
                        self.isLoading = false
                    } else {
                        // Wait before retrying (with exponential backoff)
                        try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount))) * 1_000_000_000)
                    }
                }
            }
        }
    }
    
    private func fetchNewMessages() async {
        do {
            guard let currentUserId = await supabaseDataController.getUserID() else { return }
            
            var query = supabaseDataController.supabase
                .from("chat_messages")
                .select()
            
            if let lastId = lastMessageId {
                query = query.gt("id", value: lastId)
            }
            
            let userRole = supabaseDataController.userRole
            if userRole == "fleet_manager" {
                query = query
                    .eq("recipient_type", value: recipientType.rawValue)
                    .or("and(fleet_manager_id.eq.\(currentUserId.uuidString),recipient_id.eq.\(recipientId.uuidString)),and(fleet_manager_id.eq.\(recipientId.uuidString),recipient_id.eq.\(currentUserId.uuidString))")
            } else {
                query = query
                    .eq("recipient_type", value: recipientType.rawValue)
                    .or("and(fleet_manager_id.eq.\(recipientId.uuidString),recipient_id.eq.\(currentUserId.uuidString)),and(fleet_manager_id.eq.\(currentUserId.uuidString),recipient_id.eq.\(recipientId.uuidString))")
            }
            
            let response = try await query
                .order("created_at", ascending: true)
                .execute()
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.locale = Locale(identifier: "en_US_POSIX")
                
                if let date = formatter.date(from: dateString) {
                    return date
                }
                
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                if let date = formatter.date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date string \(dateString)"
                )
            }
            
            if let newMessages = try? decoder.decode([ChatMessage].self, from: response.data) {
                await MainActor.run {
                    for var message in newMessages {
                        if !self.messages.contains(where: { $0.id == message.id }) {
                            if userRole == "fleet_manager" {
                                message.isFromCurrentUser = message.fleet_manager_id.uuidString == currentUserId.uuidString
                            } else {
                                message.isFromCurrentUser = message.recipient_id.uuidString != currentUserId.uuidString
                            }
                            
                            self.messages.append(message)
                            self.lastMessageId = message.id
                            
                            if message.recipient_id.uuidString == currentUserId.uuidString && message.status == .sent {
                                Task {
                                    await self.markMessageAsRead(message.id)
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            print("Error fetching new messages: \(error)")
        }
    }
    
    private func updateUnreadCount() {
        Task {
            do {
                guard let currentUserId = await supabaseDataController.getUserID() else { return }
                
                let response = try await supabaseDataController.supabase
                    .from("chat_messages")
                    .select("count")
                    .eq("recipient_id", value: currentUserId.uuidString)
                    .eq("status", value: MessageStatus.sent.rawValue)
                    .execute()
                
                if let jsonObject = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
                   let count = jsonObject["count"] as? Int {
                    await MainActor.run {
                        self.unreadCount = count
                    }
                }
            } catch {
                print("Error updating unread count: \(error)")
            }
        }
    }
    
    private func createNotification(message: String, type: String) async throws {
        let notification = NotificationPayload(
            message: message,
            type: type,
            created_at: ISO8601DateFormatter().string(from: Date()),
            is_read: false
        )
        
        do {
            let response = try await supabaseDataController.supabase
                .from("notifications")
                .insert(notification)
                .select()
                .single()
                .execute()
            
            if let jsonObject = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] {
                if let id = jsonObject["id"] as? String {
                    print("Notification created with ID: \(id)")
                }
                if let messageText = jsonObject["message"] as? String {
                    print("Notification message: \(messageText)")
                }
            }
        } catch {
            print("Failed to create notification: \(error.localizedDescription)")
            throw error
        }
    }
    
    func sendMessage(_ text: String) {
        Task {
            do {
                guard let currentUserId = await supabaseDataController.getUserID() else {
                    print("No user ID found")
                    return
                }
                
                let userRole = supabaseDataController.userRole
                print("Sending message as role: \(userRole ?? "unknown")")
                
                let (messageFleetManagerId, messageRecipientId): (UUID, UUID)
                
                if userRole == "fleet_manager" {
                    messageFleetManagerId = currentUserId
                    messageRecipientId = recipientId
                } else {
                    messageFleetManagerId = recipientId
                    messageRecipientId = currentUserId
                }
                
                let message = ChatMessage(
                    id: UUID(),
                    fleet_manager_id: messageFleetManagerId,
                    recipient_id: messageRecipientId,
                    recipient_type: recipientType.rawValue,
                    message_text: text,
                    status: .sent,
                    created_at: Date(),
                    updated_at: Date(),
                    is_deleted: false,
                    attachment_url: nil,
                    attachment_type: nil,
                    isFromCurrentUser: true
                )
                
                let response = try await supabaseDataController.supabase
                    .from("chat_messages")
                    .insert(message)
                    .select()
                    .single()
                    .execute()
                
                if let jsonObject = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] {
                    if let id = jsonObject["id"] as? String {
                        print("Message sent with ID: \(id)")
                    }
                    if let messageText = jsonObject["message_text"] as? String {
                        print("Message content: \(messageText)")
                    }
                    
                    // Create notification for fleet manager if message is from driver
                    if userRole != "fleet_manager" {
                        let notificationMessage = "New message from \(recipientType.rawValue): \(text)"
                        try await createNotification(
                            message: notificationMessage,
                            type: "chat_message"
                        )
                    }
                    
                    await MainActor.run {
                        self.messages.append(message)
                    }
                    
                    await loadMessages()
                }
                
            } catch {
                print("Error sending message: \(error.localizedDescription)")
                self.error = error
            }
        }
    }
    
    private func createStorageBucketIfNeeded() async throws {
        do {
            print("Checking if bucket exists: \(storageBucket)")
            do {
                // Try to get bucket info first
                _ = try await storageClient.getBucket(storageBucket)
                print("Bucket already exists: \(storageBucket)")
            } catch {
                print("Bucket does not exist, creating: \(storageBucket)")
                // Create the bucket with public access and specific mime types
                try await storageClient.createBucket(
                    storageBucket,
                    options: BucketOptions(
                        public: true,
                        fileSizeLimit: String(10485760), // 10MB limit
                        allowedMimeTypes: ["image/jpeg", "image/png"]
                    )
                )
                print("Successfully created bucket: \(storageBucket)")
            }
        } catch {
            print("Error managing storage bucket: \(error)")
            throw error
        }
    }
    
    func sendImage(_ image: UIImage) async {
        do {
            // Ensure image is not too large (max 10MB)
            var compressionQuality: CGFloat = 0.7
            var imageData = image.jpegData(compressionQuality: compressionQuality)
            
            while let data = imageData, data.count > 10 * 1024 * 1024 && compressionQuality > 0.1 {
                compressionQuality -= 0.1
                imageData = image.jpegData(compressionQuality: compressionQuality)
            }
            
            guard let finalImageData = imageData else {
                print("Failed to convert image to data")
                return
            }
            
            let fileName = "\(UUID().uuidString).jpg"
            
            // Upload image to storage
            try await storageClient
                .from(storageBucket)
                .upload(
                    path: fileName,
                    file: finalImageData,
                    options: FileOptions(
                        contentType: "image/jpeg"
                    )
                )
            
            // Get the public URL
            let publicURL = try await storageClient
                .from(storageBucket)
                .createSignedURL(
                    path: fileName,
                    expiresIn: 365 * 24 * 60 * 60 // 1 year in seconds
                )
            
            // Send message with image attachment
            guard let currentUserId = await supabaseDataController.getUserID() else {
                print("No user ID found")
                return
            }
            
            let userRole = supabaseDataController.userRole
            let (messageFleetManagerId, messageRecipientId): (UUID, UUID)
            
            if userRole == "fleet_manager" {
                messageFleetManagerId = currentUserId
                messageRecipientId = recipientId
            } else {
                messageFleetManagerId = recipientId
                messageRecipientId = currentUserId
            }
            
            // Convert URL to string
            let urlString = publicURL.absoluteString
            
            let message = ChatMessage(
                id: UUID(),
                fleet_manager_id: messageFleetManagerId,
                recipient_id: messageRecipientId,
                recipient_type: recipientType.rawValue,
                message_text: "📸 Photo",
                status: .sent,
                created_at: Date(),
                updated_at: Date(),
                is_deleted: false,
                attachment_url: urlString,
                attachment_type: "image/jpeg",
                isFromCurrentUser: true
            )
            
            print("Sending message with image URL: \(urlString)")
            
            let response = try await supabaseDataController.supabase
                .from("chat_messages")
                .insert(message)
                .select()
                .single()
                .execute()
            
            if let jsonObject = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] {
                if let id = jsonObject["id"] as? String {
                    print("Message with image sent, ID: \(id)")
                }
                
                // Create notification for fleet manager if message is from driver
                if userRole != "fleet_manager" {
                    let notificationMessage = "New photo from \(recipientType.rawValue)"
                    try await createNotification(
                        message: notificationMessage,
                        type: "chat_message"
                    )
                }
                
                await MainActor.run {
                    self.messages.append(message)
                }
                
                await loadMessages()
            }
            
        } catch {
            print("Error sending image: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    private func verifyRecipientExists() async throws -> Bool {
        let table = recipientType == .maintenance ? "maintenance_personnel" : "driver"
        print("Checking recipient in table: \(table)")
        print("Recipient ID: \(recipientId)")
        
        let response = try await supabaseDataController.supabase
            .from(table)
            .select("""
                userID,
                name,
                email
            """)
            .execute()
        
        // Print raw response for debugging
        if let responseString = String(data: response.data, encoding: .utf8) {
            print("Raw response: \(responseString)")
        }
        
        struct RecipientResponse: Codable {
            let userID: UUID
            let name: String
            let email: String
        }
        
        let decoder = JSONDecoder()
        if let recipients = try? decoder.decode([RecipientResponse].self, from: response.data) {
            print("Found \(recipients.count) recipients")
            for recipient in recipients {
                print("Recipient: \(recipient.name) (\(recipient.userID))")
                if recipient.userID == recipientId {
                    print("Match found!")
                    return true
                }
            }
        }
        
        print("No matching recipient found")
        return false
    }
    
    func markMessageAsRead(_ messageId: UUID) async {
        do {
            let response = try await supabaseDataController.supabase
                .from("chat_messages")
                .update(["status": MessageStatus.read.rawValue])
                .eq("id", value: messageId.uuidString)
                .execute()
            
            print("Message marked as read: \(response)")
            await MainActor.run {
                self.updateUnreadCount()
            }
        } catch {
            print("Error marking message as read: \(error)")
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
        realtimeChannel?.unsubscribe()
        currentLoadTask?.cancel()
    }
} 
