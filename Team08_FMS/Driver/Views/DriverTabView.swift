.sheet(isPresented: $showingPreTripInspection) {
    VehicleInspectionView(isPreTrip: true) { success in
        if success {
            // Only mark as completed if successful
            if let updatedTrip = currentTrip {
                Task {
                    do {
                        try await tripController.updateTripInspectionStatus(
                            tripId: updatedTrip.id,
                            isPreTrip: true,
                            completed: true
                        )
                        // Update local state after Supabase is updated
                        if var trip = currentTrip {
                            trip.hasCompletedPreTrip = true
                            currentTrip = trip
                        }
                    } catch {
                        alertMessage = "Failed to update pre-trip inspection status: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
            }
        } else {
            // If not successful, display alert but don't mark as completed
            alertMessage = "Please resolve all issues before starting the trip"
            showingAlert = true
        }
    }
}
.sheet(isPresented: $showingPostTripInspection) {
    VehicleInspectionView(isPreTrip: false) { success in
        if success {
            // Only mark as completed and mark delivered if successful
            if var updatedTrip = currentTrip {
                Task {
                    do {
                        try await tripController.updateTripInspectionStatus(
                            tripId: updatedTrip.id,
                            isPreTrip: false,
                            completed: true
                        )
                        // Update local state after Supabase is updated
                        if var trip = currentTrip {
                            trip.hasCompletedPostTrip = true
                            currentTrip = trip
                            // Use Task to call the async method
                            Task {
                                await MainActor.run {
                                    markCurrentTripDelivered()
                                }
                            }
                        }
                    } catch {
                        alertMessage = "Failed to update post-trip inspection status: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
            }
        } else {
            // If not successful, display alert but don't mark as completed
            alertMessage = "Please resolve all issues before completing delivery"
            showingAlert = true
        }
    }
}

// ... existing code ...

private func markCurrentTripDelivered() {
    if let trip = currentTrip, trip.hasCompletedPostTrip {
        // Create a Task to handle the async operation
        Task {
            do {
                // First mark the trip as delivered in Supabase
                try await tripController.markTripAsDelivered(trip: trip)
                print("Trip marked as delivered successfully")
                
                // The data will be updated in the controller automatically
                // when the refresh is completed in markTripAsDelivered
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to mark trip as delivered: \(error.localizedDescription)"
                    showingAlert = true
                }
                print("Error marking trip as delivered: \(error)")
            }
        }
    } else {
        print("Cannot mark as delivered: trip is nil or post-trip inspection not completed")
    }
}

struct DriverTabView: View {
    @StateObject private var availabilityManager = DriverAvailabilityManager.shared
    @StateObject private var tripController = TripDataController.shared

    // ... existing state properties ...
    
    @State private var isRefreshing = false
    @State private var lastRefreshTime = Date()
    private let minimumRefreshInterval: TimeInterval = 5 // Minimum seconds between refreshes
    
    var body: some View {
        TabView(selection: $selectedTab) {
            mainContentView
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            NavigationView {
                TripsView()
            }
            .tabItem {
                Label("Trips", systemImage: "car.fill")
            }
            .tag(1)
        }
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
        .onChange(of: tripController.currentTrip) { newTrip in
            currentTrip = newTrip
        }
        .onChange(of: tripController.upcomingTrips) { newTrips in
            upcomingTrips = newTrips
        }
        .onChange(of: tripController.recentDeliveries) { newDeliveries in
            recentDeliveries = newDeliveries
        }
        .onAppear {
            refreshTripsIfNeeded()
        }
    }
    
    private var mainContentView: some View {
        ZStack {
            // ... existing background gradient ...
            
            NavigationView {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        if let trip = currentTrip {
                            // Vehicle Details Section
                            NavigationLink(destination: VehicleDetailsView(vehicle: trip.vehicleDetails)) {
                                VehicleDetailsCard(vehicle: trip.vehicleDetails)
                            }
                            
                            // Trip Details
                            TripDetailsCard(trip: trip)
                            
                            // Action Buttons
                            HStack(spacing: 16) {
                                ActionButton(
                                    title: "Start Navigation",
                                    icon: "location.fill",
                                    color: trip.hasCompletedPreTrip ? .blue : .gray
                                ) {
                                    if !trip.hasCompletedPreTrip {
                                        alertMessage = "Please complete pre-trip inspection before starting navigation"
                                        showingAlert = true
                                    } else {
                                        // Handle navigation start
                                    }
                                }
                                
                                ActionButton(
                                    title: "Pre-Trip Inspection",
                                    icon: "checklist",
                                    color: trip.hasCompletedPreTrip ? .gray : .orange
                                ) {
                                    if !trip.hasCompletedPreTrip {
                                        showingPreTripInspection = true
                                    }
                                }
                            }
                            
                            // Show SOS button only after pre-trip inspection is completed
                            if trip.hasCompletedPreTrip {
                                SOSButton()
                                    .padding(.horizontal)
                            }
                            
                            ActionButton(
                                title: "Mark Delivered",
                                icon: "checkmark.circle.fill",
                                color: .green
                            ) {
                                if !trip.hasCompletedPreTrip {
                                    alertMessage = "Please complete pre-trip inspection before marking as delivered"
                                    showingAlert = true
                                } else if trip.hasCompletedPostTrip {
                                    Task {
                                        await MainActor.run {
                                            markCurrentTripDelivered()
                                        }
                                    }
                                } else {
                                    showingPostTripInspection = true
                                }
                            }
                        } else {
                            // No active trip view
                            NoActiveTripsView()
                        }
                    }
                    .padding(.top, 8)
                }
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.large)
                .refreshable {
                    await refreshTrips()
                }
                .toolbar {
                    // ... existing toolbar items ...
                }
            }
            
            if isRefreshing {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
        // ... existing modifiers ...
    }
    
    private func refreshTripsIfNeeded() {
        let now = Date()
        if now.timeIntervalSince(lastRefreshTime) >= minimumRefreshInterval {
            Task {
                await refreshTrips()
            }
        }
    }
    
    private func refreshTrips() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        defer { 
            isRefreshing = false
            lastRefreshTime = Date()
        }
        
        do {
            try await tripController.refreshTrips()
        } catch {
            alertMessage = "Failed to refresh trips: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct VehicleDetailsCard: View {
    let vehicle: Vehicle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vehicle Details")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(title: "Type", value: vehicle.bodyType.rawValue)
                    DetailRow(title: "License Plate", value: vehicle.licensePlate)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemSecondaryBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct TripDetailsCard: View {
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trip Details")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(title: "Destination", value: trip.destination)
                DetailRow(title: "Address", value: trip.address)
                DetailRow(title: "Distance", value: trip.distance)
            }
        }
        .padding()
        .background(Color(.systemSecondaryBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
}

struct NoActiveTripsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "car")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Active Trips")
                .font(.headline)
            
            Text("You don't have any active trips at the moment.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemSecondaryBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
} 