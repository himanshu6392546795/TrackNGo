import SwiftUI

struct InspectionItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    var isChecked: Bool = false
    var hasIssue: Bool = false
    var notes: String = ""
}

struct VehicleInspectionView: View {
    @Environment(\.presentationMode) var presentationMode
    let isPreTrip: Bool
    var onComplete: (Bool) -> Void

    @State private var inspectionItems: [InspectionItem] = []
    @State private var showingConfirmation = false
    @State private var currentSection = 0

    let sections = ["Exterior", "Interior", "Mechanical", "Safety"]

    init(isPreTrip: Bool, onComplete: @escaping (Bool) -> Void) {
        self.isPreTrip = isPreTrip
        self.onComplete = onComplete

        // Initialize with default items
        _inspectionItems = State(initialValue: [
            // Exterior
            InspectionItem(title: "Lights", description: "Check all exterior lights"),
            InspectionItem(title: "Tires", description: "Check tire pressure and wear"),
            InspectionItem(title: "Body Damage", description: "Inspect for any damage"),
            // Interior
            InspectionItem(title: "Dashboard", description: "Check all gauges and warning lights"),
            InspectionItem(title: "Seats & Belts", description: "Inspect seats and seatbelts"),
            InspectionItem(title: "Controls", description: "Test all controls and switches"),
            // Mechanical
            InspectionItem(title: "Engine", description: "Check engine operation"),
            InspectionItem(title: "Brakes", description: "Test brake system"),
            InspectionItem(title: "Fluid Levels", description: "Check all fluid levels"),
            // Safety
            InspectionItem(title: "Emergency Kit", description: "Verify emergency equipment"),
            InspectionItem(title: "Fire Extinguisher", description: "Check expiration and pressure"),
            InspectionItem(title: "First Aid Kit", description: "Verify contents and expiration")
        ])
    }

    private var allItemsChecked: Bool {
        inspectionItems.allSatisfy { item in
            item.isChecked && (!item.hasIssue || !item.notes.isEmpty)
        }
    }

    private var hasIssues: Bool {
        inspectionItems.contains { $0.hasIssue }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Section tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(sections.enumerated()), id: \.element) { index, section in
                                Button(action: { currentSection = index }) {
                                    Text(section)
                                        .font(.subheadline)
                                        .fontWeight(currentSection == index ? .semibold : .regular)
                                        .foregroundColor(currentSection == index ? .blue : .gray)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(currentSection == index ? Color.blue.opacity(0.1) : Color.clear)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Items for current section
                    let sectionItems = inspectionItems.filter { item in
                        switch currentSection {
                        case 0: // Exterior
                            return ["Lights", "Tires", "Body Damage"].contains(item.title)
                        case 1: // Interior
                            return ["Dashboard", "Seats & Belts", "Controls"].contains(item.title)
                        case 2: // Mechanical
                            return ["Engine", "Brakes", "Fluid Levels"].contains(item.title)
                        case 3: // Safety
                            return ["Emergency Kit", "Fire Extinguisher", "First Aid Kit"].contains(item.title)
                        default:
                            return false
                        }
                    }

                    ForEach(sectionItems) { item in
                        if let index = inspectionItems.firstIndex(where: { $0.id == item.id }) {
                            InspectionItemView(item: $inspectionItems[index])
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    if hasIssues {
                        Text("Please provide details for all reported issues")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.bottom, 8)
                    }

                    if currentSection < sections.count - 1 {
                        Button(action: { currentSection += 1 }) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                    } else {
                        Button(action: {
                            showingConfirmation = true
                        }) {
                            Text("Complete Inspection")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(allItemsChecked ? Color.green : Color(.systemGray4))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        .disabled(!allItemsChecked)
                    }
                }
                .padding()
                .background(
                    Color(.systemBackground)
                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: -3)
                )
            }
            .navigationTitle(isPreTrip ? "Pre-Trip Inspection" : "Post-Trip Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                    }
                }
            }
            .alert("Complete Inspection", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Confirm") {
                    // If issues exist, create a maintenance service request
                    if hasIssues {
                        // Gather details from all inspection items that reported an issue.
                        let issuesDescription = inspectionItems
                            .filter { $0.hasIssue }
                            .map { "\($0.title): \($0.notes)" }
                            .joined(separator: "\n")
                        
                        // Set the priority based on the type of inspection.
                        let priority: ServiceRequestPriority = isPreTrip ? .urgent : .low
                        
                        guard let trip = TripDataController.shared.currentTrip else { return }
                        // Create the new maintenance service request.
                        let newRequest = MaintenanceServiceRequest(
                            vehicleId: trip.vehicleDetails.id,
                            vehicleName: trip.vehicleDetails.name,
                            serviceType: .repair,
                            description: issuesDescription,
                            priority: priority,
                            date: Date(),
                            dueDate: Date().addingTimeInterval(86400), // due in 1 day; adjust as needed
                            status: .pending,
                            notes: "",
                            issueType: nil
                        )
                        
                        // Call the async insertion function.
                        Task {
                            do {
                                if isPreTrip {
                                    await SupabaseDataController.shared.updateVehicleStatus(newStatus: .underMaintenance, vehicleID: trip.vehicleDetails.id)
                                }
                                try await SupabaseDataController.shared.insertServiceRequest(request: newRequest)
                                print("Maintenance service request inserted successfully.")
                            } catch {
                                print("Error inserting maintenance request: \(error)")
                            }
                        }
                    }
                    onComplete(!hasIssues || !isPreTrip)
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                if hasIssues {
                    Text("Issues have been reported. A maintenance service request will be created.")
                } else {
                    Text("Are you sure you want to complete the inspection?")
                }
            }
        }
    }
}

struct InspectionItemView: View {
    @Binding var item: InspectionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main item row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { item.isChecked.toggle() }) {
                    ZStack {
                        Circle()
                            .fill(item.isChecked ? Color.green : Color(.tertiarySystemBackground))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(item.isChecked ? Color.green : Color(.systemGray4), lineWidth: 2)
                            )

                        if item.isChecked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(10, corners: item.isChecked && item.hasIssue ? [.topLeft, .topRight] : .allCorners)

            // Issue section (only shown when checked)
            if item.isChecked {
                Divider()
                    .padding(.horizontal)

                Button(action: { item.hasIssue.toggle() }) {
                    HStack(spacing: 10) {
                        Image(systemName: item.hasIssue ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                            .foregroundColor(item.hasIssue ? .red : .gray)

                        Text("Report Issue")
                            .font(.subheadline)
                            .foregroundColor(item.hasIssue ? .red : .gray)

                        Spacer()

                        if item.hasIssue {
                            Text("Tap to Clear")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(item.hasIssue ? .red : .secondary)
                            .opacity(item.hasIssue ? 1 : 0)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(10, corners: item.hasIssue ? [.bottomLeft, .bottomRight] : .allCorners)
            }

            // Issue details (only shown when issue is reported)
            if item.isChecked && item.hasIssue {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Issue Details")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .padding(.top, 4)

                    TextField("Describe the issue...", text: $item.notes, axis: .vertical)
                        .lineLimit(4)
                        .padding(12)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(item.notes.isEmpty ? Color.red : Color.clear, lineWidth: 1)
                        )
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(10, corners: [.bottomLeft, .bottomRight])
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// Helper extension for partial corner rounding
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

