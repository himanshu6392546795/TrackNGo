//import Foundation
//import SwiftUI
//
//enum Status: String {
//    case available = "Available"
//    case busy = "Busy"
//    case offDuty = "Off Duty"
//
//    var color: Color {
//        switch self {
//        case .available: return .green
//        case .busy: return .orange
//        case .offDuty: return .gray
//        }
//    }
//
//    var backgroundColor: Color {
//        switch self {
//        case .available: return .green.opacity(0.2)
//        case .busy: return .orange.opacity(0.2)
//        case .offDuty: return .gray.opacity(0.2)
//        }
//    }
//}
//
//enum Specialization: String, CaseIterable {
//    case engineRepair = "Engine Repair"
//    case tireMaintenance = "Tire Maintenance"
//    case electricalSystems = "Electrical Systems"
//    case diagnostics = "Diagnostics"
//    case generalMaintenance = "General Maintenance"
//}
//
//enum Certification: String, CaseIterable {
//    case aseCertified = "ASE Certified"
//    case dieselMechanic = "Diesel Mechanic"
//    case hvacSpecialist = "HVAC Specialist"
//    case electricalSystemsCertified = "Electrical Systems Certified"
//    case heavyEquipmentTechnician = "Heavy Equipment Technician"
//}
//
//struct FleetManager: Identifiable {
//    let id: UUID
//    var name: String
//    var profileImage: String
//    var email: String
//    var phoneNumber: String
//    var createdAt: Date
//    var updatedAt: Date?
//}
//
//struct Driver: Identifiable {
//    let id: UUID = UUID()
//    var name: String
//    var profileImage: String?
//    var email: String
//    var phoneNumber: String
//    var driverLicenseNumber: String
//    var driverLicenseExpiry: Date
//    var assignedVehicleID: UUID?
//    var driverRating: Double?
//    var address: String?
//    var createdAt: Date
//    var updatedAt: Date?
//    var isDeleted: Bool = false
//    var status: Status
//}
//
//struct MaintenancePersonnel: Identifiable {
//    let id: UUID = UUID()
//    var name: String
//    var profileImage: String
//    var email: String
//    var phoneNumber: String
//    var certifications: Certification
//    var yearsOfExperience: Int
//    var specialty: Specialization
//    var address: String?
//    var createdAt: Date
//    var updatedAt: Date?
//    var isDeleted: Bool = false
//    var status: Status
//    var salary: Double
//}
//
//
//
////struct FleetManager {
////    let employeeID: UUID
////    var name: String
////    var profileImage: String
////    var email: String
////    var phoneNumber: String
////    var department: String
////    var createdAt: Date
////    var updatedAt: Date
////    let avatar:String?
////}
////
////struct Driver {
////    let employeeID: UUID
////    var name: String
////    var profileImage: String
////    var email: String
////    var phoneNumber: String
////    var driverLicenseNumber: String
////    var driverLicenseExpiry: Date
////    var assignedVehicleID: String?
////    var driverRating: Double?
////    var address: String?             
////    var createdAt: Date
////    var updatedAt: Date?
////    let avatar:String?
////}
////
////struct MaintenancePersonnel {
////    let employeeID: UUID = UUID()
////    var name: String
////    var profileImage: String
////    var email: String
////    var phoneNumber: String
////    var certifications: [String]?
////    var yearsOfExperience: Int
////    var specialty: String
////    var address: String?              
////    var createdAt: Date = Date()
////    var updatedAt: Date?
////    let avatar:String?
////}




//struct FleetManager {
//    let employeeID: UUID
//    var name: String
//    var profileImage: String
//    var email: String
//    var phoneNumber: String
//    var department: String
//    var createdAt: Date
//    var updatedAt: Date
//    let avatar:String?
//}
//
//struct Driver {
//    let employeeID: UUID
//    var name: String
//    var profileImage: String
//    var email: String
//    var phoneNumber: String
//    var driverLicenseNumber: String
//    var driverLicenseExpiry: Date
//    var assignedVehicleID: String?
//    var driverRating: Double?
//    var address: String?
//    var createdAt: Date
//    var updatedAt: Date?
//    let avatar:String?
//}
//
//struct MaintenancePersonnel {
//    let employeeID: UUID = UUID()
//    var name: String
//    var profileImage: String
//    var email: String
//    var phoneNumber: String
//    var certifications: [String]?
//    var yearsOfExperience: Int
//    var specialty: String
//    var address: String?
//    var createdAt: Date = Date()
//    var updatedAt: Date?
//    let avatar:String?
//}
