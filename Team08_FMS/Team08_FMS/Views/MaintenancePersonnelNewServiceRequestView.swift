//import SwiftUI
//
//struct MaintenancePersonnelNewServiceRequestView: View {
//    @ObservedObject var dataStore: MaintenancePersonnelDataStore
//    @Environment(\.dismiss) private var dismiss
//    
//    @State private var vehicleName = ""
//    @State private var serviceType: ServiceType = .routine
//    @State private var description = ""
//    @State private var priority: ServiceRequestPriority = .medium
//    @State private var dueDate = Date().addingTimeInterval(86400 * 7)
//    @State private var notes = ""
//    @State private var issueType = ""
//    
//    var body: some View {
//        NavigationView {
//            Form {
//                Section("Vehicle Information") {
//                    TextField("Vehicle Name", text: $vehicleName)
//                    Picker("Service Type", selection: $serviceType) {
//                        ForEach(ServiceType.allCases, id: \.self) { type in
//                            Text(type.rawValue).tag(type)
//                        }
//                    }
//                    Picker("Priority", selection: $priority) {
//                        ForEach(ServiceRequestPriority.allCases, id: \.self) { priority in
//                            Text(priority.rawValue).tag(priority)
//                        }
//                    }
//                }
//                
//                Section("Service Details") {
//                    TextField("Description", text: $description)
//                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date])
//                    TextField("Issue Type (Optional)", text: $issueType)
//                }
//                
//                Section("Notes") {
//                    TextEditor(text: $notes)
//                        .frame(height: 100)
//                }
//            }
//            .navigationTitle("New Service Request")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("Cancel") {
//                        dismiss()
//                    }
//                }
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Create") {
//                        createServiceRequest()
//                    }
//                    .disabled(vehicleName.isEmpty || description.isEmpty)
//                }
//            }
//        }
//    }
//    
//    private func createServiceRequest() {
//        let request = MaintenanceServiceRequest(
//            //id: UUID(),
//            vehicleId: UUID(), // In a real app, this would come from vehicle selection
//            vehicleName: vehicleName,
//            serviceType: serviceType,
//            description: description,
//            priority: priority,
//            date: Date(),
//            dueDate: dueDate,
//            status: .pending,
//            notes: notes,
//            issueType: issueType.isEmpty ? nil : issueType
//           // safetyChecks: []
//        )
//        dataStore.serviceRequests.append(request)
//        dismiss()
//    }
//}
//
//#Preview {
//    MaintenancePersonnelNewServiceRequestView(dataStore: MaintenancePersonnelDataStore())
//} 
