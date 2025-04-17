private func filterTripsByDriver(trips: [Trip]) -> [Trip] {
    // Filter trips by the current driver ID if set
    guard let driverId = driverId else {
        return trips // Return all trips if no driver ID is set
    }
    
    return trips.filter { trip in
        // Include trips where the driver is either primary or secondary driver
        if let tripDriverId = trip.driverId {
            if tripDriverId == driverId {
                return true
            }
        }
        if let secondaryDriverId = trip.secondaryDriverId {
            if secondaryDriverId == driverId {
                return true
            }
        }
        return false
    }
} 

@MainActor
func fetchTrips() async throws {
    do {
        let query = supabaseController.supabase
            .from("trips")
            .select("""
                id,
                destination,
                trip_status,
                has_completed_pre_trip,
                has_completed_post_trip,
                vehicle_id,
                driver_id,
                secondary_driver_id,
                start_time,
                end_time,
                notes,
                created_at,
                updated_at,
                is_deleted,
                start_latitude,
                start_longitude,
                end_latitude,
                end_longitude,
                pickup,
                estimated_distance,
                estimated_time,
                vehicles (
                    id,
                    name,
                    year,
                    make,
                    model,
                    vin,
                    license_plate,
                    vehicle_type,
                    color,
                    body_type,
                    body_subtype,
                    msrp,
                    pollution_expiry,
                    insurance_expiry,
                    status
                )
            """)
            .eq("is_deleted", value: false)

        // Add driver filter if driverId is set
        if let driverId = driverId {
            query.or("driver_id.eq.\(driverId),secondary_driver_id.eq.\(driverId)")
        }

        // Execute the query
        let response = try await query.execute()

        // Configure date formatter for decoding
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        // Configure decoder with date formatter
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Handle date strings with milliseconds
            if let dotIndex = dateString.firstIndex(of: ".") {
                let truncated = String(dateString[..<dotIndex])
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                if let date = dateFormatter.date(from: truncated) {
                    return date
                }
            }

            print("Failed to decode date string: \(dateString)")
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string: \(dateString)")
        }

        // Decode the response data
        let joinedData = try decoder.decode([JoinedTripData].self, from: response.data)

        // Convert joined data to Trip objects
        let tripsWithVehicles = joinedData.map { data -> Trip in
            let supabaseTrip = SupabaseTrip(
                id: data.id,
                destination: data.destination,
                trip_status: data.trip_status,
                has_completed_pre_trip: data.has_completed_pre_trip,
                has_completed_post_trip: data.has_completed_post_trip,
                vehicle_id: data.vehicle_id,
                driver_id: data.driver_id,
                secondary_driver_id: data.secondary_driver_id,
                start_time: data.start_time,
                end_time: data.end_time,
                notes: data.notes,
                created_at: data.created_at,
                updated_at: data.updated_at ?? data.created_at,
                is_deleted: data.is_deleted,
                start_latitude: data.start_latitude,
                start_longitude: data.start_longitude,
                end_latitude: data.end_latitude,
                end_longitude: data.end_longitude,
                pickup: data.pickup,
                estimated_distance: data.estimated_distance,
                estimated_time: data.estimated_time
            )
            return Trip(from: supabaseTrip, vehicle: data.vehicles)
        }

        print("Successfully processed \(tripsWithVehicles.count) trips")

        // Update published properties
        await MainActor.run {
            // Find current trip (in progress)
            if let currentTrip = tripsWithVehicles.first(where: { $0.status == TripStatus.inProgress }) {
                self.currentTrip = currentTrip
            } else {
                self.currentTrip = nil
            }

            // Filter upcoming trips (only pending or assigned)
            self.upcomingTrips = tripsWithVehicles.filter { trip in
                trip.status == .pending || trip.status == .assigned
            }

            // Convert completed/delivered trips to delivery details
            let completedTrips = tripsWithVehicles.filter { trip in 
                trip.status == .delivered && trip.hasCompletedPostTrip
            }
        }
    } catch {
        print("Error fetching trips: \(error)")
        throw TripError.fetchError("Failed to fetch trips: \(error.localizedDescription)")
    }
}

@MainActor
func fetchAllTrips() async throws {
    do {
        let query = supabaseController.supabase
            .from("trips")
            .select("""
                id,
                destination,
                trip_status,
                has_completed_pre_trip,
                has_completed_post_trip,
                vehicle_id,
                driver_id,
                secondary_driver_id,
                start_time,
                end_time,
                notes,
                created_at,
                updated_at,
                is_deleted,
                start_latitude,
                start_longitude,
                end_latitude,
                end_longitude,
                pickup,
                estimated_distance,
                estimated_time,
                vehicles (
                    id,
                    name,
                    year,
                    make,
                    model,
                    vin,
                    license_plate,
                    vehicle_type,
                    color,
                    body_type,
                    body_subtype,
                    msrp,
                    pollution_expiry,
                    insurance_expiry,
                    status
                )
            """)
            .eq("is_deleted", value: false)

        // Execute the query
        let response = try await query.execute()

        // Configure date formatter for decoding
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        // Configure decoder with date formatter
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Handle date strings with milliseconds
            if let dotIndex = dateString.firstIndex(of: ".") {
                let truncated = String(dateString[..<dotIndex])
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                if let date = dateFormatter.date(from: truncated) {
                    return date
                }
            }

            print("Failed to decode date string: \(dateString)")
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string: \(dateString)")
        }

        // Decode the response data
        let joinedData = try decoder.decode([JoinedTripData].self, from: response.data)

        // Convert joined data to Trip objects
        let tripsWithVehicles = joinedData.map { data -> Trip in
            let supabaseTrip = SupabaseTrip(
                id: data.id,
                destination: data.destination,
                trip_status: data.trip_status,
                has_completed_pre_trip: data.has_completed_pre_trip,
                has_completed_post_trip: data.has_completed_post_trip,
                vehicle_id: data.vehicle_id,
                driver_id: data.driver_id,
                secondary_driver_id: data.secondary_driver_id,
                start_time: data.start_time,
                end_time: data.end_time,
                notes: data.notes,
                created_at: data.created_at,
                updated_at: data.updated_at ?? data.created_at,
                is_deleted: data.is_deleted,
                start_latitude: data.start_latitude,
                start_longitude: data.start_longitude,
                end_latitude: data.end_latitude,
                end_longitude: data.end_longitude,
                pickup: data.pickup,
                estimated_distance: data.estimated_distance,
                estimated_time: data.estimated_time
            )
            return Trip(from: supabaseTrip, vehicle: data.vehicles)
        }

        print("Successfully processed \(tripsWithVehicles.count) all trips")

        // Update allTrips property
        self.allTrips = tripsWithVehicles
    } catch {
        print("Error fetching all trips: \(error)")
        throw TripError.fetchError("Failed to fetch all trips: \(error.localizedDescription)")
    }
}

@MainActor
func createTrip(
    destination: String,
    vehicleId: UUID,
    driverId: UUID? = nil,
    secondaryDriverId: UUID? = nil,
    startTime: Date? = nil,
    endTime: Date? = nil,
    notes: String? = nil,
    startLatitude: Double? = nil,
    startLongitude: Double? = nil,
    endLatitude: Double? = nil,
    endLongitude: Double? = nil,
    pickup: String? = nil,
    estimatedDistance: Double? = nil,
    estimatedTime: Double? = nil
) async throws -> UUID {
    do {
        let tripId = UUID()
        var tripData: [String: Any] = [
            "id": tripId,
            "destination": destination,
            "trip_status": TripStatus.pending.rawValue,
            "has_completed_pre_trip": false,
            "has_completed_post_trip": false,
            "vehicle_id": vehicleId,
            "created_at": Date(),
            "updated_at": Date(),
            "is_deleted": false
        ]
        
        // Add optional fields
        if let driverId = driverId { tripData["driver_id"] = driverId }
        if let secondaryDriverId = secondaryDriverId { tripData["secondary_driver_id"] = secondaryDriverId }
        if let startTime = startTime { tripData["start_time"] = startTime }
        if let endTime = endTime { tripData["end_time"] = endTime }
        if let notes = notes { tripData["notes"] = notes }
        if let startLatitude = startLatitude { tripData["start_latitude"] = startLatitude }
        if let startLongitude = startLongitude { tripData["start_longitude"] = startLongitude }
        if let endLatitude = endLatitude { tripData["end_latitude"] = endLatitude }
        if let endLongitude = endLongitude { tripData["end_longitude"] = endLongitude }
        if let pickup = pickup { tripData["pickup"] = pickup }
        if let estimatedDistance = estimatedDistance { tripData["estimated_distance"] = estimatedDistance }
        if let estimatedTime = estimatedTime { tripData["estimated_time"] = estimatedTime }
        
        let query = supabaseController.supabase
            .from("trips")
            .insert(tripData)
            .select()

        _ = try await query.execute()
        try await fetchTrips()
        return tripId
    } catch {
        print("Error creating trip: \(error)")
        throw TripError.createError("Failed to create trip: \(error.localizedDescription)")
    }
}

@MainActor
func updateTrip(id: UUID, destination: String? = nil, status: TripStatus? = nil, hasCompletedPreTrip: Bool? = nil, hasCompletedPostTrip: Bool? = nil, vehicleId: UUID? = nil, driverId: UUID? = nil, secondaryDriverId: UUID? = nil, startTime: Date? = nil, endTime: Date? = nil, notes: String? = nil, startLatitude: Double? = nil, startLongitude: Double? = nil, endLatitude: Double? = nil, endLongitude: Double? = nil, pickup: String? = nil, estimatedDistance: Double? = nil, estimatedTime: Double? = nil) async throws {
    do {
        var updateData: [String: Any] = [:]
        
        if let destination = destination { updateData["destination"] = destination }
        if let status = status { updateData["trip_status"] = status }
        if let hasCompletedPreTrip = hasCompletedPreTrip { updateData["has_completed_pre_trip"] = hasCompletedPreTrip }
        if let hasCompletedPostTrip = hasCompletedPostTrip { updateData["has_completed_post_trip"] = hasCompletedPostTrip }
        if let vehicleId = vehicleId { updateData["vehicle_id"] = vehicleId }
        if let driverId = driverId { updateData["driver_id"] = driverId }
        if let secondaryDriverId = secondaryDriverId { updateData["secondary_driver_id"] = secondaryDriverId }
        if let startTime = startTime { updateData["start_time"] = startTime }
        if let endTime = endTime { updateData["end_time"] = endTime }
        if let notes = notes { updateData["notes"] = notes }
        if let startLatitude = startLatitude { updateData["start_latitude"] = startLatitude }
        if let startLongitude = startLongitude { updateData["start_longitude"] = startLongitude }
        if let endLatitude = endLatitude { updateData["end_latitude"] = endLatitude }
        if let endLongitude = endLongitude { updateData["end_longitude"] = endLongitude }
        if let pickup = pickup { updateData["pickup"] = pickup }
        if let estimatedDistance = estimatedDistance { updateData["estimated_distance"] = estimatedDistance }
        if let estimatedTime = estimatedTime { updateData["estimated_time"] = estimatedTime }
        
        updateData["updated_at"] = Date()
        
        let query = supabaseController.supabase
            .from("trips")
            .update(updateData)
            .eq("id", value: id)
            .select()
        
        _ = try await query.execute()
        try await fetchTrips()
    } catch {
        print("Error updating trip: \(error)")
        throw TripError.updateError("Failed to update trip: \(error.localizedDescription)")
    }
}

struct JoinedTripData: Codable {
    let id: UUID
    let destination: String
    let trip_status: TripStatus
    let has_completed_pre_trip: Bool
    let has_completed_post_trip: Bool
    let vehicle_id: UUID
    let driver_id: UUID
    let secondary_driver_id: UUID?
    let start_time: Date?
    let end_time: Date?
    let notes: String?
    let created_at: Date
    let updated_at: Date?
    let is_deleted: Bool
    let start_latitude: Double?
    let start_longitude: Double?
    let end_latitude: Double?
    let end_longitude: Double?
    let pickup: String?
    let estimated_distance: Double?
    let estimated_time: Double?
    let vehicles: Vehicle
}

let supabaseTrip = SupabaseTrip(
    id: data.id,
    destination: data.destination,
    trip_status: data.trip_status,
    has_completed_pre_trip: data.has_completed_pre_trip,
    has_completed_post_trip: data.has_completed_post_trip,
    vehicle_id: data.vehicle_id,
    driver_id: data.driver_id,
    secondary_driver_id: data.secondary_driver_id,
    start_time: data.start_time,
    end_time: data.end_time,
    notes: data.notes,
    created_at: data.created_at,
    updated_at: data.updated_at ?? data.created_at,
    is_deleted: data.is_deleted,
    start_latitude: data.start_latitude,
    start_longitude: data.start_longitude,
    end_latitude: data.end_latitude,
    end_longitude: data.end_longitude,
    pickup: data.pickup,
    estimated_distance: data.estimated_distance,
    estimated_time: data.estimated_time
) 