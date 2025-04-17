import SwiftUI

class DriverAvailabilityManager: ObservableObject {
    @Published var isAvailable: Bool = true
    
    static let shared = DriverAvailabilityManager()
    
    private init() {}
    
    // Update availability
    func updateAvailability(newStatus: Bool) {
        isAvailable = newStatus
    }
} 