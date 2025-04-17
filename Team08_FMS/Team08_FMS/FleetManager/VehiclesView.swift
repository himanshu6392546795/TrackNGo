//
//  VehiclesView.swift
//  Team08_FMS
//
//  Created by Snehil on 19/03/25.
//

import SwiftUI

private struct VehicleCard: View {
    var vehicle: Vehicle
    @ObservedObject var vehicleManager: VehicleManager
    @State private var showingDeleteAlert = false
    @State private var showingOptions = false
    @State private var showingDeliveryReceipt = false
    @State private var currentTrip: Trip?
    @State private var pdfData: Data? = nil
    @State private var pdfError: String? = nil
    @State private var showingPDFError = false
    
    private var statusColor: Color {
        switch vehicle.status {
        case .available: return .green
        case .inService: return .blue
        case .underMaintenance: return .orange
        case .decommissioned: return .red
        }
    }
    
    private var totalDistance: Double {
        TripDataController.shared.allTrips
            .filter { $0.vehicleDetails.id == vehicle.id && $0.status == .delivered }
            .reduce(0.0) { sum, trip in
                if let estimatedDistance = Double(trip.distance.replacingOccurrences(of: " km", with: "")) {
                    return sum + estimatedDistance
                }
                return sum
            }
    }
    
    var needsMaintenance: Bool {
        return (Int(totalDistance) - vehicle.lastMaintenanceDistance) >= 10000
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with vehicle name and status
            HStack {
                Text(vehicle.name)
                    .font(.system(.headline, design: .default))
                    .foregroundColor(.primary)
                Spacer()
                Text(vehicle.status.rawValue.capitalized)
                    .font(.system(.subheadline, design: .default))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.top)

            // Main content
            VStack(alignment: .leading, spacing: 12) {
                // Vehicle basic info
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Label("\(vehicle.year)", systemImage: "car.fill")
                            .foregroundColor(.secondary)
                        Text("\(vehicle.make) \(vehicle.model)")
                            .foregroundColor(.primary)
                    }

                    Divider()

                    VStack(alignment: .leading) {
                        Label("License", systemImage: "creditcard.fill")
                            .foregroundColor(.secondary)
                        Text(vehicle.licensePlate)
                            .foregroundColor(.primary)
                    }
                }

                Divider()

                // Vehicle details
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Label("Type", systemImage: "tag.fill")
                            .foregroundColor(.secondary)
                        Text("\(vehicle.bodyType.rawValue) - \(vehicle.bodySubtype)")
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    if !vehicle.color.isEmpty {
                        VStack(alignment: .leading) {
                            Label("Color", systemImage: "paintpalette.fill")
                                .foregroundColor(.secondary)
                            Text(vehicle.color)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Add maintenance indicator
                if needsMaintenance {
                    Divider()
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(.orange)
                        Text("Service Required")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                        Text("(\(String(format: "%.1f", totalDistance)) km)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .contextMenu {
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Delete Vehicle", systemImage: "trash")
            }

            if vehicle.status != .inService {  // Only show status options if not in service
                if vehicle.status == .underMaintenance {
                    Button {
                        Task {
                            await SupabaseDataController.shared.updateVehicleStatus(newStatus: VehicleStatus.available, vehicleID: vehicle.id)
                            if let index = vehicleManager.vehicles.firstIndex(where: { $0.id == vehicle.id }) {
                                await MainActor.run {
                                    vehicleManager.vehicles[index].status = .available
                                }
                            }
                        }
                    } label: {
                        Label("Mark as available", systemImage: "checkmark.circle.fill")
                    }
                }

                if vehicle.status == .available {
                    Button {
                        Task {
                            let maintenanceRequest = MaintenanceServiceRequest(
                                vehicleId: vehicle.id,
                                vehicleName: vehicle.name,
                                serviceType: .routine,
                                description: "Perform routine maintenance check and oil change",
                                priority: .medium,
                                date: Date(),
                                dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                                status: .pending,
                                notes: "Maintenance scheduled; verify fluid levels and tire pressure.",
                                issueType: "Routine"
                            )
                            
                            try await SupabaseDataController.shared.insertServiceRequest(request: maintenanceRequest)
                            await SupabaseDataController.shared.updateVehicleStatus(newStatus: VehicleStatus.underMaintenance, vehicleID: vehicle.id)
                            await SupabaseDataController.shared.updateVehicleLastMaintenance(lastMaintenanceDistance: vehicle.totalDistance, vehicleID: vehicle.id)
                            
                            if let index = vehicleManager.vehicles.firstIndex(where: { $0.id == vehicle.id }) {
                                await MainActor.run {
                                    vehicleManager.vehicles[index].status = .underMaintenance
                                }
                            }
                        }
                    } label: {
                        Label("Mark as under maintenance", systemImage: "checkmark.circle.fill")
                    }
                }
            }

            Button {
                showingOptions = true
            } label: {
                Label("Share Details", systemImage: "square.and.arrow.up")
            }
        }
        .alert("Delete Vehicle", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await SupabaseDataController.shared.softDeleteVehichle(vehicleID: vehicle.id)
                    await vehicleManager.loadVehiclesAsync()
                }
            }
        } message: {
            Text("Are you sure you want to delete this vehicle? This action cannot be undone.")
        }
        .sheet(isPresented: $showingDeliveryReceipt) {
            NavigationView {
                if let data = pdfData {
                    PDFViewer(data: data)
                        .navigationTitle("Delivery Receipt")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingDeliveryReceipt = false
                                }
                            }
                        }
                }
            }
        }
        .alert("Error", isPresented: $showingPDFError) {
            Button("OK") {
                showingPDFError = false
            }
        } message: {
            Text(pdfError ?? "Failed to generate delivery receipt")
        }
        .onAppear {
            // Find if this vehicle has any current trip
            currentTrip = TripDataController.shared.allTrips.first(where: { 
                $0.vehicleDetails.id == vehicle.id && 
                ($0.status == .inProgress || $0.status == .delivered)
            })
        }
    }
}

private struct VehicleListView: View {
    let vehicles: [Vehicle]
    let vehicleManager: VehicleManager

    var body: some View {
        LazyVStack(spacing: 16) {
            if vehicles.isEmpty {
                MaintenanceEmptyStateView()
            } else {
                ForEach(vehicles) { vehicle in
                    NavigationLink(destination: VehicleDetailView(vehicle: vehicle)) {
                        VehicleCard(vehicle: vehicle, vehicleManager: vehicleManager)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }
}

private struct SearchBarView: View {
    @Binding var searchText: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search vehicles...", text: $searchText)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

private struct StatusFilterView: View {
    @Binding var selectedStatus: VehicleStatus?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    title: "All",
                    isSelected: selectedStatus == nil,
                    action: { selectedStatus = nil }
                )
                
                ForEach([VehicleStatus.available, .inService, .underMaintenance], id: \.self) { status in
                    FilterChip(
                        title: status.rawValue.capitalized,
                        isSelected: selectedStatus == status,
                        action: { selectedStatus = status }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

// Add this new view for deletion mode
private struct DeleteVehiclesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vehicleManager: VehicleManager
    @State private var selectedVehicles = Set<UUID>()
    @State private var showingConfirmation = false

    var body: some View {
        NavigationView {
            List {
                ForEach(vehicleManager.vehicles) { vehicle in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(vehicle.name)
                                .font(.headline)
                            Text("\(vehicle.make) \(vehicle.model)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(vehicle.licensePlate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: selectedVehicles.contains(vehicle.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedVehicles.contains(vehicle.id) ? .accentColor : .secondary)
                            .font(.title2)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedVehicles.contains(vehicle.id) {
                            selectedVehicles.remove(vehicle.id)
                        } else {
                            selectedVehicles.insert(vehicle.id)
                        }
                    }
                }
            }
            .navigationTitle("Delete Vehicles")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Delete Selected") {
                        showingConfirmation = true
                    }
                    .foregroundColor(.red)
                    .disabled(selectedVehicles.isEmpty)
                }
            }
            .alert("Delete Vehicles", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    for id in selectedVehicles {
                        if let vehicle = vehicleManager.vehicles.first(where: { $0.id == id }) {
                            Task {
                                await SupabaseDataController.shared.softDeleteVehichle(vehicleID: vehicle.id)
                                await vehicleManager.loadVehiclesAsync()
                            }
                        }
                    }
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete \(selectedVehicles.count) vehicle\(selectedVehicles.count == 1 ? "" : "s")? This action cannot be undone.")
            }
        }
    }
}

struct VehiclesView: View {
    @EnvironmentObject private var dataManager: CrewDataController
    @EnvironmentObject private var vehicleManager: VehicleManager
    @StateObject private var notificationsViewModel = NotificationsViewModel()
    @State private var showingAddVehicle = false
    @State private var showingDeleteMode = false
    @State private var showingProfile = false
    @State private var showingMessages = false
    @State private var showingNotifications = false
    @State private var searchText = ""
    @State private var selectedStatus: VehicleStatus?

    private let minimumUpdateInterval: TimeInterval = 15.0

    private func matchesSearch(_ vehicle: Vehicle) -> Bool {
        guard !searchText.isEmpty else { return true }
        let searchText = self.searchText.lowercased()

        return vehicle.name.lowercased().contains(searchText) ||
               vehicle.make.lowercased().contains(searchText) ||
               vehicle.model.lowercased().contains(searchText) ||
               vehicle.licensePlate.lowercased().contains(searchText)
    }

    private var filteredVehicles: [Vehicle] {
        let vehicles: [Vehicle]
        
        // Don't call loadVehicles here as it was causing unnecessary reloads
        if let status = selectedStatus {
            // Filter directly from the published array
            vehicles = vehicleManager.vehicles.filter { $0.status == status }
        } else {
            vehicles = vehicleManager.vehicles
        }
        return vehicles.filter(matchesSearch)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    SearchBarView(searchText: $searchText)
                    StatusFilterView(selectedStatus: $selectedStatus)
                    
                    if vehicleManager.isLoading && vehicleManager.vehicles.isEmpty {
                        ProgressView("Loading vehicles...")
                            .padding(.top, 50)
                    } else if vehicleManager.loadError != nil && vehicleManager.vehicles.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            Text("Failed to load vehicles")
                                .font(.system(.headline, design: .default))
                            Text(vehicleManager.loadError ?? "Unknown error")
                                .font(.system(.subheadline, design: .default))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Button("Retry") {
                                vehicleManager.loadVehicles()
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding()
                    } else {
                        VehicleListView(vehicles: filteredVehicles, vehicleManager: vehicleManager)
                    }
                    
                    if vehicleManager.isLoading && !vehicleManager.vehicles.isEmpty {
                        ProgressView()
                            .padding()
                    }
                }
                .padding(.vertical)
            }
            .onAppear {
                if vehicleManager.vehicles.isEmpty {
                    vehicleManager.loadVehicles()
                }
            }
            .navigationTitle("Vehicles")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
//                        Button(action: { showingNotifications = true }) {
//                            Image(systemName: "bell.fill")
//                                .overlay(
//                                    Group {
//                                        if notificationsViewModel.unreadCount > 0 {
//                                            Text("\(min(notificationsViewModel.unreadCount, 99))")
//                                                .font(.caption2)
//                                                .padding(4)
//                                                .background(Color.red)
//                                                .clipShape(Circle())
//                                                .offset(x: 10, y: -10)
//                                        }
//                                    }
//                                )
//                        }
                        
                        Button(action: { showingAddVehicle = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                NavigationView {
                    FleetManagerProfileView()
                        .environmentObject(dataManager)
                }
            }
            .sheet(isPresented: $showingMessages) {
                NavigationView {
                    ContactView()
                        .environmentObject(dataManager)
                }
            }
            .sheet(isPresented: $showingAddVehicle) {
                VehicleSaveView(vehicleManager: vehicleManager)
            }
//            .sheet(isPresented: $showingNotifications) {
//                NotificationsView()
//            }
        }
    }
    
    func refreshVehicles() async {
        await vehicleManager.loadVehiclesAsync()
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

private struct MaintenanceEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No vehicles found")
                .font(.system(.headline, design: .default))
            Text("Add a new vehicle or try different filters")
                .font(.system(.subheadline, design: .default))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
