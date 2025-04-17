import SwiftUI
import CoreLocation
import MapKit
import Foundation

// Custom null value that conforms to Encodable
struct EncodableNull: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}

struct FleetTripsView: View {
    @ObservedObject private var tripController = TripDataController.shared
    @State private var showingError = false
    @State private var selectedFilter = 1 // Default to Upcoming
    @State private var isEditing = false
    @State private var editedDestination: String = ""
    @State private var editedAddress: String = ""
    @State private var editedNotes: String = ""
    @State private var calculatedDistance: String = ""
    @State private var calculatedTime: String = ""
    @State private var selectedDriverId: UUID? = nil
    // Define tab types
    enum TabType: Int, CaseIterable {
        case current = 0
        case upcoming = 1
        case completed = 2
        
        var title: String {
            switch self {
            case .current: return "Current"
            case .upcoming: return "Upcoming"
            case .completed: return "Completed"
            }
        }
    }
    
    var currentTrips: [Trip] {
        // Get all trips with in-progress status
        return tripController.getAllTrips().filter { $0.status == .inProgress }
    }
    
    var upcomingTrips: [Trip] {
        // Get all trips with pending or assigned status
        return tripController.getAllTrips().filter { $0.status == .pending || $0.status == .assigned }
    }
    
    var completedTrips: [Trip] {
        // Get all completed trips - either from recentDeliveries or directly from trips
        let deliveredTrips = tripController.getAllTrips().filter { $0.status == .delivered }
        
        if !deliveredTrips.isEmpty {
            return deliveredTrips
        }
        
        // Fallback to recentDeliveries if needed
        return tripController.recentDeliveries.compactMap { delivery in
            // Create a mock vehicle for the delivery
            let vehicle = Vehicle.mockVehicle(licensePlate: delivery.vehicle)
            
            // Create a SupabaseTrip with the delivery information
            let supabaseTrip = SupabaseTrip(
                id: delivery.id,
                destination: delivery.location,
                trip_status: "delivered",
                has_completed_pre_trip: true,
                has_completed_post_trip: true,
                vehicle_id: vehicle.id,
                driver_id: nil, secondary_driver_id: nil,
                start_time: nil,
                end_time: nil,
                notes: delivery.notes,
                created_at: Date(),
                updated_at: Date(),
                is_deleted: false,
                start_latitude: 0,
                start_longitude: 0,
                end_latitude: 0,
                end_longitude: 0,
                pickup: delivery.location,
                estimated_distance: nil,
                estimated_time: nil
            )
            
            return Trip(from: supabaseTrip, vehicle: vehicle)
        }
    }
    
    var filteredTrips: [Trip] {
        switch selectedFilter {
        case 0: // Current
            return currentTrips
        case 1: // Upcoming
            return upcomingTrips
        case 2: // Completed
            return completedTrips
        default:
            return []
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter control with counts
                Picker("Trip Filter", selection: $selectedFilter) {
                    ForEach(TabType.allCases.map { $0.rawValue }, id: \.self) { index in
                        Text("\(TabType(rawValue: index)?.title ?? "") (\(getTripCount(for: index)))")
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Simple header section
                HStack {
                    Text(getHeaderTitle())
                        .font(.headline)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Trip list
                if filteredTrips.isEmpty {
                    EmptyTripsView(filterType: selectedFilter)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredTrips) { trip in
                                NavigationLink(destination: TripDetailView(trip: trip)) {
                                    TripCardView(trip: trip)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Trips")
            .alert("Error", isPresented: $showingError) {
                Button("OK") {
                    showingError = false
                }
            } message: {
                if let error = tripController.error {
                    switch error {
                    case .fetchError(let message),
                         .decodingError(let message),
                         .vehicleError(let message),
                         .updateError(let message),
                         .locationError(let message):
                        Text(message)
                    }
                }
            }
            .onChange(of: tripController.error) { error, _ in
                showingError = error != nil
            }
//            .onAppear {
//                Task {
//                    await tripController.refreshAllTrips()
//                }
//            }
        }
    }
    
    private func getTripCount(for filterIndex: Int) -> Int {
        switch filterIndex {
        case 0: // Current
            return currentTrips.count
        case 1: // Upcoming
            return upcomingTrips.count
        case 2: // Completed
            return completedTrips.count
        default:
            return 0
        }
    }
    
    private func getHeaderTitle() -> String {
        switch selectedFilter {
        case 0:
            return "Current Trips"
        case 1:
            return "Upcoming Trips"
        case 2:
            return "Completed Trips"
        default:
            return "All Trips"
        }
    }
}

// Update EmptyTripsView to show different messages based on filter
struct EmptyTripsView: View {
    let filterType: Int
    
    var emptyMessage: String {
        switch filterType {
        case 0:
            return "No trips currently in progress"
        case 1:
            return "No upcoming trips scheduled"
        case 2:
            return "No completed trips"
        default:
            return "No trips available"
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 64))
                .foregroundColor(Color(.systemGray4))
            
            Text(emptyMessage)
                .font(.system(.headline, design: .default))
                .multilineTextAlignment(.center)
            
            Text("Add trips to manage your deliveries")
                .font(.system(.subheadline, design: .default))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Trip card view
enum ActiveSheet: Identifiable {
    case assign, detail
    
    var id: Int { hashValue }
}

struct TripCardView: View {
    let trip: Trip
    @State private var showingDetails = false
    @StateObject private var crewController = CrewDataController.shared
    @State var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status badge only (removed ETA)
            HStack {
                Text(statusText)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
                
                Spacer()
            }
            
            // Trip name
            Text(trip.displayName)
                .font(.headline)
            
            // Destination
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
                
                Text(trip.destination)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Distance if available
            if !trip.distance.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "ruler.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                    
                    Text(trip.distance)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Bottom section with vehicle info and driver name
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vehicle:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(trip.vehicleDetails.name)
                        .font(.subheadline)
                }
                
                Spacer()
                
                // Driver information
                if let driverId = trip.driverId,
                   let driver = crewController.drivers.first(where: { $0.userID == driverId }) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Driver:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(driver.name)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                } else {
                    Text("Unassigned")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onTapGesture {
            showingDetails = true
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Alert"),
                message: Text("Are you sure you want to delete this trip?"),
                primaryButton: .destructive(Text("Yes")) {
                    Task {
                        SupabaseDataController.shared.deleteTrip(tripID: trip.id)
                        try await TripDataController.shared.fetchAllTrips()
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingDetails) {
            TripDetailView(trip: trip)
        }
        .contextMenu {
            if trip.status == .pending || trip.status == .assigned || trip.status == .delivered {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete Trip", systemImage: "trash")
                }
            }
        }
        .onAppear {
            crewController.update()
        }
    }
    
    private var statusText: String {
        switch trip.status {
        case .inProgress:
            if !trip.hasCompletedPreTrip {
                return "Initiated"
            } else if trip.hasCompletedPreTrip && !trip.hasCompletedPostTrip {
                return "Pre-Trip Completed"
            } else if trip.hasCompletedPreTrip && trip.hasCompletedPostTrip {
                return "Post-Trip Completed"
            }
            return "In Progress"
        case .pending:
            return "Pending"
        case .delivered:
            return "Delivered"
        case .assigned:
            return "Assigned"
        }
    }
    
    private var statusColor: Color {
        switch trip.status {
        case .inProgress:
            if !trip.hasCompletedPreTrip {
                return .orange // Initiated
            } else if trip.hasCompletedPreTrip && !trip.hasCompletedPostTrip {
                return .blue // Pre-Trip Completed
            } else if trip.hasCompletedPreTrip && trip.hasCompletedPostTrip {
                return .green // Post-Trip Completed
            }
            return .blue // In Progress
        case .pending:
            return .green
        case .delivered:
            return .gray
        case .assigned:
            return .yellow
        }
    }
}

// Trip status badge
struct TripStatusBadge: View {
    let status: TripStatus
    
    var body: some View {
        Text(displayText)
            .font(.system(.subheadline, design: .default))
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(8)
    }
    
    var displayText: String {
        switch status {
        case .pending: return "Unassigned"
        case .assigned: return "Assigned"
        case .inProgress: return "In Progress"
        case .delivered: return "Completed"
        }
    }
    
    var backgroundColor: Color {
        switch status {
        case .pending: return Color(.systemGray5)
        case .assigned: return Color.blue.opacity(0.15)
        case .inProgress: return Color.orange.opacity(0.15)
        case .delivered: return Color.green.opacity(0.15)
        }
    }
    
    var textColor: Color {
        switch status {
        case .pending: return Color(.darkGray)
        case .assigned: return Color.blue
        case .inProgress: return Color.orange
        case .delivered: return Color.green
        }
    }
}

// Trip detail view
struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingAssignSheet = false
    @State private var showingDeleteAlert = false
    @StateObject private var tripController = TripDataController.shared
    let trip: Trip
    
    // Editing state variables
    @State private var isEditing = false
    @State private var editedDestination: String = ""
    @State private var editedAddress: String = ""
    @State private var editedNotes: String = ""
    @State private var calculatedDistance: String = ""
    @State private var calculatedTime: String = ""
    @State private var selectedDriverId: UUID? = nil
    
    // Delivery receipt state
    @State private var showingDeliveryReceipt = false
    @State private var pdfData: Data? = nil
    @State private var pdfError: String? = nil
    @State private var showingPDFError = false
    @State private var showingSignatureSheet = false
    @State private var fleetManagerSignature: Data? = nil
    
    // Location search state
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var activeTextField: LocationField? = nil
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var searchCompleterDelegate: TripsSearchCompleterDelegate? = nil
    @State private var destinationSelected = false
    @State private var addressSelected = false
    
    // Touched states
    @State private var destinationEdited = false
    @State private var addressEdited = false
    @State private var notesEdited = false
    
    // Save operation state
    @State private var isSaving = false
    @State private var showingSaveSuccess = false
    
    // Location field enum
    enum LocationField {
        case destination, address
    }
    
    // Field validations
    private var isDestinationValid: Bool {
        let trimmed = editedDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
    }
    
    private var isAddressValid: Bool {
        let trimmed = editedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
    }
    
    // Overall form validation
    private var isFormValid: Bool {
        isDestinationValid && isAddressValid
    }
    
    private func calculateFuelCost(from distance: String) -> (String, Double) {
        // Extract numeric value from distance string
        let numericDistance = distance.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        
        if let distance = Double(numericDistance) {
            // Calculate fuel cost ($0.5 per km/mile)
            let fuelCost = distance * 0.5
            return (String(format: "$%.2f", fuelCost), fuelCost)
        }
        return ("N/A", 0.0)
    }
    
    private func calculateTotalRevenue(distance: String, fuelCost: Double) -> String {
        let numericDistance = distance.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        
        if let distance = Double(numericDistance) {
            // Total Revenue = Fuel Cost + ($0.25 × Distance) + $50
            let distanceRevenue = distance * 0.25
            let totalRevenue = fuelCost + distanceRevenue + 50.0
            return String(format: "$%.2f", totalRevenue)
        }
        return "N/A"
    }

    var body: some View {
        NavigationView {
            List {
                // Trip Information Section with driver assignment
                Section(header: Text("TRIP INFORMATION")) {
                    if isEditing {
                        // Editable Trip ID (non-editable)
                        HStack {
                            Text("Trip ID")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(trip.id.uuidString)
                        }
                        
                        // Editable Destination
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Destination", text: $editedDestination)
                                .onChange(of: editedDestination) { _, newValue in 
                                    destinationEdited = true
                                    
                                    // If destination was previously selected and user is editing
                                    if destinationSelected && !newValue.isEmpty {
                                        if newValue != editedDestination {
                                            destinationSelected = false
                                        }
                                    }
                                    
                                    // Only show search results if not already selected and query has 3+ chars
                                    if !destinationSelected && newValue.count > 2 {
                                        searchCompleter.queryFragment = newValue
                                        activeTextField = .destination
                                    } else {
                                        searchResults = []
                                    }
                                }
                            if destinationEdited && !isDestinationValid {
                                Text("Destination cannot be empty")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Editable Address
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Address", text: $editedAddress)
                                .onChange(of: editedAddress) { _, newValue in 
                                    addressEdited = true
                                    
                                    // If address was previously selected and user is editing
                                    if addressSelected && !newValue.isEmpty {
                                        if newValue != editedAddress {
                                            addressSelected = false
                                        }
                                    }
                                    
                                    // Only show search results if not already selected and query has 3+ chars
                                    if !addressSelected && newValue.count > 2 {
                                        searchCompleter.queryFragment = newValue
                                        activeTextField = .address
                                    } else {
                                        searchResults = []
                                    }
                                }
                            if addressEdited && !isAddressValid {
                                Text("Address cannot be empty")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Search Results if any - only show when appropriate based on selection state
                        if !searchResults.isEmpty && activeTextField != nil && 
                           ((activeTextField == .destination && !destinationSelected) || 
                            (activeTextField == .address && !addressSelected)) {
                            TripsLocationSearchResults(results: searchResults) { result in
                                if activeTextField == .destination {
                                    destinationSelected = true
                                    searchForLocation(result.title, isDestination: true)
                                } else {
                                    addressSelected = true
                                    searchForLocation(result.title, isDestination: false)
                                }
                            }
                        }
                        
                        // Non-editable distance
                        if !calculatedDistance.isEmpty {
                            HStack {
                                Text("Distance")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(calculatedDistance)
                                    .foregroundColor(calculatedDistance != trip.distance ? .blue : .primary)
                            }
                        }
                        
                        // Driver assignment
                        HStack {
                            Text("Driver")
                                .foregroundColor(.secondary)
                            Spacer()
                            
                            Menu {
                                // Option to unassign driver
                                Button(action: {
                                    selectedDriverId = nil
                                }) {
                                    HStack {
                                        Text("Unassign driver")
                                            .foregroundColor(.red)
                                        Spacer()
                                        if selectedDriverId == nil {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                
                                Divider()
                                
                                // Available drivers
                                ForEach(CrewDataController.shared.drivers.filter { $0.status == .available }, id: \.userID) { driver in
                                    Button(action: {
                                        selectedDriverId = driver.userID
                                    }) {
                                        HStack {
                                            Text(driver.name)
                                            Spacer()
                                            if selectedDriverId == driver.userID {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    if let driverId = selectedDriverId,
                                       let driver = CrewDataController.shared.drivers.first(where: { $0.userID == driverId }) {
                                        Text(driver.name)
                                            .foregroundColor(.primary)
                                    } else {
                                        Text("Unassigned")
                                            .foregroundColor(.gray)
                                    }
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            .onAppear {
                                // Ensure crew data is updated when menu appears
                                CrewDataController.shared.update()
                            }
                        }
                    } else {
                        TripDetailRow(icon: "number", title: "Trip ID", value: trip.id.uuidString)
                        TripDetailRow(icon: "mappin.circle.fill", title: "Destination", value: trip.destination)
                        TripDetailRow(icon: "location.fill", title: "Address", value: trip.address)
                        if !trip.distance.isEmpty {
                            TripDetailRow(icon: "arrow.left.and.right", title: "Distance", value: trip.distance)
                        }
                        
                        // Driver information
                        if let driverId = trip.driverId,
                           let driver = CrewDataController.shared.drivers.first(where: { $0.userID == driverId }) {
                            TripDetailRow(icon: "person.fill", title: "Driver", value: driver.name)
                        } else {
                            TripDetailRow(icon: "person.fill", title: "Driver", value: "Unassigned")
                        }
                    }
                }
                
                // Vehicle Information Section
                Section(header: Text("VEHICLE INFORMATION")) {
                    TripDetailRow(icon: "car.fill", title: "Vehicle Type", value: trip.vehicleDetails.bodyType.rawValue)
                    TripDetailRow(icon: "number", title: "License Plate", value: trip.vehicleDetails.licensePlate)
                }
                
                // Delivery Status Section
                Section(header: Text("DELIVERY STATUS")) {
                    TripDetailRow(icon: statusIcon, title: "Status", value: statusText)
                    TripDetailRow(
                        icon: trip.hasCompletedPreTrip ? "checkmark.circle.fill" : "clock.badge.checkmark.fill",
                        title: "Pre-Trip Inspection",
                        value: trip.hasCompletedPreTrip ? "Completed" : "Required"
                    )
                    TripDetailRow(
                        icon: trip.hasCompletedPostTrip ? "checkmark.circle.fill" : "checkmark.shield.fill",
                        title: "Post-Trip Inspection",
                        value: trip.hasCompletedPostTrip ? "Completed" : "Required"
                    )
                }
                
                // Proof of Delivery Section (for completed trips)
//                if trip.status == .delivered {
//                    Section(header: Text("PROOF OF DELIVERY")) {
//                        Button(action: {
//                            do {
//                                pdfData = try TripDataController.shared.generateDeliveryReceipt(for: trip, signature: fleetManagerSignature)
//                                showingDeliveryReceipt = true
//                            } catch {
//                                pdfError = error.localizedDescription
//                                showingPDFError = true
//                            }
//                        }) {
//                            HStack {
//                                Image(systemName: "doc.text.fill")
//                                    .foregroundColor(.blue)
//                                Text("Delivery Receipt")
//                                Spacer()
//                                Image(systemName: "chevron.right")
//                                    .foregroundColor(.gray)
//                            }
//                        }
//                        
//                        Button(action: {
//                            showingSignatureSheet = true
//                        }) {
//                            HStack {
//                                Image(systemName: "signature")
//                                    .foregroundColor(.blue)
//                                Text("Fleet Manager Signature")
//                                Spacer()
//                                if fleetManagerSignature != nil {
//                                    Image(systemName: "checkmark.circle.fill")
//                                        .foregroundColor(.green)
//                                }
//                                Image(systemName: "chevron.right")
//                                    .foregroundColor(.gray)
//                            }
//                        }
//                        
//                        if let pdfData = pdfData {
//                            ShareLink(item: pdfData, preview: SharePreview("Delivery Receipt", image: Image(systemName: "doc.fill"))) {
//                                HStack {
//                                    Image(systemName: "square.and.arrow.up")
//                                        .foregroundColor(.blue)
//                                    Text("Download Receipt")
//                                    Spacer()
//                                    Image(systemName: "chevron.right")
//                                        .foregroundColor(.gray)
//                                }
//                            }
//                        }
//                    }
//                }
                
                // Notes Section
                Section(header: Text("NOTES")) {
                    if isEditing {
                        TextEditor(text: $editedNotes)
                            .frame(minHeight: 100)
                            .onChange(of: editedNotes) { _, _ in notesEdited = true }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            if trip.notes != nil {
                                Text("Trip Details")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Trip: \(trip.id.uuidString)")
                                    Text("From: \(trip.address)")
                                    Text("To: \(trip.destination)")
                                    
                                    if !trip.distance.isEmpty {
                                        Text("Distance: \(trip.distance)")
                                    }
                                    
                                    // Display driver information if available
                                    if let driverId = trip.driverId,
                                       let driver = CrewDataController.shared.drivers.first(where: { $0.userID == driverId }) {
                                        Text("Driver: \(driver.name)")
                                    } else {
                                        Text("Driver: Unassigned")
                                    }
                                    
                                    let (fuelCostString, fuelCostValue) = calculateFuelCost(from: trip.distance)
                                    Text("Estimated Fuel Cost: \(fuelCostString)")
                                    Text("Total Revenue: \(calculateTotalRevenue(distance: trip.distance, fuelCost: fuelCostValue))")
                                }
                                .foregroundColor(.primary)
                            }
                        }
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                    }
                }
                
                // Add Assign Driver Button for unassigned trips only
                if trip.status == .pending && trip.driverId == nil {
                    Section {
                        Button(action: {
                            showingAssignSheet = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.blue)
                                Text("Assign Driver")
                                    .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                // Delete section for upcoming trips
                if trip.status == .pending || trip.status == .assigned {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete Trip")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                initializeEditingFields()
                setupSearchCompleter()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if trip.status == .pending || trip.status == .assigned {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(isEditing ? "Save" : "Edit") {
                            if isEditing {
                                if isFormValid {
                                    saveChanges()
                                }
                            } else {
                                initializeEditingFields()
                                isEditing.toggle()
                            }
                        }
                        .disabled(isEditing && !isFormValid)
                    }
                }
            }
            .alert("Delete Trip", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteTrip()
                }
            } message: {
                Text("Are you sure you want to delete this trip? This action cannot be undone.")
            }
            .alert("Changes Saved", isPresented: $showingSaveSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Trip details have been updated successfully.")
            }
            .sheet(isPresented: $showingAssignSheet) {
                AssignDriverView(trip: trip)
            }
            .sheet(isPresented: $showingDeliveryReceipt) {
                NavigationView {
                    if let data = pdfData {
                        PDFViewer(data: data)
                            .navigationTitle("Delivery Receipt")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        showingDeliveryReceipt = false
                                    }
                                }
                            }
                    }
                }
            }
            .sheet(isPresented: $showingSignatureSheet) {
                NavigationView {
                    SignatureCaptureView(signature: $fleetManagerSignature)
                        .navigationTitle("Fleet Manager Signature")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") {
                                    showingSignatureSheet = false
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingSignatureSheet = false
                                }
                            }
                        }
                }
            }
            .alert("Error", isPresented: $showingPDFError) {
                Button("OK") {
                    showingPDFError = false
                }
            } message: {
                Text(pdfError ?? "Failed to generate delivery receipt")
            }
        }
    }
    
    private func initializeEditingFields() {
        editedDestination = trip.destination
        editedAddress = trip.address
        editedNotes = trip.notes ?? ""
        calculatedDistance = trip.distance
        calculatedTime = trip.eta
        selectedDriverId = trip.driverId
        
        destinationEdited = false
        addressEdited = false
        notesEdited = false
    }
    
    private func setupSearchCompleter() {
        searchCompleter.resultTypes = .pointOfInterest
        searchCompleter.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629), // Center of India
            span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
        )
        
        searchCompleterDelegate = TripsSearchCompleterDelegate { results in
            searchResults = Array(results.prefix(5))
        }
        
        searchCompleter.delegate = searchCompleterDelegate
    }
    
    private func searchForLocation(_ query: String, isDestination: Bool) {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        searchRequest.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629), // Center of India
            span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
        )
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let response = response, error == nil else {
                print("Error searching for location: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            if let firstItem = response.mapItems.first {
                let selectedCoordinate = firstItem.placemark.coordinate
                
                if isDestination {
                    self.editedDestination = query
                    
                    // If we also have a source location, calculate distance
                    if !self.trip.startingPoint.isEmpty {
                        // Get coordinates for the source location
                        self.getCoordinatesForAddress(self.trip.startingPoint) { sourceCoordinate in
                            if let sourceCoordinate = sourceCoordinate {
                                self.calculateDistance(from: sourceCoordinate, to: selectedCoordinate)
                            }
                        }
                    }
                } else {
                    self.editedAddress = query
                    
                    // If we also have a destination, calculate distance
                    if !self.editedDestination.isEmpty {
                        // Get coordinates for the destination
                        self.getCoordinatesForAddress(self.editedDestination) { destinationCoordinate in
                            if let destinationCoordinate = destinationCoordinate {
                                self.calculateDistance(from: selectedCoordinate, to: destinationCoordinate)
                            }
                        }
                    }
                }
                
                // Clear search results
                self.hideSearchResults()
            }
        }
    }
    
    private func hideSearchResults() {
        searchResults = []
        activeTextField = nil
    }
    
    private func getCoordinatesForAddress(_ address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let placemark = placemarks?.first, let location = placemark.location {
                completion(location.coordinate)
            } else {
                completion(nil)
            }
        }
    }
    
    private func calculateDistance(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        let sourcePlacemark = MKPlacemark(coordinate: source)
        let destinationPlacemark = MKPlacemark(coordinate: destination)
        
        let directionRequest = MKDirections.Request()
        directionRequest.source = MKMapItem(placemark: sourcePlacemark)
        directionRequest.destination = MKMapItem(placemark: destinationPlacemark)
        directionRequest.transportType = .automobile
        
        let directions = MKDirections(request: directionRequest)
        directions.calculate { response, error in
            guard let response = response, let route = response.routes.first else {
                print("Error calculating route: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Get distance in kilometers
            let distanceInMeters = route.distance
            let distanceInKilometers = distanceInMeters / 1000
            
            // Get estimated time in hours and minutes
            let timeInSeconds = route.expectedTravelTime
            let hours = Int(timeInSeconds / 3600)
            let minutes = Int((timeInSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
            
            // Update the calculated values
            DispatchQueue.main.async {
                self.calculatedDistance = String(format: "%.1f km", distanceInKilometers)
                if hours > 0 {
                    self.calculatedTime = "\(hours)h \(minutes)m"
                } else {
                    self.calculatedTime = "\(minutes)m"
                }
            }
        }
    }
    
    private func saveChanges() {
        guard !isSaving && isFormValid else { return }
        
        isSaving = true
        
        var updatedTrip = trip
        updatedTrip.destination = editedDestination
        updatedTrip.address = editedAddress
        
        // Update notes with the latest information including destination, distance, and assigned driver
        let driverInfo: String
        if let driverId = selectedDriverId,
           let driver = CrewDataController.shared.drivers.first(where: { $0.userID == driverId }) {
            driverInfo = "Driver: \(driver.name)"
        } else {
            driverInfo = "Driver: Unassigned"
        }
        
        let updatedNotes = """
        Trip: \(trip.id.uuidString)
        From: \(editedAddress)
        To: \(editedDestination)
        Distance: \(calculatedDistance)
        Estimated Time: \(calculatedTime)
        \(driverInfo)
        """
        updatedTrip.notes = updatedNotes
        
        // Update distance and time if they have changed
        let hasDistanceChanged = calculatedDistance != trip.distance && !calculatedDistance.isEmpty
        let hasTimeChanged = calculatedTime != trip.eta && !calculatedTime.isEmpty
        
        // Check if driver assignment has changed
        let hasDriverChanged = selectedDriverId != trip.driverId
        
        Task {
            do {
                // First update trip details
                try await SupabaseDataController.shared.updateTripDetails(
                    id: trip.id,
                    destination: editedDestination,
                    address: editedAddress,
                    notes: updatedNotes,
                    distance: hasDistanceChanged ? calculatedDistance : nil,
                    time: hasTimeChanged ? calculatedTime : nil
                )
                
                // If driver assignment has changed, update it
                if hasDriverChanged {
                    if let driverId = selectedDriverId {
                        try await SupabaseDataController.shared.updateTrip(id: trip.id, driverId: driverId)
                        
                        // If trip is in pending state and being assigned a driver, update status to assigned
                        if trip.status == .pending {
                            try await SupabaseDataController.shared.updateTrip(id: trip.id, status: "assigned")
                        }
                    } else {
                        // If driver is being unassigned, reset to pending status
                        try await SupabaseDataController.shared.updateTrip(id: trip.id, status: "pending")
                        
                        // Reset driver ID to null using EncodableNull instead of NSNull
                        try await SupabaseDataController.shared.databaseFrom("trips")
                            .update(["driver_id": EncodableNull()])
                            .eq("id", value: trip.id)
                            .execute()
                    }
                }
                
                await tripController.refreshAllTrips()
                
                await MainActor.run {
                    isSaving = false
                    isEditing = false
                    showingSaveSuccess = true
                }
            } catch {
                print("Error updating trip: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
    
    private func deleteTrip() {
        Task {
            do {
                SupabaseDataController.shared.deleteTrip(tripID: trip.id)
                await tripController.refreshTrips()
                await tripController.refreshAllTrips()
                try await tripController.fetchAllTrips()
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
    
    private var statusText: String {
        switch trip.status {
        case .inProgress:
            if !trip.hasCompletedPreTrip {
                return "Initiated"
            } else if trip.hasCompletedPreTrip && !trip.hasCompletedPostTrip {
                return "Pre-Trip Completed"
            } else if trip.hasCompletedPreTrip && trip.hasCompletedPostTrip {
                return "Post-Trip Completed"
            }
            return "In Progress"
        case .pending:
            return "Pending"
        case .delivered:
            return "Delivered"
        case .assigned:
            return "Assigned"
        }
    }
    
    private var statusIcon: String {
        switch trip.status {
        case .inProgress:
            if !trip.hasCompletedPreTrip {
                return "play.circle.fill" // Initiated
            } else if trip.hasCompletedPreTrip && !trip.hasCompletedPostTrip {
                return "checkmark.circle.fill" // Pre-Trip Completed
            } else if trip.hasCompletedPreTrip && trip.hasCompletedPostTrip {
                return "checkmark.shield.fill" // Post-Trip Completed
            }
            return "car.circle.fill" // In Progress
        case .pending:
            return "clock.fill"
        case .delivered:
            return "checkmark.circle.fill"
        case .assigned:
            return "person.fill"
        }
    }
}

// Map Placeholder
struct MapPlaceholder: View {
    var body: some View {
        ZStack {
            Color(.systemGray6)
            
            VStack {
                Image(systemName: "map.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
                
                Text("Map View")
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
        }
    }
}

// Labeled Content View
struct LabeledContent: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }
}

// Driver Assignment View
struct AssignDriverView: View {
    @Environment(\.dismiss) private var dismiss
    // Remove or keep crewController if needed for other purposes.
    @StateObject private var tripController = TripDataController.shared
    let trip: Trip
    
    @State private var selectedDriverId: UUID?
    @State private var selectedSecondDriverId: UUID?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    
    // Fetched available drivers for the trip duration.
    @State private var fetchedAvailableDrivers: [Driver] = []
    
    // If the trip distance is greater than 500, it's considered a long trip.
    private var isLongTrip: Bool {
        // Filter to include digits and the decimal separator
        let numericDistanceString = trip.distance.filter { "0123456789.".contains($0) }
        if let distance = Double(numericDistanceString) {
            return distance > 500
        }
        return false
    }
    
    // Use the fetched drivers instead of the crewController drivers.
    private var availableDrivers: [Driver] {
        return fetchedAvailableDrivers
    }
    
    // Exclude the driver already selected as primary.
    private var availableSecondDrivers: [Driver] {
        if let firstDriverId = selectedDriverId {
            return availableDrivers.filter { $0.userID != firstDriverId }
        }
        return availableDrivers
    }
    
    var body: some View {
        NavigationView {
            List {
                if availableDrivers.isEmpty {
                    Text("No available drivers")
                        .foregroundColor(.gray)
                } else {
                    // First Driver Section
                    Section(header: Text(isLongTrip ? "PRIMARY DRIVER" : "DRIVER")) {
                        ForEach(availableDrivers) { driver in
                            DriverRow(driver: driver, isSelected: selectedDriverId == driver.userID)
                                .onTapGesture {
                                    selectedDriverId = driver.userID
                                    // If the second driver is the same as the first, deselect it
                                    if selectedSecondDriverId == driver.userID {
                                        selectedSecondDriverId = nil
                                    }
                                }
                        }
                    }
                    
                    // Second Driver Section (only for long trips)
                    if isLongTrip {
                        Section(header: Text("SECONDARY DRIVER (Required for trips > 500km)")) {
                            ForEach(availableSecondDrivers) { driver in
                                DriverRow(driver: driver, isSelected: selectedSecondDriverId == driver.userID)
                                    .onTapGesture {
                                        selectedSecondDriverId = driver.userID
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Assign Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Assign") {
                        assignDriver()
                    }
                    .disabled(!canAssign)
                }
            }
            .onAppear {
                fetchAvailableDrivers()
            }
            .overlay {
                if isLoading {
                    ProgressView("Assigning driver...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 2)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var canAssign: Bool {
        if isLoading { return false }
        if isLongTrip {
            return selectedDriverId != nil && selectedSecondDriverId != nil
        }
        return selectedDriverId != nil
    }
    
    private func fetchAvailableDrivers() {
        // Use trip.startTime and trip.endTime if available.
        Task {
            do {
                let drivers = try await SupabaseDataController.shared.fetchAvailableDrivers(
                    startDate: trip.startTime!,
                    endDate: trip.endTime!
                )
                await MainActor.run {
                    self.fetchedAvailableDrivers = drivers
                }
            } catch {
                print("Error fetching available drivers: \(error)")
            }
        }
    }
    
    private func assignDriver() {
        guard let driverId = selectedDriverId else { return }
        isLoading = true
        
        Task {
            do {
                if trip.status == .pending {
                    // Update trip status to assigned
                    try await SupabaseDataController.shared.updateTrip(id: trip.id, status: "assigned")
                    
                    // Update primary driver
                    try await SupabaseDataController.shared.updateTrip(id: trip.id, driverId: driverId)
                    
                    // If it's a long trip, update secondary driver
                    if isLongTrip, let secondDriverId = selectedSecondDriverId {
                        try await SupabaseDataController.shared.updateTrip(id: trip.id, secondaryDriverId: secondDriverId)
                    }
                } else {
                    // Just update the driver assignments
                    try await SupabaseDataController.shared.updateTrip(id: trip.id, driverId: driverId)
                    if isLongTrip, let secondDriverId = selectedSecondDriverId {
                        try await SupabaseDataController.shared.updateTrip(id: trip.id, secondaryDriverId: secondDriverId)
                    }
                }
                
                // Refresh the trips to update the UI
                await tripController.refreshAllTrips()
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Error assigning driver: \(error.localizedDescription)"
                    showingError = true
                }
                print("Error assigning driver: \(error)")
            }
        }
    }
}


struct DriverRow: View {
    let driver: Driver
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(driver.name)
                    .fontWeight(.medium)
                Text(driver.email)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// Location search results view
struct TripsLocationSearchResults: View {
    let results: [MKLocalSearchCompletion]
    let onResultSelected: (MKLocalSearchCompletion) -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(results, id: \.self) { result in
                    Button(action: {
                        onResultSelected(result)
                    }) {
                        HStack(alignment: .top, spacing: 12) {
                            // Map pin icon with different colors for different types of locations
                            Image(systemName: iconForResult(result))
                                .foregroundColor(colorForResult(result))
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                }
                                
                                // Display the type of location
                                if let locationType = getLocationType(result) {
                                    Text(locationType)
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.leading, 40)
                }
            }
        }
        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
        .frame(height: min(CGFloat(results.count * 70), 280))
    }
    
    // Helper function to determine icon based on result type
    private func iconForResult(_ result: MKLocalSearchCompletion) -> String {
        if result.subtitle.contains("Restaurant") || result.subtitle.contains("Café") || result.subtitle.contains("Food") {
            return "fork.knife"
        } else if result.subtitle.contains("Hotel") || result.subtitle.contains("Resort") {
            return "bed.double.fill"
        } else if result.subtitle.contains("Hospital") || result.subtitle.contains("Clinic") {
            return "cross.fill"
        } else if result.subtitle.contains("School") || result.subtitle.contains("College") || result.subtitle.contains("University") {
            return "book.fill"
        } else if result.subtitle.contains("Park") || result.subtitle.contains("Garden") {
            return "leaf.fill"
        } else if result.subtitle.contains("Mall") || result.subtitle.contains("Shop") || result.subtitle.contains("Store") {
            return "bag.fill"
        } else {
            return "mappin.circle.fill"
        }
    }
    
    // Helper function to determine color based on result type
    private func colorForResult(_ result: MKLocalSearchCompletion) -> Color {
        if result.subtitle.contains("Restaurant") || result.subtitle.contains("Café") || result.subtitle.contains("Food") {
            return .orange
        } else if result.subtitle.contains("Hotel") || result.subtitle.contains("Resort") {
            return .blue
        } else if result.subtitle.contains("Hospital") || result.subtitle.contains("Clinic") {
            return .red
        } else if result.subtitle.contains("School") || result.subtitle.contains("College") || result.subtitle.contains("University") {
            return .green
        } else if result.subtitle.contains("Park") || result.subtitle.contains("Garden") {
            return .green
        } else if result.subtitle.contains("Mall") || result.subtitle.contains("Shop") || result.subtitle.contains("Store") {
            return .purple
        } else {
            return .red
        }
    }
    
    // Helper function to get location type
    private func getLocationType(_ result: MKLocalSearchCompletion) -> String? {
        let subtitle = result.subtitle.lowercased()
        
        if subtitle.contains("restaurant") || subtitle.contains("café") || subtitle.contains("cafe") {
            return "Restaurant"
        } else if subtitle.contains("hotel") || subtitle.contains("resort") {
            return "Hotel"
        } else if subtitle.contains("hospital") || subtitle.contains("clinic") {
            return "Healthcare"
        } else if subtitle.contains("school") || subtitle.contains("college") || subtitle.contains("university") {
            return "Education"
        } else if subtitle.contains("park") || subtitle.contains("garden") {
            return "Park"
        } else if subtitle.contains("mall") || subtitle.contains("shop") || subtitle.contains("store") {
            return "Shopping"
        } else if subtitle.contains("airport") || subtitle.contains("station") {
            return "Transport"
        } else if subtitle.contains("street") || subtitle.contains("road") {
            return "Street"
        } else if subtitle.contains("city") || subtitle.contains("town") {
            return "City"
        } else if subtitle.contains("landmark") || subtitle.contains("monument") {
            return "Landmark"
        } else {
            return nil
        }
    }
}

// Search completer delegate for location autocompletion
class TripsSearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    var onUpdate: ([MKLocalSearchCompletion]) -> Void
    
    init(onUpdate: @escaping ([MKLocalSearchCompletion]) -> Void) {
        self.onUpdate = onUpdate
        super.init()
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onUpdate(completer.results)
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
    }
}

// Add SignatureCaptureView
struct SignatureCaptureView: View {
    @Binding var signature: Data?
    @State private var currentDrawing: Path = Path()
    @State private var drawings: [Path] = []
    @GestureState private var isDrawing: Bool = false
    
    var body: some View {
        VStack {
            Text("Please sign below")
                .font(.headline)
                .padding()
            
            ZStack {
                Rectangle()
                    .fill(Color.white)
                    .border(Color.gray, width: 1)
                    .frame(height: 200)
                
                Path { path in
                    path.addPath(currentDrawing)
                    drawings.forEach { path.addPath($0) }
                }
                .stroke(Color.black, lineWidth: 2)
                .background(Color.white)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let point = value.location
                            if isDrawing {
                                currentDrawing.addLine(to: point)
                            } else {
                                currentDrawing = Path()
                                currentDrawing.move(to: point)
                            }
                        }
                        .onEnded { _ in
                            drawings.append(currentDrawing)
                            currentDrawing = Path()
                            
                            // Convert drawing to image and then to Data
                            let renderer = ImageRenderer(content: Path { path in
                                drawings.forEach { path.addPath($0) }
                            }.stroke(Color.black, lineWidth: 2))
                            
                            if let uiImage = renderer.uiImage {
                                signature = uiImage.pngData()
                            }
                        }
                        .updating($isDrawing) { (value, state, transaction) in
                            state = true
                        }
                )
            }
            .padding()
            
            Button(action: {
                currentDrawing = Path()
                drawings = []
                signature = nil
            }) {
                Text("Clear")
                    .foregroundColor(.red)
            }
            .padding()
        }
    }
} 

