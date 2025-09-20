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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "bell")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Notification Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // Permission status
            permissionStatusSection
            
            if notificationService.notificationPermissionStatus == .authorized {
                // Main notification toggle
                Toggle("Enable Notifications", isOn: $notificationService.notificationsEnabled)
                    .toggleStyle(SwitchToggleStyle())
                
                if notificationService.notificationsEnabled {
                    VStack(alignment: .leading, spacing: 16) {
                        Divider()
                        
                        // Notification type toggles
                        Text("Notify When:")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("UPS switches to battery power", isOn: $notificationService.notifyOnBattery)
                            Toggle("Power is restored", isOn: $notificationService.notifyOnPowerRestored)
                            Toggle("Device goes offline", isOn: $notificationService.notifyOnDeviceOffline)
                            Toggle("Critical alarms are detected", isOn: $notificationService.notifyOnCriticalAlarms)
                            
                            HStack {
                                Toggle("Battery level drops below", isOn: $notificationService.notifyOnLowBattery)
                                
                                if notificationService.notifyOnLowBattery {
                                    TextField("Threshold", value: $notificationService.lowBatteryThreshold, format: .number)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 60)
                                    
                                    Text("%")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.leading, 16)
                        
                        Divider()
                        
                        // Test notification button
                        HStack {
                            Button("Send Test Notification") {
                                notificationService.testNotification()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Spacer()
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: 500)
    }
    
    @ViewBuilder
    private var permissionStatusSection: some View {
        HStack {
            Image(systemName: permissionStatusIcon)
                .foregroundColor(permissionStatusColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(permissionStatusTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(permissionStatusDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if notificationService.notificationPermissionStatus != .authorized {
                Button(permissionStatusButtonTitle) {
                    if notificationService.notificationPermissionStatus == .denied {
                        notificationService.openSystemPreferences()
                    } else {
                        requestNotificationPermission()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(permissionStatusColor.opacity(0.1))
        .cornerRadius(8)
    }
    
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

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView()
    }
}