import SwiftUI
import CoreLocation

struct CurrentDeliveryCard: View {
    @StateObject private var tripController = TripDataController.shared
    
    var body: some View {
        if let currentTrip = tripController.currentTrip {
            VStack(alignment: .leading, spacing: 16) {
                Text("Current Delivery")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "truck")
                    Text("Vehicle Details: \(currentTrip.vehicleDetails.licensePlate)")
                        .font(.subheadline)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                // Trip Locations
                VStack(alignment: .leading, spacing: 0) {
                    // Container for the entire vertical line with destination pin
                    ZStack(alignment: .leading) {
                        // Vertical line that stops at the destination pin
                        Rectangle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 2, height: 80) // Adjust height to connect with the pin
                            .padding(.leading, 10) // Center the line with the circles
                            .padding(.top, 10) // Start below the blue circle
                        
                        // Progress bar
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 2, height: 40) // Half height for progress
                            .padding(.leading, 10)
                            .padding(.top, 10)
                        
                        VStack(alignment: .leading, spacing: 20) {
                            // Starting Point section
                            HStack(alignment: .top, spacing: 18) {
                                // Blue circle
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 20, height: 20)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Starting Point")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Text(currentTrip.startingPoint)
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("Mumbai, Maharashtra")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // Destination section
                            HStack(alignment: .top, spacing: 18) {
                                // Red location pin
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.red)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Destination")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Text(currentTrip.destination)
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text(currentTrip.address)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.leading, -4) // Adjust to align with the blue circle
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 10)
                
                HStack {
                    VStack {
                        Text("ETA")
                            .font(.caption)
                        Text(currentTrip.eta)
                            .font(.body)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    VStack {
                        Text("Distance")
                            .font(.caption)
                        Text(currentTrip.distance)
                            .font(.body)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 4)
        } else {
            // Placeholder view when there's no current trip
            VStack {
                Text("No Current Delivery")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 4)
        }
    }
}

#Preview {
    CurrentDeliveryCard()
        .padding()
        .background(Color(.systemGroupedBackground))
} 
