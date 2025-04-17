//
//  AppDataModel.swift
//  Team08_FMS
//
//  Created by Swarn Singh Chauhan on 19/03/25.
//

import Foundation
import CoreLocation

// MARK: - App Data Model
struct AppDataModel {
    // Users of the fleet management system
    //var users: [User] = []
    var drivers:[Driver] = []
    var maintenancePersonnel:[MaintenancePersonnel] = []
    
    // Vehicles in the fleet
    var vehicles: [Vehicle] = []
    
    // Trips or assignments
    var trips: [Trip] = []
    
    // Maintenance records for vehicles
    var maintenanceRecords: [MaintenanceRecord] = []
    
    // Notifications for various events
    var notifications: [NotificationItem] = []
    
    // Global settings for the app
    var settings: AppSettings = AppSettings(defaultOperatingHours: "08:00 - 18:00", supportContact: "support@example.com")
}

// Codable version of AppData for persistence
struct AppData: Codable {
    // Vehicles in the fleet
    var vehicles: [Vehicle] = []
    
    // Trips or assignments (using SupabaseTrip which is Codable)
    var trips: [SupabaseTrip] = []
    
    // Maintenance records for vehicles
    var maintenanceRecords: [MaintenanceRecord] = []
    
    // Notifications for various events
    var notifications: [NotificationItem] = []
    
    // Global settings for the app
    var settings: AppSettings = AppSettings(defaultOperatingHours: "08:00 - 18:00", supportContact: "support@example.com")
    
    // Add initializer to convert from AppDataModel
    init(from model: AppDataModel) {
        self.vehicles = model.vehicles
        // Convert Trip to SupabaseTrip if needed
        self.trips = []  // This would need proper conversion logic
        self.maintenanceRecords = model.maintenanceRecords
        self.notifications = model.notifications
        self.settings = model.settings
    }
    
    // Default initializer
    init() {
        self.vehicles = []
        self.trips = []
        self.maintenanceRecords = []
        self.notifications = []
        self.settings = AppSettings(defaultOperatingHours: "08:00 - 18:00", supportContact: "support@example.com")
    }
}

