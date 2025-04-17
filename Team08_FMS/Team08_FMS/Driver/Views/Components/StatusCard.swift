import SwiftUI

struct DriverStatusCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.system(size: 18, weight: .medium))
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct TripStatusView: View {
    @StateObject private var tripController = TripDataController.shared
    
    var body: some View {
        HStack(spacing: 12) {
            DriverStatusCard(
                icon: "clock.fill",
                title: "ETA",
                value: tripController.currentTrip?.eta ?? "N/A",
                color: .blue
            )
            
            DriverStatusCard(
                icon: "arrow.left.and.right",
                title: "Distance",
                value: tripController.currentTrip?.distance ?? "N/A",
                color: .green
            )
        }
        .padding()
        .task {
            await tripController.refreshTrips()
        }
    }
}

#Preview {
    TripStatusView()
} 
