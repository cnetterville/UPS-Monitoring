//
//  ReportSchedulerService.swift
//  UPS Monitoring
//
//  Created by Assistant on 12/19/24.
//

import Foundation
import Combine

/// Service responsible for scheduling and sending automated UPS status reports
@MainActor
class ReportSchedulerService: ObservableObject {
    static let shared = ReportSchedulerService()
    
    private var schedulerTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Dependencies
    private var monitoringService: UPSMonitoringService?
    
    // Tracking last sent reports to avoid duplicates
    private var lastDailyReportDate: Date?
    private var lastWeeklyReportDate: Date?
    private var lastMonthlyReportDate: Date?
    
    // Check interval (reduced to 1 minute for better responsiveness)
    private let checkInterval: TimeInterval = 60.0 // Changed from 300.0 (5 minutes) to 60.0 (1 minute) for more reliable scheduling
    
    private init() {
        loadReportHistory()
        // Don't start scheduler in init - wait for initialization
        
        // Listen for changes in email notification settings from NotificationService
        // We'll set up after initialization to avoid circular dependencies
    }
    
    func initialize(with monitoringService: UPSMonitoringService) {
        print("🔧 Initializing ReportSchedulerService...")
        
        self.monitoringService = monitoringService
        
        // Now set up the email notifications listener
        NotificationService.shared.$emailNotificationsEnabled
            .sink { [weak self] enabled in
                print("📧 Email notifications enabled changed to: \(enabled)")
                if enabled {
                    self?.startScheduler()
                } else {
                    self?.stopScheduler()
                }
            }
            .store(in: &cancellables)
        
        // Start scheduler if email notifications are already enabled
        let isEmailEnabled = NotificationService.shared.emailNotificationsEnabled
        print("   - Current email notifications state: \(isEmailEnabled)")
        
        if isEmailEnabled {
            startScheduler()
        }
        
        print("✅ ReportSchedulerService initialization complete")
    }
    
    // MARK: - Scheduler Management
    
    private func startScheduler() {
        guard NotificationService.shared.emailNotificationsEnabled else { 
            print("📧 Email notifications disabled - not starting scheduler")
            return 
        }
        
        print("🚀 Starting report scheduler...")
        print("   - Check interval: \(checkInterval) seconds (\(checkInterval/60) minutes)")
        
        // Stop existing timer
        stopScheduler()
        
        // Use a more reliable timer approach
        schedulerTimer = Timer(timeInterval: checkInterval, repeats: true) { [weak self] timer in
            print("⏰ Timer fired at \(Date().formatted(date: .omitted, time: .complete)) - running scheduled report check")
            guard let self = self else { 
                print("❌ Self is nil in timer callback")
                return 
            }
            
            Task { @MainActor in
                await self.checkAndSendScheduledReports()
            }
        }
        
        // Add to run loop with common modes to ensure it runs even when UI is busy
        RunLoop.main.add(schedulerTimer!, forMode: .common)
        
        // Verify timer is scheduled
        if let timer = schedulerTimer {
            print("✅ Timer created successfully:")
            print("   - Fire date: \(timer.fireDate.formatted(date: .complete, time: .complete))")
            print("   - Time interval: \(timer.timeInterval)")
            print("   - Is valid: \(timer.isValid)")
            print("   - Next fire: \(Date().addingTimeInterval(checkInterval).formatted(date: .omitted, time: .complete))")
        }
        
        print("✅ Report scheduler started successfully")
        
        // Run an immediate check
        Task { @MainActor in
            print("🔄 Running initial report check...")
            await self.checkAndSendScheduledReports()
        }
    }
    
    private func stopScheduler() {
        if schedulerTimer != nil {
            print("🛑 Stopping existing report scheduler")
            schedulerTimer?.invalidate()
            schedulerTimer = nil
        }
    }
    
    // MARK: - Report Checking Logic
    
    private func checkAndSendScheduledReports() async {
        let now = Date()
        let notificationService = NotificationService.shared
        
        print("🕐 Checking scheduled reports at \(now.formatted(date: .omitted, time: .complete))")
        
        // Check daily reports at configured time every day
        if notificationService.emailDailyReports {
            print("📅 Daily reports enabled - checking if should send...")
            print("   - Scheduled time: \(notificationService.dailyReportTime.formatted(date: .omitted, time: .complete))")
            
            if shouldSendDailyReport(at: now, scheduledTime: notificationService.dailyReportTime) {
                print("✅ Sending daily report now!")
                sendDailyReport()
            } else {
                print("❌ Daily report not due yet")
            }
        } else {
            print("📅 Daily reports disabled")
        }
        
        // Check weekly reports at configured time on configured day
        if notificationService.emailWeeklyReports {
            print("📅 Weekly reports enabled - checking if should send...")
            
            if shouldSendWeeklyReport(at: now, scheduledTime: notificationService.weeklyReportTime, weekday: notificationService.weeklyReportWeekday) {
                print("✅ Sending weekly report now!")
                sendWeeklyReport()
            } else {
                print("❌ Weekly report not due yet")
            }
        }
        
        // Check monthly reports at configured time on configured day of month
        if notificationService.emailMonthlyReports {
            print("📅 Monthly reports enabled - checking if should send...")
            
            if shouldSendMonthlyReport(at: now, scheduledTime: notificationService.monthlyReportTime, dayOfMonth: notificationService.monthlyReportDay) {
                print("✅ Sending monthly report now!")
                sendMonthlyReport()
            } else {
                print("❌ Monthly report not due yet")
            }
        }
    }
    
    private func shouldSendDailyReport(at date: Date, scheduledTime: Date) -> Bool {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        let scheduledHour = calendar.component(.hour, from: scheduledTime)
        let scheduledMinute = calendar.component(.minute, from: scheduledTime)
        
        print("   📊 Daily report timing check:")
        print("      - Current time: \(currentHour):\(String(format: "%02d", currentMinute))")
        print("      - Scheduled time: \(scheduledHour):\(String(format: "%02d", scheduledMinute))")
        
        // Check if we're within the time window (2-minute window with 1-minute checks)
        let currentTotalMinutes = currentHour * 60 + currentMinute
        let scheduledTotalMinutes = scheduledHour * 60 + scheduledMinute
        let windowMinutes = 2 // 2-minute window with 1-minute checks for better reliability
        
        print("      - Current total minutes: \(currentTotalMinutes)")
        print("      - Scheduled total minutes: \(scheduledTotalMinutes)")
        print("      - Window size: \(windowMinutes) minutes")
        print("      - Window range: \(scheduledTotalMinutes) to \(scheduledTotalMinutes + windowMinutes)")
        
        guard currentTotalMinutes >= scheduledTotalMinutes && 
              currentTotalMinutes < scheduledTotalMinutes + windowMinutes else {
            print("      ❌ Not within time window")
            return false
        }
        
        print("      ✅ Within time window")
        
        // Check if we haven't sent a daily report today
        if let lastSent = lastDailyReportDate {
            let isSameDay = calendar.isDate(lastSent, inSameDayAs: date)
            print("      - Last sent: \(lastSent.formatted(date: .complete, time: .complete))")
            print("      - Same day as today: \(isSameDay)")
            
            if isSameDay {
                print("      ❌ Already sent today")
                return false
            }
        } else {
            print("      - No previous daily report found")
        }
        
        print("      ✅ Ready to send!")
        return true
    }
    
    private func shouldSendWeeklyReport(at date: Date, scheduledTime: Date, weekday: Int) -> Bool {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        let scheduledHour = calendar.component(.hour, from: scheduledTime)
        let scheduledMinute = calendar.component(.minute, from: scheduledTime)
        
        // Check if it's the correct weekday and time
        guard currentWeekday == weekday else { return false }
        
        let currentTotalMinutes = currentHour * 60 + currentMinute
        let scheduledTotalMinutes = scheduledHour * 60 + scheduledMinute
        let windowMinutes = Int(checkInterval / 60) // 5 minutes
        
        guard currentTotalMinutes >= scheduledTotalMinutes && 
              currentTotalMinutes < scheduledTotalMinutes + windowMinutes else { return false }
        
        // Check if we haven't sent a weekly report this week
        if let lastSent = lastWeeklyReportDate {
            let weekOfYear = calendar.component(.weekOfYear, from: date)
            let lastWeekOfYear = calendar.component(.weekOfYear, from: lastSent)
            let year = calendar.component(.year, from: date)
            let lastYear = calendar.component(.year, from: lastSent)
            
            return !(year == lastYear && weekOfYear == lastWeekOfYear)
        }
        
        return true
    }
    
    private func shouldSendMonthlyReport(at date: Date, scheduledTime: Date, dayOfMonth: Int) -> Bool {
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: date)
        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        let scheduledHour = calendar.component(.hour, from: scheduledTime)
        let scheduledMinute = calendar.component(.minute, from: scheduledTime)
        
        // Check if it's the correct day of month
        guard currentDay == dayOfMonth else { return false }
        
        let currentTotalMinutes = currentHour * 60 + currentMinute
        let scheduledTotalMinutes = scheduledHour * 60 + scheduledMinute
        let windowMinutes = Int(checkInterval / 60) // 5 minutes
        
        guard currentTotalMinutes >= scheduledTotalMinutes && 
              currentTotalMinutes < scheduledTotalMinutes + windowMinutes else { return false }
        
        // Check if we haven't sent a monthly report this month
        if let lastSent = lastMonthlyReportDate {
            let month = calendar.component(.month, from: date)
            let lastMonth = calendar.component(.month, from: lastSent)
            let year = calendar.component(.year, from: date)
            let lastYear = calendar.component(.year, from: lastSent)
            
            return !(year == lastYear && month == lastMonth)
        }
        
        return true
    }
    
    // MARK: - Report Sending
    
    private func sendDailyReport() {
        guard let monitoringService = monitoringService else {
            print("❌ Cannot send daily report - monitoring service not available")
            return
        }
        
        let devices = monitoringService.devices.filter { $0.isEnabled }
        let statusData = monitoringService.statusData
        
        print("📬 Sending daily report...")
        print("   - Enabled devices: \(devices.count)")
        print("   - Status data entries: \(statusData.count)")
        
        NotificationService.shared.sendDailyReport(devices, statusData: statusData)
        
        lastDailyReportDate = Date()
        saveReportHistory()
        
        print("✅ Daily report sent and recorded at \(lastDailyReportDate?.formatted(date: .complete, time: .complete) ?? "unknown")")
    }
    
    private func sendWeeklyReport() {
        guard let monitoringService = monitoringService else {
            return
        }
        
        let devices = monitoringService.devices.filter { $0.isEnabled }
        let statusData = monitoringService.statusData
        
        NotificationService.shared.sendWeeklyReport(devices, statusData: statusData)
        
        lastWeeklyReportDate = Date()
        saveReportHistory()
    }
    
    private func sendMonthlyReport() {
        guard let monitoringService = monitoringService else {
            return
        }
        
        let devices = monitoringService.devices.filter { $0.isEnabled }
        let statusData = monitoringService.statusData
        
        NotificationService.shared.sendMonthlyReport(devices, statusData: statusData)
        
        lastMonthlyReportDate = Date()
        saveReportHistory()
    }
    
    // MARK: - Manual Report Sending (for testing)
    
    func sendTestDailyReport() {
        guard let monitoringService = monitoringService else { return }
        
        let devices = monitoringService.devices.filter { $0.isEnabled }
        let statusData = monitoringService.statusData
        
        NotificationService.shared.sendDailyReport(devices, statusData: statusData)
    }
    
    // Add method to force send daily report regardless of schedule
    func forceSendDailyReport() {
        sendDailyReport()
    }
    
    func sendTestWeeklyReport() {
        guard let monitoringService = monitoringService else { 
            return 
        }
        
        let devices = monitoringService.devices.filter { $0.isEnabled }
        let statusData = monitoringService.statusData
        
        // Bypass the settings check by calling EmailTemplateService directly
        let reportMessage = EmailTemplateService.createStatusReport(
            devices: devices,
            statusData: statusData,
            reportType: .weekly
        )
        MailjetService.shared.queueEmail(reportMessage)
    }
    
    func sendTestMonthlyReport() {
        guard let monitoringService = monitoringService else { 
            return 
        }
        
        let devices = monitoringService.devices.filter { $0.isEnabled }
        let statusData = monitoringService.statusData
        
        // Bypass the settings check by calling EmailTemplateService directly
        let reportMessage = EmailTemplateService.createStatusReport(
            devices: devices,
            statusData: statusData,
            reportType: .monthly
        )
        MailjetService.shared.queueEmail(reportMessage)
    }
    
    func debugReportScheduler() {
        print("\n=== REPORT SCHEDULER DEBUG ===")
        
        let now = Date()
        let notificationService = NotificationService.shared
        
        print("Current time: \(now.formatted(date: .complete, time: .complete))")
        print("Scheduler running: \(schedulerTimer != nil)")
        print("Check interval: \(checkInterval) seconds")
        print("Email notifications enabled: \(notificationService.emailNotificationsEnabled)")
        
        print("\nDaily Reports:")
        print("  - Enabled: \(notificationService.emailDailyReports)")
        print("  - Scheduled time: \(notificationService.dailyReportTime.formatted(date: .omitted, time: .complete))")
        if let lastDaily = lastDailyReportDate {
            print("  - Last sent: \(lastDaily.formatted(date: .complete, time: .complete))")
        } else {
            print("  - Last sent: Never")
        }
        
        print("\nWeekly Reports:")
        print("  - Enabled: \(notificationService.emailWeeklyReports)")
        print("  - Scheduled weekday: \(notificationService.weeklyReportWeekday) (1=Sunday, 2=Monday, etc.)")
        print("  - Scheduled time: \(notificationService.weeklyReportTime.formatted(date: .omitted, time: .complete))")
        if let lastWeekly = lastWeeklyReportDate {
            print("  - Last sent: \(lastWeekly.formatted(date: .complete, time: .complete))")
        } else {
            print("  - Last sent: Never")
        }
        
        print("\nMonthly Reports:")
        print("  - Enabled: \(notificationService.emailMonthlyReports)")
        print("  - Scheduled day: \(notificationService.monthlyReportDay)")
        print("  - Scheduled time: \(notificationService.monthlyReportTime.formatted(date: .omitted, time: .complete))")
        if let lastMonthly = lastMonthlyReportDate {
            print("  - Last sent: \(lastMonthly.formatted(date: .complete, time: .complete))")
        } else {
            print("  - Last sent: Never")
        }
        
        print("\nNext Report Times:")
        let nextTimes = getNextReportTimes()
        if let nextDaily = nextTimes.daily {
            print("  - Next daily: \(nextDaily.formatted(date: .complete, time: .complete))")
        }
        if let nextWeekly = nextTimes.weekly {
            print("  - Next weekly: \(nextWeekly.formatted(date: .complete, time: .complete))")
        }
        if let nextMonthly = nextTimes.monthly {
            print("  - Next monthly: \(nextMonthly.formatted(date: .complete, time: .complete))")
        }
        
        print("\nTesting daily report logic with current time:")
        let shouldSend = shouldSendDailyReport(at: now, scheduledTime: notificationService.dailyReportTime)
        print("Should send daily report now: \(shouldSend)")
        
        print("===========================\n")
    }
    
    func manualReportCheck() async {
        print("🔄 Manual report check triggered by user")
        await checkAndSendScheduledReports()
    }
    
    // MARK: - Report History Management
    
    private func saveReportHistory() {
        var history: [String: Any] = [:]
        
        if let lastDaily = lastDailyReportDate {
            history["lastDailyReportDate"] = lastDaily
        }
        
        if let lastWeekly = lastWeeklyReportDate {
            history["lastWeeklyReportDate"] = lastWeekly
        }
        
        if let lastMonthly = lastMonthlyReportDate {
            history["lastMonthlyReportDate"] = lastMonthly
        }
        
        UserDefaults.standard.set(history, forKey: "reportSchedulerHistory")
        print("💾 Saved report history: \(history.keys.joined(separator: ", "))")
    }
    
    private func loadReportHistory() {
        guard let history = UserDefaults.standard.dictionary(forKey: "reportSchedulerHistory") else { 
            print("📥 No report history found - starting fresh")
            return 
        }
        
        lastDailyReportDate = history["lastDailyReportDate"] as? Date
        lastWeeklyReportDate = history["lastWeeklyReportDate"] as? Date
        lastMonthlyReportDate = history["lastMonthlyReportDate"] as? Date
        
        print("📥 Loaded report history:")
        if let lastDaily = lastDailyReportDate {
            print("   - Last daily: \(lastDaily.formatted(date: .complete, time: .complete))")
        }
        if let lastWeekly = lastWeeklyReportDate {
            print("   - Last weekly: \(lastWeekly.formatted(date: .complete, time: .complete))")
        }
        if let lastMonthly = lastMonthlyReportDate {
            print("   - Last monthly: \(lastMonthly.formatted(date: .complete, time: .complete))")
        }
    }
    
    // MARK: - Status Information
    
    func getNextReportTimes() -> (daily: Date?, weekly: Date?, monthly: Date?) {
        let calendar = Calendar.current
        let now = Date()
        let notificationService = NotificationService.shared
        
        // Next daily report
        var nextDaily: Date?
        if notificationService.emailDailyReports {
            let scheduledHour = calendar.component(.hour, from: notificationService.dailyReportTime)
            let scheduledMinute = calendar.component(.minute, from: notificationService.dailyReportTime)
            
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = scheduledHour
            components.minute = scheduledMinute
            components.second = 0
            
            if let todayAtScheduledTime = calendar.date(from: components), todayAtScheduledTime > now {
                nextDaily = todayAtScheduledTime
            } else {
                nextDaily = calendar.date(byAdding: .day, value: 1, to: calendar.date(from: components)!)
            }
        }
        
        // Next weekly report
        var nextWeekly: Date?
        if notificationService.emailWeeklyReports {
            let currentWeekday = calendar.component(.weekday, from: now)
            let targetWeekday = notificationService.weeklyReportWeekday
            let scheduledHour = calendar.component(.hour, from: notificationService.weeklyReportTime)
            let scheduledMinute = calendar.component(.minute, from: notificationService.weeklyReportTime)
            
            var daysToAdd = targetWeekday - currentWeekday
            if daysToAdd < 0 {
                daysToAdd += 7 // Next week
            }
            
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = scheduledHour
            components.minute = scheduledMinute
            components.second = 0
            
            if daysToAdd == 0 { // Today is the target weekday
                if let todayAtScheduledTime = calendar.date(from: components), todayAtScheduledTime > now {
                    nextWeekly = todayAtScheduledTime
                } else {
                    nextWeekly = calendar.date(byAdding: .day, value: 7, to: calendar.date(from: components)!)
                }
            } else {
                nextWeekly = calendar.date(byAdding: .day, value: daysToAdd, to: calendar.date(from: components)!)
            }
        }
        
        // Next monthly report
        var nextMonthly: Date?
        if notificationService.emailMonthlyReports {
            let currentDay = calendar.component(.day, from: now)
            let targetDay = notificationService.monthlyReportDay
            let scheduledHour = calendar.component(.hour, from: notificationService.monthlyReportTime)
            let scheduledMinute = calendar.component(.minute, from: notificationService.monthlyReportTime)
            
            var components = calendar.dateComponents([.year, .month], from: now)
            components.day = targetDay
            components.hour = scheduledHour
            components.minute = scheduledMinute
            components.second = 0
            
            if currentDay < targetDay {
                // This month
                nextMonthly = calendar.date(from: components)
            } else if currentDay == targetDay {
                // Today - check if we've passed the time
                if let todayAtScheduledTime = calendar.date(from: components), todayAtScheduledTime > now {
                    nextMonthly = todayAtScheduledTime
                } else {
                    nextMonthly = calendar.date(byAdding: .month, value: 1, to: calendar.date(from: components)!)
                }
            } else {
                // Next month
                nextMonthly = calendar.date(byAdding: .month, value: 1, to: calendar.date(from: components)!)
            }
        }
        
        return (daily: nextDaily, weekly: nextWeekly, monthly: nextMonthly)
    }
    
    deinit {
        // Timer invalidation is safe to call from any thread
        schedulerTimer?.invalidate()
        schedulerTimer = nil
    }
}