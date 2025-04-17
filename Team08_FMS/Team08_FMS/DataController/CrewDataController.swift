import Foundation
import SwiftUI

// MARK: - CrewType Enum
enum CrewType {
    case drivers
    case maintenancePersonnel
}

// MARK: - Data Controller
class CrewDataController: ObservableObject {
    
    static let shared = CrewDataController()
    
    
    @Published var fleetManagers: [FleetManager] = []
    @Published var drivers: [Driver] = []
    @Published var maintenancePersonnel: [MaintenancePersonnel] = []
    @Published var trips: [Trip] = []
    
    private init() {
        loadFleetManagers()
    }
    
    // MARK: - Loading Sample Data
    func update() {
        Task {
            do {
                let driver = try await SupabaseDataController.shared.fetchDrivers()
                let personnel = try await SupabaseDataController.shared.fetchMaintenancePersonnel()
                await MainActor.run {
                    drivers = driver
                    maintenancePersonnel = personnel
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    private func loadFleetManagers() {
        fleetManagers = [
            FleetManager(
                userID: UUID(),
                id: UUID(),
                name: "Alice Johnson",
                profileImage: "fleetManager1",
                email: "alice.johnson@example.com",
                phoneNumber: 555_000_1111,
                createdAt: Date(),
                updatedAt: Date()
            ),
            FleetManager(
                userID: UUID(),
                id: UUID(),
                name: "Bob Williams",
                profileImage: "fleetManager2",
                email: "bob.williams@example.com",
                phoneNumber: 555_000_2222,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
    }
    
    private func loadDrivers() {
        drivers = [
            Driver(
                userID: UUID(),
                name: "Charlie Davis",
                profileImage: "DR", // or "driver1"
                email: "charlie.davis@example.com",
                phoneNumber: 555_111_2222,
                driverLicenseNumber: "DL123456",
                driverLicenseExpiry: Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date(),
                assignedVehicleID: nil,
                address: "123 Main Street",
                salary: 5000.0,
                yearsOfExperience: 5,
                createdAt: Date(),
                updatedAt: Date(),
                isDeleted: false,
                status: .available
            ),
            Driver(
                userID: UUID(),
                name: "Diana Prince",
                profileImage: "DI", // or "driver2"
                email: "diana.prince@example.com",
                phoneNumber: 555_333_4444,
                driverLicenseNumber: "DL654321",
                driverLicenseExpiry: Calendar.current.date(byAdding: .year, value: 3, to: Date()) ?? Date(),
                assignedVehicleID: nil,
                address: "456 Elm Street",
                salary: 5500.0,
                yearsOfExperience: 7,
                createdAt: Date(),
                updatedAt: Date(),
                isDeleted: false,
                status: .available
            )
        ]
    }
    
    private func loadMaintenancePersonnel() {
        maintenancePersonnel = [
            MaintenancePersonnel(
                userID: UUID(),
                name: "Edward King",
                profileImage: "EK", // or "maintenance1"
                email: "edward.king@example.com",
                phoneNumber: 555_555_6666,
                certifications: .aseCertified,
                yearsOfExperience: 6,
                speciality: .engineRepair,
                salary: 4000.0,
                address: "789 Oak Avenue",
                createdAt: Date(),
                updatedAt: Date(),
                isDeleted: false,
                status: .available
            ),
            MaintenancePersonnel(
                userID: UUID(),
                name: "Fiona Queen",
                profileImage: "FQ", // or "maintenance2"
                email: "fiona.queen@example.com",
                phoneNumber: 555_777_8888,
                certifications: .heavyEquipmentTechnician,
                yearsOfExperience: 4,
                speciality: .generalMaintenance,
                salary: 3800.0,
                address: "321 Pine Road",
                createdAt: Date(),
                updatedAt: Date(),
                isDeleted: false,
                status: .available
            )
        ]
    }
    
    // MARK: - Crew Operations
    
    // Add a new driver
    func addDriver(_ driver: Driver) {
        drivers.append(driver)
    }
    
    // Add a new maintenance personnel
    func addMaintenancePersonnel(_ personnel: MaintenancePersonnel) {
        maintenancePersonnel.append(personnel)
    }
    
    // Calculate the total number of pages for a given crew type based on the number of items per page.
    func calculateTotalPages(for crewType: CrewType, itemsPerPage: Int) -> Int {
        let count = crewType == .drivers ? drivers.count : maintenancePersonnel.count
        return max(1, Int(ceil(Double(count) / Double(itemsPerPage))))
    }
    
    // Get paged results for the given crew type.
    // Returns an array of CrewMemberProtocol
    func getPagedCrew(for crewType: CrewType, page: Int, itemsPerPage: Int) -> [CrewMemberProtocol] {
        let allCrew: [CrewMemberProtocol] = crewType == .drivers ? drivers : maintenancePersonnel
        let startIndex = (page - 1) * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, allCrew.count)
        
        guard startIndex < allCrew.count else {
            return []
        }
        
        return Array(allCrew[startIndex..<endIndex])
    }
    
    // MARK: - Update Operations
    
    // Update status for a driver with the given UUID
    func updateDriverStatus(_ id: UUID, status: Status) async throws {
        // Update local state
        if let index = drivers.firstIndex(where: { $0.id == id }) {
            drivers[index].status = status
        }
        
        // Update in Supabase
        await SupabaseDataController.shared.updateDriverStatus(newStatus: status, userID: nil, id: id)
    }
    
    // Get cached trips or fetch if needed
    private func getTrips() async -> [Trip] {
        return TripDataController.shared.getAllTrips()
    }
    
    // Check and update driver trip status
    func checkAndUpdateDriverTripStatus() async {
        let trips = await getTrips()
        var updatedDrivers: [(UUID, Status)] = []
        
        // Get all drivers in trips
        let driversInTrips = trips
            .filter { $0.status == .inProgress }
            .compactMap { $0.driverId }
        
        // Collect all needed updates
        for driver in drivers {
            let shouldBeBusy = driversInTrips.contains(driver.userID!)
            let needsUpdate = (shouldBeBusy && driver.status != .busy) ||
                            (!shouldBeBusy && driver.status == .busy)
            
            if needsUpdate {
                updatedDrivers.append((driver.id, shouldBeBusy ? .busy : .available))
            }
        }
        
        // Batch update all drivers at once
        if !updatedDrivers.isEmpty {
            do {
                // Update Supabase
                for (id, status) in updatedDrivers {
                    await SupabaseDataController.shared.updateDriverStatus(newStatus: status, userID: nil, id: id)
                }
                
                // Update local state in one UI refresh
                let driversToUpdate = updatedDrivers
                await MainActor.run {
                    for (id, status) in driversToUpdate {
                        if let index = drivers.firstIndex(where: { $0.id == id }) {
                            drivers[index].status = status
                        }
                    }
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    // Check and update vehicle status based on trips
    func checkAndUpdateVehicleStatus(vehicleManager: VehicleManager) async {
        let trips = await getTrips()
        var updatedVehicles: [(UUID, VehicleStatus)] = []
        
        // Get vehicles in active trips
        let activeTrips = trips.filter { $0.status == .pending || $0.status == .assigned || $0.status == .inProgress }
        let vehiclesInTrips = Set(activeTrips.map { $0.vehicleDetails.id })
        
        // Collect all needed updates
        for vehicle in vehicleManager.vehicles {
            if vehicle.status != .underMaintenance {
                let shouldBeInService = vehiclesInTrips.contains(vehicle.id)
                let needsUpdate = (shouldBeInService && vehicle.status != .inService) ||
                                (!shouldBeInService && vehicle.status == .inService)
                
                if needsUpdate {
                    updatedVehicles.append((vehicle.id, shouldBeInService ? .inService : .available))
                }
            }
        }
        
        // Batch update all vehicles at once
        if !updatedVehicles.isEmpty {
            // Update Supabase
            for (id, status) in updatedVehicles {
                await SupabaseDataController.shared.updateVehicleStatus(
                    newStatus: status,
                    vehicleID: id
                )
            }
            
            // Update local state in one UI refresh
            let vehiclesToUpdate = updatedVehicles
            await MainActor.run {
                for (id, status) in vehiclesToUpdate {
                    if let index = vehicleManager.vehicles.firstIndex(where: { $0.id == id }) {
                        vehicleManager.vehicles[index].status = status
                    }
                }
                vehicleManager.objectWillChange.send()
            }
        }
    }
    
    // Update status for maintenance personnel with the given UUID
    func updateMaintenancePersonnelStatus(_ id: UUID, status: Status) {
        if let index = maintenancePersonnel.firstIndex(where: { $0.id == id }) {
            maintenancePersonnel[index].status = status
        }
    }
    
    // Update a driver's name and recalculate its avatar (using the first two uppercase letters of the name)
    func updateDriver(_ id: UUID, name: String) {
        if let index = drivers.firstIndex(where: { $0.id == id }) {
            drivers[index].name = name
            drivers[index].profileImage = String(name.prefix(2).uppercased())
            drivers[index].updatedAt = Date()
        }
    }
    
    // Update maintenance personnel's name and recalculate its avatar
    func updateMaintenancePersonnel(_ id: UUID, name: String) {
        if let index = maintenancePersonnel.firstIndex(where: { $0.id == id }) {
            maintenancePersonnel[index].name = name
            maintenancePersonnel[index].profileImage = String(name.prefix(2).uppercased())
            maintenancePersonnel[index].updatedAt = Date()
        }
    }
    
    // Delete a driver by UUID
    func deleteDriver(_ id: UUID) {
        drivers.removeAll { $0.id == id }
    }
    
    // Delete maintenance personnel by UUID
    func deleteMaintenancePersonnel(_ id: UUID) {
        maintenancePersonnel.removeAll { $0.id == id }
    }
    
    // MARK: - Salary Expenses
    
    // Computed property that returns the sum of all salary expenses
    var totalSalaryExpenses: Double {
        let driversSalaries = drivers.reduce(0) { $0 + $1.salary }
        let maintenanceSalaries = maintenancePersonnel.reduce(0) { $0 + $1.salary }
        return driversSalaries + maintenanceSalaries
    }
    var totalFuelExpenses: Double {
        return trips.reduce(into: 0.0) { (runningTotal, trip) in
            // Extract numeric distance from trip 
            let distance = Double(trip.distance.replacingOccurrences(of: " km", with: "")
                                 .replacingOccurrences(of: " miles", with: "")) ?? 0.0
            // Calculate fuel cost using distance
            runningTotal += distance * 0.8
        }
    }
    
    private func calculateSalaries() -> Double {
        return drivers.reduce(0.0) { total, driver in
            total + (Double(driver.salary))
        }
    }
    
    private func calculateMaintenancePersonnelSalaries() -> Double {
        return maintenancePersonnel.reduce(0.0) { runningTotal, personnel in
            let salary = Double(personnel.salary)
            return runningTotal + salary
        }
    }
}
