import Foundation

enum ServiceType: String, CaseIterable, Codable {
    case routine = "Routine"
    case repair = "Repair"
    case inspection = "Inspection"
    case emergency = "Emergency"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        // Normalize the value to lowercase for matching.
        switch rawValue.lowercased() {
        case "routine":
            self = .routine
        case "repair":
            self = .repair
        case "inspection":
            self = .inspection
        case "emergency":
            self = .emergency
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ServiceType value: \(rawValue)")
        }
    }
}

enum ServiceRequestStatus: String, CaseIterable, Codable {
    case pending = "Pending"
    case assigned = "Assigned"
    case inProgress = "In Progress"
    case completed = "Completed"
    case cancelled = "Cancelled"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue.lowercased() {
        case "pending":
            self = .pending
        case "assigned":
            self = .assigned
        case "in progress":
            self = .inProgress
        case "completed":
            self = .completed
        case "cancelled":
            self = .cancelled
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ServiceRequestStatus value: \(rawValue)")
        }
    }
}

enum ServiceRequestPriority: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue.lowercased() {
        case "low":
            self = .low
        case "medium":
            self = .medium
        case "high":
            self = .high
        case "urgent":
            self = .urgent
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ServiceRequestPriority value: \(rawValue)")
        }
    }
}

enum ExpenseCategory: String, Codable, CaseIterable {
    case parts = "Parts"
    case labor = "Labor"
    case supplies = "Supplies"
    case other = "Other"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue.lowercased() {
        case "parts":
            self = .parts
        case "labor":
            self = .labor
        case "supplies":
            self = .supplies
        case "other":
            self = .other
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ExpenseCategory value: \(rawValue)")
        }
    }
}

struct SafetyCheck: Identifiable, Codable, Equatable {
    let id: UUID
    let item: String
    var isChecked: Bool
    var notes: String
    var requestID: UUID?
    var historyID: UUID?
    
    init(id: UUID = UUID(), item: String, isChecked: Bool = false, notes: String = "", requestID: UUID?, historyID: UUID?) {
        self.id = id
        self.item = item
        self.isChecked = isChecked
        self.notes = notes
        self.requestID = requestID
        self.historyID = historyID
    }
}

struct MaintenanceServiceRequest: Identifiable, Codable, Equatable {
    let id: UUID
    let vehicleId: UUID
    let vehicleName: String
    let serviceType: ServiceType
    let description: String
    let priority: ServiceRequestPriority
    let date: Date
    let dueDate: Date
    var status: ServiceRequestStatus
    var notes: String
    let issueType: String?
    var totalCost: Double
    var startDate: Date?
    var completionDate: Date?
    var personnelID: UUID?
    
    init(vehicleId: UUID, vehicleName: String, serviceType: ServiceType, description: String, priority: ServiceRequestPriority, date: Date, dueDate: Date, status: ServiceRequestStatus, notes: String, issueType: String? = nil) {
        self.id = UUID()
        self.vehicleId = vehicleId
        self.vehicleName = vehicleName
        self.serviceType = serviceType
        self.description = description
        self.priority = priority
        self.date = date
        self.dueDate = dueDate
        self.status = status
        self.notes = notes
        self.issueType = issueType
        self.totalCost = 0.0
    }
    
    static func == (lhs: MaintenanceServiceRequest, rhs: MaintenanceServiceRequest) -> Bool {
        lhs.id == rhs.id &&
        lhs.vehicleId == rhs.vehicleId &&
        lhs.vehicleName == rhs.vehicleName &&
        lhs.serviceType == rhs.serviceType &&
        lhs.description == rhs.description &&
        lhs.priority == rhs.priority &&
        lhs.date == rhs.date &&
        lhs.dueDate == rhs.dueDate &&
        lhs.status == rhs.status &&
        lhs.notes == rhs.notes &&
        lhs.issueType == rhs.issueType &&
        lhs.totalCost == rhs.totalCost &&
        lhs.startDate == rhs.startDate &&
        lhs.completionDate == rhs.completionDate
    }
}

struct Expense: Identifiable, Codable, Equatable {
    let id: UUID
    let description: String
    let amount: Double
    let date: Date
    let category: ExpenseCategory
    var requestID: UUID?
    
    init(description: String, amount: Double, date: Date, category: ExpenseCategory, requestID: UUID) {
        self.id = UUID()
        self.description = description
        self.amount = amount
        self.date = date
        self.category = category
        self.requestID = requestID
    }
}

struct ServiceHistory: Identifiable, Codable {
    let id: UUID
    let vehicleId: UUID
    let vehicleName: String
    let serviceType: ServiceType
    let description: String
    let date: Date
    let completionDate: Date
    let notes: String
    let safetyChecks: [SafetyCheck]
}

enum InspectionType: String, Codable {
    case preTrip = "Pre-Trip"
    case postTrip = "Post-Trip"
}

struct InspectionIssue: Identifiable, Codable {
    let id: UUID
    let description: String
    let severity: IssueSeverity
}

enum IssueSeverity: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}

struct InspectionRequest: Identifiable, Codable {
    let id: UUID
    let vehicleId: UUID
    let vehicleName: String
    let driverId: UUID
    let driverName: String
    let type: InspectionType
    let description: String
    let date: Date
    var status: ServiceRequestStatus
    let issues: [InspectionIssue]
    var notes: String
}
