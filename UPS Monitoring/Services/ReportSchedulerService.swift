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
    
    // Check interval (every minute)
    private let checkInterval: TimeInterval = 60.0
    
    private init() {
        loadReportHistory()
        // Don't start scheduler in init - wait for initialization
        
        // Listen for changes in email notification settings from NotificationService
        // We'll set this up after initialization to avoid circular dependencies
    }
    
    func initialize(with monitoringService: UPSMonitoringService) {
        self.monitoringService = monitoringService
        
        // Now set up the email notifications listener
        NotificationService.shared.$emailNotificationsEnabled
            .sink { [weak self] enabled in
                if enabled {
                    self?.startScheduler()
                } else {
                    self?.stopScheduler()
                }
            }
            .store(in: &cancellables)
        
        // Start scheduler if email notifications are already enabled
        if NotificationService.shared.emailNotificationsEnabled {
            startScheduler()
        }
    }
    
    // MARK: - Scheduler Management
    
    private func startScheduler() {
        guard NotificationService.shared.emailNotificationsEnabled else { return }
        
        // Stop existing timer
        stopScheduler()
        
        // Start new timer that checks every minute
        schedulerTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.checkAndSendScheduledReports()
            }
        }
        
        print("📅 Report scheduler started - checking every \(Int(checkInterval)) seconds")
    }
    
    private func stopScheduler() {
        schedulerTimer?.invalidate()
        schedulerTimer = nil
        print("📅 Report scheduler stopped")
    }
    
    // MARK: - Report Checking Logic
    
    private func checkAndSendScheduledReports() async {
        let now = Date()
        let notificationService = NotificationService.shared
        
        // Check daily reports (8:00 AM every day)
        if notificationService.emailDailyReports {
            if shouldSendDailyReport(at: now) {
                sendDailyReport()
            }
        }
        
        // Check weekly reports (Monday at 8:00 AM)
        if notificationService.emailWeeklyReports {
            if shouldSendWeeklyReport(at: now) {
                sendWeeklyReport()
            }
        }
        
        // Check monthly reports (1st of month at 8:00 AM)
        if notificationService.emailMonthlyReports {
            if shouldSendMonthlyReport(at: now) {
                sendMonthlyReport()
            }
        }
    }
    
    private func shouldSendDailyReport(at date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        // Check if it's 8:00 AM (within the check interval)
        guard hour == 8 && minute < Int(checkInterval / 60) else { return false }
        
        // Check if we haven't sent a daily report today
        if let lastSent = lastDailyReportDate {
            return !calendar.isDate(lastSent, inSameDayAs: date)
        }
        
        return true
    }
    
    private func shouldSendWeeklyReport(at date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday, 2 = Monday
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        // Check if it's Monday (weekday 2) at 8:00 AM
        guard weekday == 2 && hour == 8 && minute < Int(checkInterval / 60) else { return false }
        
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
    
    private func shouldSendMonthlyReport(at date: Date) -> Bool {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        // Check if it's the 1st of the month at 8:00 AM
        guard day == 1 && hour == 8 && minute < Int(checkInterval / 60) else { return false }
        
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
            print("❌ Cannot send daily report: monitoring service not initialized")
            return
        }
        
        let devices = monitoringService.devices.filter { $0.isEnabled }
        let statusData = monitoringService.statusData
        
        NotificationService.shared.sendDailyReport(devices, statusData: statusData)
        
        lastDailyReportDate = Date()
        saveReportHistory()
        
        print("📧 Daily UPS report sent at \(Date().formatted())")
    }
    
    private func sendWeeklyReport() {
        guard let monitoringService = monitoringService else {
            print("❌ Cannot send weekly report: monitoring service not initialized")
            return
        }
        
        let devices = monitoringService.devices.filter { $0.isEnabled }
        let statusData = monitoringService.statusData
        
        NotificationService.shared.sendWeeklyReport(devices, statusData: statusData)
        
        lastWeeklyReportDate = Date()
        saveReportHistory()
        
        print("📧 Weekly UPS report sent at \(Date().formatted())")
    }
    
    private func sendMonthlyReport() {
        guard let monitoringService = monitoringService else {
            print("❌ Cannot send monthly report: monitoring service not initialized")
            return
        }
        
        let devices = monitoringService.devices.filter { $0.isEnabled }
        let statusData = monitoringService.statusData
        
        NotificationService.shared.sendMonthlyReport(devices, statusData: statusData)
        
        lastMonthlyReportDate = Date()
        saveReportHistory()
        
        print("📧 Monthly UPS report sent at \(Date().formatted())")
    }
    
    // MARK: - Manual Report Sending (for testing)
    
    func sendTestDailyReport() {
        guard let monitoringService = monitoringService else { return }
        
        let devices = monitoringService.devices.filter { $0.isEnabled }
        let statusData = monitoringService.statusData
        
        NotificationService.shared.sendDailyReport(devices, statusData: statusData)
        print("📧 Test daily report sent")
    }
    
    func sendTestWeeklyReport() {
        guard let monitoringService = monitoringService else { return }
        
        let devices = monitoringService.devices.filter { $0.isEnabled }
        let statusData = monitoringService.statusData
        
        NotificationService.shared.sendWeeklyReport(devices, statusData: statusData)
        print("📧 Test weekly report sent")
    }
    
    func sendTestMonthlyReport() {
        guard let monitoringService = monitoringService else { return }
        
        let devices = monitoringService.devices.filter { $0.isEnabled }
        let statusData = monitoringService.statusData
        
        NotificationService.shared.sendMonthlyReport(devices, statusData: statusData)
        print("📧 Test monthly report sent")
    }
    
    // MARK: - Report History Management
    
    private func saveReportHistory() {
        let history: [String: Any?] = [
            "lastDailyReportDate": lastDailyReportDate,
            "lastWeeklyReportDate": lastWeeklyReportDate,
            "lastMonthlyReportDate": lastMonthlyReportDate
        ]
        
        UserDefaults.standard.set(history, forKey: "reportSchedulerHistory")
    }
    
    private func loadReportHistory() {
        guard let history = UserDefaults.standard.dictionary(forKey: "reportSchedulerHistory") else { return }
        
        lastDailyReportDate = history["lastDailyReportDate"] as? Date
        lastWeeklyReportDate = history["lastWeeklyReportDate"] as? Date
        lastMonthlyReportDate = history["lastMonthlyReportDate"] as? Date
    }
    
    // MARK: - Status Information
    
    func getNextReportTimes() -> (daily: Date?, weekly: Date?, monthly: Date?) {
        let calendar = Calendar.current
        let now = Date()
        let notificationService = NotificationService.shared
        
        // Next daily report (tomorrow at 8:00 AM, or today if before 8:00 AM)
        var nextDaily: Date?
        if notificationService.emailDailyReports {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = 8
            components.minute = 0
            components.second = 0
            
            if let todayAt8AM = calendar.date(from: components), todayAt8AM > now {
                nextDaily = todayAt8AM
            } else {
                nextDaily = calendar.date(byAdding: .day, value: 1, to: calendar.date(from: components)!)
            }
        }
        
        // Next weekly report (next Monday at 8:00 AM)
        var nextWeekly: Date?
        if notificationService.emailWeeklyReports {
            let weekday = calendar.component(.weekday, from: now)
            let daysUntilMonday = weekday == 1 ? 1 : (9 - weekday) // Sunday = 1, Monday = 2
            
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = 8
            components.minute = 0
            components.second = 0
            
            if weekday == 2 { // If today is Monday
                if let todayAt8AM = calendar.date(from: components), todayAt8AM > now {
                    nextWeekly = todayAt8AM
                } else {
                    nextWeekly = calendar.date(byAdding: .day, value: 7, to: calendar.date(from: components)!)
                }
            } else {
                nextWeekly = calendar.date(byAdding: .day, value: daysUntilMonday, to: calendar.date(from: components)!)
            }
        }
        
        // Next monthly report (next 1st at 8:00 AM)
        var nextMonthly: Date?
        if notificationService.emailMonthlyReports {
            let day = calendar.component(.day, from: now)
            
            var components = calendar.dateComponents([.year, .month], from: now)
            components.day = 1
            components.hour = 8
            components.minute = 0
            components.second = 0
            
            if day == 1 {
                if let todayAt8AM = calendar.date(from: components), todayAt8AM > now {
                    nextMonthly = todayAt8AM
                } else {
                    nextMonthly = calendar.date(byAdding: .month, value: 1, to: calendar.date(from: components)!)
                }
            } else {
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