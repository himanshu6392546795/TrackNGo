import SwiftUI

struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading && viewModel.notifications.isEmpty {
                    ProgressView()
                } else if viewModel.notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Notifications")
                            .font(.headline)
                        Text("You're all caught up!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(viewModel.notifications) { notification in
                            NotificationCell(notification: notification) {
                                Task {
                                    await viewModel.markAsRead(notification)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.loadNotifications()
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                if !viewModel.notifications.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Mark All Read") {
                            Task {
                                await viewModel.markAllAsRead()
                            }
                        }
                    }
                }
            }
        }
    }
}

struct NotificationCell: View {
    let notification: NotificationItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                Circle()
                    .fill(notification.type.color.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: notification.type.iconName)
                            .foregroundColor(notification.type.color)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.message)
                        .font(.system(.body))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(notification.created_at, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if !notification.is_read {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .background(notification.is_read ? Color.clear : Color.blue.opacity(0.05))
    }
} 