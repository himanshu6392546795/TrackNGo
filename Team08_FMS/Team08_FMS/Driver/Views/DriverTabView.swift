import SwiftUI
import MapKit
import AVFoundation
import CoreLocation

struct DriverTabView: View {
    @StateObject private var availabilityManager = DriverAvailabilityManager.shared
    @StateObject private var tripController = TripDataController.shared
    let driverId: UUID

    init(driverId: UUID) {
        self.driverId = driverId
    }

    @State private var showingChatBot = false
    @State private var showingPreTripInspection = false
    @State private var showingPostTripInspection = false
    @State private var showingVehicleDetails = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedTab = 0
    @State private var showingProfileView = false
    @State private var showingNavigation = false
    @State private var showingDeliveryDetails = false
    @State private var selectedDelivery: DeliveryDetails?
    @State private var isCurrentTripDeclined = false
    @State private var tripQueue: [Trip] = []
    @State private var showingSosModal = false
    
    // Route Information
    @State private var availableRoutes: [RouteOption] = [
//        RouteOption(id: "1", name: "Route 1", eta: "25 mins", distance: "8.5 km", isRecommended: true),
//        RouteOption(id: "2", name: "Route 2", eta: "32 mins", distance: "7.8 km", isRecommended: false),
        RouteOption(id: "3", name: "Route 3", eta: "1h 21m", distance: "53 km", isRecommended: false)
    ]
    @State private var selectedRouteId: String = "1"
    
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
        .environmentObject(tripController)
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
        .task {
            // Set the driver ID and load trips
            tripController.setDriverId(driverId)
            await tripController.refreshTrips()
            TripDataController.shared.startMonitoringRegions()
        }
    }
    
    private var mainContentView: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.05), Color.white]),
                startPoint: .top,
                endPoint: .center
            )
            .edgesIgnoringSafeArea(.all)
            
            NavigationView {
                ZStack {
                    if tripController.isLoading {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                            Text("Loading trips...")
                                .foregroundColor(.gray)
                        }
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 24) {
                                // Current Delivery Card
                                if let currentTrip = tripController.currentTrip,
                                   currentTrip.status == .inProgress && availabilityManager.isAvailable {
                                    currentDeliveryCard(currentTrip)
                                }
                                
                                // Only show upcoming trips and trip queue if available
                                if availabilityManager.isAvailable {
                                    // Trip Queue Section
                                    if !tripQueue.isEmpty {
                                        tripQueueSection
                                    }

                                    // Upcoming Trips Section
                                    VStack(alignment: .leading, spacing: 20) {
                                        HStack {
                                            Text("Upcoming Trips")
                                                .font(.system(.title2, design: .default).weight(.bold))
                                            
                                            if !tripController.upcomingTrips.isEmpty {
                                                Text("\(tripController.upcomingTrips.count)")
                                                    .font(.system(.headline, design: .default).weight(.semibold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 4)
                                                    .background(Color.blue)
                                                    .cornerRadius(12)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal)

                                        if tripController.upcomingTrips.isEmpty {
                                            emptyUpcomingTripsView
                                        } else {
                                            VStack(spacing: 0) {
                                                ForEach(tripController.upcomingTrips) { trip in
                                                    UpcomingTripRow(trip: trip)
                                                        .environmentObject(tripController)
                                                    if trip.id != tripController.upcomingTrips.last?.id {
                                                        Divider()
                                                            .padding(.horizontal)
                                                    }
                                                }
                                            }
                                            .background(Color(.secondarySystemBackground))
                                            .cornerRadius(20)
                                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                                            .padding(.horizontal)
                                        }
                                    }
                                } else {
                                    // Display message when driver is unavailable
                                    unavailableDriverSection
                                }

                                // Recent Deliveries Section
                                VStack(alignment: .leading, spacing: 20) {
                                    HStack {
                                        Text("Recent Deliveries")
                                            .font(.system(size: 24, weight: .bold))
                                        
                                        if !tripController.recentDeliveries.isEmpty {
                                            Text("\(tripController.recentDeliveries.count)")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(Color.green)
                                                .cornerRadius(12)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    
                                    if tripController.recentDeliveries.isEmpty {
                                        emptyRecentDeliveriesView
                                    } else {
                                        VStack(spacing: 0) {
                                            ForEach(tripController.recentDeliveries) { delivery in
                                                Button {
                                                    selectedDelivery = delivery
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                        showingDeliveryDetails = true
                                                    }
                                                } label: {
                                                    DeliveryRow(delivery: delivery)
                                                }
                                                .buttonStyle(PlainButtonStyle())

                                                if delivery.id != tripController.recentDeliveries.last?.id {
                                                    Divider()
                                                        .padding(.horizontal)
                                                }
                                            }
                                        }
                                        .onChange(of: selectedDelivery) { _, newValue in
                                            if newValue != nil {
                                                showingDeliveryDetails = true
                                            }
                                        }
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(20)
                                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                                        .padding(.horizontal)
                                    }
                                }
                                
                                // Bottom padding for better scrolling experience
                                Spacer().frame(height: 20)
                            }
                            .padding(.top, 8)
                        }
                        .refreshable {
                            await tripController.refreshTrips()
                        }
                    }
                }
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            Button(action: {
                                showingProfileView = true
                            }) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.blue)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                                            .frame(width: 30, height: 30)
                                    )
                            }
                        }
                    }
                }
            }
            
            // Full-screen navigation view
            if showingNavigation {
                navigationOverlay
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingNavigation)
        .sheet(isPresented: $showingChatBot) {
            ChatBotView()
        }
        .sheet(isPresented: $showingProfileView) {
            DriverProfileView()
        }
        .sheet(isPresented: $showingPreTripInspection) {
            VehicleInspectionView(isPreTrip: true) { success in
                if success {
                    // Only mark as completed if successful
                    if let currentTrip = tripController.currentTrip {
                        Task {
                            do {
                                try await tripController.updateTripInspectionStatus(
                                    tripId: currentTrip.id,
                                    isPreTrip: true,
                                    completed: true
                                )
                            } catch {
                                alertMessage = "Failed to update pre-trip inspection status: \(error.localizedDescription)"
                                showingAlert = true
                            }
                        }
                    }
                } else {
                    alertMessage = "Please resolve all issues before starting the trip"
                    showingAlert = true
                }
            }
        }
        .sheet(isPresented: $showingPostTripInspection) {
            VehicleInspectionView(isPreTrip: false) { success in
                if success {
                    // Only mark as completed if successful
                    if let currentTrip = tripController.currentTrip {
                        Task {
                            do {
                                try await tripController.updateTripInspectionStatus(
                                    tripId: currentTrip.id,
                                    isPreTrip: false,
                                    completed: true
                                )
                                await MainActor.run {
                                    markCurrentTripDelivered()
                                }
                            } catch {
                                alertMessage = "Failed to update post-trip inspection status: \(error.localizedDescription)"
                                showingAlert = true
                            }
                        }
                    }
                } else {
                    alertMessage = "Please resolve all issues before completing delivery"
                    showingAlert = true
                }
            }
        }
        .sheet(isPresented: $showingVehicleDetails) {
            if let currentTrip = tripController.currentTrip {
                VehicleDetailsView(vehicleDetails: currentTrip.vehicleDetails)
            }
        }
        .sheet(isPresented: $showingSosModal) {
            SOSModalView(isPresented: $showingSosModal)
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Action Required"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showingDeliveryDetails) {
            if let delivery = selectedDelivery {
                DeliveryDetailsView(delivery: delivery)
            }
        }
    }
    
    private var navigationOverlay: some View {
        RealTimeNavigationView(
            destination: tripController.currentTrip?.destinationCoordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
            destinationName: tripController.currentTrip?.destination ?? "",
            address: tripController.currentTrip?.address ?? "",
            sourceCoordinate: tripController.currentTrip?.sourceCoordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
            onDismiss: { 
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingNavigation = false 
                }
            }
        )
        .edgesIgnoringSafeArea(.all)
        .transition(.move(edge: .bottom))
        .zIndex(1)
    }
    
    private func currentDeliveryCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Delivery")
                .font(.system(size: 22, weight: .bold))
            
            currentDeliveryContent(trip)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    private func currentDeliveryContent(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Vehicle Details Button
            Button(action: {
                showingVehicleDetails = true
            }) {
                HStack {
                    Image(systemName: "truck.box.fill")
                        .font(.title3)
                    VStack(alignment: .leading) {
                        Text("Vehicle Details")
                            .font(.headline)
                        Text(trip.vehicleDetails.licensePlate)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Route Information
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "map.fill")
                        .foregroundColor(.blue)
                    Text("Route Information")
                        .font(.headline)
                }
                
                ZStack {
                    // Background with rounded corners
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                    
                    HStack(alignment: .top, spacing: 12) {
                        // Left side: Line with dots
                        ZStack {
                            // Vertical line
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2)
                                .frame(height: 100)
                            
                            // Dots
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                
                                Spacer()
                                
                                Rectangle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                            }
                            .frame(height: 100)
                        }
                        .padding(.top, 8)
                        
                        // Right side: Location details
                        VStack(alignment: .leading, spacing: 16) {
                            // Pickup Location
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pickup")
                                    .font(.system(size: 14))
                                    .foregroundColor(.green)
                                Text(trip.startingPoint)
                                    .font(.system(size: 16, weight: .regular))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            
                            // Destination Location
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Destination")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                Text(trip.destination)
                                    .font(.system(size: 16, weight: .regular))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        Spacer()
                    }
                    .padding(16)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            
            // Status Cards
            if !isCurrentTripDeclined {
                HStack(spacing: 10) {
                    // ETA Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                )
                            Text("ETA")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        Text(selectedRouteEta(trip))
                            .font(.system(size: 24, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Distance Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "arrow.left.and.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.green)
                                )
                            Text("Distance")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        Text(selectedRouteDistance(trip))
                            .font(.system(size: 24, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // Action Buttons
            HStack(spacing: 10) {
                // Start Navigation Button
                Button(action: {
                    if !trip.hasCompletedPreTrip {
                        alertMessage = "Please complete pre-trip inspection before starting navigation"
                        showingAlert = true
                    } else if trip.vehicleDetails.status == .underMaintenance {
                        alertMessage = "Vehicle is under maintenance"
                        showingAlert = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingNavigation = true
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Start Navigation")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                
                // Pre-Trip Inspection Button
                Button(action: {
                    showingPreTripInspection = true
                }) {
                    HStack {
                        Image(systemName: "checklist")
                        Text("Pre-Trip\nInspection")
                            .multilineTextAlignment(.center)
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                }
            }
            
            // Mark Delivered and SOS Buttons
            HStack(spacing: 10) {
                // Mark Delivered Button
                Button(action: {
                    if !trip.hasCompletedPreTrip {
                        alertMessage = "Please complete pre-trip inspection before marking as delivered"
                        showingAlert = true
                    } else if trip.vehicleDetails.status == .underMaintenance {
                        alertMessage = "Vehicle is under maintenance"
                        showingAlert = true
                    } else {
                        Task {
                            await MainActor.run {
                                markCurrentTripDelivered()
                            }
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Mark Delivered")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(10)
                }
                
                // SOS Button
                Button(action: {
                    showingSosModal = true
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("SOS")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .cornerRadius(10)
                }
            }
        }
    }
    
    // Route Information
    private func selectedRouteEta(_ trip: Trip) -> String {
        availableRoutes.first(where: { $0.id == selectedRouteId })?.eta ?? trip.eta
    }
    
    private func selectedRouteDistance(_ trip: Trip) -> String {
        availableRoutes.first(where: { $0.id == selectedRouteId })?.distance ?? trip.distance
    }
    
    private var routeSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available Routes")
                .font(.headline)
                .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(availableRoutes.sorted(by: { $0.id < $1.id })) { route in
                        Button(action: {
                            selectedRouteId = route.id
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(route.name)
                                        .font(.system(size: 14, weight: .semibold))
                                    
                                    if route.isRecommended {
                                        Text("Recommended")
                                            .font(.system(size: 10))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                    }
                                }
                                
                                HStack(spacing: 12) {
                                    Label(route.eta, systemImage: "clock")
                                        .font(.system(size: 12))
                                    
                                    Label(route.distance, systemImage: "arrow.left.and.right")
                                        .font(.system(size: 12))
                                }
                            }
                            .padding(10)
                            .frame(width: 160)
                            .background(selectedRouteId == route.id ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedRouteId == route.id ? Color.blue : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 8)
    }
    
    // Add RouteOption struct
    struct RouteOption: Identifiable {
        let id: String
        let name: String
        let eta: String
        let distance: String
        let isRecommended: Bool
    }
    
    private func tripLocationsView(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Route Info Card
            VStack(spacing: 16) {
                // Title
                Text("Route Information")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                
                // Pickup and Drop-off with connecting line
                HStack(spacing: 20) {
                    // Pickup Location
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                            Text(trip.startingPoint)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                        }
                        Text("Pickup")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Connecting Line
                    Rectangle()
                        .fill(Color(uiColor: .systemGray3))
                        .frame(height: 2)
                        .frame(maxWidth: 80)
                        .padding(.vertical, 14)
                    
                    // Drop-off Location
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                            Text(trip.destination)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                        }
                        Text("Destination")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 4)
            }
            .padding(16)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
        .padding(.vertical, 4)
    }
    
    private func tripActionButtons(_ trip: Trip) -> some View {
        VStack(spacing: 12) {
            if isCurrentTripDeclined {
                // Show Accept/Decline buttons for declined trip
                HStack(spacing: 12) {
                    ActionButton(
                        title: "Accept Trip",
                        icon: "checkmark",
                        color: .green
                    ) {
                        isCurrentTripDeclined = false
                    }
                    
                    ActionButton(
                        title: "Decline Trip",
                        icon: "xmark",
                        color: .red
                    ) {
                        Task {
                            if let index = tripQueue.firstIndex(where: { $0.id == trip.id }) {
                                tripQueue.remove(at: index)
                            }
                        }
                    }
                }
            } else {
                // Show regular action buttons in a grid layout
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // Start Navigation Button
                        Button(action: {
                            if !trip.hasCompletedPreTrip {
                                alertMessage = "Please complete pre-trip inspection before starting navigation"
                                showingAlert = true
                            } else {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingNavigation = true
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                Text("Start Navigation")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background((trip.vehicleDetails.status != .underMaintenance) ? Color.blue : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(trip.vehicleDetails.status == .underMaintenance)
                        
                        // Pre-Trip Inspection Button
                        Button(action: {
                            if !trip.hasCompletedPreTrip {
                                showingPreTripInspection = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "checklist")
                                Text("Pre-Trip Inspection")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(trip.hasCompletedPreTrip ? Color.gray : Color.orange)
                            .cornerRadius(12)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        // Mark Delivered Button
                        Button(action: {
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
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Mark Delivered")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background((trip.vehicleDetails.status != .underMaintenance) ? Color.green : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(trip.vehicleDetails.status == .underMaintenance)
                        
                        // SOS Button
                        Button(action: {
                            showingSosModal = true
                        }) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("SOS")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var tripQueueSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Trip Queue")
                .font(.system(size: 24, weight: .bold))
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                ForEach(tripQueue) { trip in
                    QueuedTripRow(
                        trip: trip,
                        onStart: {
                            Task {
                                do {
                                    try await tripController.startTrip(trip: trip)
                                    if let index = tripQueue.firstIndex(where: { $0.id == trip.id }) {
                                        tripQueue.remove(at: index)
                                    }
                                } catch {
                                    alertMessage = "Failed to start trip: \(error.localizedDescription)"
                                    showingAlert = true
                                }
                            }
                        },
                        onDecline: {
                            // Remove from queue
                            if let index = tripQueue.firstIndex(where: { $0.id == trip.id }) {
                                tripQueue.remove(at: index)
                            }
                        }
                    )
                    if trip.id != tripQueue.last?.id {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            .padding(.horizontal)
        }
    }
    
    private var emptyUpcomingTripsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("No Upcoming Trips")
                .font(.system(.headline, design: .default))
            Text("Check back later for new assignments")
                .font(.system(.subheadline, design: .default))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    private var emptyRecentDeliveriesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("No Recent Deliveries")
                .font(.system(.headline, design: .default))
            Text("Completed deliveries will appear here")
                .font(.system(.subheadline, design: .default))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    private var unavailableDriverSection: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "car.fill.badge.xmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)
                .padding()
            
            Text("You are currently unavailable for trips")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Your status will automatically change back to available tomorrow.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    private func markCurrentTripDelivered() {
        if let trip = tripController.currentTrip, trip.hasCompletedPostTrip {
            // Create a Task to handle the async operation
            Task {
                do {
                    // First update the trip inspection status in Supabase if needed
                    if !trip.hasCompletedPreTrip {
                        try await tripController.updateTripInspectionStatus(
                            tripId: trip.id,
                            isPreTrip: true,
                            completed: true
                        )
                    }
                    
                    if !trip.hasCompletedPostTrip {
                        try await tripController.updateTripInspectionStatus(
                            tripId: trip.id,
                            isPreTrip: false,
                            completed: true
                        )
                    }
                    
                    // Then mark the trip as delivered in Supabase
                    try await tripController.markTripAsDelivered(trip: trip)
                    print("Trip marked as delivered successfully")
                    
                    // Explicitly refresh trips to ensure data is updated
                    await tripController.refreshTrips()
                    
                    // If there are no more trips, move to the next one
                    if tripController.currentTrip == nil {
                        if !tripQueue.isEmpty {
                            // Take the next trip from the queue
                            let nextTrip = tripQueue.removeFirst()
                            Task {
                                try await tripController.startTrip(trip: nextTrip)
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        alertMessage = "Failed to mark trip as delivered: \(error.localizedDescription)"
                        showingAlert = true
                    }
                    print("Error marking trip as delivered: \(error)")
                }
            }
        } else {
            // If pre-trip not completed, show alert
            if let trip = tripController.currentTrip, !trip.hasCompletedPreTrip {
                alertMessage = "Please complete pre-trip inspection before marking as delivered"
                showingAlert = true
            }
            // If post-trip not completed, show post-trip inspection
            else if let trip = tripController.currentTrip, !trip.hasCompletedPostTrip {
                showingPostTripInspection = true
            } else {
                print("Cannot mark as delivered: trip is nil")
            }
        }
    }
    
    private func acceptTrip(_ trip: Trip) {
        // If there's no current trip, make this the current trip
        if tripController.currentTrip?.status != .inProgress {
            Task {
                do {
                    try await tripController.startTrip(trip: trip)
                } catch {
                    alertMessage = "Failed to start trip: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

struct DeliveryRow: View {
    let delivery: DeliveryDetails
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(delivery.location)
                        .font(.headline)
                    Text(delivery.date)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(delivery.status)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(12)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            
            // Get first line of notes for display as preview
            if let firstLine = delivery.notes.split(separator: "\n").first {
                HStack(spacing: 6) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    
                    Text(String(firstLine).replacingOccurrences(of: "Trip: ", with: ""))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .padding(.leading, 16)
            }
            
            // Display the vehicle info
            HStack(spacing: 6) {
                Image(systemName: "car.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                
                Text(delivery.vehicle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.leading, 16)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

struct UpcomingTripRow: View {
    let trip: Trip
    @EnvironmentObject var tripController: TripDataController
    @State private var showingAlert = false
    @State private var errorMessage = ""
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with destination and start button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.destination)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    if let pickup = trip.pickup {
                        Text(pickup)
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                Button(action: {
                    Task {
                        do {
                            try await tripController.startTrip(trip: trip)
                        } catch {
                            errorMessage = "You have an active trip in progress. Please complete the current trip before starting a new one. This trip will be automatically activated after completing the current trip."
                            showingAlert = true
                        }
                    }
                }) {
                    Text("Start Trip")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(20)
                }
            }
            
            // Trip details
            VStack(alignment: .leading, spacing: 8) {
                if !trip.eta.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        Text("ETA:")
                            .foregroundColor(.gray)
                        Text(trip.eta)
                    }
                    .font(.subheadline)
                }
                
                if !trip.distance.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.and.right")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        Text("Distance:")
                            .foregroundColor(.gray)
                        Text(trip.distance)
                    }
                    .font(.subheadline)
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
        .sheet(isPresented: $showingDetails) {
            TripDetailsView(trip: trip)
        }
        .alert("Active Trip in Progress", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

struct VehicleDetailItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.subheadline)
                .bold()
        }
        .frame(maxWidth: .infinity)
    }
}

struct VehicleDetailsView: View {
    @Environment(\.presentationMode) var presentationMode
    let vehicleDetails: Vehicle
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Basic Information")) {
                    DetailRow(icon: "car.fill", title: "Vehicle Type", value: vehicleDetails.vehicleType.rawValue)
                    DetailRow(icon: "number", title: "License Plate", value: vehicleDetails.licensePlate)
                }
                
                Section(header: Text("Additional Information")) {
                    DetailRow(icon: "calendar", title: "Last Maintenance", value: "2024-03-15")
                    DetailRow(icon: "gauge", title: "Mileage", value: "45,678 mi")
                    DetailRow(icon: "fuelpump.fill", title: "Fuel Level", value: "75%")
                }
                
                Section(header: Text("Status")) {
                    DetailRow(icon: "checkmark.circle.fill", title: "Vehicle Status", value: "Active")
                    DetailRow(icon: "wrench.fill", title: "Maintenance Due", value: "In 2 weeks")
                    DetailRow(icon: "exclamationmark.triangle.fill", title: "Alerts", value: "None")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Vehicle Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.primary)
        }
    }
}

struct NavigationStep: View {
    let direction: String
    let distance: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title2)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(direction)
                    .font(.headline)
                Text(distance)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
}

struct DeliveryDetailsView: View {
    @Environment(\.presentationMode) var presentationMode
    let delivery: DeliveryDetails
    
    // Parse notes to get structured information
    private var parsedNotes: [String: String] {
        var result = [String: String]()
        let lines = delivery.notes.split(separator: "\n")
        
        for line in lines where line.contains(":") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                result[key] = value
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationView {
            List {
                // Trip Info Section
                Section(header: Text("Trip Information")) {
                    if let tripName = parsedNotes["Trip"] {
                        DetailRow(icon: "shippingbox.fill", title: "Trip ID", value: tripName)
                    }
                    DetailRow(icon: "mappin.circle.fill", title: "Destination", value: delivery.location)
                    DetailRow(icon: "calendar", title: "Delivery Date", value: delivery.date)
                    DetailRow(icon: "checkmark.circle.fill", title: "Status", value: delivery.status)
                }
                
                // Route Details Section
                Section(header: Text("Route Details")) {
                    if let startPoint = parsedNotes["From"] {
                        DetailRow(icon: "arrow.up.circle.fill", title: "Starting Point", value: startPoint)
                    }
                    if let distance = parsedNotes["Distance"] {
                        DetailRow(icon: "arrow.left.and.right", title: "Distance", value: distance)
                    }
                }
                
                // Cargo Section
                Section(header: Text("Cargo Information")) {
                    if let cargo = parsedNotes["Cargo"] {
                        DetailRow(icon: "box.truck.fill", title: "Cargo Type", value: cargo)
                    }
                }
                
                // Vehicle & Driver Info Section
                Section(header: Text("Vehicle")) {
//                    DetailRow(icon: "person.fill", title: "Driver", value: delivery.driver)
                    DetailRow(icon: "truck.box.fill", title: "Vehicle", value: delivery.vehicle)
                }
                
                // Additional Notes Section (original notes minus structured info)
                let filteredNotes = delivery.notes.split(separator: "\n")
                    .filter { !$0.contains("Trip:") && !$0.contains("Cargo:") && !$0.contains("Distance:") && !$0.contains("From:") }
                    .joined(separator: "\n")
                
                if !filteredNotes.isEmpty {
                    Section(header: Text("Additional Notes")) {
                        Text(filteredNotes)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(.vertical, 8)
                    }
                }
                
                // Proof of Delivery Section
//                Section(header: Text("Proof of Delivery")) {
//                    HStack {
//                        Image(systemName: "doc.fill")
//                        Text("Delivery Receipt")
//                        Spacer()
//                        Image(systemName: "arrow.down.circle")
//                            .foregroundColor(.blue)
//                    }
//                    
//                    HStack {
//                        Image(systemName: "signature")
//                        Text("Customer Signature")
//                        Spacer()
//                        Image(systemName: "eye")
//                            .foregroundColor(.blue)
//                    }
//                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Delivery Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct QueuedTripRow: View {
    let trip: Trip
    let onStart: () -> Void
    let onDecline: () -> Void
    @State private var showingDeclineAlert = false
    @StateObject private var tripController = TripDataController.shared
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.displayName)
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(trip.destination)
                        .font(.headline)
                    Text(trip.address)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(trip.eta)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Text(trip.distance)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                Text("In Queue")
                    .font(.caption)
                    .foregroundColor(.orange)
                Spacer()
                Text("Ready to start")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        do {
                            try await tripController.startTrip(trip: trip)
                            onStart()
                        } catch {
                            alertMessage = "You have an active trip in progress. Please complete the current trip before starting a new one. This trip will be automatically activated after completing the current trip."
                            showingAlert = true
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Trip")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                
                Button(action: { showingDeclineAlert = true }) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Decline")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .alert(isPresented: $showingDeclineAlert) {
            Alert(
                title: Text("Decline Trip"),
                message: Text("Are you sure you want to decline trip \(trip.displayName)?"),
                primaryButton: .destructive(Text("Decline")) {
                    onDecline()
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Active Trip in Progress", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

struct MapPoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
}

struct MapPolyline: View {
    let coordinates: [CLLocationCoordinate2D]
    let strokeColor: Color
    let lineWidth: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Start at the first coordinate
                let startPoint = CGPoint(
                    x: 0,
                    y: geometry.size.height / 2
                )
                path.move(to: startPoint)
                
                // Draw a line to the end point
                let endPoint = CGPoint(
                    x: geometry.size.width,
                    y: geometry.size.height / 2
                )
                path.addLine(to: endPoint)
            }
            .stroke(strokeColor, lineWidth: lineWidth)
        }
    }
}

struct SOSModalView: View {
    @Binding var isPresented: Bool
    @StateObject private var profileManager = ProfileManager.shared
    @State private var emergencySubject: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingChat = false
    @State private var selectedOption: SOSOption = .emergency
    

    
    enum SOSOption {
        case emergency
        case chat
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Emergency icon and header
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("Emergency Assistance")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.top, 20)
                
                // Option Picker
                Picker("Select Option", selection: $selectedOption) {
                    Text("Emergency").tag(SOSOption.emergency)
                    Text("Chat").tag(SOSOption.chat)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if selectedOption == .emergency {
                    // Emergency View
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emergency Subject")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter emergency details", text: $emergencySubject)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Contact Fleet Manager Button
                    Button(action: {
                        if emergencySubject.isEmpty {
                            alertMessage = "Please enter emergency details"
                            showingAlert = true
                        } else {
                            // Handle emergency contact
                            // This would trigger the phone call
                        }
                    }) {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("Contact Fleet Manager")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(emergencySubject.isEmpty ? Color.gray : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.1), radius: 5)
                    }
                    .disabled(emergencySubject.isEmpty)
                    .padding(.horizontal)
                    .padding(.top, 20)
                } else {
                    // Chat View
                    if let manager = profileManager.fleetManager {
                        if let userID = manager.userID {
                            ChatView(recipientType: .driver, recipientId: userID, recipientName: manager.name)
                                .frame(maxHeight: .infinity)
                        } else {
                            Text("Unable to start chat: Fleet manager information is incomplete")
                                .foregroundColor(.red)
                                .padding()
                        }
                    } else {
                        ProgressView("Loading fleet manager...")
                    }
                }
                
                Spacer()
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Missing Information"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .navigationTitle("SOS Emergency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

class ProfileManager: ObservableObject {
    static let shared = ProfileManager()
    
    @Published var fleetManager: FleetManager?
    @Published var fleetManagerName: String = "Snehil Rai"
    @Published var fleetManagerPhone: String = "9302399874"
    @Published var fleetManagers: [FleetManager] = []
    
    private init() {
        // Load fleet manager details from local storage or fetch from server
        Task {
            await loadFleetManagerDetails()
        }
    }
    
    private func loadFleetManagerDetails() async {
        do {
            fleetManagers = try await SupabaseDataController.shared.fetchFleetManagers()
            if !fleetManagers.isEmpty {
                await MainActor.run {
                    self.fleetManager = fleetManagers[0]
                    self.fleetManagerName = fleetManagers[0].name
                    self.fleetManagerPhone = String(fleetManagers[0].phoneNumber)
                }
            }
        } catch {
            print("Error loading fleet manager details: \(error)")
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        DriverTabView(driverId: UUID())
    }
} 

