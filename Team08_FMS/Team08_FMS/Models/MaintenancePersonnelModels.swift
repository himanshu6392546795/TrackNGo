import Foundation

// Local data models for maintenance personnel
struct MaintenancePersonnelServiceHistory: Identifiable, Codable {
    let id: UUID
    let vehicleId: UUID
    let vehicleName: String
    let serviceType: ServiceType
    let description: String
    let date: Date
    let completionDate: Date
    let notes: String
}

struct MaintenancePersonnelRoutineSchedule: Identifiable, Codable {
    let id: UUID
    let vehicleId: UUID
    let vehicleName: String
    let serviceType: ServiceType
    let interval: Int // in days
    let lastServiceDate: Date
    let nextServiceDate: Date
    let notes: String
}

class MaintenancePersonnelDataStore: ObservableObject {
    @Published var serviceRequests: [MaintenanceServiceRequest] = []
    @Published var filteredRequests: [MaintenanceServiceRequest] = []
    @Published var serviceHistory: [MaintenancePersonnelServiceHistory] = []
    @Published var routineSchedules: [MaintenancePersonnelRoutineSchedule] = []
    @Published var inspectionRequests: [InspectionRequest] = []  // Assuming these remain local or handled separately
    @Published var totalExpenses: Double = 0
    private var userID: UUID?
    
    init() {
        // Load data from Supabase when the data store is created
        Task {
            await loadData()
            await calculateExpenses()
        }
    }
    
    // MARK: - Data Loading
    
    func calculateExpenses() async {
        do {
            let expenses = try await SupabaseDataController.shared.fetchAllExpense()
            print("Fetched expenses: \(expenses)")
            print("Expense count: \(expenses.count)")
            
            // Log each expense's amount
            expenses.forEach { expense in
                print("Expense amount: \(expense.amount)")
            }
            
            let total = expenses.reduce(0.0) { partialResult, expense in
                partialResult + expense.amount
            }
            
            print("Calculated total: \(total)")
            
            await MainActor.run {
                self.totalExpenses = total
            }
            
        } catch {
            print("Cannot fetch total expenses: \(error.localizedDescription)")
        }
    }

    
    func loadData() async {
        do {
            // Fetch data from Supabase via the shared data controller
            let fetchedServiceHistory = try await SupabaseDataController.shared.fetchServiceHistory()
            let fetchedRoutineSchedules = try await SupabaseDataController.shared.fetchRoutineSchedule()
            let fetchedServiceRequests = try await SupabaseDataController.shared.fetchServiceRequests()
            
            await MainActor.run {
                self.serviceHistory = fetchedServiceHistory
                self.routineSchedules = fetchedRoutineSchedules
                self.serviceRequests = fetchedServiceRequests
            }
        } catch {
            print("Error loading data: \(error)")
        }
    }
    
    // MARK: - Service History Methods
    
    func addToServiceHistory(from request: MaintenanceServiceRequest) async {
        do {
            // Generate a new ID for the history record.
            let newHistoryID = UUID()
            
            // Fetch any safety checks that were added for this service request.
            let safetyChecksFromRequest = try await fetchSafetyChecks(requestID: request.id)
            var safetyCheckIDs: [UUID] = []
            
            // Update each safety check with the new historyID and update them in Supabase.
            for var check in safetyChecksFromRequest {
                check.historyID = newHistoryID
                try await SupabaseDataController.shared.insertSafetyCheck(check: check)
                safetyCheckIDs.append(check.id)
            }
            
            // Create the new history record including the safety check IDs.
            let newHistory = MaintenancePersonnelServiceHistory(
                id: newHistoryID,
                vehicleId: request.vehicleId,
                vehicleName: request.vehicleName,
                serviceType: request.serviceType,
                description: request.description,
                date: request.date,
                completionDate: Date(),  // set to now
                notes: request.notes
            )
            
            // Insert the new service history record.
            try await SupabaseDataController.shared.insertServiceHistory(history: newHistory)
            // Refresh the local service history data after insertion.
            let history = try await SupabaseDataController.shared.fetchServiceHistory()
            await MainActor.run {
                self.serviceHistory = history
            }
        } catch {
            print("Error adding service history: \(error)")
        }
    }
    
    func addServiceHistory(_ history: MaintenancePersonnelServiceHistory) async {
        do {
            try await SupabaseDataController.shared.insertServiceHistory(history: history)
            serviceHistory = try await SupabaseDataController.shared.fetchServiceHistory()
        } catch {
            print("Error inserting service history: \(error)")
        }
    }
    
    // MARK: - Routine Schedule Methods
    
    func addRoutineSchedule(_ schedule: MaintenancePersonnelRoutineSchedule) async {
        do {
            try await SupabaseDataController.shared.insertRoutineSchedule(schedule: schedule)
            routineSchedules = try await SupabaseDataController.shared.fetchRoutineSchedule()
        } catch {
            print("Error inserting routine schedule: \(error)")
        }
    }
    
    func updateRoutineSchedule(_ schedule: MaintenancePersonnelRoutineSchedule) async {
        do {
            try await SupabaseDataController.shared.insertRoutineSchedule(schedule: schedule)
            routineSchedules = try await SupabaseDataController.shared.fetchRoutineSchedule()
        } catch {
            print("Error updating routine schedule: \(error)")
        }
    }
    
    func deleteRoutineSchedule(_ schedule: MaintenancePersonnelRoutineSchedule) async {
        do {
            try await SupabaseDataController.shared.deleteRoutineSchedule(schedule: schedule)
            routineSchedules = try await SupabaseDataController.shared.fetchRoutineSchedule()
        } catch {
            print("Error deleting routine schedule: \(error)")
        }
    }
    
    // MARK: - Service Request Methods
    
    func addServiceRequest(_ request: MaintenanceServiceRequest) async {
        do {
            try await SupabaseDataController.shared.insertServiceRequest(request: request)
            serviceRequests = try await SupabaseDataController.shared.fetchServiceRequests()
        } catch {
            print("Error inserting service request: \(error)")
        }
    }
    
    func updateServiceRequestStatus(_ request: MaintenanceServiceRequest, newStatus: ServiceRequestStatus, userID: UUID?) async {
        if let index = serviceRequests.firstIndex(where: { $0.id == request.id }) {
            var updatedRequest = request
            updatedRequest.status = newStatus
            
            // Handle specific status changes (e.g., start date for "In Progress" and completion date for "Completed")
            switch newStatus {
            case .inProgress:
                updatedRequest.startDate = Date()
            case .completed:
                await SupabaseDataController.shared.updateVehicleStatus(newStatus: .available, vehicleID: request.vehicleId)
                updatedRequest.completionDate = Date()
            default:
                break
            }
            
            do {
                if let userID = userID {
                    let updateSuccess = try await SupabaseDataController.shared.assignServiceToPersonnel(serviceRequestId: updatedRequest.id, userID: userID)
                    if updateSuccess {
                        // Capture a copy of updatedRequest using a capture list.
                        await MainActor.run { [safeUpdatedRequest = updatedRequest] in
                            serviceRequests[index] = safeUpdatedRequest
                            print("Service request status updated successfully.")
                        }
                    } else {
                        print("Failed to update service request status in Supabase.")
                    }
                } else {
                    let updateSuccess = try await SupabaseDataController.shared.updateServiceRequestStatus(
                        serviceRequestId: updatedRequest.id,
                        newStatus: newStatus
                    )
                    if updateSuccess {
                        // Capture a copy of updatedRequest using a capture list.
                        await MainActor.run { [safeUpdatedRequest = updatedRequest] in
                            serviceRequests[index] = safeUpdatedRequest
                            print("Service request status updated successfully.")
                        }
                    } else {
                        print("Failed to update service request status in Supabase.")
                    }
                }
            } catch {
                print("Error updating service request status: \(error)")
            }
        }
    }

    // MARK: - Expense Methods
    
    func addExpense(to request: MaintenanceServiceRequest, expense: Expense) async {
        do {
            try await SupabaseDataController.shared.insertExpense(expense: expense)
            let updatedRequests = try await SupabaseDataController.shared.fetchServiceRequests()
            await MainActor.run {
                serviceRequests = updatedRequests
            }
        } catch {
            print("Error inserting expense: \(error)")
        }
    }
    
    // MARK: - Safety Check Methods
    
    func updateSafetyChecks(for request: MaintenanceServiceRequest, checks: [SafetyCheck]) async {
        do {
            // Insert (or update) all provided safety checks.
            // In a complete implementation you might also handle deletions.
            for check in checks {
                try await SupabaseDataController.shared.insertSafetyCheck(check: check)
            }
            serviceRequests = try await SupabaseDataController.shared.fetchServiceRequests()
        } catch {
            print("Error updating safety checks: \(error)")
        }
    }
    
    // MARK: - Fetch Safety Checks
        
    func fetchSafetyChecks(requestID: UUID) async throws -> [SafetyCheck] {
        // This method should call your SupabaseDataController method to fetch safety checks by requestID.
        let checks = try await SupabaseDataController.shared.fetchSafetyChecks(requestId: requestID)
        return checks
    }
    
    func fetchSafetyChecks(historyID: UUID) async throws -> [SafetyCheck] {
        // This method should call your SupabaseDataController method to fetch safety checks by requestID.
        let checks = try await SupabaseDataController.shared.fetchSafetyChecks(historyId: historyID)
        return checks
    }
    
    func fetchExpenses(for requestID: UUID) async throws -> [Expense] {
        // Call the Supabase data controller to fetch expenses for the given service request ID.
        let expenses = try await SupabaseDataController.shared.fetchExpenses(for: requestID)
        return expenses
    }
}
