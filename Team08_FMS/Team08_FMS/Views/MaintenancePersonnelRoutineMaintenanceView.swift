//import SwiftUI
//
//struct MaintenancePersonnelRoutineMaintenanceView: View {
//    @ObservedObject var dataStore: MaintenancePersonnelDataStore
//    @State private var showingNewSchedule = false
//    @State private var searchText = ""
//    
//    var filteredSchedules: [MaintenancePersonnelRoutineSchedule] {
//        dataStore.routineSchedules.filter { schedule in
//            searchText.isEmpty || 
//            schedule.vehicleName.localizedCaseInsensitiveContains(searchText)
//        }
//    }
//    
//    var body: some View {
//        NavigationView {
//            List {
//                Section {
//                    ForEach(filteredSchedules) { schedule in
//                        NavigationLink(destination: MaintenancePersonnelRoutineScheduleDetailView(schedule: schedule, dataStore: dataStore)) {
//                            RoutineScheduleRow(schedule: schedule)
//                        }
//                    }
//                }
//            }
//            .searchable(text: $searchText, prompt: "Search vehicles")
//            .navigationTitle("Routine Maintenance")
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button(action: { showingNewSchedule = true }) {
//                        Image(systemName: "plus")
//                    }
//                }
//            }
//            .sheet(isPresented: $showingNewSchedule) {
//                MaintenancePersonnelNewRoutineScheduleView(dataStore: dataStore)
//            }
//        }
//    }
//}
//
//struct RoutineScheduleRow: View {
//    let schedule: MaintenancePersonnelRoutineSchedule
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 4) {
//            Text(schedule.vehicleName)
//                .font(.headline)
//            
//            HStack {
//                Label(schedule.serviceType.rawValue, systemImage: "gear")
//                    .font(.subheadline)
//                Spacer()
//                Text("Every \(schedule.interval) days")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//            
//            HStack {
//                Text("Next Service:")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                Text(schedule.nextServiceDate.formatted(date: .abbreviated, time: .omitted))
//                    .font(.caption)
//            }
//        }
//        .padding(.vertical, 4)
//    }
//}
//
//struct MaintenancePersonnelRoutineScheduleDetailView: View {
//    let schedule: MaintenancePersonnelRoutineSchedule
//    @ObservedObject var dataStore: MaintenancePersonnelDataStore
//    @Environment(\.dismiss) private var dismiss
//    @State private var showingDeleteAlert = false
//    
//    var body: some View {
//        List {
//            Section("Schedule Information") {
//                LabeledContent(label: "Vehicle", value: schedule.vehicleName)
//                LabeledContent(label: "Service Type", value: schedule.serviceType.rawValue)
//                LabeledContent(label: "Interval", value: "\(schedule.interval) days")
//                LabeledContent(label: "Last Service", value: schedule.lastServiceDate.formatted(date: .long, time: .omitted))
//                LabeledContent(label: "Next Service", value: schedule.nextServiceDate.formatted(date: .long, time: .omitted))
//            }
//            
//            Section("Notes") {
//                Text(schedule.notes)
//            }
//            
//            Section {
//                Button(action: { showingDeleteAlert = true }) {
//                    Label("Delete Schedule", systemImage: "trash")
//                        .foregroundColor(.red)
//                }
//            }
//        }
//        .navigationTitle("Schedule Details")
//        .alert("Delete Schedule", isPresented: $showingDeleteAlert) {
//            Button("Cancel", role: .cancel) { }
//            Button("Delete", role: .destructive) {
//                Task {
//                    await dataStore.deleteRoutineSchedule(schedule)
//                }
//                dismiss()
//            }
//        } message: {
//            Text("Are you sure you want to delete this routine maintenance schedule?")
//        }
//    }
//}
//
//struct MaintenancePersonnelNewRoutineScheduleView: View {
//    @ObservedObject var dataStore: MaintenancePersonnelDataStore
//    @Environment(\.dismiss) private var dismiss
//    
//    @State private var vehicleName = ""
//    @State private var serviceType: ServiceType = .routine
//    @State private var interval = 30
//    @State private var notes = ""
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
//                }
//                
//                Section("Schedule") {
//                    Stepper("Interval: \(interval) days", value: $interval, in: 1...365)
//                }
//                
//                Section("Notes") {
//                    TextEditor(text: $notes)
//                        .frame(height: 100)
//                }
//            }
//            .navigationTitle("New Schedule")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("Cancel") {
//                        dismiss()
//                    }
//                }
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Save") {
//                        saveSchedule()
//                    }
//                    .disabled(vehicleName.isEmpty)
//                }
//            }
//        }
//    }
//    
//    private func saveSchedule() {
//        let schedule = MaintenancePersonnelRoutineSchedule(
//            id: UUID(),
//            vehicleId: UUID(), // In a real app, this would come from vehicle selection
//            vehicleName: vehicleName,
//            serviceType: serviceType,
//            interval: interval,
//            lastServiceDate: Date(),
//            nextServiceDate: Date().addingTimeInterval(TimeInterval(interval * 86400)),
//            notes: notes
//        )
//        Task {
//            await dataStore.addRoutineSchedule(schedule)
//        }
//        dismiss()
//    }
//}
//
//#Preview {
//    MaintenancePersonnelRoutineMaintenanceView(dataStore: MaintenancePersonnelDataStore())
//} 
