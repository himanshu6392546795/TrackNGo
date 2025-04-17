import SwiftUI

struct ContactPerson: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let email: String
    let phone: String
}

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    var type: MessageType = .text
}

enum MessageType {
    case text
    case action(actions: [QuickAction])
}

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
}

struct ChatBotView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var messages: [Message] = []
    @State private var newMessage = ""
    @State private var isTyping = false
    @State private var selectedContact: ContactRole = .fleetManager
    @State private var showingContactDetails = false
    
    enum ContactRole: String, CaseIterable {
        case fleetManager = "Fleet Manager"
        case maintenance = "Maintenance"
    }
    
    // Sample contact data
    let fleetManagerContact = ContactPerson(
        name: "Sarah Johnson",
        role: "Fleet Manager",
        email: "sarah.j@fleetmanagement.com",
        phone: "+1 234 567 8901"
    )
    
    let maintenanceContact = ContactPerson(
        name: "Mike Wilson",
        role: "Maintenance",
        email: "mike.w@fleetmanagement.com",
        phone: "+1 234 567 8902"
    )
    
    var currentContact: ContactPerson {
        selectedContact == .fleetManager ? fleetManagerContact : maintenanceContact
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if showingContactDetails {
                    // Contact Details View
                    contactDetailsView
                } else {
                    // Contact Selection View
                    contactSelectionView
                }
            }
            .navigationTitle("Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var contactSelectionView: some View {
        VStack(spacing: 20) {
            Text("SELECT CONTACT")
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
            
            HStack(spacing: 20) {
                contactButton(role: .fleetManager)
                contactButton(role: .maintenance)
            }
            .padding(.horizontal)
            
            Text("CONTACT DETAILS")
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
            
            VStack(alignment: .center, spacing: 12) {
                Text(currentContact.name)
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text(currentContact.email)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(currentContact.phone)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(currentContact.role)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            
            Spacer()
            
            Text("MESSAGE")
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            TextEditor(text: $newMessage)
                .frame(height: 150)
                .cornerRadius(8)
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
            
            Button("Send Message") {
                showingContactDetails = true
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    private func contactButton(role: ContactRole) -> some View {
        Button {
            selectedContact = role
        } label: {
            Text(role.rawValue)
                .font(.headline)
                .foregroundColor(selectedContact == role ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedContact == role ? Color.blue : Color(.systemGray5))
                .cornerRadius(8)
        }
    }
    
    private var contactDetailsView: some View {
        VStack {
            // Contact Info Header
            HStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentContact.name)
                        .font(.headline)
                    Text(currentContact.role)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button("Back") {
                    showingContactDetails = false
                }
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            
            // Chat Messages
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageView(message: message) { action in
                            handleQuickAction(action)
                        }
                    }
                    
                    if messages.isEmpty {
                        Text("Your conversation will appear here")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.top, 40)
                    }
                }
                .padding()
            }
            
            // Message Input
            HStack(spacing: 12) {
                TextField("Type your message...", text: $newMessage)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(newMessage.isEmpty ? Color.gray : Color.blue)
                        .clipShape(Circle())
                }
                .disabled(newMessage.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    private func sendMessage() {
        guard !newMessage.isEmpty else { return }
        
        let userMessage = Message(content: newMessage, isUser: true, timestamp: Date())
        messages.append(userMessage)
        
        // Auto-reply for demo purposes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let responseText = "I've received your message and will respond shortly. If this is urgent, please call me directly at \(currentContact.phone)."
            let response = Message(content: responseText, isUser: false, timestamp: Date())
            messages.append(response)
        }
        
        newMessage = ""
    }
    
    private func handleQuickAction(_ action: QuickAction) {
        let message = Message(content: action.title, isUser: true, timestamp: Date())
        messages.append(message)
    }
}

struct MessageView: View {
    let message: Message
    let onActionSelected: (QuickAction) -> Void
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            // Message bubble
            HStack {
                if message.isUser { Spacer() }
                
                VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                    Text(message.content)
                        .padding(12)
                        .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(message.isUser ? .white : .primary)
                        .cornerRadius(20)
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                if !message.isUser { Spacer() }
            }
            
            // Quick actions if available
            if case .action(let actions) = message.type {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(actions) { action in
                            Button(action: { onActionSelected(action) }) {
                                HStack {
                                    Image(systemName: action.icon)
                                    Text(action.title)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(action.color.opacity(0.1))
                                .foregroundColor(action.color)
                                .cornerRadius(16)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ChatBotView_Previews: PreviewProvider {
    static var previews: some View {
        ChatBotView()
    }
} 