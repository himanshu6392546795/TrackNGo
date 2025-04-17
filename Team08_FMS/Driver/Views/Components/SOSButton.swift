import SwiftUI

struct ContactPerson {
    let name: String
    let email: String
    let phone: String
    let role: String
}

struct SOSButton: View {
    @State private var showingSOSOptions = false
    @State private var selectedContact: ContactType = .fleetManager
    @State private var message: String = ""
    
    enum ContactType {
        case fleetManager
        case maintenance
    }
    
    let fleetManager = ContactPerson(
        name: "Sarah Johnson",
        email: "sarah.j@fleetmanagement.com",
        phone: "+1 234 567 8901",
        role: "Fleet Manager"
    )
    
    let maintenance = ContactPerson(
        name: "Maintenance Team",
        email: "maintenance@fleetmanagement.com",
        phone: "+1 234 567 8902",
        role: "Maintenance"
    )
    
    var body: some View {
        Button(action: {
            showingSOSOptions = true
        }) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                Text("SOS")
                    .foregroundColor(.white)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .cornerRadius(10)
        }
        .sheet(isPresented: $showingSOSOptions) {
            NavigationView {
                VStack(spacing: 20) {
                    // SELECT CONTACT Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SELECT CONTACT")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                        
                        HStack(spacing: 12) {
                            Button(action: { selectedContact = .fleetManager }) {
                                Text("Fleet Manager")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(selectedContact == .fleetManager ? Color.blue : Color(.systemGray5))
                                    .foregroundColor(selectedContact == .fleetManager ? .white : .primary)
                                    .cornerRadius(10)
                            }
                            
                            Button(action: { selectedContact = .maintenance }) {
                                Text("Maintenance")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(selectedContact == .maintenance ? Color.blue : Color(.systemGray5))
                                    .foregroundColor(selectedContact == .maintenance ? .white : .primary)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemSecondaryBackground))
                    .cornerRadius(12)
                    
                    // CONTACT DETAILS Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("CONTACT DETAILS")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                        
                        VStack(alignment: .center, spacing: 8) {
                            Text(selectedContact == .fleetManager ? fleetManager.name : maintenance.name)
                                .font(.title2)
                                .fontWeight(.medium)
                            
                            Text(selectedContact == .fleetManager ? fleetManager.email : maintenance.email)
                                .foregroundColor(.gray)
                            
                            Text(selectedContact == .fleetManager ? fleetManager.phone : maintenance.phone)
                                .foregroundColor(.gray)
                            
                            Text(selectedContact == .fleetManager ? fleetManager.role : maintenance.role)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color(.systemSecondaryBackground))
                    .cornerRadius(12)
                    
                    // MESSAGE Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("MESSAGE")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                        
                        TextEditor(text: $message)
                            .frame(height: 150)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    .padding()
                    .background(Color(.systemSecondaryBackground))
                    .cornerRadius(12)
                    
                    // Send Message Button
                    Button(action: {
                        sendMessage()
                    }) {
                        Text("Send Message")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Spacer()
                }
                .padding()
                .navigationTitle("Contact")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Close") {
                    showingSOSOptions = false
                })
            }
        }
    }
    
    private func sendMessage() {
        // Here you would implement the actual message sending logic
        // For example, sending an email, SMS, or API call
        let contact = selectedContact == .fleetManager ? fleetManager : maintenance
        print("Sending message to \(contact.name): \(message)")
        showingSOSOptions = false
    }
}

#Preview {
    SOSButton()
        .padding()
} 