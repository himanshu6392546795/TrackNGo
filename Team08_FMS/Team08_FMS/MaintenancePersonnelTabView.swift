//
//  MaintenancePersonnelHomeScreen.swift
//  Team08_FMS
//
//  Created by Snehil on 18/03/25.
//

import SwiftUI

struct MaintenancePersonnelTabView: View {
    @State private var selectedTab = 0
    @State private var showingProfile = false
    @State private var showingContact = false
    
    // Sample data - In a real app, this would come from a database
    let preTripRequests = [
        ServiceRequest(vehicleId: "V001", vehicleName: "Truck 1", issueType: "Pre-Trip", description: "Oil change required", priority: "High", date: Date(), status: "Pending"),
        ServiceRequest(vehicleId: "V002", vehicleName: "Van 2", issueType: "Pre-Trip", description: "Tire pressure check", priority: "Medium", date: Date(), status: "In Progress")
    ]
    
    let postTripRequests = [
        ServiceRequest(vehicleId: "V003", vehicleName: "Bus 1", issueType: "Post-Trip", description: "Brake system check", priority: "High", date: Date(), status: "Pending"),
        ServiceRequest(vehicleId: "V004", vehicleName: "Truck 2", issueType: "Post-Trip", description: "Engine maintenance", priority: "Medium", date: Date(), status: "Scheduled")
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                // Header
                HStack {
                    Text("Home")
                        .font(.system(.title, design: .default))
                        .fontWeight(.bold)
                    Spacer()
                    HStack(spacing: 15) {
                        Button(action: {
                            showingProfile = true
                        }) {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                        }
                    }
                }
                .padding()
                
                // Tab View for different sections
                Picker("View", selection: $selectedTab) {
                    Text("Service Requests").tag(0)
                    Text("Schedule").tag(1)
                    Text("Vehicle Status").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Service Requests Tab
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Pre-Trip Requests Section
                            VStack(alignment: .leading) {
                                Text("Pre-Trip Service Requests")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(preTripRequests) { request in
                                    RServiceRequestCard(request: request)
                                }
                            }
                            
                            // Post-Trip Requests Section
                            VStack(alignment: .leading) {
                                Text("Post-Trip Service Requests")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(postTripRequests) { request in
                                    RServiceRequestCard(request: request)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                    .tag(0)
                    
                    // Schedule Tab
                    Text("Maintenance Schedule")
                        .tag(1)
                    
                    // Vehicle Status Tab
                    Text("Vehicle Status Overview")
                        .tag(2)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingProfile) {
                MaintenancePersonnelProfileView()
            }
            .sheet(isPresented: $showingContact) {
                ContactView()
            }
        }
    }
}

struct RServiceRequestCard: View {
    let request: ServiceRequest
    @State private var showingContact = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(request.vehicleName)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(request.priority)
                    .font(.subheadline)
                    .padding(6)
                    .background(priorityColor(request.priority))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Text(request.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Vehicle ID: \(request.vehicleId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(request.status)
                    .font(.caption)
                    .padding(4)
                    .background(statusColor(request.status))
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            if request.status == "In Progress" {
                Button(action: {
                    showingContact = true
                }) {
                    HStack {
                        Image(systemName: "message.fill")
                        Text("Contact")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingContact) {
            ContactView()
        }
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "High": return .red
        case "Medium": return .orange
        case "Low": return .green
        default: return .gray
        }
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status {
        case "Pending": return .orange
        case "In Progress": return .blue
        case "Scheduled": return .green
        default: return .gray
        }
    }
}

struct ContactView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedContact: ContactType = .fleetManager
    @State private var message = ""
    @State private var showingAlert = false
    
    enum ContactType {
        case fleetManager
        case driver
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Contact")) {
                    Picker("Contact", selection: $selectedContact) {
                        Text("Fleet Manager").tag(ContactType.fleetManager)
                        Text("Driver").tag(ContactType.driver)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Contact Details")) {
                    if selectedContact == .fleetManager {
                        ContactRow(title: "Name", value: "Sarah Johnson")
                        ContactRow(title: "Email", value: "sarah.j@fleetmanagement.com")
                        ContactRow(title: "Phone", value: "+1 234 567 8901")
                        ContactRow(title: "Role", value: "Fleet Manager")
                    } else {
                        ContactRow(title: "Name", value: "Mike Wilson")
                        ContactRow(title: "Email", value: "mike.w@fleetmanagement.com")
                        ContactRow(title: "Phone", value: "+1 234 567 8902")
                        ContactRow(title: "Role", value: "Driver")
                    }
                }
                
                Section(header: Text("Message")) {
                    TextEditor(text: $message)
                        .frame(height: 100)
                }
                
                Section {
                    Button(action: sendMessage) {
                        HStack {
                            Spacer()
                            Text("Send Message")
                            Spacer()
                        }
                    }
                    .disabled(message.isEmpty)
                }
            }
            .navigationTitle("Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
            .alert("Message Sent", isPresented: $showingAlert) {
                Button("OK") {
                    message = ""
                    dismiss()
                }
            } message: {
                Text("Your message has been sent successfully.")
            }
        }
    }
    
    private func sendMessage() {
        // Here you would typically implement the actual message sending logic
        showingAlert = true
    }
}

struct ContactRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    MaintenancePersonnelTabView()
}
