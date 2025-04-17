import SwiftUI

struct MaintenancePersonnelDashboardView: View {
    @StateObject private var dataStore = MaintenancePersonnelDataStore()
    @State private var selectedStatus: ServiceRequestStatus = .pending
    @State private var selectedPriority: ServiceRequestPriority?
    @State private var showingProfile = false
    @State private var showingChat = false
    @State private var userID: UUID?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Overview
                    StatsOverviewView(
                        dataStore: dataStore,
                        selectedStatus: $selectedStatus
                    )
                    .padding(.horizontal)
                    
                    // Priority Filter
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Filter by Priority")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                PriorityFilterButton(
                                    title: "All",
                                    isSelected: selectedPriority == nil,
                                    color: .blue
                                ) {
                                    selectedPriority = nil
                                }
                                
                                PriorityFilterButton(
                                    title: "High",
                                    isSelected: selectedPriority == .high,
                                    color: .orange
                                ) {
                                    selectedPriority = .high
                                }
                                
                                PriorityFilterButton(
                                    title: "Medium",
                                    isSelected: selectedPriority == .medium,
                                    color: .yellow
                                ) {
                                    selectedPriority = .medium
                                }
                                
                                PriorityFilterButton(
                                    title: "Low",
                                    isSelected: selectedPriority == .low,
                                    color: .green
                                ) {
                                    selectedPriority = .low
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Service Requests List
                    LazyVStack(spacing: 16) {
                        ForEach(filteredRequests) { request in
                            NavigationLink(destination: MaintenancePersonnelServiceRequestDetailView(request: request, dataStore: dataStore)) {
                                ServiceRequestCard(request: request, dataStore: dataStore)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showingChat = true }) {
                            Image(systemName: "message.fill")
                                .font(.title2)
                        }
                        
                        Button(action: { showingProfile = true }) {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                MaintenancePersonnelProfileView()
            }
            .sheet(isPresented: $showingChat) {
                MaintenancePersonnelChatView()
            }
            .refreshable {
                await dataStore.loadData()
            }
        }
        .task {
            self.userID = await SupabaseDataController.shared.getUserID()
        }
    }
    
    private var filteredRequests: [MaintenanceServiceRequest] {
        dataStore.serviceRequests.filter { request in
            // Always filter by status.
            guard request.status == selectedStatus else { return false }
            
            // If a priority is selected, filter by it.
            if let priority = selectedPriority, request.priority != priority {
                return false
            }
            
            // If there's a valid userID, only allow requests with no assigned personnel or those matching the user.
            if let currentUserID = userID {
                return request.personnelID == nil || request.personnelID == currentUserID
            }
            
            // If userID is nil, do not filter on personnel.
            return true
        }
    }
}

struct StatsOverviewView: View {
    @ObservedObject var dataStore: MaintenancePersonnelDataStore
    @Binding var selectedStatus: ServiceRequestStatus
    @State var userID: UUID?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Overview")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                DashboardStatCard(
                    title: "Pending",
                    count: pendingCount,
                    icon: "clock.fill",
                    iconColor: Color.orange,
                    isSelected: selectedStatus == .pending
                ) {
                    selectedStatus = .pending
                }
                
                DashboardStatCard(
                    title: "In Progress",
                    count: inProgressCount,
                    icon: "wrench.fill",
                    iconColor: Color.blue,
                    isSelected: selectedStatus == .inProgress
                ) {
                    selectedStatus = .inProgress
                }
                
                DashboardStatCard(
                    title: "Completed",
                    count: completedCount,
                    icon: "checkmark.circle.fill",
                    iconColor: Color.green,
                    isSelected: selectedStatus == .completed
                ) {
                    selectedStatus = .completed
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .task {
            userID = await SupabaseDataController.shared.getUserID()
        }
    }
    
    private var filteredRequests: [MaintenanceServiceRequest] {
        dataStore.serviceRequests.filter { request in
            // If there's a valid userID, only allow requests with no assigned personnel or those matching the user.
            if let currentUserID = userID {
                return request.personnelID == nil || request.personnelID == currentUserID
            }
            
            // If userID is nil, do not filter on personnel.
            return true
        }
    }

    
    private var pendingCount: Int {
        filteredRequests.filter { $0.status == .pending }.count
    }
    
    private var inProgressCount: Int {
        filteredRequests.filter { $0.status == .inProgress }.count
    }
    
    private var completedCount: Int {
        filteredRequests.filter { $0.status == .completed }.count
    }
}

struct DashboardStatCard: View {
    let title: String
    let count: Int
    let icon: String
    let iconColor: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : iconColor)
                
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : iconColor)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? iconColor : iconColor.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct PriorityFilterButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? color : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct ServiceRequestCard: View {
    let request: MaintenanceServiceRequest
    @ObservedObject var dataStore: MaintenancePersonnelDataStore
    @State private var expenses: [Expense] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.vehicleName)
                        .font(.headline)
                    
                    Text(request.serviceType.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                PriorityBadge(priority: request.priority)
            }
            
            Divider()
            
            // Details
            VStack(alignment: .leading, spacing: 8) {
                Text(request.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.gray)
                    Text(request.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    StatusBadge(status: request.status)
                }
                
                if request.status == .inProgress {
                    Label("\(expenses.count) Expenses", systemImage: "dollarsign.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            // Recent Expenses Preview
            if request.status == .inProgress && !expenses.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Expenses")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    ForEach(expenses.prefix(2)) { expense in
                        HStack {
                            Text(expense.description)
                                .font(.caption)
                            Spacer()
                            Text("$\(expense.amount, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    if expenses.count > 2 {
                        Text("+ \(expenses.count - 2) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(priorityColor.opacity(0.3), lineWidth: 2)
        )
        .onAppear {
            fetchExpensesForRequest()
        }
    }
    
    private var priorityColor: Color {
        switch request.priority {
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        case .urgent: return .red
        }
    }
    
    private func fetchExpensesForRequest() {
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
}

struct PriorityBadge: View {
    let priority: ServiceRequestPriority
    
    var body: some View {
        Text(priority.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor.opacity(0.2))
            .foregroundColor(priorityColor)
            .cornerRadius(8)
    }
    
    private var priorityColor: Color {
        switch priority {
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        case .urgent: return .red
        }
    }
}

struct StatusBadge: View {
    let status: ServiceRequestStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .inProgress: return .blue
        case .completed: return .green
        case .cancelled: return .red
        case .assigned: return .green
        }
    }
}

#Preview {
    MaintenancePersonnelDashboardView()
} 
