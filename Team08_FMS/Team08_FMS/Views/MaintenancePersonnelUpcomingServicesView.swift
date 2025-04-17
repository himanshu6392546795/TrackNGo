//import SwiftUI
//
//struct MaintenancePersonnelUpcomingServicesView: View {
//    @ObservedObject var dataStore: MaintenancePersonnelDataStore
//    @State private var selectedTab = 0
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // Header
//            Text("Driver Inspection Reports")
//                .font(.title2)
//                .fontWeight(.bold)
//                .padding(.top)
//            
//            // Segmented Control for Pre/Post Trip
//            Picker("Inspection Type", selection: $selectedTab) {
//                Text("Pre-Trip (\(preTripCount))").tag(0)
//                Text("Post-Trip (\(postTripCount))").tag(1)
//            }
//            .pickerStyle(.segmented)
//            .padding()
//            
//            // List of Requests
//            ScrollView {
//                LazyVStack(spacing: 16) {
//                    ForEach(selectedTab == 0 ? preTripRequests : postTripRequests) { request in
//                        NavigationLink(destination: InspectionRequestDetailView(request: request)) {
//                            InspectionRequestCard(request: request)
//                        }
//                    }
//                }
//                .padding()
//            }
//        }
//        .background(Color(.systemGroupedBackground))
//    }
//    
//    private var preTripRequests: [InspectionRequest] {
//        dataStore.inspectionRequests.filter { $0.type == .preTrip }
//    }
//    
//    private var postTripRequests: [InspectionRequest] {
//        dataStore.inspectionRequests.filter { $0.type == .postTrip }
//    }
//    
//    private var preTripCount: Int {
//        preTripRequests.count
//    }
//    
//    private var postTripCount: Int {
//        postTripRequests.count
//    }
//}
//
//struct InspectionRequestCard: View {
//    let request: InspectionRequest
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            // Header
//            HStack {
//                VStack(alignment: .leading, spacing: 4) {
//                    Text(request.vehicleName)
//                        .font(.headline)
//                    
//                    HStack {
//                        Image(systemName: "person.circle.fill")
//                            .foregroundColor(.blue)
//                        Text(request.driverName)
//                            .font(.subheadline)
//                            .foregroundColor(.secondary)
//                    }
//                }
//                
//                Spacer()
//                
//                StatusBadge(status: request.status)
//            }
//            
//            Divider()
//            
//            // Details
//            VStack(alignment: .leading, spacing: 8) {
//                HStack {
//                    Image(systemName: request.type == .preTrip ? "sunrise.fill" : "sunset.fill")
//                        .foregroundColor(request.type == .preTrip ? .orange : .purple)
//                    Text(request.description)
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                }
//                
//                HStack {
//                    Image(systemName: "clock.fill")
//                        .foregroundColor(.gray)
//                    Text(request.date.formatted(date: .abbreviated, time: .shortened))
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//            }
//            
//            if !request.issues.isEmpty {
//                Divider()
//                
//                // Issues Preview
//                VStack(alignment: .leading, spacing: 8) {
//                    HStack {
//                        Image(systemName: "exclamationmark.triangle.fill")
//                            .foregroundColor(.red)
//                        Text("Issues Reported")
//                            .font(.subheadline)
//                            .fontWeight(.medium)
//                    }
//                    
//                    ForEach(request.issues.prefix(2)) { issue in
//                        HStack(alignment: .top, spacing: 8) {
//                            Circle()
//                                .fill(severityColor(issue.severity))
//                                .frame(width: 8, height: 8)
//                                .padding(.top, 6)
//                            
//                            Text(issue.description)
//                                .font(.subheadline)
//                        }
//                    }
//                    
//                    if request.issues.count > 2 {
//                        Text("+ \(request.issues.count - 2) more issues")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                            .padding(.leading, 16)
//                    }
//                }
//            }
//        }
//        .padding()
//        .background(Color(.systemBackground))
//        .cornerRadius(12)
//        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
//    }
//    
//    private func severityColor(_ severity: IssueSeverity) -> Color {
//        switch severity {
//        case .low: return .green
//        case .medium: return .orange
//        case .high: return .red
//        case .critical: return .purple
//        }
//    }
//}
//
//struct InspectionRequestDetailView: View {
//    let request: InspectionRequest
//    @State private var showingAlert = false
//    @State private var alertMessage = ""
//    @State private var showingMaintenanceSheet = false
//    @State private var showingExpenseSheet = false
//    @State private var selectedDate = Date()
//    @State private var maintenanceNotes = ""
//    @State private var maintenanceStatus: MaintenanceStatus = .scheduled
//    @State private var expenses: [MaintenanceExpense] = []
//    
//    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 20) {
//                // Vehicle Info Card
//                InspectionVehicleInfoCard(request: request)
//                    .padding(.horizontal)
//                
//                // Driver Info Card
//                InspectionDriverInfoCard(request: request)
//                    .padding(.horizontal)
//                
//                // Issues Card
//                if !request.issues.isEmpty {
//                    InspectionIssuesCard(issues: request.issues)
//                        .padding(.horizontal)
//                    
//                    // Priority Warning
//                    HStack {
//                        Image(systemName: "exclamationmark.triangle.fill")
//                            .foregroundColor(.red)
//                        Text("Priority Maintenance Required")
//                            .font(.headline)
//                            .foregroundColor(.red)
//                    }
//                    .padding(.horizontal)
//                }
//                
//                // Maintenance Status Card
//                if maintenanceStatus != .notScheduled {
//                    MaintenanceStatusCard(status: maintenanceStatus, date: selectedDate)
//                        .padding(.horizontal)
//                }
//                
//                // Expenses Card
//                if !expenses.isEmpty {
//                    MaintenanceExpensesCard(expenses: expenses)
//                        .padding(.horizontal)
//                }
//                
//                // Action Buttons
//                VStack(spacing: 12) {
//                    if maintenanceStatus == .notScheduled && !request.issues.isEmpty {
//                        Button(action: {
//                            showingMaintenanceSheet = true
//                        }) {
//                            HStack {
//                                Image(systemName: "wrench.and.screwdriver.fill")
//                                Text("Schedule Maintenance")
//                            }
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color.orange)
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                        }
//                    }
//                    
//                    if maintenanceStatus == .scheduled {
//                        Button(action: {
//                            maintenanceStatus = .inProgress
//                        }) {
//                            HStack {
//                                Image(systemName: "play.circle.fill")
//                                Text("Start Maintenance")
//                            }
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color.green)
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                        }
//                    }
//                    
//                    if maintenanceStatus == .inProgress {
//                        Button(action: {
//                            showingExpenseSheet = true
//                        }) {
//                            HStack {
//                                Image(systemName: "dollarsign.circle.fill")
//                                Text("Add Expense")
//                            }
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color.blue)
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                        }
//                        
//                        Button(action: {
//                            if !expenses.isEmpty {
//                                maintenanceStatus = .completed
//                            } else {
//                                alertMessage = "Please add at least one expense before marking as completed"
//                                showingAlert = true
//                            }
//                        }) {
//                            HStack {
//                                Image(systemName: "checkmark.circle.fill")
//                                Text("Mark as Completed")
//                            }
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color.green)
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                        }
//                    }
//                    
//                    Button(action: {
//                        alertMessage = "Inspection marked as reviewed"
//                        showingAlert = true
//                    }) {
//                        HStack {
//                            Image(systemName: "checkmark.circle.fill")
//                            Text("Mark as Reviewed")
//                        }
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.blue)
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                    }
//                }
//                .padding(.horizontal)
//            }
//            .padding(.vertical)
//        }
//        .navigationTitle("Inspection Details")
//        .navigationBarTitleDisplayMode(.large)
//        .alert("Success", isPresented: $showingAlert) {
//            Button("OK", role: .cancel) {}
//        } message: {
//            Text(alertMessage)
//        }
//        .sheet(isPresented: $showingMaintenanceSheet) {
//            NavigationView {
//                Form {
//                    Section(header: Text("Maintenance Details")) {
//                        DatePicker("Schedule Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
//                        
//                        TextEditor(text: $maintenanceNotes)
//                            .frame(height: 100)
//                    }
//                    
//                    Section(header: Text("Issues to Address")) {
//                        ForEach(request.issues) { issue in
//                            VStack(alignment: .leading, spacing: 4) {
//                                HStack {
//                                    Circle()
//                                        .fill(severityColor(issue.severity))
//                                        .frame(width: 8, height: 8)
//                                    Text(issue.severity.rawValue)
//                                        .font(.subheadline)
//                                        .fontWeight(.medium)
//                                }
//                                Text(issue.description)
//                                    .font(.subheadline)
//                                    .foregroundColor(.secondary)
//                            }
//                        }
//                    }
//                }
//                .navigationTitle("Schedule Maintenance")
//                .navigationBarItems(
//                    leading: Button("Cancel") {
//                        showingMaintenanceSheet = false
//                    },
//                    trailing: Button("Schedule") {
//                        scheduleMaintenance()
//                    }
//                )
//            }
//        }
//        .sheet(isPresented: $showingExpenseSheet) {
//            NavigationView {
//                ExpenseFormView(expenses: $expenses)
//            }
//        }
//    }
//    
//    private func severityColor(_ severity: IssueSeverity) -> Color {
//        switch severity {
//        case .low: return .green
//        case .medium: return .orange
//        case .high: return .red
//        case .critical: return .purple
//        }
//    }
//    
//    private func scheduleMaintenance() {
//        maintenanceStatus = .scheduled
//        alertMessage = "Maintenance scheduled for \(selectedDate.formatted(date: .abbreviated, time: .shortened))"
//        showingAlert = true
//        showingMaintenanceSheet = false
//    }
//}
//
//struct InspectionVehicleInfoCard: View {
//    let request: InspectionRequest
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Text("Vehicle Information")
//                .font(.headline)
//            
//            Divider()
//            
//            InfoRow(title: "Vehicle", value: request.vehicleName, icon: "car.fill")
//            InfoRow(title: "Inspection Type", value: request.type.rawValue, icon: request.type == .preTrip ? "sunrise.fill" : "sunset.fill")
//            InfoRow(title: "Date", value: request.date.formatted(date: .abbreviated, time: .shortened), icon: "calendar")
//        }
//        .padding()
//        .background(Color(.systemBackground))
//        .cornerRadius(12)
//        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
//    }
//}
//
//struct InspectionDriverInfoCard: View {
//    let request: InspectionRequest
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Text("Driver Information")
//                .font(.headline)
//            
//            Divider()
//            
//            InfoRow(title: "Driver", value: request.driverName, icon: "person.fill")
//            if !request.notes.isEmpty {
//                Text("Notes")
//                    .font(.subheadline)
//                    .fontWeight(.medium)
//                    .padding(.top, 4)
//                
//                Text(request.notes)
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//            }
//        }
//        .padding()
//        .background(Color(.systemBackground))
//        .cornerRadius(12)
//        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
//    }
//}
//
//struct InspectionIssuesCard: View {
//    let issues: [InspectionIssue]
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Text("Reported Issues")
//                .font(.headline)
//            
//            Divider()
//            
//            ForEach(issues) { issue in
//                VStack(alignment: .leading, spacing: 4) {
//                    HStack {
//                        Circle()
//                            .fill(severityColor(issue.severity))
//                            .frame(width: 8, height: 8)
//                        
//                        Text(issue.severity.rawValue)
//                            .font(.subheadline)
//                            .fontWeight(.medium)
//                    }
//                    
//                    Text(issue.description)
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                }
//                .padding(.vertical, 4)
//                
//                if issue.id != issues.last?.id {
//                    Divider()
//                }
//            }
//        }
//        .padding()
//        .background(Color(.systemBackground))
//        .cornerRadius(12)
//        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
//    }
//    
//    private func severityColor(_ severity: IssueSeverity) -> Color {
//        switch severity {
//        case .low: return .green
//        case .medium: return .orange
//        case .high: return .red
//        case .critical: return .purple
//        }
//    }
//}
//
//struct MaintenanceStatusCard: View {
//    let status: MaintenanceStatus
//    let date: Date
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Text("Maintenance Status")
//                .font(.headline)
//            
//            Divider()
//            
//            HStack {
//                Circle()
//                    .fill(statusColor)
//                    .frame(width: 12, height: 12)
//                
//                Text(status.rawValue)
//                    .font(.subheadline)
//                    .fontWeight(.medium)
//                
//                Spacer()
//                
//                Text(date.formatted(date: .abbreviated, time: .shortened))
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//        }
//        .padding()
//        .background(Color(.systemBackground))
//        .cornerRadius(12)
//        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
//    }
//    
//    private var statusColor: Color {
//        switch status {
//        case .scheduled: return .orange
//        case .inProgress: return .blue
//        case .completed: return .green
//        case .notScheduled: return .gray
//        }
//    }
//}
//
//struct MaintenanceExpensesCard: View {
//    let expenses: [MaintenanceExpense]
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Text("Maintenance Expenses")
//                .font(.headline)
//            
//            Divider()
//            
//            ForEach(expenses) { expense in
//                VStack(alignment: .leading, spacing: 4) {
//                    HStack {
//                        Text(expense.description)
//                            .font(.subheadline)
//                            .fontWeight(.medium)
//                        
//                        Spacer()
//                        
//                        Text("$\(String(format: "%.2f", expense.amount))")
//                            .font(.subheadline)
//                    }
//                    
//                    Text(expense.date.formatted(date: .abbreviated, time: .shortened))
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//                .padding(.vertical, 4)
//                
//                if expense.id != expenses.last?.id {
//                    Divider()
//                }
//            }
//            
//            Divider()
//            
//            HStack {
//                Text("Total")
//                    .font(.subheadline)
//                    .fontWeight(.medium)
//                
//                Spacer()
//                
//                Text("$\(String(format: "%.2f", totalExpenses))")
//                    .font(.subheadline)
//                    .fontWeight(.bold)
//            }
//        }
//        .padding()
//        .background(Color(.systemBackground))
//        .cornerRadius(12)
//        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
//    }
//    
//    private var totalExpenses: Double {
//        expenses.reduce(0) { $0 + $1.amount }
//    }
//}
//
//struct ExpenseFormView: View {
//    @Binding var expenses: [MaintenanceExpense]
//    @Environment(\.dismiss) var dismiss
//    @State private var description = ""
//    @State private var amount = ""
//    @State private var date = Date()
//    
//    var body: some View {
//        NavigationView {
//            Form {
//                Section(header: Text("Expense Details")) {
//                    TextField("Description", text: $description)
//                    TextField("Amount", text: $amount)
//                        .keyboardType(.decimalPad)
//                    DatePicker("Date", selection: $date, displayedComponents: [.date])
//                }
//            }
//        }
//        .navigationTitle("Add Expense")
//        .navigationBarItems(
//            leading: Button("Cancel") {
//                dismiss()
//            },
//            trailing: Button("Add") {
//                if let amountDouble = Double(amount), !description.isEmpty {
//                    let expense = MaintenanceExpense(
//                        id: UUID(),
//                        description: description,
//                        amount: amountDouble,
//                        date: date
//                    )
//                    expenses.append(expense)
//                    dismiss()
//                }
//            }
//            .disabled(description.isEmpty || amount.isEmpty)
//        )
//    }
//}
//
//
//#Preview {
//    MaintenancePersonnelUpcomingServicesView(dataStore: MaintenancePersonnelDataStore())
//} 
