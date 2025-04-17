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
        }
    }
}

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
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("Add trips to manage your deliveries")
                .font(.subheadline)
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
    
    var body: some View {
        // Implementation of TripCardView
        Text("Trip Card View")
    }
}

struct PDFViewer: UIViewRepresentable {
    let data: Data
    @State private var isLoading = true
    @State private var error: Error?
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        isLoading = true
        if let document = PDFDocument(data: data) {
            pdfView.document = document
            isLoading = false
        } else {
            error = TripError.updateError("Failed to load PDF document")
            isLoading = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: PDFViewer
        
        init(_ parent: PDFViewer) {
            self.parent = parent
        }
    }
}

// Update TripDetailView to handle PDF generation errors
struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingAssignSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingPDFViewer = false
    @State private var pdfError: String? = nil
    @State private var showingPDFError = false
    @StateObject private var tripController = TripDataController.shared
    let trip: Trip
    @State private var pdfData: Data?
    
    // Editing state variables
    @State private var isEditing = false
    @State private var editedDestination: String = ""
    @State private var editedAddress: String = ""
    @State private var editedNotes: String = ""
    @State private var calculatedDistance: String = ""
    @State private var calculatedTime: String = ""
    @State private var selectedDriverId: UUID? = nil
    
    var body: some View {
        NavigationView {
            List {
                // ... existing code ...
                
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
                
                // Add Proof of Delivery Section for completed trips
                if trip.status == .delivered {
                    Section(header: Text("PROOF OF DELIVERY")) {
                        Button(action: {
                            do {
                                pdfData = try TripDataController.shared.generateDeliveryReceipt(for: trip)
                                showingPDFViewer = true
                            } catch {
                                pdfError = error.localizedDescription
                                showingPDFError = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.blue)
                                Text("Delivery Receipt")
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                // Driver Information Section
                Section(header: Text("DRIVER INFORMATION")) {
                    // Primary Driver
                    if let driverId = trip.driverId,
                       let driver = CrewDataController.shared.drivers.first(where: { $0.userID == driverId }) {
                        TripDetailRow(icon: "person.fill", title: "Primary Driver", value: driver.name)
                    } else {
                        TripDetailRow(icon: "person.fill", title: "Primary Driver", value: "Unassigned")
                    }
                    
                    // Secondary Driver (for long trips)
                    if trip.distance.components(separatedBy: CharacterSet.decimalDigits.inverted).joined().isEmpty == false,
                       let distance = Double(trip.distance.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()),
                       distance > 500 {
                        if let secondaryDriverId = trip.secondaryDriverId,
                           let secondaryDriver = CrewDataController.shared.drivers.first(where: { $0.userID == secondaryDriverId }) {
                            TripDetailRow(icon: "person.2.fill", title: "Secondary Driver", value: secondaryDriver.name)
                        } else {
                            TripDetailRow(icon: "person.2.fill", title: "Secondary Driver", value: "Unassigned")
                        }
                    }
                }
                
                // ... existing code ...
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingPDFViewer) {
                if let data = pdfData {
                    NavigationView {
                        PDFViewer(data: data)
                            .navigationTitle("Delivery Receipt")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        showingPDFViewer = false
                                    }
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
            // ... existing code ...
        }
    }
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

// Add Proof of Delivery Section for completed trips
if trip.status == .delivered {
    Section(header: Text("PROOF OF DELIVERY")) {
        Button(action: {
            showingPDFViewer = true
        }) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.blue)
                Text("Delivery Receipt")
                    .foregroundColor(.blue)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
    }
}

.sheet(isPresented: $showingPDFViewer) {
    NavigationView {
        PDFViewer(data: TripDataController.shared.generateDeliveryReceipt(for: trip))
            .navigationTitle("Delivery Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingPDFViewer = false
                    }
                }
            }
    }
} 