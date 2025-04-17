import SwiftUI

struct AlertsView: View {
    @StateObject private var viewModel = NotificationsViewModel()
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack {
                if viewModel.isLoading && viewModel.notifications.isEmpty {
                    ProgressView("Loading alerts...")
                        .padding()
                } else if let error = viewModel.error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        
                        Text("Error Loading Alerts")
                            .font(.headline)
                        
                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button {
                            Task {
                                await viewModel.loadNotifications()
                            }
                        } label: {
                            Text("Try Again")
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                } else if viewModel.notifications.isEmpty {
                    AlertEmptyStateView()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Summary Cards Section
                            AlertSummarySection(
                                unreadCount: viewModel.unreadCount,
                                totalCount: viewModel.notifications.count
                            )
                            .padding(.top, 8)
                            .padding(.horizontal)
                            
                            // Notifications List
                            NotificationsListView(
                                notifications: viewModel.notifications,
                                onMarkAsRead: { notification in
                                    Task {
                                        await viewModel.markAsRead(notification)
                                    }
                                },
                                onDelete: { notification in
                                    Task {
                                        await viewModel.deleteNotification(notification)
                                    }
                                }
                            )
                            .padding(.top, 16)
                        }
                    }
                    .refreshable {
                        await viewModel.loadNotifications()
                    }
                }
            }
        }
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
            
            if !viewModel.notifications.isEmpty {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.markAllAsRead()
                        }
                    } label: {
                        Text("Mark All as Read")
                            .font(.subheadline)
                    }
                }
            }
        }
        .task {
            await viewModel.loadNotifications()
        }
        .alert("Enable Notifications", isPresented: $viewModel.showNotificationPermissionAlert) {
            Button("Open Settings") {
                viewModel.openAppSettings()
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("To receive important alerts about your fleet, please enable notifications in Settings.")
        }
    }
}

// MARK: - Supporting Views

struct AlertEmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "bell.slash.circle.fill")
                    .font(.system(size: 50))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.gray)
            }
            
            VStack(spacing: 8) {
                Text("No Alerts")
                    .font(.system(.title2, design: .default).weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("You're all caught up!")
                    .font(.system(.subheadline, design: .default))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AlertSummarySection: View {
    let unreadCount: Int
    let totalCount: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Unread Card
            AlertSummaryCard(
                icon: "bell.fill",
                title: "Unread",
                count: unreadCount,
                color: .blue
            )
            
            // Total Card
            AlertSummaryCard(
                icon: "bell",
                title: "Total",
                count: totalCount,
                color: .gray
            )
        }
    }
}

struct AlertSummaryCard: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                Text("\(count)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

struct NotificationsListView: View {
    let notifications: [NotificationItem]
    let onMarkAsRead: (NotificationItem) -> Void
    let onDelete: (NotificationItem) -> Void
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(notifications) { notification in
                AlertNotificationRow(notification: notification)
                    .padding(.horizontal)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if !notification.is_read {
                            Button {
                                onMarkAsRead(notification)
                            } label: {
                                Label("Mark as Read", systemImage: "checkmark")
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDelete(notification)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }
}

struct AlertNotificationRow: View {
    let notification: NotificationItem
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: notification.type.iconName)
                .font(.system(size: 24))
                .foregroundColor(notification.type.color)
                .padding(6)
                .background(Color(UIColor.systemGray6))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.message)
                    .font(.system(.body))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(notification.created_at, style: .relative)
                    .font(.system(.caption))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !notification.is_read {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
