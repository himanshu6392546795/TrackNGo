//
//  ContentView.swift
//  Team08_FMS
//
//  Created by Snehil on 17/03/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: SupabaseDataController
    @StateObject private var notificationsViewModel = NotificationsViewModel()
    @State private var showingNotifications = false

    var body: some View {
        ZStack {
            VStack {
                if !auth.isAuthenticated {
                    RoleSelectionView()
                } else {
                    if let userID = auth.userID, auth.isGenPass {
                        ResetGeneratedPasswordView(userID: userID)
                    } else {
                        switch auth.userRole {
                        case "fleet_manager":
                            FleetManagerTabView()
                        case "driver":
                            if let userID = auth.userID {
                                DriverTabView(driverId: userID)
                            }
                        case "maintenance_personnel":
                            MaintenancePersonnelDashboardView()
                        default:
                            RoleSelectionView()
                        }
                    }
                }
            }
            .animation(.easeInOut, value: auth.isAuthenticated)
        }
        .environmentObject(notificationsViewModel)
        .sheet(isPresented: $showingNotifications) {
            AlertsView()
                .environmentObject(notificationsViewModel)
        }
        .task {
            await auth.autoLogin()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SupabaseDataController.shared)
        .environmentObject(VehicleManager.shared)
        .environmentObject(CrewDataController.shared)
}
