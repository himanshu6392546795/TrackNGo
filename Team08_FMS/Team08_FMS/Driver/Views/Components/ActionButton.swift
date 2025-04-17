import SwiftUI

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 10) {
        HStack(spacing: 10) {
            ActionButton(title: "Start Navigation", icon: "location.fill", color: .blue) {}
            ActionButton(title: "Pre-Trip Inspection", icon: "checklist", color: .orange) {}
        }
        ActionButton(title: "Mark Delivered", icon: "checkmark.circle.fill", color: .green) {}
    }
    .padding()
} 