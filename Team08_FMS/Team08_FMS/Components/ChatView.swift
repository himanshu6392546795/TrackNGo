import SwiftUI

enum RecipientType: String {
    case maintenance = "maintenance"
    case driver = "driver"
    
    var displayName: String {
        switch self {
        case .maintenance:
            return "Maintenance"
        case .driver:
            return "Driver"
        }
    }
}

struct ChatView: View {
    let recipientType: RecipientType
    let recipientId: UUID
    let recipientName: String
    let contextData: [String: String]?
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText = ""
    @State private var isShowingEmergencySheet = false
    @FocusState private var isFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    @StateObject private var tripController = TripDataController.shared
    @State private var isShowingImagePicker = false
    @State private var selectedImage: UIImage?
    
    init(recipientType: RecipientType, recipientId: UUID, recipientName: String, contextData: [String: String]? = nil) {
        self.recipientType = recipientType
        self.recipientId = recipientId
        self.recipientName = recipientName
        self.contextData = contextData
        self._viewModel = StateObject(wrappedValue: ChatViewModel(recipientId: recipientId, recipientType: recipientType))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            chatHeader
            
            // Context info if available
            if let contextData = contextData {
                contextInfoView(data: contextData)
            }
            
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await viewModel.loadMessages()
                }
                .overlay {
                    if viewModel.messages.isEmpty && viewModel.isLoading {
                        ProgressView("Loading messages...")
                            .scaleEffect(1.0)
                    }
                }
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: viewModel.messages) { _, _ in
                    scrollToBottom()
                }
            }
            
            // Message input with trip details button for drivers
            messageInputView
        }
        .sheet(isPresented: $isShowingEmergencySheet) {
            EmergencyAssistanceView()
        }
    }
    
    private func contextInfoView(data: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch recipientType {
            case .maintenance:
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Service Request")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(data["vehicleName"] ?? "")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Text(data["status"] ?? "")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                Text(data["serviceType"] ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            case .driver:
                if data["tripId"] != nil {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active Trip")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(data["destination"] ?? "")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        Text(data["status"] ?? "")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    private var chatHeader: some View {
        HStack {
            // Back button
            Button(action: {
                // Handle back action
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)
            
            // Recipient info
            VStack(alignment: .leading, spacing: 2) {
                Text(recipientName)
                    .font(.headline)
                Text(recipientType.displayName)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Emergency button - only show for drivers
            if recipientType == .driver {
                Button(action: {
                    isShowingEmergencySheet = true
                }) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundColor(ChatThemeColors.emergency)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
    }
    
    private var messageInputView: some View {
        VStack(spacing: 8) {
            // Trip details button (only for drivers)
            if recipientType == .driver,
               tripController.currentTrip != nil {
                Button(action: sendTripDetails) {
                    HStack {
                        Image(systemName: "car.fill")
                        Text("Send Trip Details")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ChatThemeColors.primary)
                    .cornerRadius(20)
                }
                .padding(.horizontal)
            }
            
            HStack(spacing: 12) {
                // Photo picker button
                Button(action: {
                    isShowingImagePicker = true
                }) {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(ChatThemeColors.primary)
                }
                .sheet(isPresented: $isShowingImagePicker) {
                    ImagePicker(image: $selectedImage, isShown: $isShowingImagePicker) { image in
                        if let image = image {
                            Task {
                                await viewModel.sendImage(image)
                                scrollToBottom()
                            }
                        }
                    }
                }
                
                // Message text field
                TextField("Type a message...", text: $messageText)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .focused($isFocused)
                
                // Send button
                Button(action: {
                    sendMessage()
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(messageText.isEmpty ? Color.gray : ChatThemeColors.primary)
                        )
                }
                .disabled(messageText.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: -2)
    }
    
    private func scrollToBottom() {
        withAnimation(.easeOut(duration: 0.3)) {
            if let lastMessage = viewModel.messages.last {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        viewModel.sendMessage(messageText)
        messageText = ""
        scrollToBottom()
    }
    
    private func sendTripDetails() {
        guard let trip = tripController.currentTrip else { return }
        
        let tripDetails = """
        🚗 Trip Details:
        Vehicle: \(trip.vehicleDetails.make) \(trip.vehicleDetails.model)
        License Plate: \(trip.vehicleDetails.licensePlate)
        
        📍 From: \(trip.startingPoint)
        🎯 To: \(trip.destination)
        
        📅 Scheduled: \(formatDate(trip.startTime ?? Date()))
        🚚 Status: \(trip.status.rawValue)
        📏 Distance: \(trip.distance)
        
        🔍 Additional Info:
        \(trip.notes ?? "No additional notes")
        """
        
        viewModel.sendMessage(tripDetails)
        scrollToBottom()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Add ImagePicker struct
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isShown: Bool
    var onImagePicked: (UIImage?) -> Void
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
                parent.onImagePicked(uiImage)
            }
            parent.isShown = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isShown = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {
    }
}

// Preview provider
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView(
            recipientType: .driver,
            recipientId: UUID(),
            recipientName: "John Smith",
            contextData: ["tripId": UUID().uuidString, "destination": "New York", "status": "In Progress"]
        )
    }
} 
