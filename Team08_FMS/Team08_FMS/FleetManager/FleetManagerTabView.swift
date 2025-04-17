//
//  FleetManagerHomeScreen.swift
//  Team08_FMS
//
//  Created by Snehil on 18/03/25.
//

import SwiftUI

struct FleetManagerTabView: View {
    @StateObject private var vehicleManager = VehicleManager()
    @StateObject private var dataManager = CrewDataController.shared
    @StateObject private var notificationsViewModel = NotificationsViewModel()
    @State private var refreshTask: Task<Void, Never>?
    @State private var showingNotifications = false

    var body: some View {
        TabView {
            FleetManagerDashboardTabView()
                .environmentObject(dataManager)
                .environmentObject(vehicleManager)
                .environmentObject(notificationsViewModel)
                .tabItem {
                    Image(systemName: "gauge")
                    Text("Dashboard")
                }
            
            FleetTripsView()
                .environmentObject(notificationsViewModel)
                .tabItem {
                    Image(systemName: "shippingbox.fill")
                    Text("Trips")
                }
            
            VehiclesView()
                .environmentObject(dataManager)
                .environmentObject(vehicleManager)
                .environmentObject(notificationsViewModel)
                .tabItem {
                    Image(systemName: "car.fill")
                    Text("Vehicles")
                }
            
            FleetCrewManagementView()
                .environmentObject(dataManager)
                .environmentObject(vehicleManager)
                .environmentObject(notificationsViewModel)
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Crew")
                }
        }
        .task {
            // Initial load
            print("🔄 FleetManagerTabView: Loading initial data...")
            vehicleManager.loadVehicles()
            CrewDataController.shared.update()
            listenForGeofenceEvents()
            await refreshData()
        }
        .onDisappear {
            refreshTask?.cancel()
        }
        .sheet(isPresented: $showingNotifications) {
            AlertsView()
                .environmentObject(notificationsViewModel)
        }
    }
    
    private func refreshData() async {
        await TripDataController.shared.refreshAllTrips()
        await SupabaseDataController.shared.fetchGeofenceEvents()
        await dataManager.checkAndUpdateDriverTripStatus()
    }
    
    func listenForGeofenceEvents() {
        SupabaseDataController.shared.subscribeToGeofenceEvents()
    }
}

#Preview {
    FleetManagerTabView()
        .environmentObject(SupabaseDataController.shared)
}
