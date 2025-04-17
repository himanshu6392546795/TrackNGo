import SwiftUI
import Supabase

struct AddDriverView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var supabase = SupabaseDataController.shared
    @StateObject private var crewDataController = CrewDataController.shared
    
    // Driver information
    @State private var name = ""
    @State private var avatar = ""
    @State private var experience = ""
    @State private var licenseNumber = ""
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var address = ""
    @State private var licenseExpiration = Date()
    @State private var salary = ""
    
    let licenseTypes = ["Class A CDL", "Class B CDL", "Class C CDL", "Non-CDL"]
    
    // MARK: - Touched States for Inline Validation
    @State private var nameEdited = false
    @State private var experienceEdited = false
    @State private var phoneEdited = false
    @State private var emailEdited = false
    @State private var licenseNumberEdited = false
    @State private var salaryEdited = false
    
    // Save state to prevent duplicate taps.
    @State private var isSaving = false
    
    // MARK: - Field Validations
    private var isNameValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Only letters and spaces allowed.
        let regex = "^[A-Za-z ]+$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed)
    }
    
    private var isExperienceValid: Bool {
        if let exp = Int(experience), exp >= 0 {
            return true
        }
        return false
    }
    
    private var isPhoneValid: Bool {
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && Int(trimmed) != nil
    }
    
    private var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Basic email regex.
        let regex = #"^\S+@\S+\.\S+$"#
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed)
    }
    
    private var isLicenseValid: Bool {
        let trimmedLicense = licenseNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let regex = "^[A-Z]{2}\\s?[0-9]{2}\\s?[0-9]{4}\\s?[0-9]{7}$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmedLicense)
    }
    
    private var isSalaryValid: Bool {
        if let sal = Double(salary), sal > 0 {
            return true
        }
        return false
    }
    
    // Overall form validity.
    private var isFormValid: Bool {
        isNameValid &&
        isExperienceValid &&
        isPhoneValid &&
        isEmailValid &&
        isLicenseValid &&
        isSalaryValid
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section("Basic Information") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Full Name", text: $name)
                            .onChange(of: name) { _, _ in nameEdited = true }
                        if nameEdited && !isNameValid {
                            Text("Name cannot be empty and must contain only letters and spaces.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Optionally, auto-generate avatar initials from name.
                    TextField("Avatar (optional)", text: $avatar)
                        .onChange(of: name) { _, _ in
                            if avatar.isEmpty {
                                let words = name.components(separatedBy: " ")
                                avatar = words.compactMap { $0.first }.map(String.init).joined()
                            }
                        }
                }
                
                // Contact Information
                Section("Contact Information") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Phone Number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .onChange(of: phoneNumber) { _, _ in phoneEdited = true }
                        if phoneEdited && !isPhoneValid {
                            Text("Phone must be numeric and cannot be empty.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .onChange(of: email) { _, _ in emailEdited = true }
                        if emailEdited && !isEmailValid {
                            Text("Enter a valid email address.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    TextField("Address", text: $address)
                }
                
                // Professional Details
                Section("Professional Details") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Experience (years)", text: $experience)
                            .keyboardType(.numberPad)
                            .onChange(of: experience) { _, _ in experienceEdited = true }
                        if experienceEdited && !isExperienceValid {
                            Text("Experience must be a nonnegative number.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Driver License Number", text: $licenseNumber)
                            .onChange(of: licenseNumber) { _, _ in licenseNumberEdited = true }
                        if licenseNumberEdited && !isLicenseValid {
                            Text("License number format is invalid. Please use the format: AA 00 0000 0000000")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    DatePicker("License Expiration", selection: $licenseExpiration, displayedComponents: .date)
                }
                
                // Compensation
                Section("Compensation") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Monthly Salary", text: $salary)
                            .keyboardType(.decimalPad)
                            .onChange(of: salary) { newValue, _ in
                                // Filter non-numeric characters (keeping one dot).
                                let filtered = newValue.filter { "0123456789.".contains($0) }
                                if filtered != newValue {
                                    salary = filtered
                                }
                                salaryEdited = true
                            }
                        if salaryEdited && !isSalaryValid {
                            Text("Salary must be a positive number.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Add Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveDriver()
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
        }
    }
    
    private func saveDriver() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            guard let salaryDouble = Double(salary),
                  let experienceInt = Int(experience),
                  let phoneNumberInt = Int(phoneNumber) else {
                print("Invalid salary, experience, or phone number format.")
                isSaving = false
                return
            }
            
            // Create a new Driver instance. (Make sure your Driver model conforms to Codable.)
            var newDriver = Driver(
                userID: UUID(),
                name: name,
                profileImage: avatar.isEmpty ? nil : avatar,
                email: email,
                phoneNumber: phoneNumberInt,
                driverLicenseNumber: licenseNumber,
                driverLicenseExpiry: licenseExpiration,
                assignedVehicleID: nil,
                address: address,
                salary: salaryDouble,
                yearsOfExperience: experienceInt,
                createdAt: Date(),
                isDeleted: false,
                status: .available
            )
            
            do {
                guard let signUpID = await supabase.signUp(name: newDriver.name, email: newDriver.email, phoneNo: newDriver.phoneNumber, role: "driver") else {
                    isSaving = false
                    return
                }
                newDriver.userID = signUpID
                try await supabase.insertDriver(driver: newDriver, password: AppDataController.shared.randomPasswordGenerator(length: 6))
                await supabase.setUserSession()
                await MainActor.run {
                    crewDataController.update()
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                print("Error saving driver: \(error.localizedDescription)")
            }
            isSaving = false
        }
    }
}

#Preview {
    AddDriverView()
        .environmentObject(SupabaseDataController.shared)
}
