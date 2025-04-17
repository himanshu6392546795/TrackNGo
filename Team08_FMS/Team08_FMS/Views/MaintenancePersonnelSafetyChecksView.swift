//import SwiftUI
//
//struct ServicesEmptyStateView: View {
//    let icon: String
//    let title: String
//    let message: String
//    
//    var body: some View {
//        VStack(spacing: 16) {
//            Image(systemName: icon)
//                .font(.system(size: 50))
//                .foregroundColor(.gray)
//            
//            Text(title)
//                .font(.headline)
//                .foregroundColor(.gray)
//            
//            Text(message)
//                .font(.subheadline)
//                .foregroundColor(.gray)
//                .multilineTextAlignment(.center)
//                .padding(.horizontal)
//        }
//        .frame(maxHeight: .infinity)
//        .padding()
//    }
//}
//
//struct MaintenancePersonnelSafetyChecksView: View {
//    @ObservedObject var dataStore: MaintenancePersonnelDataStore
//    @State private var selectedRequest: MaintenanceServiceRequest?
//    @State private var showingDetail = false
//    @State private var showingAlert = false
//    @State private var alertMessage = ""
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            if dataStore.serviceRequests.isEmpty {
//                ServicesEmptyStateView(
//                    icon: "checkmark.shield",
//                    title: "No Service Requests",
//                    message: "There are no service requests that require safety checks at the moment."
//                )
//            } else {
//                List {
//                    ForEach(dataStore.serviceRequests) { request in
//                        SafetyCheckRow(request: request, dataStore: dataStore)
//                            .contentShape(Rectangle())
//                            .onTapGesture {
//                                selectedRequest = request
//                                showingDetail = true
//                            }
//                    }
//                }
//                .listStyle(PlainListStyle())
//            }
//        }
//        .sheet(isPresented: $showingDetail) {
//            if let request = selectedRequest {
//                NavigationView {
//                    SafetyCheckDetailView(request: request, dataStore: dataStore)
//                        .navigationTitle("Safety Checks")
//                        .navigationBarItems(trailing: Button("Done") {
//                            showingDetail = false
//                        })
//                }
//            }
//        }
//        .alert("Error", isPresented: $showingAlert) {
//            Button("OK", role: .cancel) {}
//        } message: {
//            Text(alertMessage)
//        }
//    }
//}
//
//struct SafetyCheckRow: View {
//    let request: MaintenanceServiceRequest
//    @ObservedObject var dataStore: MaintenancePersonnelDataStore
//    @State private var safetyChecks: [SafetyCheck] = []
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack {
//                Text(request.vehicleName)
//                    .font(.headline)
//                Spacer()
//                StatusBadge(status: request.status)
//            }
//            
//            Text(request.description)
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//                .lineLimit(2)
//            
//            HStack {
//                Label("\(safetyChecks.filter { $0.isChecked }.count)/\(safetyChecks.count) Checks",
//                      systemImage: "checkmark.circle.fill")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                
//                Spacer()
//                
//                if !safetyChecks.isEmpty {
//                    ProgressView(value: Double(safetyChecks.filter { $0.isChecked }.count),
//                                 total: Double(safetyChecks.count))
//                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
//                        .frame(width: 100)
//                }
//            }
//        }
//        .padding(.vertical, 8)
//        .onAppear {
//            loadSafetyChecks()
//        }
//    }
//    
//    private func loadSafetyChecks() {
//        Task {
//            do {
//                let fetchedChecks = try await dataStore.fetchSafetyChecks(requestID: request.id)
//                await MainActor.run {
//                    self.safetyChecks = fetchedChecks
//                }
//            } catch {
//                print("Error fetching safety checks for request \(request.id): \(error)")
//            }
//        }
//    }
//}
//
//
//struct SafetyCheckDetailView: View {
//    let request: MaintenanceServiceRequest
//    @ObservedObject var dataStore: MaintenancePersonnelDataStore
//    @State private var safetyChecks: [SafetyCheck] = []
//    @State private var showingSaveAlert = false
//    @State private var showingErrorAlert = false
//    @State private var errorMessage = ""
//    
//    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 20) {
//                // Vehicle Info Card
//                MaintenanceVehicleInfoCard(request: request)
//                
//                // Safety Checks Section
//                VStack(alignment: .leading, spacing: 16) {
//                    Text("Safety Checks")
//                        .font(.headline)
//                        .padding(.horizontal)
//                    
//                    ForEach($safetyChecks) { $check in
//                        SafetyCheckItem(check: $check)
//                    }
//                }
//                .padding(.vertical)
//            }
//        }
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                Button("Save") {
//                    saveSafetyChecks()
//                }
//                .fontWeight(.medium)
//            }
//        }
//        .alert("Success", isPresented: $showingSaveAlert) {
//            Button("OK", role: .cancel) {}
//        } message: {
//            Text("Safety checks have been saved successfully.")
//        }
//        .alert("Error", isPresented: $showingErrorAlert) {
//            Button("OK", role: .cancel) {}
//        } message: {
//            Text(errorMessage)
//        }
//        .onAppear {
//            loadSafetyChecks()
//        }
//    }
//    
//    // Loads safety checks for the given service request
//    private func loadSafetyChecks() {
//        Task {
//            do {
//                // Assuming your data store now has a method to fetch safety checks for a request.
//                let checks = try await dataStore.fetchSafetyChecks(requestID: request.id)
//                await MainActor.run {
//                    self.safetyChecks = checks
//                }
//            } catch {
//                await MainActor.run {
//                    errorMessage = "Failed to load safety checks: \(error.localizedDescription)"
//                    showingErrorAlert = true
//                }
//            }
//        }
//    }
//    
//    // Saves the updated safety checks
//    private func saveSafetyChecks() {
//        Task {
//            await dataStore.updateSafetyChecks(for: request, checks: safetyChecks)
//        }
//        showingSaveAlert = true
//    }
//}
//
//
//struct MaintenanceVehicleInfoCard: View {
//    let request: MaintenanceServiceRequest
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Text("Vehicle Information")
//                .font(.headline)
//            
//            Divider()
//            
//            InfoRow(title: "Vehicle", value: request.vehicleName, icon: "car.fill")
//            InfoRow(title: "Service Type", value: request.serviceType.rawValue, icon: "wrench.fill")
//            InfoRow(title: "Priority", value: request.priority.rawValue, icon: "exclamationmark.triangle.fill")
//            InfoRow(title: "Due Date", value: request.dueDate.formatted(date: .abbreviated, time: .shortened), icon: "calendar")
//        }
//        .padding()
//        .background(Color(.systemBackground))
//        .cornerRadius(12)
//        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
//        .padding(.horizontal)
//    }
//}
//
//struct RInfoRow: View {
//    let title: String
//    let value: String
//    let icon: String
//    
//    var body: some View {
//        HStack {
//            Image(systemName: icon)
//                .foregroundColor(.blue)
//                .frame(width: 24)
//            
//            Text(title)
//                .foregroundColor(.secondary)
//            
//            Spacer()
//            
//            Text(value)
//                .fontWeight(.medium)
//        }
//    }
//}
//
//struct SafetyCheckItem: View {
//    @Binding var check: SafetyCheck
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack {
//                Button(action: {
//                    withAnimation {
//                        check.isChecked.toggle()
//                    }
//                }) {
//                    Image(systemName: check.isChecked ? "checkmark.circle.fill" : "circle")
//                        .foregroundColor(check.isChecked ? .green : .gray)
//                        .font(.title2)
//                }
//                
//                Text(check.item)
//                    .font(.subheadline)
//                    .fontWeight(.medium)
//            }
//            
//            if check.isChecked {
//                TextField("Add notes...", text: $check.notes, axis: .vertical)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .transition(.opacity.combined(with: .move(edge: .top)))
//            }
//        }
//        .padding()
//        .background(Color(.systemBackground))
//        .cornerRadius(12)
//        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
//        .padding(.horizontal)
//    }
//}
//
//#Preview {
//    MaintenancePersonnelSafetyChecksView(dataStore: MaintenancePersonnelDataStore())
//} 
// 
