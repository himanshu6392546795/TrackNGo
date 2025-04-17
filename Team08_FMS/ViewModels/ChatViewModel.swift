private func createStorageBucketIfNeeded() async throws {
        do {
            print("Checking if bucket exists: \(storageBucket)")
            do {
                // Try to get bucket info first
                _ = try await storageClient.getBucket(storageBucket)
                print("Bucket already exists: \(storageBucket)")
            } catch {
                print("Bucket does not exist, creating: \(storageBucket)")
                // First create the bucket in the storage.buckets table
                try await supabaseDataController.supabase.database
                    .from("storage.buckets")
                    .insert([
                        "id": storageBucket,
                        "name": storageBucket,
                        "public": true,
                        "file_size_limit": 10485760,
                        "allowed_mime_types": ["image/jpeg", "image/png"]
                    ])
                    .execute()
                
                // Then create the bucket in storage
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
            print("Error managing storage bucket: \(error.localizedDescription)")
            // Don't throw the error, just log it - the bucket might already exist in the database
            print("Attempting to proceed with upload anyway...")
        }
    }

func sendImage(_ image: UIImage) async {
        do {
            // First ensure the bucket exists
            try await createStorageBucketIfNeeded()
            
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
            
            guard let currentUserId = await supabaseDataController.getUserID() else {
                print("No user ID found")
                return
            }
            
            let fileName = "chat/\(UUID().uuidString).jpg"
            print("Attempting to upload file: \(fileName) to bucket: \(storageBucket)")
            
            // First create the object entry in storage.objects
            try await supabaseDataController.supabase.database
                .from("storage.objects")
                .insert([
                    "bucket_id": storageBucket,
                    "name": fileName,
                    "owner": currentUserId.uuidString,
                    "size": finalImageData.count,
                    "mime_type": "image/jpeg",
                    "metadata": [
                        "lastModified": Date().timeIntervalSince1970,
                        "size": finalImageData.count,
                        "type": "image/jpeg"
                    ]
                ])
                .execute()
            
            // Then upload the actual file
            try await storageClient
                .from(storageBucket)
                .upload(
                    path: fileName,
                    file: finalImageData,
                    options: FileOptions(
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )
            
            print("Successfully uploaded image, getting public URL...")
            
            // Get the public URL
            let publicURL = try await storageClient
                .from(storageBucket)
                .createSignedURL(
                    path: fileName,
                    expiresIn: 365 * 24 * 60 * 60 // 1 year in seconds
                )
            
            print("Got public URL: \(publicURL.absoluteString)")
            
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
            
            let response = try await supabaseDataController.supabase.database
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