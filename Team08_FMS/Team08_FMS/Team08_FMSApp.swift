//
//  Team08_FMSApp.swift
//  Team08_FMS
//
//  Created by Snehil on 17/03/25.
//

import SwiftUI

@main
struct Team08_FMSApp: App {
    @StateObject private var supabaseDataController = SupabaseDataController.shared
    @StateObject private var vehicleManager = VehicleManager.shared
    @StateObject private var crewDataController = CrewDataController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(supabaseDataController)
                .environmentObject(vehicleManager)
                .environmentObject(crewDataController)
        }
    }
}
