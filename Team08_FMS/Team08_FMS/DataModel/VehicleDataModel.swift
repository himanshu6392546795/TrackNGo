//
//  VehicleDataModel.swift
//  Team08_FMS
//
//  Created by Snehil on 20/03/25.
//

import Foundation

enum VehicleStatus: String, Codable {
    case available = "Available"
    case inService = "In Service"
    case underMaintenance = "Under Maintenance"
    case decommissioned = "Decommissioned"

    static let allValues: [VehicleStatus] = [
        .available,
        .inService,
        .underMaintenance,
        .decommissioned
    ]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = VehicleStatus(rawValue: rawValue) ?? .available
    }
}

enum VehicleType: String, Codable, CaseIterable {
    case truck = "Truck"
    case van = "Van"
    case car = "Car"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = VehicleType(rawValue: rawValue) ?? .truck
    }
}

enum BodyType: String, Codable, CaseIterable {
    case pickup = "Pickup"
    case cargo = "Cargo"
    case sedan = "Sedan"
    case suv = "SUV"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = BodyType(rawValue: rawValue) ?? .pickup
    }
}

struct VehicleDocuments: Codable, Equatable {
    var pollutionCertificate: Data?
    var rc: Data?
    var insurance: Data?
    
    enum CodingKeys: String, CodingKey {
        case pollutionCertificate = "pollution_certificate"
        case rc
        case insurance
    }
}

struct VehiclePayload: Codable {
    let id: UUID
    let name: String
    let year: Int
    let make: String
    let model: String
    let vin: String
    let license_plate: String
    let vehicle_type: VehicleType
    let color: String
    let body_type: BodyType
    let body_subtype: String
    let msrp: Double
    let pollution_expiry: String
    let insurance_expiry: String
    let status: VehicleStatus
    let driver_id: UUID?
    let lastMaintenanceDistance: Int
    let totalDistance: Int
}

struct Vehicle: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var year: Int
    var make: String
    var model: String
    var vin: String
    var licensePlate: String
    var vehicleType: VehicleType
    var color: String
    var bodyType: BodyType
    var bodySubtype: String
    var msrp: Double
    var pollutionExpiry: Date
    var insuranceExpiry: Date
    var status: VehicleStatus
    var driverId: UUID?
    var lastMaintenanceDistance: Int = 0
    var totalDistance: Int = 0
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case year
        case make
        case model
        case vin
        case licensePlate = "license_plate"
        case vehicleType = "vehicle_type"
        case color
        case bodyType = "body_type"
        case bodySubtype = "body_subtype"
        case msrp
        case pollutionExpiry = "pollution_expiry"
        case insuranceExpiry = "insurance_expiry"
        case status
        case driverId = "driver_id"
        case lastMaintenanceDistance
        case totalDistance
    }
    
    static func == (lhs: Vehicle, rhs: Vehicle) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.year == rhs.year &&
               lhs.make == rhs.make &&
               lhs.model == rhs.model &&
               lhs.vin == rhs.vin &&
               lhs.licensePlate == rhs.licensePlate &&
               lhs.vehicleType == rhs.vehicleType &&
               lhs.color == rhs.color &&
               lhs.bodyType == rhs.bodyType &&
               lhs.bodySubtype == rhs.bodySubtype &&
               lhs.msrp == rhs.msrp &&
               lhs.pollutionExpiry == rhs.pollutionExpiry &&
               lhs.insuranceExpiry == rhs.insuranceExpiry &&
               lhs.status == rhs.status &&
               lhs.driverId == rhs.driverId
    }
    
    static func mockVehicle(licensePlate: String = "Unknown") -> Vehicle {
        Vehicle(
            name: "Mock Vehicle",
            year: 2024,
            make: "Generic",
            model: "Model",
            vin: "12345678901234567",
            licensePlate: licensePlate,
            vehicleType: .truck,
            color: "White",
            bodyType: .cargo,
            bodySubtype: "Standard",
            msrp: 50000.0,
            pollutionExpiry: Date().addingTimeInterval(365*24*60*60),
            insuranceExpiry: Date().addingTimeInterval(365*24*60*60),
            status: .available
        )
    }
}

// MARK: - Supporting Data Models
struct Route: Codable {
    var startLocation: String
    var endLocation: String
    var waypoints: [String]?
}

enum MaintenanceStatus: String, Codable {
    case notScheduled = "Not Scheduled"
    case scheduled = "Scheduled"
    case inProgress = "In Progress"
    case completed = "Completed"
}

struct MaintenanceRecord: Identifiable, Codable {
    var id: UUID
    var vehicleID: UUID
    var personnelID: UUID
    var date: Date
    var description: String
    var status: MaintenanceStatus
    var expenses: [MaintenanceExpense]
    var notes: String?
}

struct MaintenanceExpense: Identifiable, Codable {
    let id: UUID
    let description: String
    let amount: Double
    let date: Date
}

struct AppSettings: Codable {
    var defaultOperatingHours: String
    var supportContact: String
}

struct ServiceRequest: Identifiable {
    let id = UUID()
    let vehicleId: String
    let vehicleName: String
    let issueType: String
    let description: String
    let priority: String
    let date: Date
    let status: String
}
