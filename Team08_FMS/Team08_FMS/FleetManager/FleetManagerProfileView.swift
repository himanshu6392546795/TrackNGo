import SwiftUI

struct FleetManagerProfileView: View {
    @StateObject private var supabaseDataController = SupabaseDataController.shared
    @State private var fleetManager: FleetManager?
    @State private var showAlert = false
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        Group {
            if let fm = fleetManager {
                ScrollView {
                    VStack(spacing: 20) {
                        profileHeader(for: fm)
                        personalInfo(for: fm)
                        contactInfo(for: fm)
                        workInfo()
                        resetPasswordButton
                        logoutButton
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                }
            } else {
                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            }
        }
        .background(Color(.systemGroupedBackground))
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Alert"),
                message: Text("Are you sure you want to log out?"),
                primaryButton: .destructive(Text("Yes")) {
                    Task {
                        SupabaseDataController.shared.signOut()
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { backButton }
        .task {
            await loadFleetManagerData()
        }
    }
    
    // MARK: - View Components
    
    private func profileHeader(for fm: FleetManager) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .foregroundColor(.blue)
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            Text(fm.name)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func personalInfo(for fm: FleetManager) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Personal Information")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                infoRow(title: "Name", value: fm.name)
                Divider()
                infoRow(title: "Role", value: "Fleet Manager")
                Divider()
                infoRow(title: "ID", value: fm.id.uuidString.prefix(6) + "...")
            }
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    private func contactInfo(for fm: FleetManager) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contact Information")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                infoRow(title: "Email", value: fm.email)
                Divider()
                infoRow(title: "Phone", value: "\(fm.phoneNumber)")
            }
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    /// In this example, work info is static.
    private func workInfo() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Work Information")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                infoRow(title: "Department", value: "Fleet Operations")
                Divider()
                infoRow(title: "Location", value: "Main Office")
                Divider()
                infoRow(title: "Working Hours", value: "9:00 AM - 5:00 PM")
            }
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    /// New Reset Password button that navigates to ResetPasswordView.
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
            Task { showAlert = true }
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
                Text("Log Out")
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
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
    }
    
    // MARK: - Data Loading
    
    private func loadFleetManagerData() async {
        if let userID = await supabaseDataController.getUserID() {
            do {
                if let fetchedManager = try await supabaseDataController.fetchFleetManagerByUserID(userID: userID) {
                    self.fleetManager = fetchedManager
                }
            } catch {
                print("Error fetching fleet manager: \(error.localizedDescription)")
            }
        }
    }
    
    private var backButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Back") {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
