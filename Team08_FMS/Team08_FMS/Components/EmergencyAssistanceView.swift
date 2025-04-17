import SwiftUI

struct EmergencyAssistanceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var emergencyDescription = ""
    @State private var emergencySubject = ""
    @StateObject private var supabaseDataController = SupabaseDataController.shared
    @State private var fleetManager: FleetManager?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Warning Icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(ChatThemeColors.emergency)
                    .padding(.top, 20)
                
                // Emergency Title
                Text("Emergency Assistance")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Description Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Describe your emergency situation")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    TextEditor(text: $emergencyDescription)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                // Subject Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Emergency Subject")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    TextField("Enter emergency details", text: $emergencySubject)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal, 8)
                }
                
                // Fleet Manager Contact
                if let manager = fleetManager {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Fleet Manager Contact")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(manager.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Text(formatPhoneNumber(manager.phoneNumber))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                // Contact Button
                Button(action: {
                    if let manager = fleetManager {
                        callFleetManager(phoneNumber: manager.phoneNumber)
                    }
                }) {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text("Contact Fleet Manager")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray4))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
                .disabled(fleetManager == nil)
                
                Spacer()
            }
            .padding()
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
            .task {
                await fetchFleetManager()
            }
        }
    }
    
    private func fetchFleetManager() async {
        do {
            let fleetManagers = try await supabaseDataController.fetchFleetManagers()
            if !fleetManagers.isEmpty {
                await MainActor.run {
                    self.fleetManager = fleetManagers[0]
                }
            }
        } catch {
            print("Error fetching fleet manager: \(error)")
        }
    }
    
    private func formatPhoneNumber(_ number: Int) -> String {
        let numberString = String(format: "%010d", number) // Ensure 10 digits with leading zeros
        return "+1 (\(numberString.prefix(3))) \(numberString.dropFirst(3).prefix(3))-\(numberString.dropFirst(6))"
    }
    
    private func callFleetManager(phoneNumber: Int) {
        let phoneNumberString = String(phoneNumber)
        if let url = URL(string: "tel://\(phoneNumberString)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

// Preview provider
struct EmergencyAssistanceView_Previews: PreviewProvider {
    static var previews: some View {
        EmergencyAssistanceView()
    }
} 