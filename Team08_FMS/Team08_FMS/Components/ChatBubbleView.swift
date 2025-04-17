import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    @State private var imageData: Data?
    @State private var isImageLoading = false
    @State private var isAnimating = false
    @StateObject private var supabaseController = SupabaseDataController.shared
    @State private var currentUserId: UUID?
    
    private var backgroundColor: Color {
        message.isFromCurrentUser ? .blue : Color(.systemGray5)
    }
    
    private var textColor: Color {
        message.isFromCurrentUser ? .white : .black
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                HStack {
                    if !message.isFromCurrentUser {
                        // Fleet manager icon
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 24))
                            .padding(.trailing, 4)
                    }
                    
                    VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                        if let attachmentUrl = message.attachment_url,
                           message.attachment_type == "image/jpeg" {
                            // Image message
                            VStack(alignment: .leading, spacing: 4) {
                                if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 200, maxHeight: 200)
                                        .cornerRadius(8)
                                } else {
                                    if isImageLoading {
                                        ProgressView()
                                            .frame(width: 200, height: 200)
                                    } else {
                                        Color.gray.opacity(0.3)
                                            .frame(width: 200, height: 200)
                                            .cornerRadius(8)
                                            .onAppear {
                                                loadImage(from: attachmentUrl)
                                            }
                                    }
                                }
                                
                                Text(message.created_at, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .padding(8)
                            .background(message.isFromCurrentUser ? ChatThemeColors.primary : Color(.systemGray6))
                            .cornerRadius(12)
                        } else {
                            // Text message
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message.message_text)
                                    .foregroundColor(message.isFromCurrentUser ? .white : .primary)
                                
                                Text(message.created_at, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(message.isFromCurrentUser ? .white.opacity(0.8) : .gray)
                            }
                            .padding(8)
                            .background(message.isFromCurrentUser ? ChatThemeColors.primary : Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        HStack(spacing: 4) {
                            Text(formatDate(message.created_at))
                                .font(.caption2)
                                .foregroundColor(.gray)
                            
                            if message.isFromCurrentUser {
                                Group {
                                    switch message.status {
                                    case .sent:
                                        Image(systemName: "checkmark")
                                    case .delivered:
                                        Image(systemName: "checkmark.circle")
                                    case .read:
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                }
                                .font(.caption2)
                                .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    if message.isFromCurrentUser {
                        // Driver icon
                        Image(systemName: "car.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 24))
                            .padding(.leading, 4)
                    }
                }
            }
            
            if !message.isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .onAppear {
            withAnimation(ChatBubbleAnimation.messageAppearance) {
                isAnimating = true
            }
            
            // Get current user ID when view appears
            Task {
                currentUserId = await supabaseController.getUserID()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        isImageLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                await MainActor.run {
                    self.imageData = data
                    self.isImageLoading = false
                }
            } catch {
                print("Error loading image: \(error)")
                await MainActor.run {
                    self.isImageLoading = false
                }
            }
        }
    }
}

// Preview provider
struct ChatBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChatBubbleView(message: ChatMessage(
                id: UUID(),
                fleet_manager_id: UUID(),
                recipient_id: UUID(),
                recipient_type: "driver",
                message_text: "Hello, this is a test message that's quite long to see how it wraps",
                status: .delivered,
                created_at: Date(),
                updated_at: Date(),
                is_deleted: false,
                attachment_url: nil,
                attachment_type: nil,
                isFromCurrentUser: true
            ))
            
            ChatBubbleView(message: ChatMessage(
                id: UUID(),
                fleet_manager_id: UUID(),
                recipient_id: UUID(),
                recipient_type: "driver",
                message_text: "This is a response",
                status: .read,
                created_at: Date(),
                updated_at: Date(),
                is_deleted: false,
                attachment_url: nil,
                attachment_type: nil,
                isFromCurrentUser: false
            ))
        }
        .padding()
    }
} 
