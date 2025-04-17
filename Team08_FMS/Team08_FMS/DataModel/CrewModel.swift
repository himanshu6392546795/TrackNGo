import Foundation
import SwiftUI

enum Status: String, Codable, Identifiable {
    case available = "available"
    case busy = "busy"
    case offDuty = "offDuty"

    var color: Color {
        switch self {
        case .available: return .green
        case .busy: return .orange
        case .offDuty: return .red
        }
    }

    var backgroundColor: Color {
        switch self {
        case .available: return .green.opacity(0.2)
        case .busy: return .orange.opacity(0.2)
        case .offDuty: return .gray.opacity(0.2)
        }
    }
    
    var id: String { self.rawValue }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Status(rawValue: rawValue) ?? .available
    }
}

enum Specialization: String, CaseIterable, Codable, Identifiable {
    case engineRepair = "engineRepair"
    case tireMaintenance = "tireMaintenance"
    case electricalSystems = "electricalSystems"
    case diagnostics = "diagnostics"
    case generalMaintenance = "generalMaintenance"
    
    var id: String { self.rawValue }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Specialization(rawValue: rawValue) ?? .generalMaintenance
    }
}

enum Certification: String, CaseIterable, Codable, Identifiable {
    case aseCertified = "aseCertified"
    case dieselMechanic = "dieselMechanic"
    case hvacSpecialist = "hvacSpecialist"
    case electricalSystemsCertified = "electricalSystemsCertified"
    case heavyEquipmentTechnician = "heavyEquipmentTechnician"
    
    var id: String { self.rawValue }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Certification(rawValue: rawValue) ?? .dieselMechanic
    }
}

struct FleetManager: Identifiable, Codable {
    var userID: UUID?
    let id: UUID
    var name: String
    var profileImage: String?
    var email: String
    var phoneNumber: Int
    var createdAt: Date?
    var updatedAt: Date?
}

struct Driver: Identifiable, Codable {
    var userID: UUID?
    var id: UUID = UUID()
    var name: String
    var profileImage: String?
    var email: String
    var phoneNumber: Int
    var driverLicenseNumber: String
    var driverLicenseExpiry: Date?
    var assignedVehicleID: UUID?
    var address: String?
    var salary: Double
    var yearsOfExperience: Int
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool = false
    var status: Status
}

struct MaintenancePersonnel: Identifiable, Codable {
    var userID: UUID?
    var id: UUID = UUID()
    var name: String
    var profileImage: String?
    var email: String
    var phoneNumber: Int
    var certifications: Certification
    var yearsOfExperience: Int
    var speciality: Specialization
    var salary: Double
    var address: String?
    var createdAt: Date?
    var updatedAt: Date?
    var isDeleted: Bool = false
    var status: Status
}

protocol CrewMemberProtocol {
    var id: UUID { get }
    var name: String { get set }
    var avatar: String { get set } // Renamed from profileImage
    var email: String { get }
    var phoneNumber: Int { get }
    var salary: Double { get }
    var status: Status { get set }
}

extension Driver: CrewMemberProtocol {
    var avatar: String {
        get { profileImage ?? "" } // Return a default value if nil
        set { profileImage = newValue }
    }
}

extension MaintenancePersonnel: CrewMemberProtocol {
    var avatar: String {
        get { profileImage ?? "" }
        set { profileImage = newValue }
    }
}
