//import SwiftUI
//
//struct MaintenancePersonnelServiceHistoryView: View {
//    @ObservedObject var dataStore: MaintenancePersonnelDataStore
//    @State private var searchText = ""
//    @State private var selectedServiceType: ServiceType?
//    @State private var selectedHistory: MaintenancePersonnelServiceHistory?
//    @State private var showingDetail = false
//    
//    var filteredHistory: [MaintenancePersonnelServiceHistory] {
//        var history = dataStore.serviceHistory
//        
//        if let serviceType = selectedServiceType {
//            history = history.filter { $0.serviceType == serviceType }
//        }
//        
//        if !searchText.isEmpty {
//            history = history.filter {
//                $0.vehicleName.localizedCaseInsensitiveContains(searchText) ||
//                $0.description.localizedCaseInsensitiveContains(searchText)
//            }
//        }
//        
//        return history.sorted { $0.date > $1.date }
//    }
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // Search and Filter Bar
//            VStack(spacing: 12) {
//                HStack {
//                    Image(systemName: "magnifyingglass")
//                        .foregroundColor(.gray)
//                    TextField("Search history...", text: $searchText)
//                        .textFieldStyle(RoundedBorderTextFieldStyle())
//                }
//                .padding(.horizontal)
//                
//                ScrollView(.horizontal, showsIndicators: false) {
//                    HStack(spacing: 12) {
//                        ForEach(ServiceType.allCases, id: \.self) { type in
//                            ServiceTypeFilterButton(
//                                type: type,
//                                isSelected: selectedServiceType == type,
//                                action: {
//                                    withAnimation {
//                                        selectedServiceType = selectedServiceType == type ? nil : type
//                                    }
//                                }
//                            )
//                        }
//                    }
//                    .padding(.horizontal)
//                }
//            }
//            .padding(.vertical, 8)
//            .background(Color(.systemBackground))
//            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
//            
//            if filteredHistory.isEmpty {
//                ServicesEmptyStateView(
//                    icon: "clock",
//                    title: "No Service History",
//                    message: "There are no service history records to display."
//                )
//            } else {
//                List {
//                    ForEach(filteredHistory) { history in
//                        ServiceHistoryRow(history: history, dataStore: dataStore)
//                            .contentShape(Rectangle())
//                            .onTapGesture {
//                                selectedHistory = history
//                                showingDetail = true
//                            }
//                    }
//                }
//                .listStyle(PlainListStyle())
//            }
//        }
//        .sheet(isPresented: $showingDetail) {
//            if let history = selectedHistory {
//                NavigationView {
//                    ServiceHistoryDetailView(history: history, dataStore: dataStore)
//                        .navigationTitle("Service History Details")
//                        .navigationBarItems(trailing: Button("Done") {
//                            showingDetail = false
//                        })
//                }
//            }
//        }
//    }
//}
//
//struct ServiceTypeFilterButton: View {
//    let type: ServiceType
//    let isSelected: Bool
//    let action: () -> Void
//    
//    var body: some View {
//        Button(action: action) {
//            HStack(spacing: 4) {
//                Image(systemName: iconName)
//                Text(type.rawValue)
//            }
//            .font(.subheadline)
//            .fontWeight(.medium)
//            .padding(.horizontal, 16)
//            .padding(.vertical, 8)
//            .background(isSelected ? Color.blue : Color(.systemGray6))
//            .foregroundColor(isSelected ? .white : .primary)
//            .cornerRadius(20)
//        }
//    }
//    
//    private var iconName: String {
//        switch type {
//        case .routine: return "wrench.fill"
//        case .repair: return "hammer.fill"
//        case .inspection: return "magnifyingglass"
//        case .emergency: return "exclamationmark.triangle.fill"
//        }
//    }
//}
//
//struct ServiceHistoryRow: View {
//    let history: MaintenancePersonnelServiceHistory
//    @ObservedObject var dataStore: MaintenancePersonnelDataStore
//    @State private var safetyChecks: [SafetyCheck] = []
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack {
//                Text(history.vehicleName)
//                    .font(.headline)
//                Spacer()
//                ServiceTypeBadge(type: history.serviceType)
//            }
//            
//            Text(history.description)
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//                .lineLimit(2)
//            
//            HStack {
//                Label(history.date.formatted(date: .abbreviated, time: .shortened),
//                      systemImage: "calendar")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                
//                Spacer()
//                
//                Label("\(safetyChecks.filter { $0.isChecked }.count) Checks",
//                      systemImage: "checkmark.circle.fill")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//        }
//        .padding(.vertical, 8)
//        .onAppear(perform: loadSafetyChecks)
//    }
//    
//    private func loadSafetyChecks() {
//        Task {
//            do {
//                // Fetch safety checks based on the history's ID, which now represents the history record.
//                let fetchedChecks = try await dataStore.fetchSafetyChecks(historyID: history.id)
//                await MainActor.run {
//                    self.safetyChecks = fetchedChecks
//                }
//            } catch {
//                print("Error fetching safety checks for history \(history.id): \(error)")
//            }
//        }
//    }
//}
//
//
//struct ServiceTypeBadge: View {
//    let type: ServiceType
//    
//    var body: some View {
//        HStack(spacing: 4) {
//            Image(systemName: iconName)
//            Text(type.rawValue)
//        }
//        .font(.caption)
//        .fontWeight(.medium)
//        .padding(.horizontal, 8)
//        .padding(.vertical, 4)
//        .background(backgroundColor.opacity(0.2))
//        .foregroundColor(backgroundColor)
//        .cornerRadius(8)
//    }
//    
//    private var iconName: String {
//        switch type {
//        case .routine: return "wrench.fill"
//        case .repair: return "hammer.fill"
//        case .inspection: return "magnifyingglass"
//        case .emergency: return "exclamationmark.triangle.fill"
//        }
//    }
//    
//    private var backgroundColor: Color {
//        switch type {
//        case .routine: return .blue
//        case .repair: return .orange
//        case .inspection: return .green
//        case .emergency: return .red
//        }
//    }
//}
//
//struct ServiceHistoryDetailView: View {
//    let history: MaintenancePersonnelServiceHistory
//    @ObservedObject var dataStore: MaintenancePersonnelDataStore
//    @State private var safetyChecks: [SafetyCheck] = []
//    
//    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 20) {
//                // Vehicle Info Card
//                MaintenanceVehicleHistoryInfoCard(history: history)
//                
//                // Service Details Card
//                ServiceDetailsCard(history: history)
//                
//                // Safety Checks Card
//                if !safetyChecks.isEmpty {
//                    SafetyChecksCard(checks: safetyChecks)
//                }
//            }
//            .padding(.vertical)
//        }
//        .onAppear {
//            loadSafetyChecks()
//        }
//    }
//    
//    private func loadSafetyChecks() {
//        Task {
//            do {
//                // Adjust the parameter if safety checks are tied to a different identifier
//                let fetchedChecks = try await dataStore.fetchSafetyChecks(historyID: history.id)
//                await MainActor.run {
//                    self.safetyChecks = fetchedChecks
//                }
//            } catch {
//                print("Error fetching safety checks for history \(history.id): \(error)")
//            }
//        }
//    }
//}
//
//
//struct MaintenanceVehicleHistoryInfoCard: View {
//    let history: MaintenancePersonnelServiceHistory
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Text("Vehicle Information")
//                .font(.headline)
//            
//            Divider()
//            
//            InfoRow(title: "Vehicle", value: history.vehicleName, icon: "car.fill")
//            InfoRow(title: "Service Type", value: history.serviceType.rawValue, icon: "wrench.fill")
//            InfoRow(title: "Date", value: history.date.formatted(date: .abbreviated, time: .shortened), icon: "calendar")
//            InfoRow(title: "Completion", value: history.completionDate.formatted(date: .abbreviated, time: .shortened), icon: "checkmark.circle.fill")
//        }
//        .padding()
//        .background(Color(.systemBackground))
//        .cornerRadius(12)
//        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
//        .padding(.horizontal)
//    }
//}
//
//struct ServiceDetailsCard: View {
//    let history: MaintenancePersonnelServiceHistory
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Text("Service Details")
//                .font(.headline)
//            
//            Divider()
//            
//            Text(history.description)
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//            
//            if !history.notes.isEmpty {
//                Text("Notes")
//                    .font(.subheadline)
//                    .fontWeight(.medium)
//                    .padding(.top, 4)
//                
//                Text(history.notes)
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//            }
//        }
//        .padding()
//        .background(Color(.systemBackground))
//        .cornerRadius(12)
//        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
//        .padding(.horizontal)
//    }
//}
//
//struct SafetyChecksCard: View {
//    let checks: [SafetyCheck]
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Text("Safety Checks")
//                .font(.headline)
//            
//            Divider()
//            
//            ForEach(checks) { check in
//                HStack(alignment: .top, spacing: 12) {
//                    Image(systemName: check.isChecked ? "checkmark.circle.fill" : "circle")
//                        .foregroundColor(check.isChecked ? .green : .gray)
//                        .font(.title3)
//                    
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text(check.item)
//                            .font(.subheadline)
//                            .fontWeight(.medium)
//                        
//                        if !check.notes.isEmpty {
//                            Text(check.notes)
//                                .font(.caption)
//                                .foregroundColor(.secondary)
//                        }
//                    }
//                }
//                
//                if check.id != checks.last?.id {
//                    Divider()
//                }
//            }
//        }
//        .padding()
//        .background(Color(.systemBackground))
//        .cornerRadius(12)
//        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
//        .padding(.horizontal)
//    }
//}
//
//#Preview {
//    MaintenancePersonnelServiceHistoryView(dataStore: MaintenancePersonnelDataStore())
//} 
