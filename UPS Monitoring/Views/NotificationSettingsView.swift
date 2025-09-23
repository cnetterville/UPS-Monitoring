//
//  NotificationSettingsView.swift
//  UPS Monitoring
//
//  Created by Curtis Netterville on 9/17/25.
//

import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @StateObject private var notificationService = NotificationService.shared
    @State private var showingSystemPreferences = false
    @State private var hoveredCard: String? = nil
    
    private var enabledNotificationCount: Int {
        var count = 0
        if notificationService.notifyOnBattery { count += 1 }
        if notificationService.notifyOnPowerRestored { count += 1 }
        if notificationService.notifyOnDeviceOffline { count += 1 }
        if notificationService.notifyOnCriticalAlarms { count += 1 }
        if notificationService.notifyOnLowBattery { count += 1 }
        return count
    }
    
    var body: some View {
        ZStack {
            // Liquid Glass Background
            LiquidGlassBackground()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with liquid glass effect
                    headerSection
                    
                    // Permission status with glass card
                    permissionStatusSection
                    
                    if notificationService.notificationPermissionStatus == .authorized {
                        // Main notification toggle with glass effect
                        mainToggleSection
                        
                        if notificationService.notificationsEnabled {
                            // Notification preferences with glass cards
                            notificationTypesSection
                            
                            // Test section with glass effect
                            testSection
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(24)
            }
        }
        .frame(maxWidth: 600)
    }
    
    @ViewBuilder
    private var headerSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "header") {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.blue.opacity(0.4),
                                    Color.cyan.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 30
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.blue.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    Image(systemName: "bell")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.bounce.up, value: hoveredCard == "header")
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notification Settings")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.primary, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Configure alerts and notifications for UPS events")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var mainToggleSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "main-toggle") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Notifications")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Receive alerts for UPS status changes and critical events")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    LiquidGlassToggle(isOn: $notificationService.notificationsEnabled)
                }
            }
        }
    }
    
    @ViewBuilder
    private var notificationTypesSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "notification-types") {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Alert Types")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Spacer()
                    
                    Text("\(enabledNotificationCount) enabled")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                }
                
                VStack(spacing: 16) {
                    NotificationToggleRow(
                        icon: "battery.75",
                        title: "Battery Power",
                        description: "When UPS switches to battery power",
                        isOn: $notificationService.notifyOnBattery,
                        accentColor: .orange
                    )
                    
                    NotificationToggleRow(
                        icon: "bolt.fill",
                        title: "Power Restored",
                        description: "When power returns to normal operation",
                        isOn: $notificationService.notifyOnPowerRestored,
                        accentColor: .green
                    )
                    
                    NotificationToggleRow(
                        icon: "wifi.slash",
                        title: "Device Offline",
                        description: "When UPS device goes offline or stops responding",
                        isOn: $notificationService.notifyOnDeviceOffline,
                        accentColor: .red
                    )
                    
                    NotificationToggleRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Critical Alarms",
                        description: "When critical alarms are detected on the UPS",
                        isOn: $notificationService.notifyOnCriticalAlarms,
                        accentColor: .red
                    )
                    
                    // Low battery with custom threshold
                    VStack(alignment: .leading, spacing: 12) {
                        NotificationToggleRow(
                            icon: "battery.25",
                            title: "Low Battery",
                            description: "When battery charge drops below threshold",
                            isOn: $notificationService.notifyOnLowBattery,
                            accentColor: .yellow
                        )
                        
                        if notificationService.notifyOnLowBattery {
                            LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "battery-threshold") {
                                HStack(spacing: 12) {
                                    Text("Threshold:")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 8) {
                                        TextField("", value: $notificationService.lowBatteryThreshold, format: .number)
                                            .textFieldStyle(.plain)
                                            .multilineTextAlignment(.center)
                                            .frame(width: 50)
                                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(.ultraThinMaterial)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(
                                                                LinearGradient(
                                                                    colors: [
                                                                        Color.white.opacity(0.3),
                                                                        Color.yellow.opacity(0.2)
                                                                    ],
                                                                    startPoint: .topLeading,
                                                                    endPoint: .bottomTrailing
                                                                ),
                                                                lineWidth: 1
                                                            )
                                                    )
                                            )
                                        
                                        Text("%")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var testSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "test-section") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Test Notifications")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("Send a test notification to verify your settings are working correctly.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                LiquidGlassButton(
                    "Send Test Notification",
                    icon: "paperplane.fill",
                    style: .primary
                ) {
                    notificationService.testNotification()
                }
            }
        }
    }
    
    @ViewBuilder
    private var permissionStatusSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "permission-status") {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    permissionStatusColor.opacity(0.3),
                                    permissionStatusColor.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 8,
                                endRadius: 25
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: permissionStatusIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(permissionStatusColor)
                        .symbolEffect(.bounce, value: notificationService.notificationPermissionStatus)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(permissionStatusTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(permissionStatusDescription)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if notificationService.notificationPermissionStatus != .authorized {
                    LiquidGlassButton(
                        permissionStatusButtonTitle,
                        style: permissionStatusColor == .red ? .destructive : .primary
                    ) {
                        if notificationService.notificationPermissionStatus == .denied {
                            notificationService.openSystemPreferences()
                        } else {
                            requestNotificationPermission()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Permission Status Helpers
    
    private var permissionStatusIcon: String {
        switch notificationService.notificationPermissionStatus {
        case .authorized:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        case .provisional:
            return "bell.badge.fill"
        case .ephemeral:
            return "bell.fill"
        @unknown default:
            return "bell.slash.fill"
        }
    }
    
    private var permissionStatusColor: Color {
        switch notificationService.notificationPermissionStatus {
        case .authorized:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        case .provisional, .ephemeral:
            return .blue
        @unknown default:
            return .gray
        }
    }
    
    private var permissionStatusTitle: String {
        switch notificationService.notificationPermissionStatus {
        case .authorized:
            return "Notifications Enabled"
        case .denied:
            return "Notifications Disabled"
        case .notDetermined:
            return "Permission Required"
        case .provisional:
            return "Provisional Access"
        case .ephemeral:
            return "Temporary Access"
        @unknown default:
            return "Unknown Status"
        }
    }
    
    private var permissionStatusDescription: String {
        switch notificationService.notificationPermissionStatus {
        case .authorized:
            return "UPS Monitoring can send notifications for critical events."
        case .denied:
            return "Enable notifications in System Preferences to receive UPS alerts."
        case .notDetermined:
            return "Allow notifications to receive alerts about UPS status changes."
        case .provisional:
            return "Notifications are delivered quietly. Check System Preferences for full access."
        case .ephemeral:
            return "Temporary notification access is active."
        @unknown default:
            return "Notification permission status is unknown."
        }
    }
    
    private var permissionStatusButtonTitle: String {
        switch notificationService.notificationPermissionStatus {
        case .denied:
            return "Open System Preferences"
        case .notDetermined:
            return "Request Permission"
        default:
            return ""
        }
    }
    
    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                // The notification service will automatically update its status
            }
        }
    }
}

// MARK: - Notification Toggle Row Component

struct NotificationToggleRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    let accentColor: Color
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Glass icon container
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        accentColor.opacity(isOn ? 0.3 : 0.1),
                                        accentColor.opacity(isOn ? 0.1 : 0.05)
                                    ],
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 20
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        accentColor.opacity(isOn ? 0.4 : 0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                accentColor,
                                accentColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isHovered ? 1.1 : 1.0)
                    .symbolEffect(.bounce, value: isOn)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            LiquidGlassToggle(isOn: $isOn)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(isHovered ? 0.6 : 0.4)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    accentColor.opacity(isOn ? 0.3 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .shadow(
            color: accentColor.opacity(isOn && isHovered ? 0.2 : 0.1),
            radius: isHovered ? 8 : 4,
            x: 0,
            y: isHovered ? 4 : 2
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
        .onHover { hovered in
            isHovered = hovered
        }
    }
}

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView()
            .frame(width: 600, height: 700)
    }
}