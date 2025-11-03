//
//  NotificationService.swift
//  UPSMonitoring
//
//  Created by Curtis Netterville on 9/17/25.
//

import Foundation
import UserNotifications
import Combine
import AppKit

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    // Existing notification preferences
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "NotificationsEnabled")
            if !notificationsEnabled {
                removeAllPendingNotifications()
            }
            saveEmailSettings()
        }
    }
    
    @Published var notifyOnBattery: Bool {
        didSet { 
            UserDefaults.standard.set(notifyOnBattery, forKey: "NotifyOnBattery")
            saveEmailSettings()
        }
    }
    
    @Published var notifyOnPowerRestored: Bool {
        didSet { 
            UserDefaults.standard.set(notifyOnPowerRestored, forKey: "NotifyOnPowerRestored")
            saveEmailSettings()
        }
    }
    
    @Published var notifyOnLowBattery: Bool {
        didSet { 
            UserDefaults.standard.set(notifyOnLowBattery, forKey: "NotifyOnLowBattery")
            saveEmailSettings()
        }
    }
    
    @Published var notifyOnDeviceOffline: Bool {
        didSet { 
            UserDefaults.standard.set(notifyOnDeviceOffline, forKey: "NotifyOnDeviceOffline")
            saveEmailSettings()
        }
    }
    
    @Published var notifyOnCriticalAlarms: Bool {
        didSet { 
            UserDefaults.standard.set(notifyOnCriticalAlarms, forKey: "NotifyOnCriticalAlarms")
            saveEmailSettings()
        }
    }
    
    @Published var lowBatteryThreshold: Double {
        didSet { 
            UserDefaults.standard.set(lowBatteryThreshold, forKey: "LowBatteryThreshold")
            saveEmailSettings()
        }
    }
    
    // Email notification settings
    @Published var emailNotificationsEnabled = false {
        didSet { saveEmailSettings() }
    }
    @Published var emailOnCritical = true {
        didSet { saveEmailSettings() }
    }
    @Published var emailOnWarning = true {
        didSet { saveEmailSettings() }
    }
    @Published var emailOnMaintenance = true {
        didSet { saveEmailSettings() }
    }
    @Published var emailDailyReports = false {
        didSet { saveEmailSettings() }
    }
    @Published var emailWeeklyReports = true {
        didSet { saveEmailSettings() }
    }
    @Published var emailMonthlyReports = false {
        didSet { saveEmailSettings() }
    }
    
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    
    // Track previous status to detect changes
    private var previousStatusData: [UUID: UPSStatus] = [:]
    
    // Debouncing for online/offline status
    private var deviceOfflineTimers: [UUID: Timer] = [:]
    private var deviceOnlineTimers: [UUID: Timer] = [:]
    private var stableStatusData: [UUID: UPSStatus] = [:]
    
    private var statusCleanupTimer: Timer?
    private var pendingStatusChanges: [UUID: (status: UPSStatus, timestamp: Date)] = [:]
    
    // Timing constants (in seconds)
    private let offlineDebounceTime: TimeInterval = 30.0 // Device must be offline for 30 seconds
    private let onlineDebounceTime: TimeInterval = 10.0  // Device must be online for 10 seconds
    private let statusCleanupInterval: TimeInterval = 5.0 // Check pending changes every 5 seconds
    
    private var cancellables = Set<AnyCancellable>()
    
    private let mailjetService = MailjetService.shared
    
    private override init() {
        // Load preferences from UserDefaults
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "NotificationsEnabled") as? Bool ?? true
        self.notifyOnBattery = UserDefaults.standard.object(forKey: "NotifyOnBattery") as? Bool ?? true
        self.notifyOnPowerRestored = UserDefaults.standard.object(forKey: "NotifyOnPowerRestored") as? Bool ?? true
        self.notifyOnLowBattery = UserDefaults.standard.object(forKey: "NotifyOnLowBattery") as? Bool ?? true
        self.notifyOnDeviceOffline = UserDefaults.standard.object(forKey: "NotifyOnDeviceOffline") as? Bool ?? true
        self.notifyOnCriticalAlarms = UserDefaults.standard.object(forKey: "NotifyOnCriticalAlarms") as? Bool ?? true
        self.lowBatteryThreshold = UserDefaults.standard.object(forKey: "LowBatteryThreshold") as? Double ?? 20.0
        
        super.init()
        
        loadEmailSettings()
        requestNotificationPermission()
    }

    // MARK: - Email Settings Management
    
    private func saveEmailSettings() {
        let settings: [String: Any] = [
            "emailNotificationsEnabled": emailNotificationsEnabled,
            "emailOnCritical": emailOnCritical,
            "emailOnWarning": emailOnWarning,
            "emailOnMaintenance": emailOnMaintenance,
            "emailDailyReports": emailDailyReports,
            "emailWeeklyReports": emailWeeklyReports,
            "emailMonthlyReports": emailMonthlyReports
        ]
        
        UserDefaults.standard.set(settings, forKey: "emailNotificationSettings")
    }
    
    private func loadEmailSettings() {
        guard let settings = UserDefaults.standard.dictionary(forKey: "emailNotificationSettings") else { return }
        
        emailNotificationsEnabled = settings["emailNotificationsEnabled"] as? Bool ?? false
        emailOnCritical = settings["emailOnCritical"] as? Bool ?? true
        emailOnWarning = settings["emailOnWarning"] as? Bool ?? true
        emailOnMaintenance = settings["emailOnMaintenance"] as? Bool ?? true
        emailDailyReports = settings["emailDailyReports"] as? Bool ?? false
        emailWeeklyReports = settings["emailWeeklyReports"] as? Bool ?? true
        emailMonthlyReports = settings["emailMonthlyReports"] as? Bool ?? false
    }

    func initialize(with monitoringService: UPSMonitoringService) {
        // Initialize the report scheduler with monitoring service after both services are ready
        Task { @MainActor in
            ReportSchedulerService.shared.initialize(with: monitoringService)
        }
        
        // Observe status changes
        monitoringService.$statusData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] statusData in
                self?.checkForStatusChanges(statusData, devices: monitoringService.devices)
            }
            .store(in: &cancellables)
    }
    
    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification permission error: \(error)")
                }
                self.updatePermissionStatus()
            }
        }
    }
    
    private func updatePermissionStatus() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }
    
    private func checkForStatusChanges(_ currentStatusData: [UUID: UPSStatus], devices: [UPSDevice]) {
        guard notificationsEnabled && notificationPermissionStatus == .authorized else { return }
        
        for device in devices where device.isEnabled {
            guard let currentStatus = currentStatusData[device.id] else { continue }
            let previousStatus = previousStatusData[device.id]
            let stableStatus = stableStatusData[device.id]
            
            // Handle online/offline status changes with debouncing
            handleOnlineOfflineStatusChange(device: device, currentStatus: currentStatus, stableStatus: stableStatus)
            
            // For other status changes, use the stable status if available, otherwise current
            let statusToCompare = stableStatus ?? currentStatus
            
            if let previous = previousStatus {
                // Check for power source changes (going on battery or returning to normal)
                if let prevSource = previous.outputSource, let currentSource = statusToCompare.outputSource {
                    if prevSource != "Battery" && currentSource == "Battery" && notifyOnBattery {
                        sendOnBatteryNotification(device: device, status: statusToCompare)
                        
                        // Email notification for power failure
                        if emailNotificationsEnabled && emailOnCritical {
                            let emailMessage = EmailTemplateService.createCriticalAlert(
                                device: device,
                                status: statusToCompare,
                                alertType: .powerFailure,
                                additionalInfo: "The UPS switched to battery power at \(Date().formatted()). Estimated runtime: \(statusToCompare.formattedRuntime ?? "Unknown")"
                            )
                            mailjetService.queueEmail(emailMessage)
                        }
                    } else if prevSource == "Battery" && currentSource != "Battery" && notifyOnPowerRestored {
                        sendPowerRestoredNotification(device: device, status: statusToCompare)
                        
                        // Email notification for power restored
                        if emailNotificationsEnabled && emailOnWarning {
                            sendPowerRestoredEmail(device: device, status: statusToCompare)
                        }
                    }
                }
                
                // Check for low battery (only if charge decreased)
                if let prevCharge = previous.batteryCharge,
                   let currentCharge = statusToCompare.batteryCharge,
                   notifyOnLowBattery {
                    
                    // Send notification if we just crossed the threshold (going down)
                    if prevCharge > lowBatteryThreshold && currentCharge <= lowBatteryThreshold {
                        sendLowBatteryNotification(device: device, status: statusToCompare)
                        
                        // Email notification for low battery
                        if emailNotificationsEnabled && emailOnCritical {
                            let emailMessage = EmailTemplateService.createCriticalAlert(
                                device: device,
                                status: statusToCompare,
                                alertType: .batteryLow(threshold: lowBatteryThreshold),
                                additionalInfo: "Battery level dropped to \(Int(currentCharge))% at \(Date().formatted()). Consider immediate action to prevent data loss."
                            )
                            mailjetService.queueEmail(emailMessage)
                        }
                    }
                }
                
                // Check for high temperature
                if let prevTemp = previous.temperature,
                   let currentTemp = statusToCompare.temperature {
                    if prevTemp <= 35.0 && currentTemp > 35.0 {
                        if emailNotificationsEnabled && emailOnWarning {
                            let emailMessage = EmailTemplateService.createWarningAlert(
                                device: device,
                                status: statusToCompare,
                                alertType: .highTemperature(temp: currentTemp),
                                value: "\(Int(currentTemp))°C",
                                threshold: "Normal range: 20-35°C"
                            )
                            mailjetService.queueEmail(emailMessage)
                        }
                    }
                }
                
                // Check for high load
                if let prevLoad = previous.load,
                   let currentLoad = statusToCompare.load {
                    if prevLoad <= 80.0 && currentLoad > 80.0 {
                        if emailNotificationsEnabled && emailOnWarning {
                            let emailMessage = EmailTemplateService.createWarningAlert(
                                device: device,
                                status: statusToCompare,
                                alertType: .highLoad(load: currentLoad),
                                value: "\(Int(currentLoad))%",
                                threshold: "Recommended maximum: 80%"
                            )
                            mailjetService.queueEmail(emailMessage)
                        }
                    }
                }
                
                // Check for critical alarms
                if let prevAlarms = previous.alarmsPresent,
                   let currentAlarms = statusToCompare.alarmsPresent,
                   notifyOnCriticalAlarms {
                    
                    if prevAlarms == 0 && currentAlarms > 0 {
                        sendCriticalAlarmNotification(device: device, status: statusToCompare)
                        
                        // Email notification for critical alarms
                        if emailNotificationsEnabled && emailOnCritical {
                            let emailMessage = EmailTemplateService.createCriticalAlert(
                                device: device,
                                status: statusToCompare,
                                alertType: .criticalAlarm,
                                additionalInfo: "The UPS has reported \(currentAlarms) active alarm(s) at \(Date().formatted()). Professional service may be required."
                            )
                            mailjetService.queueEmail(emailMessage)
                        }
                    }
                }
                
            } else {
                // First time seeing this device - check if it's in a critical state
                // Only use stable status for first-time checks if device has been stable
                if statusToCompare.isOnline {
                    if let charge = statusToCompare.batteryCharge,
                       charge <= lowBatteryThreshold && notifyOnLowBattery {
                        sendLowBatteryNotification(device: device, status: statusToCompare)
                    }
                    
                    if let outputSource = statusToCompare.outputSource,
                       outputSource == "Battery" && notifyOnBattery {
                        sendOnBatteryNotification(device: device, status: statusToCompare)
                    }
                    
                    if let alarms = statusToCompare.alarmsPresent,
                       alarms > 0 && notifyOnCriticalAlarms {
                        sendCriticalAlarmNotification(device: device, status: statusToCompare)
                    }
                }
            }
            
            // Check for battery aging (maintenance alert)
            if emailNotificationsEnabled && emailOnMaintenance,
               let batteryAge = device.batteryAgeInDays {
                let ageInYears = batteryAge / 365
                if ageInYears >= 3 {
                    // Only send this once per month to avoid spam
                    let lastSent = UserDefaults.standard.object(forKey: "lastBatteryAgingAlert_\(device.id)") as? Date
                    let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
                    
                    if lastSent == nil || lastSent! < thirtyDaysAgo {
                        let emailMessage = EmailTemplateService.createMaintenanceAlert(
                            device: device,
                            alertType: .batteryReplacement(age: ageInYears),
                            details: "The battery was installed on \(device.batteryInstallDate?.formatted(date: .long, time: .omitted) ?? "Unknown date") and is now \(ageInYears) years old. Consider scheduling a replacement to ensure continued reliable operation."
                        )
                        mailjetService.queueEmail(emailMessage)
                        
                        UserDefaults.standard.set(Date(), forKey: "lastBatteryAgingAlert_\(device.id)")
                    }
                }
            }
        }
        
        // Update previous status using stable status where available
        for device in devices where device.isEnabled {
            if let currentStatus = currentStatusData[device.id] {
                if let stableStatus = stableStatusData[device.id] {
                    previousStatusData[device.id] = stableStatus
                } else {
                    previousStatusData[device.id] = currentStatus
                }
            }
        }
    }
    
    private func handleOnlineOfflineStatusChange(device: UPSDevice, currentStatus: UPSStatus, stableStatus: UPSStatus?) {
        let deviceId = device.id
        let isCurrentlyOnline = currentStatus.isOnline
        let wasStableOnline = stableStatus?.isOnline ?? isCurrentlyOnline
        
        // If current status matches stable status, no need to start timers
        if isCurrentlyOnline == wasStableOnline {
            // Cancel any pending timers since status is stable
            deviceOfflineTimers[deviceId]?.invalidate()
            deviceOfflineTimers.removeValue(forKey: deviceId)
            deviceOnlineTimers[deviceId]?.invalidate()
            deviceOnlineTimers.removeValue(forKey: deviceId)
            return
        }
        
        if isCurrentlyOnline && !wasStableOnline {
            // Device appears to be coming online
            // Cancel offline timer if it exists
            deviceOfflineTimers[deviceId]?.invalidate()
            deviceOfflineTimers.removeValue(forKey: deviceId)
            
            // Start online confirmation timer if not already running
            if deviceOnlineTimers[deviceId] == nil {
                deviceOnlineTimers[deviceId] = Timer.scheduledTimer(withTimeInterval: onlineDebounceTime, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    
                    Task { @MainActor in
                        // Confirm device is still online and update stable status
                        self.stableStatusData[deviceId] = currentStatus
                        
                        // Send notification if we have a previous stable status that was offline
                        if let previousStable = stableStatus, !previousStable.isOnline {
                            self.sendDeviceOnlineNotification(device: device)
                        }
                        
                        // Clean up timer
                        self.deviceOnlineTimers.removeValue(forKey: deviceId)
                    }
                }
            }
            
        } else if !isCurrentlyOnline && wasStableOnline {
            // Device appears to be going offline
            // Cancel online timer if it exists
            deviceOnlineTimers[deviceId]?.invalidate()
            deviceOnlineTimers.removeValue(forKey: deviceId)
            
            // Start offline confirmation timer if not already running
            if deviceOfflineTimers[deviceId] == nil && notifyOnDeviceOffline {
                deviceOfflineTimers[deviceId] = Timer.scheduledTimer(withTimeInterval: offlineDebounceTime, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    
                    Task { @MainActor in
                        // Confirm device is still offline and update stable status
                        self.stableStatusData[deviceId] = currentStatus
                        
                        // Send offline notification
                        self.sendDeviceOfflineNotification(device: device)
                        
                        // Email notification for device offline
                        if self.emailNotificationsEnabled && self.emailOnCritical {
                            let emailMessage = EmailTemplateService.createCriticalAlert(
                                device: device,
                                status: nil,
                                alertType: .deviceOffline,
                                additionalInfo: "The device stopped responding at \(Date().formatted()). Please check network connectivity and device status."
                            )
                            self.mailjetService.queueEmail(emailMessage)
                        }
                        
                        // Clean up timer
                        self.deviceOfflineTimers.removeValue(forKey: deviceId)
                    }
                }
            }
        }
    }
    
    private func sendPowerRestoredEmail(device: UPSDevice, status: UPSStatus) {
        let customMessage = EmailMessage(
            alertType: .warning,
            subject: "✅ Power Restored - \(device.name)",
            textContent: """
            POWER RESTORED NOTIFICATION
            
            Device: \(device.name)
            Time: \(Date().formatted())
            
            The UPS has returned to line power operation after running on battery.
            
            Current Status:
            - Battery Level: \(Int(status.batteryCharge ?? 0))%
            - Status: \(status.isOnline ? "Online" : "Offline")
            
            System is now operating normally.
            
            ---
            UPS Monitoring System
            """,
            htmlContent: """
            <!DOCTYPE html>
            <html>
            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                    <div style="background: linear-gradient(135deg, #4CAF50, #45a049); color: white; padding: 20px; text-align: center; border-radius: 8px;">
                        <h1 style="margin: 0; font-size: 24px;">✅ Power Restored</h1>
                        <p style="margin: 10px 0 0 0; opacity: 0.9;">\(device.name)</p>
                    </div>
                    
                    <div style="padding: 20px; border: 2px solid #4CAF50; border-radius: 8px; margin-top: 20px;">
                        <h2 style="color: #4CAF50; margin: 0 0 15px 0;">System Status: Normal</h2>
                        <p>The UPS has returned to line power operation after running on battery.</p>
                        <ul>
                            <li>Battery Level: <strong>\(Int(status.batteryCharge ?? 0))%</strong></li>
                            <li>Status: <strong>\(status.isOnline ? "Online" : "Offline")</strong></li>
                            <li>Restored at: <strong>\(Date().formatted())</strong></li>
                        </ul>
                    </div>
                    
                    <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                        <p style="color: #666; font-size: 14px;">UPS Monitoring System</p>
                    </div>
                </div>
            </body>
            </html>
            """,
            deviceName: device.name,
            deviceData: nil
        )
        mailjetService.queueEmail(customMessage)
    }
    
    // MARK: - Report Generation
    
    func sendDailyReport(_ devices: [UPSDevice], statusData: [UUID: UPSStatus]) {
        guard emailNotificationsEnabled && emailDailyReports else { return }
        
        let reportMessage = EmailTemplateService.createStatusReport(
            devices: devices,
            statusData: statusData,
            reportType: .daily
        )
        mailjetService.queueEmail(reportMessage)
    }
    
    func sendWeeklyReport(_ devices: [UPSDevice], statusData: [UUID: UPSStatus]) {
        print("🔍 Weekly report request:")
        print("   - Email notifications enabled: \(emailNotificationsEnabled)")
        print("   - Weekly reports enabled: \(emailWeeklyReports)")
        
        guard emailNotificationsEnabled && emailWeeklyReports else { 
            print("   ❌ Weekly report blocked by settings")
            return 
        }
        
        print("   ✅ Sending weekly report")
        let reportMessage = EmailTemplateService.createStatusReport(
            devices: devices,
            statusData: statusData,
            reportType: .weekly
        )
        mailjetService.queueEmail(reportMessage)
    }
    
    func sendMonthlyReport(_ devices: [UPSDevice], statusData: [UUID: UPSStatus]) {
        print("🔍 Monthly report request:")
        print("   - Email notifications enabled: \(emailNotificationsEnabled)")
        print("   - Monthly reports enabled: \(emailMonthlyReports)")
        
        guard emailNotificationsEnabled && emailMonthlyReports else { 
            print("   ❌ Monthly report blocked by settings")
            return 
        }
        
        print("   ✅ Sending monthly report")
        let reportMessage = EmailTemplateService.createStatusReport(
            devices: devices,
            statusData: statusData,
            reportType: .monthly
        )
        mailjetService.queueEmail(reportMessage)
    }
    
    // MARK: - Notification Methods
    
    private func sendDeviceOnlineNotification(device: UPSDevice) {
        let content = UNMutableNotificationContent()
        content.title = "UPS Back Online"
        content.body = "\(device.name) has reconnected and is back online."
        content.sound = .default
        content.categoryIdentifier = "UPS_STATUS"
        
        sendNotification(identifier: "device_online_\(device.id)", content: content)
    }
    
    private func sendDeviceOfflineNotification(device: UPSDevice) {
        let content = UNMutableNotificationContent()
        content.title = "UPS Offline"
        content.body = "\(device.name) has gone offline and is no longer responding."
        content.sound = .default
        content.categoryIdentifier = "UPS_STATUS"
        
        sendNotification(identifier: "device_offline_\(device.id)", content: content)
    }
    
    private func sendOnBatteryNotification(device: UPSDevice, status: UPSStatus) {
        let content = UNMutableNotificationContent()
        content.title = "Power Failure"
        content.body = "\(device.name) is now running on battery power."
        
        if let charge = status.batteryCharge {
            content.body += " Battery: \(Int(charge))%"
        }
        
        if let runtime = status.formattedRuntime {
            content.body += " (\(runtime) remaining)"
        }
        
        content.sound = .default
        content.categoryIdentifier = "UPS_POWER"
        
        sendNotification(identifier: "on_battery_\(device.id)", content: content, delay: 5.0)
    }
    
    private func sendPowerRestoredNotification(device: UPSDevice, status: UPSStatus) {
        let content = UNMutableNotificationContent()
        content.title = "Power Restored"
        content.body = "\(device.name) has returned to normal power operation."
        
        if let charge = status.batteryCharge {
            content.body += " Battery: \(Int(charge))%"
        }
        
        content.sound = .default
        content.categoryIdentifier = "UPS_POWER"
        
        sendNotification(identifier: "power_restored_\(device.id)", content: content)
    }
    
    private func sendLowBatteryNotification(device: UPSDevice, status: UPSStatus) {
        let content = UNMutableNotificationContent()
        content.title = "Low Battery Warning"
        
        if let charge = status.batteryCharge {
            content.body = "\(device.name) battery is low at \(Int(charge))%."
        } else {
            content.body = "\(device.name) has a low battery."
        }
        
        if let runtime = status.formattedRuntime {
            content.body += " Estimated runtime: \(runtime)"
        }
        
        content.sound = UNNotificationSound.defaultCritical
        content.categoryIdentifier = "UPS_BATTERY"
        
        sendNotification(identifier: "low_battery_\(device.id)", content: content)
    }
    
    private func sendCriticalAlarmNotification(device: UPSDevice, status: UPSStatus) {
        let content = UNMutableNotificationContent()
        content.title = "UPS Critical Alarm"
        
        if let alarms = status.alarmsPresent {
            content.body = "\(device.name) has \(alarms) active alarm(s). Check the device immediately."
        } else {
            content.body = "\(device.name) has active alarms. Check the device immediately."
        }
        
        content.sound = UNNotificationSound.defaultCritical
        content.categoryIdentifier = "UPS_ALARM"
        
        sendNotification(identifier: "critical_alarm_\(device.id)", content: content)
    }
    
    private func sendNotification(identifier: String, content: UNMutableNotificationContent, delay: TimeInterval = 0) {
        let center = UNUserNotificationCenter.current()
        
        // Remove any existing notification with this identifier
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        
        let trigger: UNNotificationTrigger?
        if delay > 0 {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        } else {
            trigger = nil
        }
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
    
    private func removeAllPendingNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
    }
    
    // MARK: - Public Methods
    
    func testNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "UPS Monitoring notifications are working correctly."
        content.sound = .default
        
        sendNotification(identifier: "test_notification", content: content)
    }
    
    func testEmailNotification() {
        Task {
            do {
                try await mailjetService.sendTestEmail()
                let content = UNMutableNotificationContent()
                content.title = "Test Email Sent"
                content.body = "Check your email for the test message"
                content.sound = .default
                sendNotification(identifier: "test_email_notification", content: content)
            } catch {
                let content = UNMutableNotificationContent()
                content.title = "Email Test Failed"
                content.body = error.localizedDescription
                content.sound = .default
                sendNotification(identifier: "test_email_failed", content: content)
            }
        }
    }
    
    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func resetNotificationData() {
        previousStatusData.removeAll()
        stableStatusData.removeAll()
        
        // Cancel all pending timers
        deviceOfflineTimers.values.forEach { $0.invalidate() }
        deviceOnlineTimers.values.forEach { $0.invalidate() }
        deviceOfflineTimers.removeAll()
        deviceOnlineTimers.removeAll()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notifications even when app is in foreground
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification actions
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification - show the app
            DispatchQueue.main.async {
                WindowManager.shared.showMainWindow()
            }
        default:
            break
        }
        
        completionHandler()
    }
}