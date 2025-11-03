//
//  MailjetService.swift
//  UPS Monitoring
//
//  Created by Assistant on 12/19/24.
//

import Foundation
import Combine

/// Mailjet email service for sending UPS monitoring notifications
@MainActor
class MailjetService: ObservableObject {
    static let shared = MailjetService()
    
    // MARK: - Configuration
    @Published var isConfigured = false
    @Published var isLoading = false
    @Published var apiKey: String = "" {
        didSet {
            if !isLoading {
                print("🔧 API Key updated: \(apiKey.isEmpty ? "EMPTY" : "[HIDDEN]")")
                updateConfiguration()
            }
        }
    }
    @Published var apiSecret: String = "" {
        didSet {
            if !isLoading {
                print("🔧 API Secret updated: \(apiSecret.isEmpty ? "EMPTY" : "[HIDDEN]")")
                updateConfiguration()
            }
        }
    }
    @Published var fromEmail: String = "" {
        didSet {
            if !isLoading {
                print("🔧 From Email updated: '\(fromEmail)'")
                updateConfiguration()
            }
        }
    }
    @Published var fromName: String = "UPS Monitoring" {
        didSet {
            if !isLoading {
                print("🔧 From Name updated: '\(fromName)'")
                updateConfiguration()
            }
        }
    }
    @Published var recipients: [EmailRecipient] = [] {
        didSet {
            if !isLoading {
                saveRecipients()
            }
        }
    }
    
    // MARK: - Rate Limiting
    private var lastEmailTimes: [String: Date] = [:]
    private let minInterval: TimeInterval = 300 // 5 minutes between same alert types
    private let maxEmailsPerHour = 20
    private var emailsSentThisHour: [(Date, String)] = []
    
    // MARK: - Email Queue
    private var emailQueue: [EmailMessage] = []
    private var isProcessingQueue = false
    
    private init() {
        loadConfiguration()
    }
    
    // MARK: - Configuration Management
    
    private func updateConfiguration() {
        let wasConfigured = isConfigured
        isConfigured = !apiKey.isEmpty && !apiSecret.isEmpty && !fromEmail.isEmpty
        
        if isConfigured != wasConfigured {
            print("📊 Configuration status changed: \(isConfigured ? "CONFIGURED" : "NOT CONFIGURED")")
        }
        
        saveConfiguration()
    }
    
    private func saveConfiguration() {
        guard !isLoading else {
            print("⚠️  Skipping save during loading")
            return
        }
        
        print("💾 Saving configuration...")
        
        // Store sensitive data in Keychain
        do {
            if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try KeychainService.shared.store(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: KeychainService.Keys.mailjetAPIKey)
                print("✅ API Key saved to keychain")
            } else {
                try? KeychainService.shared.delete(for: KeychainService.Keys.mailjetAPIKey)
                print("🗑️  API Key deleted from keychain")
            }
            
            if !apiSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try KeychainService.shared.store(apiSecret.trimmingCharacters(in: .whitespacesAndNewlines), for: KeychainService.Keys.mailjetAPISecret)
                print("✅ API Secret saved to keychain")
            } else {
                try? KeychainService.shared.delete(for: KeychainService.Keys.mailjetAPISecret)
                print("🗑️  API Secret deleted from keychain")
            }
        } catch {
            print("❌ Failed to save credentials to Keychain: \(error.localizedDescription)")
        }
        
        // Store non-sensitive data in UserDefaults
        let trimmedFromEmail = fromEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFromName = fromName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        UserDefaults.standard.set(trimmedFromEmail, forKey: "mailjet_from_email")
        UserDefaults.standard.set(trimmedFromName, forKey: "mailjet_from_name")
        
        print("✅ From Email saved: '\(trimmedFromEmail)'")
        print("✅ From Name saved: '\(trimmedFromName)'")
    }
    
    private func loadConfiguration() {
        print("📥 Loading configuration...")
        isLoading = true
        
        // Load sensitive data from Keychain
        do {
            let loadedApiKey = try KeychainService.shared.retrieve(for: KeychainService.Keys.mailjetAPIKey) ?? ""
            let loadedApiSecret = try KeychainService.shared.retrieve(for: KeychainService.Keys.mailjetAPISecret) ?? ""
            
            print("🔐 Loaded from Keychain - API Key: \(loadedApiKey.isEmpty ? "EMPTY" : "[HIDDEN]"), API Secret: \(loadedApiSecret.isEmpty ? "EMPTY" : "[HIDDEN]")")
            
            apiKey = loadedApiKey
            apiSecret = loadedApiSecret
        } catch {
            print("❌ Failed to load credentials from Keychain: \(error.localizedDescription)")
            // Fallback to empty strings
            apiKey = ""
            apiSecret = ""
        }
        
        // Load non-sensitive data from UserDefaults
        let loadedFromEmail = UserDefaults.standard.string(forKey: "mailjet_from_email") ?? ""
        let loadedFromName = UserDefaults.standard.string(forKey: "mailjet_from_name") ?? "UPS Monitoring"
        
        print("📱 Loaded from UserDefaults - From Email: '\(loadedFromEmail)', From Name: '\(loadedFromName)'")
        
        fromEmail = loadedFromEmail
        fromName = loadedFromName
        
        // Load recipients
        loadRecipients()
        
        isLoading = false
        updateConfiguration()
        
        print("🎉 Configuration loaded - Is Configured: \(isConfigured)")
    }
    
    func reloadConfiguration() {
        print("🔄 Reloading configuration...")
        loadConfiguration()
    }
    
    private func saveRecipients() {
        if let data = try? JSONEncoder().encode(recipients) {
            UserDefaults.standard.set(data, forKey: "mailjet_recipients")
            print("✅ Recipients saved: \(recipients.count) recipients")
        }
    }
    
    private func loadRecipients() {
        if let data = UserDefaults.standard.data(forKey: "mailjet_recipients"),
           let decoded = try? JSONDecoder().decode([EmailRecipient].self, from: data) {
            recipients = decoded
            print("📥 Recipients loaded: \(recipients.count) recipients")
        }
    }
    
    // MARK: - Email Sending
    
    func sendEmail(_ message: EmailMessage) async throws {
        guard isConfigured else {
            throw MailjetError.notConfigured
        }
        
        guard !recipients.isEmpty else {
            throw MailjetError.noRecipients
        }
        
        // Check rate limiting
        try await checkRateLimit(for: message.alertType)
        
        // Filter recipients based on alert type
        let targetRecipients = recipients.filter { recipient in
            recipient.isEnabled && recipient.alertTypes.contains(message.alertType)
        }
        
        guard !targetRecipients.isEmpty else {
            throw MailjetError.noEnabledRecipients
        }
        
        // Build email payload
        let payload = buildEmailPayload(message: message, recipients: targetRecipients)
        
        // Send via Mailjet API
        try await sendToMailjetAPI(payload: payload)
        
        // Update rate limiting records
        await updateRateLimit(for: message.alertType)
    }
    
    private func checkRateLimit(for alertType: EmailAlertType) async throws {
        // Skip rate limiting for test emails and reports
        if alertType == .test || alertType == .report {
            return
        }
        
        // Clean old entries
        let oneHourAgo = Date().addingTimeInterval(-3600)
        emailsSentThisHour = emailsSentThisHour.filter { $0.0 > oneHourAgo }
        
        // Check hourly limit
        if emailsSentThisHour.count >= maxEmailsPerHour {
            throw MailjetError.rateLimitExceeded
        }
        
        // Check minimum interval for same alert type
        let alertTypeKey = alertType.rawValue
        if let lastTime = lastEmailTimes[alertTypeKey],
           Date().timeIntervalSince(lastTime) < minInterval {
            throw MailjetError.tooFrequent
        }
    }
    
    private func updateRateLimit(for alertType: EmailAlertType) async {
        // Don't update rate limit tracking for test emails and reports
        if alertType == .test || alertType == .report {
            return
        }
        
        lastEmailTimes[alertType.rawValue] = Date()
        emailsSentThisHour.append((Date(), alertType.rawValue))
    }
    
    private func buildEmailPayload(message: EmailMessage, recipients: [EmailRecipient]) -> [String: Any] {
        let toRecipients = recipients.map { recipient in
            [
                "Email": recipient.email,
                "Name": recipient.name.isEmpty ? recipient.email : recipient.name
            ]
        }
        
        return [
            "Messages": [
                [
                    "From": [
                        "Email": fromEmail,
                        "Name": fromName
                    ],
                    "To": toRecipients,
                    "Subject": message.subject,
                    "TextPart": message.textContent,
                    "HTMLPart": message.htmlContent,
                    "CustomID": "UPSMonitoring-\(message.alertType.rawValue)-\(UUID().uuidString)"
                ]
            ]
        ]
    }
    
    private func sendToMailjetAPI(payload: [String: Any]) async throws {
        let url = URL(string: "https://api.mailjet.com/v3.1/send")!
        var request = URLRequest(url: url)
        
        // Set up the request
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Basic Authentication
        let credentials = "\(apiKey):\(apiSecret)"
        if let credentialsData = credentials.data(using: .utf8) {
            let base64Credentials = credentialsData.base64EncodedString()
            request.addValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
        
        // Set the body
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        // Send the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                // Try to parse error message
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Mailjet API Error: \(errorData)")
                }
                throw MailjetError.apiError(httpResponse.statusCode)
            }
        }
        
        // Parse response for success confirmation
        if let responseData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("Mailjet Response: \(responseData)")
        }
    }
    
    // MARK: - Queue Management
    
    func queueEmail(_ message: EmailMessage) {
        emailQueue.append(message)
        processQueue()
    }
    
    private func processQueue() {
        guard !isProcessingQueue, !emailQueue.isEmpty else { return }
        
        isProcessingQueue = true
        
        Task {
            while !emailQueue.isEmpty {
                let message = emailQueue.removeFirst()
                do {
                    try await sendEmail(message)
                    print("✅ Email sent successfully: \(message.subject)")
                } catch {
                    print("❌ Failed to send email: \(error.localizedDescription)")
                    // Could implement retry logic here
                }
                
                // Wait between emails to avoid overwhelming the API
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
            
            await MainActor.run {
                isProcessingQueue = false
            }
        }
    }
    
    // MARK: - Recipient Management
    
    func addRecipient(_ recipient: EmailRecipient) {
        if !recipients.contains(where: { $0.email == recipient.email }) {
            recipients.append(recipient)
        }
    }
    
    func removeRecipient(_ recipient: EmailRecipient) {
        recipients.removeAll { $0.id == recipient.id }
    }
    
    func updateRecipient(_ recipient: EmailRecipient) {
        if let index = recipients.firstIndex(where: { $0.id == recipient.id }) {
            recipients[index] = recipient
        }
    }
    
    // MARK: - Test Email
    
    func sendTestEmail() async throws {
        let testMessage = EmailMessage(
            alertType: .test,
            subject: "UPS Monitoring - Test Email",
            textContent: """
            This is a test email from your UPS Monitoring system.
            
            If you receive this email, your email notifications are working correctly.
            
            Configuration:
            - From: \(fromName) <\(fromEmail)>
            - Recipients: \(recipients.count) configured
            
            Best regards,
            UPS Monitoring System
            """,
            htmlContent: """
            <!DOCTYPE html>
            <html>
            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                    <h1 style="color: #2196F3; text-align: center;">UPS Monitoring - Test Email</h1>
                    
                    <p>This is a test email from your UPS Monitoring system.</p>
                    
                    <div style="background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0;">
                        <p><strong>✅ Email notifications are working correctly!</strong></p>
                    </div>
                    
                    <h3>Configuration Details:</h3>
                    <ul>
                        <li>From: \(fromName) &lt;\(fromEmail)&gt;</li>
                        <li>Recipients: \(recipients.count) configured</li>
                        <li>Test sent at: \(Date().formatted())</li>
                    </ul>
                    
                    <hr style="border: 1px solid #eee; margin: 30px 0;">
                    <p style="text-align: center; color: #666; font-size: 14px;">
                        UPS Monitoring System
                    </p>
                </div>
            </body>
            </html>
            """,
            deviceName: nil,
            deviceData: nil
        )
        
        try await sendEmail(testMessage)
    }
}

// MARK: - Supporting Types

struct EmailRecipient: Codable, Identifiable {
    let id: UUID
    var name: String
    var email: String
    var isEnabled: Bool = true
    var alertTypes: Set<EmailAlertType> = Set(EmailAlertType.allCases)
    
    init(name: String = "", email: String, isEnabled: Bool = true, alertTypes: Set<EmailAlertType> = Set(EmailAlertType.allCases)) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.isEnabled = isEnabled
        self.alertTypes = alertTypes
    }
}

struct EmailMessage {
    let alertType: EmailAlertType
    let subject: String
    let textContent: String
    let htmlContent: String
    let deviceName: String?
    let deviceData: [String: Any]?
}

enum EmailAlertType: String, CaseIterable, Codable {
    case critical = "critical"
    case warning = "warning"
    case maintenance = "maintenance"
    case report = "report"
    case test = "test"
    
    var displayName: String {
        switch self {
        case .critical: return "Critical Alerts"
        case .warning: return "Warning Alerts"
        case .maintenance: return "Maintenance Alerts"
        case .report: return "Status Reports"
        case .test: return "Test Emails"
        }
    }
    
    var description: String {
        switch self {
        case .critical: return "Power failures, device offline, critical battery levels"
        case .warning: return "High temperature, battery aging, high load"
        case .maintenance: return "Battery replacement reminders, maintenance schedules"
        case .report: return "Daily/weekly status reports and summaries"
        case .test: return "Test emails to verify configuration"
        }
    }
    
    var color: String {
        switch self {
        case .critical: return "#F44336"
        case .warning: return "#FF9800"
        case .maintenance: return "#2196F3"
        case .report: return "#4CAF50"
        case .test: return "#9E9E9E"
        }
    }
}

enum MailjetError: LocalizedError {
    case notConfigured
    case noRecipients
    case noEnabledRecipients
    case rateLimitExceeded
    case tooFrequent
    case apiError(Int)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Mailjet is not configured. Please set your API key, secret, and from email address."
        case .noRecipients:
            return "No email recipients configured."
        case .noEnabledRecipients:
            return "No enabled recipients for this alert type."
        case .rateLimitExceeded:
            return "Email rate limit exceeded. Too many emails sent this hour."
        case .tooFrequent:
            return "Email sent too frequently. Please wait before sending the same alert type."
        case .apiError(let code):
            return "Mailjet API error: HTTP \(code)"
        }
    }
}