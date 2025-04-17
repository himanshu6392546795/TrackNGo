import Foundation

class VehicleManager: ObservableObject {
    
    static let shared = VehicleManager()
    
    @Published var vehicles: [Vehicle] = []
    @Published var isLoading: Bool = false
    @Published var loadError: String? = nil
    
    init() {
        loadVehicles()
    }

    func loadVehiclesAsync() async {
        if isLoading { return }
        
        await MainActor.run {
            isLoading = true
            loadError = nil
        }
        
        do {
            let vehicles = try await SupabaseDataController.shared.fetchVehicles()
            
            await MainActor.run {
                self.vehicles = vehicles
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func loadVehicles() {
        Task {
            await loadVehiclesAsync()
        }
    }
 
    func fetchVehicleDetails(vehicleId: UUID) async throws -> Vehicle? {
        do {
            return try await SupabaseDataController.shared.fetchVehicleDetails(vehicleId: vehicleId)
        } catch {
            print("Error fetching vehicle details: \(error.localizedDescription)")
            throw error
        }
    }
}
