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
    @StateObject private var mailjetService = MailjetService.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingSystemPreferences = false
    @State private var hoveredCard: String? = nil
    @State private var showingAddRecipient = false
    @State private var showingMailjetConfig = false
    
    private var enabledNotificationCount: Int {
        var count = 0
        if notificationService.notifyOnBattery { count += 1 }
        if notificationService.notifyOnPowerRestored { count += 1 }
        if notificationService.notifyOnDeviceOffline { count += 1 }
        if notificationService.notifyOnCriticalAlarms { count += 1 }
        if notificationService.notifyOnLowBattery { count += 1 }
        return count
    }
    
    private var enabledEmailAlertCount: Int {
        var count = 0
        if notificationService.emailOnCritical { count += 1 }
        if notificationService.emailOnWarning { count += 1 }
        if notificationService.emailOnMaintenance { count += 1 }
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
                        }
                    }
                    
                    // Email Notifications Section
                    emailNotificationsSection
                    
                    if notificationService.emailNotificationsEnabled {
                        // Mailjet Configuration
                        mailjetConfigurationSection
                        
                        // Email Recipients
                        emailRecipientsSection
                        
                        // Email Alert Types
                        emailAlertTypesSection
                        
                        // Email Reports
                        emailReportsSection
                    }
                    
                    // Test sections
                    if notificationService.notificationsEnabled || notificationService.emailNotificationsEnabled {
                        testSection
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(24)
            }
        }
        .frame(maxWidth: 800) // Increased for email settings
        .sheet(isPresented: $showingAddRecipient) {
            AddEmailRecipientView(mailjetService: mailjetService)
        }
        .sheet(isPresented: $showingMailjetConfig) {
            MailjetConfigurationView(mailjetService: mailjetService)
        }
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
                                colors: [
                                    colorScheme == .dark ? Color.white : Color.black,
                                    Color.blue.opacity(0.8)
                                ],
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
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
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
    
    // MARK: - Email Notifications Section
    
    @ViewBuilder
    private var emailNotificationsSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "email-notifications") {
            VStack(alignment: .leading, spacing: 16) {
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
                        
                        Image(systemName: "envelope")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue, Color.cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .symbolEffect(.bounce.up, value: hoveredCard == "email-notifications")
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email Notifications")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Text("Send critical alerts and reports via email")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    LiquidGlassToggle(isOn: $notificationService.emailNotificationsEnabled)
                }
                
                if !mailjetService.isConfigured && notificationService.emailNotificationsEnabled {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            
                            Text("Email service not configured")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.orange)
                            
                            Spacer()
                        }
                        
                        LiquidGlassButton(
                            "Configure Mailjet",
                            icon: "gear",
                            style: .primary
                        ) {
                            showingMailjetConfig = true
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    @ViewBuilder
    private var mailjetConfigurationSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "mailjet-config") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Email Service Configuration")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(mailjetService.isConfigured ? .green : .red)
                            .frame(width: 8, height: 8)
                        
                        Text(mailjetService.isConfigured ? "Configured" : "Not Configured")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(mailjetService.isConfigured ? .green : .red)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                }
                
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("API Configuration")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Mailjet API key, secret, and sender details")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        LiquidGlassButton(
                            "Configure",
                            icon: "gear",
                            style: .secondary
                        ) {
                            showingMailjetConfig = true
                        }
                    }
                    
                    if mailjetService.isConfigured {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("From:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text("\(mailjetService.fromName) <\(mailjetService.fromEmail)>")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            
                            HStack {
                                Text("Recipients:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text("\(mailjetService.recipients.count) configured")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.blue)
                                
                                Spacer()
                            }
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var emailRecipientsSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "email-recipients") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Email Recipients")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Spacer()
                    
                    Text("\(mailjetService.recipients.count) recipients")
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
                
                if mailjetService.recipients.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(.secondary)
                        
                        Text("No recipients configured")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("Add email recipients to receive UPS alerts")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 8) {
                        ForEach(mailjetService.recipients) { recipient in
                            EmailRecipientRow(
                                recipient: recipient,
                                mailjetService: mailjetService,
                                hoveredCard: $hoveredCard
                            )
                        }
                    }
                }
                
                LiquidGlassButton(
                    "Add Recipient",
                    icon: "plus.circle.fill",
                    style: .primary
                ) {
                    showingAddRecipient = true
                }
            }
        }
    }
    
    @ViewBuilder
    private var emailAlertTypesSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "email-alert-types") {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Email Alert Types")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Spacer()
                    
                    Text("\(enabledEmailAlertCount) enabled")
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
                    EmailAlertToggleRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Critical Alerts",
                        description: "Device offline, power failures, battery depleted",
                        isOn: $notificationService.emailOnCritical,
                        accentColor: .red
                    )
                    
                    EmailAlertToggleRow(
                        icon: "exclamationmark.circle.fill",
                        title: "Warning Alerts",
                        description: "High temperature, high load, battery aging",
                        isOn: $notificationService.emailOnWarning,
                        accentColor: .orange
                    )
                    
                    EmailAlertToggleRow(
                        icon: "wrench.and.screwdriver.fill",
                        title: "Maintenance Alerts",
                        description: "Battery replacement, scheduled maintenance",
                        isOn: $notificationService.emailOnMaintenance,
                        accentColor: .blue
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var emailReportsSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "email-reports") {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green, Color.mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status Reports")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Text("Automated email reports with UPS status summaries")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(spacing: 16) {
                    // Daily Reports
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Daily Reports")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                
                                Text("Daily status summary")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            LiquidGlassToggle(isOn: $notificationService.emailDailyReports)
                        }
                        
                        if notificationService.emailDailyReports {
                            HStack(spacing: 12) {
                                Image(systemName: "clock")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.green)
                                    .frame(width: 20)
                                
                                Text("Send at:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                DatePicker("", selection: $notificationService.dailyReportTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.green.opacity(notificationService.emailDailyReports ? 0.3 : 0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.8
                                    )
                            )
                    )
                    
                    // Weekly Reports
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Weekly Reports")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                
                                Text("Weekly summary")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            LiquidGlassToggle(isOn: $notificationService.emailWeeklyReports)
                        }
                        
                        if notificationService.emailWeeklyReports {
                            VStack(spacing: 8) {
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.green)
                                        .frame(width: 20)
                                    
                                    Text("Send on:")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Picker("Weekday", selection: $notificationService.weeklyReportWeekday) {
                                        Text("Sunday").tag(1)
                                        Text("Monday").tag(2)
                                        Text("Tuesday").tag(3)
                                        Text("Wednesday").tag(4)
                                        Text("Thursday").tag(5)
                                        Text("Friday").tag(6)
                                        Text("Saturday").tag(7)
                                    }
                                    .pickerStyle(.menu)
                                    .frame(minWidth: 100)
                                }
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.green)
                                        .frame(width: 20)
                                    
                                    Text("Send at:")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    DatePicker("", selection: $notificationService.weeklyReportTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                }
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.green.opacity(notificationService.emailWeeklyReports ? 0.3 : 0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.8
                                    )
                            )
                    )
                    
                    // Monthly Reports
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Monthly Reports")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                
                                Text("Monthly summary")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            LiquidGlassToggle(isOn: $notificationService.emailMonthlyReports)
                        }
                        
                        if notificationService.emailMonthlyReports {
                            VStack(spacing: 8) {
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.green)
                                        .frame(width: 20)
                                    
                                    Text("Send on day:")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Picker("Day of month", selection: $notificationService.monthlyReportDay) {
                                        ForEach(Array(1...31), id: \.self) { day in
                                            Text("\(day)\(day.ordinalSuffix)")
                                                .tag(day)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(minWidth: 80)
                                }
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.green)
                                        .frame(width: 20)
                                    
                                    Text("Send at:")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    DatePicker("", selection: $notificationService.monthlyReportTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                }
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.green.opacity(notificationService.emailMonthlyReports ? 0.3 : 0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.8
                                    )
                            )
                    )
                }
                
                // Next scheduled reports info
                if notificationService.emailNotificationsEnabled && 
                   (notificationService.emailDailyReports || notificationService.emailWeeklyReports || notificationService.emailMonthlyReports) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Next Scheduled Reports")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        let nextReportTimes = ReportSchedulerService.shared.getNextReportTimes()
                        
                        VStack(spacing: 8) {
                            if notificationService.emailDailyReports, let nextDaily = nextReportTimes.daily {
                                HStack {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.green)
                                        .frame(width: 16)
                                    
                                    Text("Daily:")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text(nextDaily, style: .relative)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    
                                    Text("at \(nextDaily.formatted(date: .omitted, time: .shortened))")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            if notificationService.emailWeeklyReports, let nextWeekly = nextReportTimes.weekly {
                                HStack {
                                    Image(systemName: "calendar.badge.plus")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.blue)
                                        .frame(width: 16)
                                    
                                    Text("Weekly:")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text(nextWeekly, style: .relative)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    
                                    Text("at \(nextWeekly.formatted(date: .omitted, time: .shortened))")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            if notificationService.emailMonthlyReports, let nextMonthly = nextReportTimes.monthly {
                                HStack {
                                    Image(systemName: "calendar.circle")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.purple)
                                        .frame(width: 16)
                                    
                                    Text("Monthly:")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text(nextMonthly, style: .relative)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    
                                    Text("at \(nextMonthly.formatted(date: .omitted, time: .shortened))")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var testSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "test-section") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Test Notifications")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text("Send test notifications to verify your settings are working correctly.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    // Local and Email Alert Tests
                    HStack(spacing: 12) {
                        if notificationService.notificationsEnabled {
                            LiquidGlassButton(
                                "Test Local",
                                icon: "bell.fill",
                                style: .secondary
                            ) {
                                notificationService.testNotification()
                            }
                        }
                        
                        if notificationService.emailNotificationsEnabled && mailjetService.isConfigured {
                            LiquidGlassButton(
                                "Test Email",
                                icon: "envelope.fill",
                                style: .primary
                            ) {
                                notificationService.testEmailNotification()
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Email Report Tests
                    if notificationService.emailNotificationsEnabled && mailjetService.isConfigured {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Test Reports")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            HStack(spacing: 8) {
                                LiquidGlassButton(
                                    "Daily",
                                    icon: "calendar",
                                    style: .secondary
                                ) {
                                    ReportSchedulerService.shared.sendTestDailyReport()
                                }
                                
                                LiquidGlassButton(
                                    "Weekly",
                                    icon: "calendar.badge.plus",
                                    style: .secondary
                                ) {
                                    ReportSchedulerService.shared.sendTestWeeklyReport()
                                }
                                
                                LiquidGlassButton(
                                    "Monthly",
                                    icon: "calendar.circle",
                                    style: .secondary
                                ) {
                                    ReportSchedulerService.shared.sendTestMonthlyReport()
                                }
                                
                                Spacer()
                            }
                            
                            // Debug section (in development)
                            #if DEBUG
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Debug Scheduler")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.orange)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                
                                HStack(spacing: 8) {
                                    LiquidGlassButton(
                                        "Debug Info",
                                        icon: "info.circle",
                                        style: .secondary
                                    ) {
                                        ReportSchedulerService.shared.debugReportScheduler()
                                    }
                                    
                                    LiquidGlassButton(
                                        "Force Check",
                                        icon: "clock.arrow.circlepath",
                                        style: .secondary
                                    ) {
                                        Task {
                                            await ReportSchedulerService.shared.manualReportCheck()
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                            #endif
                        }
                        .padding(.top, 8)
                    }
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
    @Environment(\.colorScheme) private var colorScheme
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
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
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

// MARK: - Email Alert Toggle Row

struct EmailAlertToggleRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    let accentColor: Color
    @Environment(\.colorScheme) private var colorScheme
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
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
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

// MARK: - Email Report Toggle Row

struct EmailReportToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            LiquidGlassToggle(isOn: $isOn)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .opacity(isHovered ? 0.5 : 0.3)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.green
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
            color: Color.green.opacity(isOn && isHovered ? 0.2 : 0.1),
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

// MARK: - Extensions

extension Int {
    var ordinalSuffix: String {
        switch self % 10 {
        case 1:
            return self % 100 == 11 ? "th" : "st"
        case 2:
            return self % 100 == 12 ? "th" : "nd"
        case 3:
            return self % 100 == 13 ? "th" : "rd"
        default:
            return "th"
        }
    }
}