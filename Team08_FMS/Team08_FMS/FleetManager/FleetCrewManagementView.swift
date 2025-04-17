//
//  FleetCrewManagementView.swift
//  Team08_FMS
//
//  Created by Snehil on 19/03/25.
//

import SwiftUI

//@_exported import Team08_FMS

struct FleetCrewManagementView: View {
    @EnvironmentObject private var dataManager: CrewDataController
    @State private var crewType: CrewType = .drivers
    @State private var showingAddDriverSheet = false
    @State private var showingAddMaintenanceSheet = false
    @State private var searchText = ""
    @State private var selectedStatus: Status?  // Updated to use our new Status enum

    // We now filter on any crew member conforming to CrewMemberProtocol.
    var filteredCrew: [any CrewMemberProtocol] {
        let crewList: [any CrewMemberProtocol] = crewType == .drivers ? dataManager.drivers : dataManager.maintenancePersonnel
        return crewList.filter { crew in
            let matchesSearch = searchText.isEmpty ||
                crew.name.lowercased().contains(searchText.lowercased())
            let matchesStatus = selectedStatus == nil || crew.status == selectedStatus
            return matchesSearch && matchesStatus
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search crew members...", text: $searchText)
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // Crew Type Selector
                    Picker("Crew Type", selection: $crewType) {
                        Text("Drivers").tag(CrewType.drivers)
                        Text("Maintenance Personnel").tag(CrewType.maintenancePersonnel)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    // Status Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            FilterChip(
                                title: "All",
                                isSelected: selectedStatus == nil,
                                action: { selectedStatus = nil }
                            )
                            
                            ForEach([Status.available, .busy, .offDuty], id: \.self) { status in
                                FilterChip(
                                    title: AppDataController.shared.getStatusString(status: status),
                                    isSelected: selectedStatus == status,
                                    action: { selectedStatus = status }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)

                    // Crew List
                    LazyVStack(spacing: 16) {
                        if filteredCrew.isEmpty {
                            EmptyStateView(type: crewType)
                        } else {
                            ForEach(filteredCrew, id: \.id) { crew in
                                CrewCardView(crewMember: crew)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Crew Management")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            if crewType == .drivers {
                                showingAddDriverSheet = true
                            } else {
                                showingAddMaintenanceSheet = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddDriverSheet) {
                AddDriverView()
                    .environmentObject(dataManager)
            }
            .sheet(isPresented: $showingAddMaintenanceSheet) {
                AddMaintenancePersonnelView()
                    .environmentObject(dataManager)
            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .default))
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

private struct EmptyStateView: View {
    let type: CrewType

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No \(type == .drivers ? "drivers" : "maintenance personnel") found")
                .font(.system(.headline, design: .default))
            Text("Add new crew members or try different filters")
                .font(.system(.subheadline, design: .default))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

struct CrewCardView: View {
    let crewMember: any CrewMemberProtocol
    @EnvironmentObject var dataManager: CrewDataController
    @State private var showingDeleteAlert = false
    @State private var showingMessageSheet = false
    @State private var unreadMessageCount = 0
    
    // This computed property returns the most recent crew member from the data manager.
    var currentCrew: any CrewMemberProtocol {
        if crewMember is Driver {
            return dataManager.drivers.first { $0.id == crewMember.id } ?? crewMember
        } else {
            return dataManager.maintenancePersonnel.first { $0.id == crewMember.id } ?? crewMember
        }
    }
    
    // Helper to get the userID safely
    private var recipientId: UUID? {
        if let driver = currentCrew as? Driver {
            return driver.userID
        } else if let maintenance = currentCrew as? MaintenancePersonnel {
            return maintenance.userID
        }
        return nil
    }
    
    // Check if driver is in a trip
    private var isInTrip: Bool {
        guard let driver = currentCrew as? Driver else { return false }
        return driver.status == .busy
    }
    
    var body: some View {
        NavigationLink(destination: CrewProfileView(crewMember: currentCrew)) {
            VStack(spacing: 0) {
                // Header with name and status
                HStack {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(currentCrew.avatar)
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            )
                        
                        VStack(alignment: .leading) {
                            Text(currentCrew.name)
                                .font(.headline)
                            Text(role)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    // Chat Button with Badge
                    Button(action: {
                        showingMessageSheet = true
                    }) {
                        Image(systemName: "message.fill")
                            .foregroundColor(.blue)
                            .overlay(
                                Group {
                                    if unreadMessageCount > 0 {
                                        Text("\(unreadMessageCount)")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .offset(x: 10, y: -10)
                                    }
                                }
                            )
                    }
                    .padding(.horizontal, 8)
                    
                    Text(AppDataController.shared.getStatusString(status: currentCrew.status))
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(currentCrew.status.color)
                        .clipShape(Capsule())
                }
                .padding()
                
                Divider()
                
                // Summary Details Section
                VStack(spacing: 12) {
                    if let driver = currentCrew as? Driver {
                        HStack {
                            Label("Experience: \(driver.yearsOfExperience) yrs", systemImage: "clock.fill")
                                .font(.caption)
                            Spacer()
                            Label("License: \(driver.driverLicenseNumber)", systemImage: "car.fill")
                                .font(.caption)
                        }
                    } else if let maintenance = currentCrew as? MaintenancePersonnel {
                        HStack {
                            Label("Experience: \(maintenance.yearsOfExperience) yrs", systemImage: "clock.fill")
                                .font(.caption)
                            Spacer()
                            Label("Specialty: \(AppDataController.shared.getSpecialityString(speciality: maintenance.speciality))", systemImage: "wrench.fill")
                                .font(.caption)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Delete Crew Member", systemImage: "trash")
            }
            
            if currentCrew is Driver {
                if !isInTrip {  // Only show status change options if not in a trip
                    if currentCrew.status == .available {
                        Button {
                            Task { [weak dataManager] in
                                do {
                                    try await updateCrewStatus(.offDuty)
                                    dataManager?.update()
                                } catch {
                                    print("Error updating crew status: \(error)")
                                }
                            }
                        } label: {
                            Label("Mark as Off Duty", systemImage: "checkmark.circle.fill")
                        }
                    }
                    else if currentCrew.status == .offDuty {
                        Button {
                            Task { [weak dataManager] in
                                do {
                                    try await updateCrewStatus(.available)
                                    dataManager?.update()
                                } catch {
                                    print("Error updating crew status: \(error)")
                                }
                            }
                        } label: {
                            Label("Mark as Available", systemImage: "checkmark.circle.fill")
                        }
                    }
                }
            } else {
                // For maintenance personnel, show status options as before
                if currentCrew.status == .available {
                    Button {
                        Task { [weak dataManager] in
                            do {
                                try await updateCrewStatus(.offDuty)
                                dataManager?.update()
                            } catch {
                                print("Error updating crew status: \(error)")
                            }
                        }
                    } label: {
                        Label("Mark as Off Duty", systemImage: "checkmark.circle.fill")
                    }
                }
                else if currentCrew.status == .offDuty {
                    Button {
                        Task { [weak dataManager] in
                            do {
                                try await updateCrewStatus(.available)
                                dataManager?.update()
                            } catch {
                                print("Error updating crew status: \(error)")
                            }
                        }
                    } label: {
                        Label("Mark as Available", systemImage: "checkmark.circle.fill")
                    }
                }
            }
            
            if currentCrew is Driver {
                Button {
                    showingMessageSheet = true
                } label: {
                    Label("Send Message", systemImage: "message.fill")
                }
            }
        }
        .alert("Delete Crew Member", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteCrew()
            }
        } message: {
            Text("Are you sure you want to delete this crew member? This action cannot be undone.")
        }
        .sheet(isPresented: $showingMessageSheet) {
            if let id = recipientId {
                NavigationView {
                    ChatView(
                        recipientType: currentCrew is Driver ? .driver : .maintenance,
                        recipientId: id,
                        recipientName: currentCrew.name
                    )
                }
            }
        }
        .onAppear {
            if let id = recipientId {
                Task {
                    do {
                        let response = try await SupabaseDataController.shared.supabase
                            .from("chat_messages")
                            .select()
                            .eq("recipient_id", value: id)
                            .eq("status", value: "sent")
                            .execute()
                        
                        let count = response.count ?? 0
                        await MainActor.run {
                            self.unreadMessageCount = count
                        }
                    } catch {
                        print("Error loading unread message count: \(error)")
                    }
                }
            }
        }
    }
    
    // Determine the role based on the type.
    var role: String {
        if currentCrew is Driver { return "Driver" }
        else { return "Maintenance" }
    }
    
    private func updateCrewStatus(_ newStatus: Status) async throws {
        if currentCrew is Driver {
            await SupabaseDataController.shared.updateDriverStatus(newStatus: newStatus, userID: nil, id: currentCrew.id)
        } else {
            await SupabaseDataController.shared.updateMaintenancePersonnelStatus(newStatus: newStatus, userID: nil, id: currentCrew.id)
        }
    }
    
    private func deleteCrew() {
        if currentCrew is Driver {
            Task { [weak dataManager] in
                await SupabaseDataController.shared.softDeleteDriver(for: currentCrew.id)
                dataManager?.update()
            }
        }
        else {
            Task { [weak dataManager] in
                await SupabaseDataController.shared.softDeleteMaintenancePersonnel(for: currentCrew.id)
                dataManager?.update()
            }
        }
    }
}


struct StatusCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }

            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(title)
                .font(.system(.subheadline, design: .default))
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .padding()
        .frame(width: 110, height: 100)
        .background(isSelected ? color.opacity(0.1) : Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? color : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
    }
}
