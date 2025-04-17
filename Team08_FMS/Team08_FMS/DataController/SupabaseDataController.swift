import Foundation
import Supabase
import Combine
import SwiftSMTP

struct GeofenceEvents: Codable, Identifiable {
    
    let id: UUID
    
    // The ID for the trip
    let tripId: UUID
    
    // The event message
    let message: String
    
    // When the event was created or triggered
    let timestamp: Date = Date()
    
    // Whether the event has been read
    var isRead: Bool = false
    
    // Map the Swift property names to your database column names
    enum CodingKeys: String, CodingKey {
        case id
        case tripId
        case message
        case timestamp
        case isRead
    }
}

class SupabaseDataController: ObservableObject {
    static let shared = SupabaseDataController()
    
    @Published var userRole: String?
    @Published var isAuthenticated: Bool = false
    @Published var authError: String?
    @Published var userID: UUID?
    @Published var otpVerified: Bool = false
    
    @Published var is2faEnabled: Bool = true
    
    @Published var roleMatched: Bool = false
    @Published var isGenPass: Bool = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var session: Session?
    @Published var geofenceEvents: [GeofenceEvents] = []
    
     let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://tkfrvzxwjlimhhvdwwqi.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRrZnJ2enh3amxpbWhodmR3d3FpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIyMTA5MjUsImV4cCI6MjA1Nzc4NjkyNX0.7vNQWGbjOYFeynNt8N8V-DzoJbS3qq28o3LAa1XvLnw"
    )
    
    private init() {
//        Task {
//            await checkSession()
//        }
    }
    
    func sendEmail(toName: String, toEmail: String, subject: String, text: String) {
        let smtp = SMTP(
            hostname: "smtp.gmail.com",     // SMTP server address
            email: "c0sm042532@gmail.com",        // username to login
            password: "xjsk jrno odyh exoe",
            port: 587
        )
        let fromUser = Mail.User(name: "Team08 FMS", email: "c0sm042532@gmail.com")
        let toUser = Mail.User(name: toName, email: toEmail)
        let mail = Mail(from: fromUser, to: [toUser], subject: subject, text: text)
        smtp.send(mail) { (error) in
            if let error = error {
                print(error)
            }
        }
    }
    
    func setUserSession() async {
        do {
            guard let session = session else {
                print("Cannot set session")
                return
            }
            let accessToken = session.accessToken
            let refreshToken = session.refreshToken
            try await supabase.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
            print(session)
        } catch {
            print("Cannot set session")
        }
    }
    
    func setSessionManually(userSession: Session) async {
        do {
            let accessToken = userSession.accessToken
            let refreshToken = userSession.refreshToken
            
            // Save tokens
            UserDefaults.standard.set(accessToken, forKey: "accessToken")
            UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
            UserDefaults.standard.synchronize()  // Ensure they are saved

            // Verify the values were saved
            print("Saved accessToken: \(UserDefaults.standard.string(forKey: "accessToken") ?? "nil")")
            print("Saved refreshToken: \(UserDefaults.standard.string(forKey: "refreshToken") ?? "nil")")

            try await supabase.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
            print("Session set manually: \(userSession)")
        } catch {
            print("Cannot set session: \(error)")
        }
    }
    
    func saveUserDefaults() {
        guard let session = session else {
            print("cannot store user defaults")
            return
        }
        let accessToken = session.accessToken
        let refreshToken = session.refreshToken
        // Save tokens
        UserDefaults.standard.set(accessToken, forKey: "accessToken")
        UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
        UserDefaults.standard.synchronize()  // Ensure they are saved

        // Verify the values were saved
        print("Saved accessToken: \(UserDefaults.standard.string(forKey: "accessToken") ?? "nil")")
        print("Saved refreshToken: \(UserDefaults.standard.string(forKey: "refreshToken") ?? "nil")")
    }
    
    func autoLogin() async {
        guard let accessToken = UserDefaults.standard.string(forKey: "accessToken"),
              let refreshToken = UserDefaults.standard.string(forKey: "refreshToken") else {
            print("No saved session found in UserDefaults")
            return
        }

        print("Retrieved accessToken: \(accessToken)")
        print("Retrieved refreshToken: \(refreshToken)")

        do {
            try await supabase.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)

            // Ensure session is valid
            await MainActor.run {
                session = supabase.auth.currentSession
                userID = session?.user.id
            }
            // Fetch user role using the retrieved user ID
            await fetchUserRole(userID: session!.user.id)
            await MainActor.run {
                self.isAuthenticated = true
                userID = supabase.auth.currentUser?.id
            }
            print("Auto-login successful")
        } catch {
            print("Auto-login failed: \(error)")
        }
    }

    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            
            await MainActor.run {
                self.isAuthenticated = true
                self.userID = session.user.id
            }
            
            // Fetch additional user-related data
            await fetchUserRole(userID: session.user.id)
            await CheckGenPass(userID: session.user.id)
            
        } catch {
            // If an error occurs, reset the session-related properties
            print("Error checking session: \(error.localizedDescription)")
            await MainActor.run {
                self.isAuthenticated = false
                self.userRole = nil
                self.userID = nil
                self.isGenPass = false
                self.otpVerified = false
            }
        }
    }
    
    // MARK: - Authentication
    func signUp(name: String, email: String, phoneNo: Int, role: String) async -> UUID? {
        struct UserRole: Codable {
            let user_id: UUID
            let role_id: Int
        }
        
        struct GenPass: Codable {
            let user_id: UUID
        }
        
        let roleMapping: [String: Int] = [
            "fleet_manager": 1,
            "driver": 2,
            "maintenance_personnel": 3
        ]
        
        guard let roleID = roleMapping[role] else {
            print("Invalid role: \(role)")
            return nil
        }
        
        do {
            await MainActor.run {
                session = supabase.auth.currentSession
            }
            let password = AppDataController.shared.randomPasswordGenerator(length: 6)
            print(password)
            let signUpResponse = try await supabase.auth.signUp(email: email, password: password)
            
//            let userID = signUpResponse.user.id
            
            let userRole = UserRole(user_id: signUpResponse.user.id, role_id: roleID)
            try await supabase
                .from("user_roles")
                .insert(userRole)
                .execute()
            
            let genPass = GenPass(user_id: signUpResponse.user.id)
            try await supabase
                .from("gen_pass")
                .insert(genPass)
                .execute()
            
            let inviteEmail = """
            Dear \(name),

            Welcome to Fleet Management System! We're excited to have you on board.

            Your login credentials as a \(role) are as follows:

            - Email: \(email)
            - Password: \(password)

            Please log into the app and update your password for security.
            """
            
            sendEmail(toName: name, toEmail: email, subject: "Welcome to Fleet Management System", text: inviteEmail)
            
            print("User signed up successfully with role: \(role)")
            
            return signUpResponse.user.id
        } catch {
            print("Error during sign-up: \(error.localizedDescription)")
            return nil
        }
    }

    func signInWithPassword(email: String, password: String, roleName: String, completion: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                let session = try await supabase.auth.signIn(email: email, password: password)
                await fetchUserRole(userID: session.user.id)
                var role = ""
                
                if roleName == "Fleet Manager" {
                    role = "fleet_manager"
                } else if roleName == "Driver" {
                    role = "driver"
                } else if roleName == "Maintenance Personnel" {
                    role = "maintenance_personnel"
                } else {
                    await MainActor.run {
                        alertMessage = "No account found for \(email) as a \(roleName). Please check your credentials or select the correct role."
                    }
                    signOut()
                    return
                }
                
                if role == userRole {
                    await MainActor.run {
                        userID = session.user.id
                        self.roleMatched = true
                        self.session = session
                    }
                    await CheckGenPass(userID: userID!)
                    if isGenPass {
                        await MainActor.run {
                            self.isAuthenticated = true
                        }
                    }
                    await MainActor.run {
                        self.authError = nil
                    }
                } else {
                    await MainActor.run {
                        alertMessage = "No account found for \(email) as a \(roleName). Please check your credentials or select the correct role."
                        showAlert = true
                    }
                    signOut()
                }
                if !is2faEnabled || isAuthenticated {
                    await MainActor.run {
                        isAuthenticated = true
                    }
                    saveUserDefaults()
                }
                completion(true, nil)
            } catch {
                completion(false, error.localizedDescription)
                await MainActor.run {
                    authError = "Login failed: \(error.localizedDescription)"
                    alertMessage = authError!
                    showAlert = true
                    isAuthenticated = false
                }
                print("Login error: \(error.localizedDescription)")
            }
        }
    }
    
    func verifyCurrentPassword(email: String, currentPassword: String, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                let _ = try await supabase.auth.signIn(email: email, password: currentPassword)
                completion(true) // Password is correct
            } catch {
                print("Incorrect password: \(error.localizedDescription)")
                completion(false) // Password is incorrect
            }
        }
    }
    
    // Function to send an OTP for a forgot-password scenario.
    func sendOTPForForgotPassword(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                // Attempt to send an OTP via email. Note: 'shouldCreateUser' is false because this is for password recovery.
                _ = try await supabase.auth.signInWithOTP(email: email, shouldCreateUser: false)
                completion(.success(()))
            } catch {
                print("Error sending OTP: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // Function to verify the OTP entered by the user during password recovery.
    func verifyOTPForForgotPassword(email: String, otp: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                // Verify the OTP code. Adjust the 'type' parameter if your backend expects a different OTP type.
                _ = try await supabase.auth.verifyOTP(email: email, token: otp, type: .magiclink)
                completion(.success(()))
            } catch {
                print("OTP verification failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func sendOTP(email: String, completion: @escaping (Bool, String?) -> Void) {
        Task {
            if !isGenPass {
                do {
                    try await supabase.auth.signInWithOTP(email: email, shouldCreateUser: false)
                    completion(true, nil)
                } catch {
                    signOut()
                    completion(false, error.localizedDescription)
                }
            }
            else {
                await MainActor.run {
                    self.isAuthenticated = true
                }
            }
        }
    }
    
    func verifyOTP(email: String, token: String, completion: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                try await supabase.auth.verifyOTP(email: email, token: token, type: .magiclink)
                await MainActor.run {
                    self.isAuthenticated = true
                    self.otpVerified = true
                }
                saveUserDefaults()
                completion(true, nil)
            } catch {
                completion(false, error.localizedDescription)
                await MainActor.run {
                    authError = "Login failed: \(error.localizedDescription)"
                    alertMessage = authError!
                    showAlert = true
                }
            }
        }
    }
    
    func signOut() {
        Task {
            do {
                try await supabase.auth.signOut()
                
                UserDefaults.standard.removeObject(forKey: "accessToken")
                UserDefaults.standard.removeObject(forKey: "refreshToken")
                UserDefaults.standard.synchronize() // Ensure changes are saved
                
                await MainActor.run {
                    self.userRole = nil
                    self.isAuthenticated = false
                    self.userID = nil
                    self.isGenPass = false
                    self.otpVerified = false
                    self.roleMatched = false
                    self.session = nil
                }
            } catch {
            }
        }
    }
    
    func CheckGenPass(userID: UUID) async {
        struct GenPassRow: Codable {
            let is_gen: Bool
        }

        do {
            let response = try await supabase
                .from("gen_pass")
                .select("is_gen")
                .eq("user_id", value: userID)
                .execute()
            
            // Ensure response.data is not nil
            let responseData = response.data
            // Debugging: Print raw JSON response
            if let jsonString = String(data: responseData, encoding: .utf8) {
                print("Raw JSON: \(jsonString)")
            }

            // Decode JSON
            let decodedRows = try JSONDecoder().decode([GenPassRow].self, from: responseData)

            // Extract first row
            if let firstRow = decodedRows.first {
                await MainActor.run {
                    self.isGenPass = firstRow.is_gen
                }
            } else {
                print("No matching row found for userID: \(userID)")
            }
        } catch {
            print("Error checking generated password : \(error.localizedDescription)")
        }
    }
    
    func updatePassword(newPassword: String) async -> Bool {
        do {
            try await supabase.auth.update(user: UserAttributes(password: newPassword))
            try await supabase
                .from("gen_pass")
                .update(["is_gen": false])
                .eq("user_id", value: supabase.auth.user().id)
                .execute()
            await MainActor.run {
                self.isGenPass = false  // This will trigger the UI update
            }
            return true  // Successfully updated
        } catch {
            print("Error updating password: \(error.localizedDescription)")
            return false
        }
    }
    
    func resetPassword(newPassword: String) async -> Bool {
        do {
            try await supabase.auth.update(user: UserAttributes(password: newPassword))
            return true
        } catch {
            print("Error updating password: \(error.localizedDescription)")
            return false
        }
    }
    
    func getUserID() async -> UUID? {
        guard let userID = supabase.auth.currentUser?.id else { return nil }
        return userID
    }
    
    func subscribeToGeofenceEvents() {
        Task {
            let myChannel = supabase.channel("db-changes")
            let changes = myChannel.postgresChange(AnyAction.self, schema: "public", table: "geofence_events")
            await myChannel.subscribe()
            for await change in changes {
              switch change {
              case .insert(let action):
                  print(action)
                  await fetchGeofenceEvents()
              case .update(let action):
                  print(action)
                  await fetchGeofenceEvents()
              case .delete(let action):
                  print(action)
                  await fetchGeofenceEvents()
              }
            }
        }
    }
    
    func fetchGeofenceEvents() async {
        do {
            // Select all columns; you can also specify columns explicitly
            let response = try await supabase
                .from("geofence_events")
                .select("*")
                // Optionally, order by timestamp descending
                .order("timestamp", ascending: false)
                .execute()
            
            // Decode the returned data into an array of GeofenceEvents
            let events = try JSONDecoder().decode([GeofenceEvents].self, from: response.data)
            
            // Update your local array
            await MainActor.run {
                self.geofenceEvents = events
            }
            
        } catch {
            print("Error fetching geofence events: \(error.localizedDescription)")
        }
    }
    
    func insertIntoGeofenceEvents(event: GeofenceEvents) {
        Task {
            do {
                let response = try await supabase
                    .from("geofence_events")
                    .insert(event)
                    .execute()
                print(response)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func deleteFromGeofenceEvents(event: GeofenceEvents) {
        Task {
            do {
                let response = supabase
                    .from("geofence_events")
                    .delete()
                    .eq("tripId", value: event.tripId)
                print(response)
            }
        }
    }
    
    // MARK: - Fetch User Role
    private func fetchUserRole(userID: UUID) async {
        do {
            let userRolesResult = try await supabase
                .from("user_roles")
                .select("role_id")
                .eq("user_id", value: userID)
                .eq("isDeleted", value: false)
                .execute()
            
            struct UserRoleID: Codable {
                let role_id: Int
            }
            
            let userRoles = try JSONDecoder().decode([UserRoleID].self, from: userRolesResult.data)
            guard let roleID = userRoles.first?.role_id else { return }
            
            let roleResult = try await supabase
                .from("roles")
                .select("role_name")
                .eq("id", value: roleID)
                .execute()
            
            struct Role: Codable {
                let role_name: String
            }
            
            let roles = try JSONDecoder().decode([Role].self, from: roleResult.data)
            guard let roleName = roles.first?.role_name else { return }
            
            await MainActor.run { self.userRole = roleName } // Update safely on main thread
            print(roleName)
            
        } catch {
            print("Error fetching user role: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Manage Crew and Vehicle Record
    func fetchFleetManagerByUserID(userID: UUID) async throws -> FleetManager? {
        do {
            let response = try await supabase
                .from("fleet_manager")
                .select()
                .eq("userID", value: userID)
                .execute()
            
            let data = response.data

            // Print raw JSON response for debugging
            if let rawJSON = String(data: data, encoding: .utf8) {
                print("Raw JSON Response for Fleet Manager: \(rawJSON)")
            }

            // Decode JSON as an array of dictionaries and extract the first record
            guard let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]],
                  !jsonArray.isEmpty else {
                print("No fleet manager found for userID: \(userID)")
                return nil
            }

            // Convert the first record back to Data
            let transformedData = try JSONSerialization.data(withJSONObject: jsonArray[0], options: [])

            // Custom Date Formatter (Supports Fractional Seconds)
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)

            // Decode into FleetManager model
            let fleetManager = try decoder.decode(FleetManager.self, from: transformedData)
            print("Decoded Fleet Manager: \(fleetManager)")
            return fleetManager
        } catch {
            print("Error fetching fleet manager: \(error.localizedDescription)")
            return nil
        }
    }

    func fetchFleetManagers() async throws -> [FleetManager] {
        do {
            let response = try await supabase
                .from("fleet_manager")
                .select()
                .is("deletedAt", value: nil)  // Check for non-deleted records
                .execute()
            
            let data = response.data

            // Decode JSON as an array of dictionaries first
            guard let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
                print("Invalid JSON structure")
                return []
            }

            // Convert transformed array back to Data
            let transformedData = try JSONSerialization.data(withJSONObject: jsonArray, options: [])

            // Custom Date Formatter (Supports Fractional Seconds)
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)

            // Decode into FleetManager model
            let fleetManagers = try decoder.decode([FleetManager].self, from: transformedData)
            print("Decoded Fleet Managers: \(fleetManagers)")
            return fleetManagers
        } catch {
            print("Error fetching fleet managers: \(error)")
            throw error
        }
    }
    
    func fetchDriverByUserID(userID: UUID) async throws -> Driver? {
        do {
            let response = try await supabase
                .from("driver")
                .select()
                .eq("userID", value: userID)
                .execute()
            
            let data = response.data
            
            // Print raw JSON response for debugging
            if let rawJSON = String(data: data, encoding: .utf8) {
                print("Raw JSON Response for Driver: \(rawJSON)")
            }
            
            // Decode JSON as an array of dictionaries and extract the first record
            guard var jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]],
                  !jsonArray.isEmpty else {
                print("No driver found for userID: \(userID)")
                return nil
            }
            
            // Fix date format for driverLicenseExpiry if present
            for i in 0..<jsonArray.count {
                if let expiryDateString = jsonArray[i]["driverLicenseExpiry"] as? String {
                    // Set up a formatter for the input format "yyyy-MM-dd HH:mm:ss"
                    let inputFormatter = DateFormatter()
                    inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    inputFormatter.locale = Locale(identifier: "en_US_POSIX")
                    
                    if let date = inputFormatter.date(from: expiryDateString) {
                        // Configure ISO8601DateFormatter to include fractional seconds
                        let isoFormatter = ISO8601DateFormatter()
                        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        let formattedDate = isoFormatter.string(from: date)
                        
                        // Update the JSON with the properly formatted date string
                        jsonArray[i]["driverLicenseExpiry"] = formattedDate
                    }
                }
            }
            
            // Convert the first record back to Data
            let transformedData = try JSONSerialization.data(withJSONObject: jsonArray[0], options: [])
            
            // Custom Date Formatter (Supports Fractional Seconds)
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            // Decode into Driver model
            let driver = try decoder.decode(Driver.self, from: transformedData)
            print("Decoded Driver: \(driver)")
            return driver
        } catch {
            print("Error fetching driver: \(error.localizedDescription)")
            return nil
        }
    }
    
    func fetchDrivers() async throws -> [Driver] {
        do {
            let response = try await supabase
                .from("driver")
                .select()
                .eq("isDeleted", value: false)
                .execute()
            
            let data = response.data

            // Decode JSON as an array of dictionaries first
            guard var jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
                print("Invalid JSON structure")
                return []
            }

            // Fix date format for driverLicenseExpiry
            for i in 0..<jsonArray.count {
                if let expiryDateString = jsonArray[i]["driverLicenseExpiry"] as? String {
                    // Set up a formatter for the input format "yyyy-MM-dd HH:mm:ss"
                    let inputFormatter = DateFormatter()
                    inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    inputFormatter.locale = Locale(identifier: "en_US_POSIX")
                    
                    if let date = inputFormatter.date(from: expiryDateString) {
                        // Configure ISO8601DateFormatter to include fractional seconds
                        let isoFormatter = ISO8601DateFormatter()
                        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        let formattedDate = isoFormatter.string(from: date)
                        
                        // Update the JSON with the properly formatted date string
                        jsonArray[i]["driverLicenseExpiry"] = formattedDate
                    }
                }
            }

            // Convert transformed array back to Data
            let transformedData = try JSONSerialization.data(withJSONObject: jsonArray, options: [])

            // Custom Date Formatter (Supports Fractional Seconds)
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss" // Allows fractional seconds
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)

            // Decode into Driver model
            let drivers = try decoder.decode([Driver].self, from: transformedData)
//            print("Decoded Drivers: \(drivers)")
            return drivers
        } catch {
            print("Error fetching drivers: \(error)")
            return []
        }
    }

    func fetchMaintenancePersonnelByUserID(userID: UUID) async throws -> MaintenancePersonnel? {
        do {
            let response = try await supabase
                .from("maintenance_personnel")
                .select()
                .eq("userID", value: userID)
                .execute()
            
            let data = response.data
            
            // Print raw JSON response for debugging
            if let rawJSON = String(data: data, encoding: .utf8) {
                print("Raw JSON Response for Maintenance Personnel: \(rawJSON)")
            }
            
            // Custom Date Formatter (Supports Fractional Seconds)
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            // Decode JSON as an array of dictionaries and extract the first record
            guard let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]],
                  !jsonArray.isEmpty else {
                print("No maintenance personnel found for userID: \(userID)")
                return nil
            }
            
            // Convert the first record back to Data
            let transformedData = try JSONSerialization.data(withJSONObject: jsonArray[0], options: [])
            
            // Decode into MaintenancePersonnel model
            let personnel = try decoder.decode(MaintenancePersonnel.self, from: transformedData)
            print("Decoded Maintenance Personnel: \(personnel)")
            return personnel
        } catch {
            print("Error fetching maintenance personnel: \(error.localizedDescription)")
            return nil
        }
    }
    
    func fetchMaintenancePersonnel() async throws -> [MaintenancePersonnel] {
        do {
            let response = try await supabase
                .from("maintenance_personnel")
                .select()
                .eq("isDeleted", value: false)
                .execute()
            
            let data = response.data

            // Custom Date Formatter
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss" // Fractional seconds support
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)

            // Decode data
            let personnels = try decoder.decode([MaintenancePersonnel].self, from: data)
            return personnels
        } catch {
            print("Error fetching maintenance personnel: \(error)")
            return []
        }
    }

    func insertDriver(driver: Driver, password: String) async throws {
        do {
            // Set up a custom JSONEncoder with ISO8601 format including milliseconds.
            let encoder = JSONEncoder()
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            
            // Encode the driver to JSON for debugging/logging.
            let driverJSONData = try encoder.encode(driver)
            if let driverJSONString = String(data: driverJSONData, encoding: .utf8) {
                print("Driver JSON to insert: \(driverJSONString)")
            }
            
            // Insert the driver into the "driver" table.
            let response = try await supabase
                .from("driver")
                .insert(driver)
                .execute()
            
            // Print raw JSON response for debugging.
            if let rawJSON = String(data: response.data, encoding: .utf8) {
                print("Raw JSON Insert Response for Driver: \(rawJSON)")
            }
            
            print("Insert response: \(response)")
            
        } catch {
            print("Error inserting driver: \(error.localizedDescription)")
            throw error
        }
    }
    
    func insertMaintenancePersonnel(personnel: MaintenancePersonnel, password: String) async throws {
        do {
            // Set up a custom JSONEncoder with ISO8601 format including milliseconds.
            let encoder = JSONEncoder()
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            
            // Encode the personnel to JSON for debugging/logging.
            let personnelJSONData = try encoder.encode(personnel)
            if let personnelJSONString = String(data: personnelJSONData, encoding: .utf8) {
                print("Maintenance Personnel JSON to insert: \(personnelJSONString)")
            }
            
            // Insert the personnel record into the "maintenance_personnel" table.
            let response = try await supabase
                .from("maintenance_personnel")
                .insert(personnel)
                .execute()
            
            // Print raw JSON response for debugging.
            if let rawJSON = String(data: response.data, encoding: .utf8) {
                print("Raw JSON Insert Response for Maintenance Personnel: \(rawJSON)")
            }
            
            print("Insert response: \(response)")
            
        } catch {
            print("Error inserting maintenance personnel: \(error.localizedDescription)")
            throw error
        }
    }
    
    func fetchVehicles() async throws -> [Vehicle] {
        do {
            // Specify only the fields we need for the list view
            // This significantly reduces the data transfer size
            let response = try await supabase
                .from("vehicles")
                .select()
                .notEquals("status", value: "Decommissioned")
                .execute()
            
            let data = response.data
            
            // Configure date formatter for decoding
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            // Configure decoder with date formatter
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            // Decode data directly - just like maintenance personnel
            let vehicles = try decoder.decode([Vehicle].self, from: data)
            
            return vehicles
        } catch {
            print("Error fetching vehicles: \(error)")
            return []
        }
    }

    func updateDriverStatus(newStatus: Status, userID: UUID?, id: UUID?) async {
        // Use [String: String] since newStatus.rawValue is a String.
        let payload: [String: String] = ["status": newStatus.rawValue]
        
        do {
            if let userID {
                let response = try await supabase
                    .from("driver")
                    .update(payload)
                    .eq("userID", value: userID)
                    .execute()
                let data = response.data
                let jsonString = String(data: data, encoding: .utf8)
                print("Update response data: \(jsonString ?? "")")
            } else if id != nil {
                let response = try await supabase
                    .from("driver")
                    .update(payload)
                    .eq("id", value: id)
                    .execute()
                let data = response.data
                let jsonString = String(data: data, encoding: .utf8)
                print("Update response data: \(jsonString ?? "")")
            }
        } catch {
            print("Exception updating driver status: \(error.localizedDescription)")
        }
    }
    
    func updateMaintenancePersonnelStatus(newStatus: Status, userID: UUID?, id: UUID?) async {
        // Use [String: String] since newStatus.rawValue is a String.
        print(newStatus)
        let payload: [String: String] = ["status": newStatus.rawValue]
        
        do {
            if let userID {
                let response = try await supabase
                    .from("maintenance_personnel")
                    .update(payload)
                    .eq("userID", value: userID)
                    .execute()
                
                let data = response.data
                let jsonString = String(data: data, encoding: .utf8)
                print("Update response data: \(jsonString ?? "")")
            }
            else if id != nil {
                let response = try await supabase
                    .from("maintenance_personnel")
                    .update(payload)
                    .eq("id", value: id)
                    .execute()
                
                let data = response.data
                let jsonString = String(data: data, encoding: .utf8)
                print("Update response data: \(jsonString ?? "")")
            }
        } catch {
            print("Exception updating maintenance personnel status: \(error.localizedDescription)")
        }
    }
    
    func softDeleteDriver(for userID: UUID) async {
        do {
            let response = try await supabase
            .from("driver")
            .update(["isDeleted": true])
            .eq("id", value: userID)
            .execute()
            
            let response2 = try await supabase
                .from("user_roles")
                .update(["isDeleted": true])
                .eq("user_id", value: userID)
                .execute()
        
            let data = response.data
            let data2 = response2.data
            let jsonString = String(data: data, encoding: .utf8)
            let jsonString2 = String(data: data2, encoding: .utf8)
            print("Update response data: \(jsonString ?? "")\n\(jsonString2 ?? "")")
        } catch {
            print("Exception deleting driver details: \(error.localizedDescription)")
        }
    }
    
    func softDeleteMaintenancePersonnel(for userID: UUID) async {
        do {
            let response = try await supabase
                .from("maintenance_personnel")
                .update(["isDeleted": true])
                .eq("id", value: userID)
                .execute()
            
            let response2 = try await supabase
                .from("user_roles")
                .update(["isDeleted": true])
                .eq("user_id", value: userID)
                .execute()
            
            let data = response.data
            let data2 = response2.data
            let jsonString = String(data: data, encoding: .utf8)
            let jsonString2 = String(data: data2, encoding: .utf8)
            print("Update response data: \(jsonString ?? "")\n\(jsonString2 ?? "")")
        } catch {
            print("Exception deleting maintenance personnel details: \(error.localizedDescription)")
        }
    }
    
    func updateDriver(driver: Driver) async {
        do {
            let encoder = JSONEncoder()
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            
            // Encode the personnel to JSON for debugging/logging.
            let personnelJSONData = try encoder.encode(driver)
            if let personnelJSONString = String(data: personnelJSONData, encoding: .utf8) {
                print("Driver JSON to insert: \(personnelJSONString)")
            }
            
        let response = try await supabase
            .from("driver")
            .update(driver)
            .eq("id", value: driver.id)
            .execute()
        
        let data = response.data
        let jsonString = String(data: data, encoding: .utf8)
        print("Update response data: \(jsonString ?? "")")
        } catch {
            print("Exception updating driver details: \(error.localizedDescription)")
        }
    }
    
    func updateMaintenancePersonnel(personnel: MaintenancePersonnel) async {
        do {
            
            let encoder = JSONEncoder()
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            encoder.dateEncodingStrategy = .formatted(dateFormatter)
            
            // Encode the personnel to JSON for debugging/logging.
            let personnelJSONData = try encoder.encode(personnel)
            if let personnelJSONString = String(data: personnelJSONData, encoding: .utf8) {
                print("Maintenance Personnel JSON to insert: \(personnelJSONString)")
            }
            let response = try await supabase
                .from("maintenance_personnel")
                .update(personnel)
                .eq("id", value: personnel.id)
                .execute()
            
            let data = response.data
            let jsonString = String(data: data, encoding: .utf8)
            print("Update response data: \(jsonString ?? "")")
        } catch {
            print("Exception updating maintenance personnel details: \(error.localizedDescription)")
        }
    }
    
    func insertVehicle(vehicle: Vehicle) async throws {
        // 1. Create a date formatter for encoding date fields as "yyyy-MM-dd"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        // 2. Convert your `Vehicle`'s dates to strings
        let pollutionExpiryString = dateFormatter.string(from: vehicle.pollutionExpiry)
        let insuranceExpiryString = dateFormatter.string(from: vehicle.insuranceExpiry)

        // 3. Convert document `Data` fields to Base64 strings (if they exist)
//        let pollutionCertBase64 = vehicle.documents?.pollutionCertificate?.base64EncodedString()
//        let rcBase64 = vehicle.documents?.rc?.base64EncodedString()
//        let insuranceBase64 = vehicle.documents?.insurance?.base64EncodedString()

        // 5. Create an instance of the payload
        let payload = VehiclePayload(
            id: vehicle.id,
            name: vehicle.name,
            year: vehicle.year,
            make: vehicle.make,
            model: vehicle.model,
            vin: vehicle.vin,
            license_plate: vehicle.licensePlate,
            vehicle_type: vehicle.vehicleType,
            color: vehicle.color,
            body_type: vehicle.bodyType,
            body_subtype: vehicle.bodySubtype,
            msrp: vehicle.msrp,
            pollution_expiry: pollutionExpiryString,
            insurance_expiry: insuranceExpiryString,
            status: vehicle.status,
            driver_id: vehicle.driverId,
            lastMaintenanceDistance: vehicle.lastMaintenanceDistance,
            totalDistance: vehicle.totalDistance
//            pollution_certificate: pollutionCertBase64,
//            rc: rcBase64,
//            insurance: insuranceBase64
        )

        do {
            // 6. Insert the payload into Supabase
            let response = try await supabase
                .from("vehicles")
                .insert([payload])
                .execute()
            
            print("Insert success: \(response)")
        } catch {
            print("Error inserting vehicle: \(error.localizedDescription)")
        }
    }

    func updateVehicle(vehicle: Vehicle) async throws {
        // 1. Create a date formatter for encoding date fields as "yyyy-MM-dd"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        // 2. Convert your `Vehicle`'s dates to strings
        let pollutionExpiryString = dateFormatter.string(from: vehicle.pollutionExpiry)
        let insuranceExpiryString = dateFormatter.string(from: vehicle.insuranceExpiry)

        // 3. Convert document `Data` fields to Base64 strings (if they exist)
//        let pollutionCertBase64 = vehicle.documents?.pollutionCertificate?.base64EncodedString()
//        let rcBase64 = vehicle.documents?.rc?.base64EncodedString()
//        let insuranceBase64 = vehicle.documents?.insurance?.base64EncodedString()

        // 5. Create an instance of the update payload with current vehicle details.
        let payload = VehiclePayload(
            id: vehicle.id,
            name: vehicle.name,
            year: vehicle.year,
            make: vehicle.make,
            model: vehicle.model,
            vin: vehicle.vin,
            license_plate: vehicle.licensePlate,
            vehicle_type: vehicle.vehicleType,
            color: vehicle.color,
            body_type: vehicle.bodyType,
            body_subtype: vehicle.bodySubtype,
            msrp: vehicle.msrp,
            pollution_expiry: pollutionExpiryString,
            insurance_expiry: insuranceExpiryString,
            status: vehicle.status,
            driver_id: vehicle.driverId,
            lastMaintenanceDistance: vehicle.lastMaintenanceDistance,
            totalDistance: vehicle.totalDistance
        )

        do {
            // 6. Update the payload in Supabase by filtering with the vehicle's `id`
            let response = try await supabase
                .from("vehicles")
                .update(payload)
                .eq("id", value: vehicle.id)
                .execute()
            
            print("Update success: \(response)")
            print("Payload: \(payload)")

        } catch {
            print("Error updating vehicle: \(error.localizedDescription)")
        }
    }

    func softDeleteVehichle(vehicleID: UUID) async {
        do {
            // 6. Update the payload in Supabase by filtering with the vehicle's `id`
            let response = try await supabase
                .from("vehicles")
                .update(["status": "Decommissioned"])
                .eq("id", value: vehicleID)
                .execute()
            
            print("Update success: \(response)")
        } catch {
            print("Error updating vehicle: \(error)")
        }
    }
    
    func updateVehicleStatus(newStatus: VehicleStatus, vehicleID: UUID) async {
        do {
            // 6. Update the payload in Supabase by filtering with the vehicle's `id`
            let response = try await supabase
                .from("vehicles")
                .update(["status": newStatus.rawValue])
                .eq("id", value: vehicleID)
                .execute()
            
            print("Update success: \(response)")
        } catch {
            print("Error updating vehicle: \(error)")
        }
    }
    
    func updateVehicleLastMaintenance(lastMaintenanceDistance: Int, vehicleID: UUID) async {
        do {
            // 6. Update the payload in Supabase by filtering with the vehicle's `id`
            let response = try await supabase
                .from("vehicles")
                .update(["lastMaintenanceDistance": lastMaintenanceDistance])
                .eq("id", value: vehicleID)
                .execute()
            
            print("Update success: \(response)")
        } catch {
            print("Error updating vehicle: \(error)")
        }
    }
    
    func updateVehicleTotalMaintenance(totalDistance: Int, vehicleID: UUID) async {
        do {
            // 6. Update the payload in Supabase by filtering with the vehicle's `id`
            let response = try await supabase
                .from("vehicles")
                .update(["totalDistance": totalDistance])
                .eq("id", value: vehicleID)
                .execute()
            
            print("Update success: \(response)")
        } catch {
            print("Error updating vehicle: \(error)")
        }
    }
    
    // MARK: - Trip Management
    
    struct TripPayload: Codable {
        let destination: String
        let vehicle_id: UUID
        let driver_id: UUID?
        let start_time: Date?
        let end_time: Date?
        let start_latitude: Double?
        let start_longitude: Double?
        let end_latitude: Double?
        let end_longitude: Double?
        let notes: String?
        let pickup: String?
        let estimated_distance: Double?
        let estimated_time: Double?
        let estimated_cost: Double?
    }
    
    func createTrip(name: String, destination: String, vehicleId: UUID, driverId: UUID?, startTime: Date?, endTime: Date?, startLat: Double?, startLong: Double?, endLat: Double?, endLong: Double?, notes: String?, distance: Double? = nil, time: Double? = nil, cost: Double? = nil) async throws -> Bool {
        let payload = TripPayload(
            destination: destination,
            vehicle_id: vehicleId,
            driver_id: driverId,
            start_time: startTime,
            end_time: endTime,
            start_latitude: startLat,
            start_longitude: startLong,
            end_latitude: endLat,
            end_longitude: endLong,
            notes: notes,
            pickup: name,
            estimated_distance: distance,
            estimated_time: time,
            estimated_cost: cost
        )
        
        do {
            let response = try await supabase
                .from("trips")
                .insert(payload)
                .execute()
            
            print("Trip created successfully: \(response)")
            return true
        } catch {
            print("Error creating trip: \(error)")
            return false
        }
    }
    
    public func updateTripDetails(id: UUID, destination: String, address: String, notes: String, distance: String? = nil, time: String? = nil) async throws {
        do {
            // First update the basic trip info
            try await databaseFrom("trips")
                .update([
                    "destination": destination,
                    "pickup": address,
                    "notes": notes
                ])
                .eq("id", value: id)
                .execute()
            
            // If distance is provided, update it separately
            if let distance = distance {
                // Extract numeric value from distance string
                let numericDistance = distance.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .joined()
                
                if let distanceValue = Double(numericDistance) {
                    try await databaseFrom("trips")
                        .update(["estimated_distance": distanceValue])
                        .eq("id", value: id)
                        .execute()
                }
            }
            
            // If time is provided, update it separately
            if let time = time {
                // Extract hours and minutes from time string (e.g., "2h 30m" or "45m")
                let components = time.lowercased().components(separatedBy: CharacterSet.letters)
                let hours = components.first?.trimmingCharacters(in: .whitespaces) ?? "0"
                let minutes = components.last?.trimmingCharacters(in: .whitespaces) ?? "0"
                
                if let hoursValue = Double(hours), let minutesValue = Double(minutes) {
                    let totalHours = hoursValue + (minutesValue / 60.0)
                    try await databaseFrom("trips")
                        .update(["estimated_time": totalHours])
                        .eq("id", value: id)
                        .execute()
                }
            }
            
            print("Trip details updated for id \(id)")
        } catch {
            print("Error updating trip details: \(error)")
            throw error
        }
    }
    
    func deleteTrip(tripID: UUID) {
        Task {
            do {
                let response = try await supabase
                    .from("trips")
                    .delete()
                    .eq("id", value: tripID)
                    .execute()
                
                print("Trip deleted successfully: \(response)")
            }
        }
    }

    // Optimized function to fetch a single vehicle with all details including documents
    func fetchVehicleDetails(vehicleId: UUID) async throws -> Vehicle? {
        do {
            // First check if we already have this vehicle in memory
            // If so, we can fetch just the documents to supplement the data
            
            let response = try await supabase
                .from("vehicles")
                .select("*") // Need all fields including documents
                .eq("id", value: vehicleId)
                .single() // Only need one record
                .execute()
            
            let data = response.data
            
            // Configure date formatter for decoding
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            // Configure decoder with date formatter
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            // Decode directly
            let vehicle = try decoder.decode(Vehicle.self, from: data)
            return vehicle
        } catch {
            print("Error fetching vehicle details: \(error)")
            return nil
        }
    }

    // Add these new public methods
    public func databaseFrom(_ table: String) -> PostgrestQueryBuilder {
        return supabase.from(table)
    }

    public func updateTrip(id: UUID, status: String) async throws {
        try await supabase
            .from("trips")
            .update(["trip_status": status])
            .eq("id", value: id)
            .execute()
    }
    
    public func updateTrip(id: UUID, driverId: UUID) async throws {
        do {
            let response = try await supabase
                .from("trips")
                .update(["driver_id": driverId])
                .eq("id", value: id)
                .execute()
            
            print("Trip update success: \(response)")
        } catch {
            print("Error updating trip: \(error)")
            throw error
        }
    }

    public func updateTrip(id: UUID, secondaryDriverId: UUID) async throws {
        do {
            let response = try await supabase
                .from("trips")
                .update(["secondary_driver_id": secondaryDriverId])
                .eq("id", value: id)
                .execute()
            
            print("Trip secondary driver update success: \(response)")
        } catch {
            print("Error updating trip secondary driver: \(error)")
            throw error
        }
    }
    
    func fetchAvailableVehicles(startDate: Date, endDate: Date) async throws -> [Vehicle] {
        let vehicles = try await fetchVehicles()
        let trips = TripDataController.shared.allTrips // Use existing trips instead of refreshing
        
        // Filter trips that overlap with the given date range.
        // This assumes each trip has an `endTime` property.
        let filteredTrips = trips.filter { trip in
            if let startTime = trip.startTime, let endTime = trip.endTime {
                return startTime < endDate && endTime > startDate
            } else {
                return false
            }
        }
        
        var availableVehicles: [Vehicle] = []
        
        // Add vehicles that are not used in any of the overlapping trips.
        for vehicle in vehicles {
            let isUsed = filteredTrips.contains { trip in
                trip.vehicleDetails.id == vehicle.id
            }
            if !isUsed && vehicle.status != .underMaintenance {
                availableVehicles.append(vehicle)
            }
        }
        
        return availableVehicles
    }
    
    func fetchAvailableDrivers(startDate: Date, endDate: Date) async throws -> [Driver] {
        let drivers = try await fetchDrivers()
        let trips = TripDataController.shared.getAllTrips()
        
        // Filter trips that overlap with the given date range.
        let filteredTrips = trips.filter { trip in
            if let startTime = trip.startTime, let endTime = trip.endTime {
                return startTime < endDate && endTime > startDate
            } else {
                return false
            }
        }
        
        var availableDrivers: [Driver] = []
        
        // Add drivers that are not used in any of the overlapping trips.
        for driver in drivers {
            let isUsed = filteredTrips.contains { trip in
                trip.driverId == driver.id
            }
            if !isUsed && driver.status != .offDuty {
                availableDrivers.append(driver)
            }
        }
        
        return availableDrivers
    }
    
//    func fetchTripByID(tripID: UUID) async throws -> Trip {
//        let decoder = JSONDecoder()
//        let dateFormatter = DateFormatter()
//        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
//        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
//        
//        decoder.dateDecodingStrategy = .custom { decoder in
//            let container = try decoder.singleValueContainer()
//            let dateString = try container.decode(String.self)
//            let formats = [
//                "yyyy-MM-dd'T'HH:mm:ss",
//                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
//                "yyyy-MM-dd'T'HH:mm:ssZ",
//                "yyyy-MM-dd"
//            ]
//            for format in formats {
//                dateFormatter.dateFormat = format
//                if let date = dateFormatter.date(from: dateString) {
//                    return date
//                }
//            }
//            if let dotIndex = dateString.firstIndex(of: ".") {
//                let truncated = String(dateString[..<dotIndex])
//                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
//                if let date = dateFormatter.date(from: truncated) {
//                    return date
//                }
//            }
//            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string: \(dateString)")
//        }
//        
//        let query = supabase
//            .from("trips")
//            .select("""
//                id,
//                destination,
//                trip_status,
//                has_completed_pre_trip,
//                has_completed_post_trip,
//                vehicle_id,
//                driver_id,
//                start_time,
//                end_time,
//                notes,
//                created_at,
//                updated_at,
//                is_deleted,
//                start_latitude,
//                start_longitude,
//                end_latitude,
//                end_longitude,
//                pickup,
//                vehicles (
//                    id,
//                    name,
//                    year,
//                    make,
//                    model,
//                    vin,
//                    license_plate,
//                    vehicle_type,
//                    color,
//                    body_type,
//                    body_subtype,
//                    msrp,
//                    pollution_expiry,
//                    insurance_expiry,
//                    status
//                )
//            """)
//            .eq("is_deleted", value: false)
//            .eq("id", value: tripID)
//        
//        let response = try await query.execute()
//        
//        struct JoinedTripData: Codable {
//            let id: UUID
//            let destination: String
//            let trip_status: String
//            let has_completed_pre_trip: Bool
//            let has_completed_post_trip: Bool
//            let vehicle_id: UUID
//            let driver_id: UUID?
//            let start_time: Date?
//            let end_time: Date?
//            let notes: String?
//            let created_at: Date
//            let updated_at: Date?
//            let is_deleted: Bool
//            let start_latitude: Double?
//            let start_longitude: Double?
//            let end_latitude: Double?
//            let end_longitude: Double?
//            let pickup: String?
//            let vehicles: Vehicle
//        }
//        
//        let joinedData = try decoder.decode([JoinedTripData].self, from: response.data)
//        guard let data = joinedData.first else {
//            throw TripError.fetchError("No trip found with the given ID.")
//        }
//        
//        let supabaseTrip = SupabaseTrip(
//            id: data.id,
//            destination: data.destination,
//            trip_status: data.trip_status,
//            has_completed_pre_trip: data.has_completed_pre_trip,
//            has_completed_post_trip: data.has_completed_post_trip,
//            vehicle_id: data.vehicle_id,
//            driver_id: data.driver_id,
//            start_time: data.start_time,
//            end_time: data.end_time,
//            notes: data.notes,
//            created_at: data.created_at,
//            updated_at: data.updated_at ?? data.created_at,
//            is_deleted: data.is_deleted,
//            start_latitude: data.start_latitude,
//            start_longitude: data.start_longitude,
//            end_latitude: data.end_latitude,
//            end_longitude: data.end_longitude,
//            pickup: data.pickup
//        )
//        
//        return Trip(from: supabaseTrip, vehicle: data.vehicles)
//    }

    // MARK: - Service History
        
    func fetchServiceHistory() async throws -> [MaintenancePersonnelServiceHistory] {
        print("Fetching MaintenancePersonnelServiceHistory...")

        // Fetch raw data from Supabase
        let response = try await supabase
            .from("maintenancepersonnelservicehistory")
            .select()
            .execute()

        // Ensure response data exists
        let jsonData = response.data

        // Configure DateFormatter for timestamp decoding
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        // Configure JSONDecoder with date decoding strategy
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)

        // Convert JSON dictionary into `MaintenancePersonnelServiceHistory` array
        let history: [MaintenancePersonnelServiceHistory] = try decoder.decode([MaintenancePersonnelServiceHistory].self, from: jsonData)

//        print("Decoded Maintenance Personnel Service History: \(history)")
        return history
    }
        
    func insertServiceHistory(history: MaintenancePersonnelServiceHistory) async throws {
        print("Inserting MaintenancePersonnelServiceHistory: \(history)")
        try await supabase
            .from("maintenancepersonnelservicehistory")
            .insert(history)
            .execute()
        print("Insert complete for MaintenancePersonnelServiceHistory")
    }

    // MARK: - Routine Schedule

    func fetchRoutineSchedule() async throws -> [MaintenancePersonnelRoutineSchedule] {
        print("Fetching MaintenancePersonnelRoutineSchedule...")

        let response = try await supabase
            .from("maintenancepersonnelroutineschedule")
            .select()
            .execute()

        // Ensure response data exists
        let jsonData = response.data

        // Configure DateFormatter for timestamp decoding
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss" // Ensure this matches Supabase timestamp format
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Optional: Adjust as needed

        // Configure JSONDecoder with custom date formatter
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)

        // Decode JSON into the struct
        let personnelRoutineSchedule = try decoder.decode([MaintenancePersonnelRoutineSchedule].self, from: jsonData)

//        print("Decoded Maintenance Personnel Routine Schedule: \(personnelRoutineSchedule)")
        return personnelRoutineSchedule
    }
    
    func insertRoutineSchedule(schedule: MaintenancePersonnelRoutineSchedule) async throws {
        print("Inserting MaintenancePersonnelRoutineSchedule: \(schedule)")
        try await supabase
            .from("maintenancepersonnelroutineschedule")
            .insert(schedule)
            .execute()
        print("Insert complete for MaintenancePersonnelRoutineSchedule")
    }
    
    func deleteRoutineSchedule(schedule: MaintenancePersonnelRoutineSchedule) async throws {
        print("Deleting MaintenancePersonnelRoutineSchedule with id: \(schedule.id.uuidString)")
        try await supabase
            .from("maintenancepersonnelroutineschedule")
            .delete()
            .eq("id", value: schedule.id.uuidString)
            .execute()
        print("Deletion complete for MaintenancePersonnelRoutineSchedule with id: \(schedule.id.uuidString)")
    }

    // MARK: - Service Request

    func fetchServiceRequests() async throws -> [MaintenanceServiceRequest] {
        print("Fetching MaintenanceServiceRequest...")

        let requestResponse = try await supabase
            .from("maintenanceservicerequest")
            .select()
            .execute()

        let jsonData = requestResponse.data

        // Configure DateFormatter for timestamp decoding
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        // Configure JSONDecoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)

        // Convert JSON dictionaries into `MaintenanceServiceRequest` objects
        let serviceRequests: [MaintenanceServiceRequest] = try decoder.decode([MaintenanceServiceRequest].self, from: jsonData)

//        print("Decoded MaintenanceServiceRequest: \(serviceRequests)")
        return serviceRequests
    }

    func insertServiceRequest(request: MaintenanceServiceRequest) async throws {
        print("Inserting MaintenanceServiceRequest: \(request)")
        try await supabase
            .from("maintenanceservicerequest")
            .insert(request)
            .execute()
        print("Insert complete for MaintenanceServiceRequest")
    }

    // MARK: - Safety Check

    func fetchSafetyChecks(requestId: UUID) async throws -> [SafetyCheck] {
//        print("Fetching SafetyChecks for requestId: \(requestId)")
        let response = try await supabase
            .from("safetycheck")
            .select()
            .eq("requestID", value: requestId)
            .execute()
        let safetyChecks = try JSONDecoder().decode([SafetyCheck].self, from: response.data)
//        print("Decoded SafetyChecks for requestId \(requestId): \(safetyChecks)")
        return safetyChecks
    }
    
    func fetchSafetyChecks(historyId: UUID) async throws -> [SafetyCheck] {
//        print("Fetching SafetyChecks for requestId: \(historyId)")
        let response = try await supabase
            .from("safetycheck")
            .select()
            .eq("historyID", value: historyId)
            .execute()
        let safetyChecks = try JSONDecoder().decode([SafetyCheck].self, from: response.data)
//        print("Decoded SafetyChecks for requestId \(historyId): \(safetyChecks)")
        return safetyChecks
    }
    
    func insertSafetyCheck(check: SafetyCheck) async throws {
//        print("Inserting SafetyCheck: \(check)")
        try await supabase
            .from("safetycheck")
            .insert(check)
            .execute()
        print("Insert complete for SafetyCheck")
    }

    // MARK: - Expense

    func fetchExpenses(for requestId: UUID) async throws -> [Expense] {
//        print("Fetching Expenses for requestId: \(requestId.uuidString)")
        let response = try await supabase
            .from("expense")
            .select()
            .eq("requestID", value: requestId.uuidString)
            .execute()
        
        // Configure DateFormatter for timestamp decoding
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        // Configure JSONDecoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        
        // Decode JSON into Expense objects
        let expenses = try decoder.decode([Expense].self, from: response.data)
//        print("Decoded Expenses for requestId \(requestId.uuidString): \(expenses)")
        return expenses
    }
    
    func insertExpense(expense: Expense) async throws {
        print("Inserting Expense: \(expense)")
        try await supabase
            .from("expense")
            .insert(expense)
            .execute()
        print("Insert complete for Expense")
    }
    
    func updateServiceRequestStatus(serviceRequestId: UUID, newStatus: ServiceRequestStatus) async throws -> Bool {
        let payload: [String: String] = ["status": newStatus.rawValue]
        
        // Perform the update on the Supabase table
        let response = try await supabase
            .from("maintenanceservicerequest")  // The table you are updating
            .update(payload)  // Update the status column
            .eq("id", value: serviceRequestId)  // Assuming `id` is the primary key
            .execute()
        
        // Check if the response was successful
        if response.status == 200 {
            return true
        } else {
            throw NSError(domain: "SupabaseError", code: response.status, userInfo: [NSLocalizedDescriptionKey: "Failed to update service request status."])
        }
    }
    
    func assignServiceToPersonnel(serviceRequestId: UUID, userID: UUID) async throws -> Bool {
        let newStatus = ServiceRequestStatus.inProgress
        let payload: [String: String] = ["status": newStatus.rawValue, "personnelID": userID.uuidString]
        
        // Perform the update on the Supabase table
        let response = try await supabase
            .from("maintenanceservicerequest")  // The table you are updating
            .update(payload)  // Update the status column
            .eq("id", value: serviceRequestId)  // Assuming `id` is the primary key
            .execute()
        
        // Check if the response was successful
        if response.status == 200 {
            return true
        } else {
            throw NSError(domain: "SupabaseError", code: response.status, userInfo: [NSLocalizedDescriptionKey: "Failed to update service request status."])
        }
    }
    
    func fetchAllExpense() async throws -> [Expense] {
        // Fetch expenses from Supabase filtered by requestID
        let response = try await supabase
            .from("expense")
            .select()
            .execute()
        
        // Configure DateFormatter for timestamp decoding
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        // Configure JSONDecoder with the custom date decoding strategy
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        
        // Decode JSON into an array of Expense objects
        let expenses = try decoder.decode([Expense].self, from: response.data)
        
        return expenses
    }
}
