import SwiftUI

struct MaintenancePersonnelChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabaseController = SupabaseDataController.shared
    @State private var fleetManager: FleetManager?
    @State private var isLoading = true
    let serviceRequest: MaintenanceServiceRequest?
    
    init(serviceRequest: MaintenanceServiceRequest? = nil) {
        self.serviceRequest = serviceRequest
    }
    
    var body: some View {
        Group {
            if let manager = fleetManager {
                if let userID = manager.userID {
                    ChatView(
                        recipientType: .maintenance,
                        recipientId: userID,
                        recipientName: manager.name,
                        contextData: serviceRequest.map { request in
                            [
                                "requestId": request.id.uuidString,
                                "vehicleName": request.vehicleName,
                                "serviceType": request.serviceType.rawValue,
                                "status": request.status.rawValue
                            ]
                        }
                    )
                } else {
                    ContentUnavailableView("Unable to start chat", 
                        systemImage: "exclamationmark.triangle",
                        description: Text("Fleet manager information is incomplete"))
                }
            } else if isLoading {
                ProgressView("Loading fleet manager...")
            } else {
                ContentUnavailableView("No Fleet Manager Available", 
                    systemImage: "person.fill.questionmark",
                    description: Text("Unable to find fleet manager details"))
            }
        }
        .task {
            await fetchFleetManager()
        }
    }
    
    private func fetchFleetManager() async {
        isLoading = true
        do {
            let fleetManagers = try await supabaseController.fetchFleetManagers()
            await MainActor.run {
                if !fleetManagers.isEmpty {
                    self.fleetManager = fleetManagers[0]
                }
                isLoading = false
            }
        } catch {
            print("Error fetching fleet manager: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    MaintenancePersonnelChatView()
} 