import SwiftUI
import PDFKit

struct FleetManagerServiceRequestDetailView: View {
    let request: MaintenanceServiceRequest
    @ObservedObject var dataStore: MaintenancePersonnelDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingExpenseSheet = false
    @State private var showingCompletionAlert = false
    @State private var expenseDescription = ""
    @State private var expenseAmount = ""
    @State private var selectedExpenseCategory: ExpenseCategory = .parts
    @State private var safetyChecks: [SafetyCheck] = []
    @State private var expenses: [Expense] = []
    @State private var showingExpenseReceipt = false
    @State private var expenseReceiptData: Data?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Vehicle Info Card
                FleetManagerVehicleRequestInfoCard(request: request)
                    .padding(.horizontal)
                
                // Service Details Card
                FleetManagerMaintenanceServiceDetailsCard(request: request)
                    .padding(.horizontal)
                // Expenses Card
                FleetManagerExpensesCard(expenses: expenses)
                    .padding(.horizontal)
                
                // Action Buttons
                VStack(spacing: 12) {
                    if request.status == .completed {
                        Button(action: {
                            expenseReceiptData = generateExpenseReceipt()
                            showingExpenseReceipt = true
                        }) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                Text("View Expense Receipt")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Service Request Details")
        .navigationBarTitleDisplayMode(.large)
        .alert("Success", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingExpenseSheet, onDismiss: {loadExpenses()}){
            NavigationView {
                AddExpenseView(
                    request: request,
                    dataStore: dataStore,
                    description: $expenseDescription,
                    amount: $expenseAmount,
                    category: $selectedExpenseCategory,
                    isPresented: $showingExpenseSheet
                )
            }
        }
        .alert("Complete Service Request", isPresented: $showingCompletionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Complete") {
                completeServiceRequest()
            }
        } message: {
            Text("Are you sure you want to mark this service request as completed?")
        }
        .sheet(isPresented: $showingExpenseReceipt) {
            if let data = expenseReceiptData {
                NavigationView {
                    PDFKitView(data: data)
                        .navigationTitle("Expense Receipt")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Done") {
                                    showingExpenseReceipt = false
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                ShareLink(
                                    item: data,
                                    preview: SharePreview(
                                        "Maintenance Expense Receipt",
                                        image: Image(systemName: "doc.fill")
                                    )
                                )
                            }
                        }
                }
            }
        }
        .onAppear {
            loadSafetyChecks()
            loadExpenses()
        }
    }
    
    // MARK: - Data Loading Methods
    
    private func loadSafetyChecks() {
        Task {
            do {
                let fetchedChecks = try await dataStore.fetchSafetyChecks(requestID: request.id)
                await MainActor.run {
                    self.safetyChecks = fetchedChecks
                }
            } catch {
                print("Error fetching safety checks for request \(request.id): \(error)")
            }
        }
    }
    
    private func loadExpenses() {
        Task {
            do {
                let fetchedExpenses = try await dataStore.fetchExpenses(for: request.id)
                await MainActor.run {
                    self.expenses = fetchedExpenses
                }
            } catch {
                print("Error fetching expenses for request \(request.id): \(error)")
            }
        }
    }
    
    // MARK: - Action Methods
    
    private func startMaintenance() {
        Task {
//            if let userID = await SupabaseDataController.shared.getUserID() {
//                await dataStore.updateServiceRequestStatus(request, newStatus: .inProgress, userID: userID)
//            } else {
//                print("No userID found to assign the service request.")
//            }
        }
        alertMessage = "Maintenance started successfully"
        showingAlert = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
    
    private func completeServiceRequest() {
        Task {
            await dataStore.updateServiceRequestStatus(request, newStatus: .completed, userID: nil)
            await dataStore.addToServiceHistory(from: request)
        }
        alertMessage = "Service request marked as completed"
        showingAlert = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
    
    private func generateExpenseReceipt() -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "FMS App",
            kCGPDFContextAuthor: "Maintenance Personnel",
            kCGPDFContextTitle: "Maintenance Expense Receipt"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let pdfData = renderer.pdfData { context in
            context.beginPage()
            let ctx = UIGraphicsGetCurrentContext()!
            
            // Set up text attributes
            let titleAttributes = [
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 24),
                NSAttributedString.Key.foregroundColor: UIColor.black
            ]
            let headerAttributes = [
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14),
                NSAttributedString.Key.foregroundColor: UIColor.black
            ]
            let textAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12),
                NSAttributedString.Key.foregroundColor: UIColor.black
            ]
            
            // Draw title
            let title = "MAINTENANCE EXPENSE RECEIPT"
            let titleSize = title.size(withAttributes: titleAttributes)
            let titleX = (pageRect.width - titleSize.width) / 2
            title.draw(at: CGPoint(x: titleX, y: 40), withAttributes: titleAttributes)
            
            // Set up table drawing parameters
            var yPosition: CGFloat = 100
            let leftMargin: CGFloat = 50
            let labelWidth: CGFloat = 150  // Width for labels
            let valueWidth: CGFloat = 350  // Width for values
            let rowHeight: CGFloat = 25
            let padding: CGFloat = 5
            
            // Function to draw a table row with word wrap
            func drawTableRow(label: String, value: String, atY y: CGFloat) -> CGFloat {
                let rect = CGRect(x: leftMargin, y: y, width: labelWidth + valueWidth, height: rowHeight)
                ctx.stroke(rect)
                
                // Draw vertical line between columns
                let midX = leftMargin + labelWidth
                ctx.move(to: CGPoint(x: midX, y: y))
                ctx.addLine(to: CGPoint(x: midX, y: y + rowHeight))
                ctx.strokePath()
                
                // Draw label
                let labelRect = CGRect(x: leftMargin + padding, y: y + padding,
                                     width: labelWidth - padding * 2, height: rowHeight - padding * 2)
                label.draw(in: labelRect, withAttributes: textAttributes)
                
                // Draw value with potential wrapping
                let valueRect = CGRect(x: midX + padding, y: y + padding,
                                     width: valueWidth - padding * 2, height: rowHeight - padding * 2)
                value.draw(in: valueRect, withAttributes: textAttributes)
                
                return y + rowHeight
            }
            
            // Draw Service Request Information section
            "Service Request Information".draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 25
            
            yPosition = drawTableRow(label: "Request ID:", value: request.id.uuidString, atY: yPosition)
            yPosition = drawTableRow(label: "Vehicle:", value: request.vehicleName, atY: yPosition)
            yPosition = drawTableRow(label: "Service Type:", value: request.serviceType.rawValue, atY: yPosition)
            yPosition = drawTableRow(label: "Priority:", value: request.priority.rawValue, atY: yPosition)
            
            yPosition += 20
            
            // Draw Expenses section
            "Expenses".draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 25
            
            // Draw expense items
            for expense in expenses {
                yPosition = drawTableRow(
                    label: expense.description,
                    value: String(format: "$%.2f", expense.amount),
                    atY: yPosition
                )
            }
            
            yPosition += 10
            
            // Draw total
            let totalCost = expenses.reduce(0) { $0 + $1.amount }
            yPosition = drawTableRow(
                label: "Total Cost:",
                value: String(format: "$%.2f", totalCost),
                atY: yPosition
            )
            
            yPosition += 20
            
            // Draw Completion Information section
            "Completion Information".draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 25
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            
            yPosition = drawTableRow(
                label: "Completion Date:",
                value: dateFormatter.string(from: Date()),
                atY: yPosition
            )
            
            yPosition += 40
            
            // Draw Signature section
            "Maintenace Personnel Signature:".draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 25
            
            // Draw signature box
            let signatureRect = CGRect(x: leftMargin, y: yPosition, width: 200, height: 60)
            ctx.stroke(signatureRect)
            
            yPosition += 80
            
            // Draw date
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .none
            let dateString = "Date: \(dateFormatter.string(from: Date()))"
            dateString.draw(at: CGPoint(x: leftMargin, y: yPosition), withAttributes: textAttributes)
        }
        
        return pdfData
    }
}

// Add PDFKitView for displaying PDF
struct FleetManagerPDFKitView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: data)
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(data: data)
    }
}

struct FleetManagerExpensesCard: View {
    let expenses: [Expense]
    
    private var totalCost: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Expenses")
                    .font(.headline)
                Spacer()
                Text("Total: $\(totalCost, specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            Divider()
            
            if expenses.isEmpty {
                Text("No expenses added yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(expenses) { expense in
                    ExpenseRow(expense: expense)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct FleetManagerExpenseRow: View {
    let expense: Expense
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.description)
                    .font(.subheadline)
                Text(expense.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(expense.amount, specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(.green)
                Text(expense.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct FleetManagerAddExpenseView: View {
    let request: MaintenanceServiceRequest
    @ObservedObject var dataStore: MaintenancePersonnelDataStore
    @Binding var description: String
    @Binding var amount: String
    @Binding var category: ExpenseCategory
    @Binding var isPresented: Bool
    @FocusState private var focusedField: Bool
    
    var isValidAmount: Bool {
        guard let value = Double(amount), value > 0 else { return false }
        return true
    }
    
    var body: some View {
        Form {
            Section("Expense Details") {
                TextField("Description", text: $description)
                    .focused($focusedField)
                
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                    .focused($focusedField)
                
                Picker("Category", selection: $category) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
            }
        }
        .navigationTitle("Add Expense")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    isPresented = false
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    addExpense()
                }
                .disabled(description.isEmpty || amount.isEmpty || !isValidAmount)
            }
        }
    }
    
    private func addExpense() {
        guard let amountValue = Double(amount) else { return }
        
        let expense = Expense(
            description: description,
            amount: amountValue,
            date: Date(),
            category: category,
            requestID: request.id
        )
        
        Task {
            await dataStore.addExpense(to: request, expense: expense)
        }
        
        // Reset fields after adding expense
        description = ""
        amount = ""
        category = .parts
        isPresented = false
        focusedField = false  // Dismiss keyboard
    }
}

struct FleetManagerVehicleRequestInfoCard: View {
    let request: MaintenanceServiceRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vehicle Information")
                .font(.headline)
            
            Divider()
            
            InfoRow(title: "Vehicle", value: request.vehicleName, icon: "car.fill")
            InfoRow(title: "Service Type", value: request.serviceType.rawValue, icon: "wrench.fill")
            InfoRow(title: "Priority", value: request.priority.rawValue, icon: "exclamationmark.triangle.fill")
            InfoRow(title: "Due Date", value: request.dueDate.formatted(date: .abbreviated, time: .shortened), icon: "calendar")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct FleetManagerInfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct FleetManagerMaintenanceServiceDetailsCard: View {
    let request: MaintenanceServiceRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Service Details")
                .font(.system(.headline, design: .default))
            
            Divider()
            
            Text(request.description)
                .font(.system(.subheadline, design: .default))
                .foregroundColor(.secondary)
            
            if let issueType = request.issueType {
                Text("Issue Type")
                    .font(.system(.subheadline, design: .default))
                    .fontWeight(.medium)
                    .padding(.top, 4)
                
                Text(issueType)
                    .font(.system(.subheadline, design: .default))
                    .foregroundColor(.secondary)
            }
            
            if !request.notes.isEmpty {
                Text("Notes")
                    .font(.system(.subheadline, design: .default))
                    .fontWeight(.medium)
                    .padding(.top, 4)
                
                Text(request.notes)
                    .font(.system(.subheadline, design: .default))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct FleetManagerSafetyChecksCard: View {
    let checks: [SafetyCheck]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Safety Checks")
                .font(.headline)
            
            Divider()
            
            ForEach(checks) { check in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: check.isChecked ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(check.isChecked ? .green : .gray)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(check.item)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if !check.notes.isEmpty {
                            Text(check.notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if check.id != checks.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}
