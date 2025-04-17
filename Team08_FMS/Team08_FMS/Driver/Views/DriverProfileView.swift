import SwiftUI

struct DriverProfileView: View {
    @StateObject private var supabaseDataController = SupabaseDataController.shared
    @State private var driver: Driver?
    @State private var showingStatusChangeAlert = false
    @State private var pendingStatus: Status?
    @State private var showAlert = false
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            Group {
                if let driver = driver {
                    ScrollView {
                        VStack(spacing: 20) {
                            profileHeader(for: driver)
                            statusToggle(for: driver)
                            contactInformation(for: driver)
                            licenseInformation(for: driver)
                            experienceDetails(for: driver)
                            resetPasswordButton
                            logoutButton
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                } else {
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert(isPresented: $showingStatusChangeAlert) {
                if pendingStatus == .available {
                    return Alert(
                        title: Text("Confirm Status Change"),
                        message: Text("Your status will be updated to Available."),
                        dismissButton: .default(Text("OK"), action: {
                            Task {
                                if let userID = await supabaseDataController.getUserID() {
                                    await supabaseDataController.updateDriverStatus(newStatus: .available, userID: userID, id: nil)
                                    self.driver?.status = .available
                                }
                            }
                        })
                    )
                } else {
                    return Alert(
                        title: Text("Confirm Status Change"),
                        message: Text("Your status will be updated to Unavailable."),
                        primaryButton: .cancel(Text("Cancel")),
                        secondaryButton: .default(Text("Confirm"), action: {
                            Task {
                                if let driver = driver {
                                    await supabaseDataController.updateDriverStatus(newStatus: .offDuty, userID: nil, id: driver.id)
                                    self.driver?.status = .offDuty
                                }
                            }
                        })
                    )
                }
            }
//            .alert(isPresented: $showAlert) {
//                Alert(
//                    title: Text("Alert"),
//                    message: Text("Are you sure you want to log out?"),
//                    primaryButton: .destructive(Text("Yes")) {
//                        Task {
//                            SupabaseDataController.shared.signOut()
//                        }
//                    },
//                    secondaryButton: .cancel()
//                )
//            }
            .task {
                if let userID = await supabaseDataController.getUserID() {
                    do {
                        if let fetchedDriver = try await supabaseDataController.fetchDriverByUserID(userID: userID) {
                            self.driver = fetchedDriver
                        }
                    } catch {
                        print("Error fetching driver: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private func profileHeader(for driver: Driver) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .foregroundColor(.blue)
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            Text(driver.name)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(driver.email)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func statusToggle(for driver: Driver) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Status")
                    .font(.headline)
                Spacer()
                Text(driver.status == .available ? "Available" : "Unavailable")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(driver.status == .available ? .green : .red)
                
                Toggle("", isOn: statusToggleBinding(for: driver))
                    .tint(.green)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func contactInformation(for driver: Driver) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONTACT INFORMATION")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                infoRow(title: "Phone", value: "\(driver.phoneNumber)")
                Divider()
                infoRow(title: "Email", value: driver.email)
            }
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    private func licenseInformation(for driver: Driver) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LICENSE INFORMATION")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                NavigationLink {
                    LicenseDetailView(
                        name: driver.name,
                        licenseNumber: driver.driverLicenseNumber,
                        expiryDate: driver.driverLicenseExpiry != nil ? formattedDate(driver.driverLicenseExpiry!) : "N/A"
                    )
                } label: {
                    HStack {
                        Text("Driver License")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
                Divider()
                infoRow(title: "License Number", value: driver.driverLicenseNumber)
                Divider()
                infoRow(title: "Expiry Date", value: driver.driverLicenseExpiry != nil ? formattedDate(driver.driverLicenseExpiry!) : "N/A")
            }
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    private func experienceDetails(for driver: Driver) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EXPERIENCE & DETAILS")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                infoRow(title: "Experience", value: "\(driver.yearsOfExperience) Years")
                Divider()
                infoRow(title: "Salary", value: "$\(driver.salary)")
            }
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    private var resetPasswordButton: some View {
        NavigationLink(destination: ResetPasswordView()) {
            HStack {
                Image(systemName: "lock.rotation")
                    .foregroundColor(.blue)
                Text("Reset Password")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
        }
    }
    
    private var logoutButton: some View {
        Button {
            Task { supabaseDataController.signOut() }
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
                Text("Logout")
                    .font(.headline)
                    .foregroundColor(.red)
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(20)
        }
        .padding(.top, 20)
        .padding(.horizontal)
    }
    
    // MARK: - Helper Functions
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
                .font(.subheadline)
        }
        .padding()
    }
    
    private func statusToggleBinding(for driver: Driver) -> Binding<Bool> {
        Binding<Bool>(
            get: { driver.status == .available },
            set: { newValue in
                let newStatus: Status = newValue ? .available : .offDuty
                if newStatus != driver.status {
                    pendingStatus = newStatus
                    showingStatusChangeAlert = true
                }
            }
        )
    }
    
    // Helper to format dates
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
 
struct LicenseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let name: String
    let licenseNumber: String
    let expiryDate: String

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    licenseCard
                }
                .padding()
            }
            .navigationTitle("Driver License")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var licenseCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DRIVER LICENSE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.7))
            
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 80, height: 100)
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.blue)
                        .frame(width: 50)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text("№")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(licenseNumber)
                            .font(.caption)
                    }
                    
                    HStack(spacing: 4) {
                        Text("EXP")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(expiryDate)
                            .font(.caption)
                    }
                    
                    HStack(spacing: 4) {
                        Text("NAME")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(name)
                            .font(.caption)
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color(.systemGray6))
        }
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
