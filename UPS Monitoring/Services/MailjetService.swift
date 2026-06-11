//
//  BrevoService.swift
//  UPS Monitoring
//
//  Transactional email via the Brevo API (https://api.brevo.com)
//

import Foundation
import Combine

@MainActor
class BrevoService: ObservableObject {
    static let shared = BrevoService()

    // MARK: - Configuration
    @Published var isConfigured = false
    @Published var isLoading = false
    @Published var apiKey: String = "" {
        didSet { if !isLoading { updateConfiguration() } }
    }
    @Published var fromEmail: String = "" {
        didSet { if !isLoading { updateConfiguration() } }
    }
    @Published var fromName: String = "UPS Monitoring" {
        didSet { if !isLoading { updateConfiguration() } }
    }
    @Published var recipients: [EmailRecipient] = [] {
        didSet { if !isLoading { saveRecipients() } }
    }

    // MARK: - Rate Limiting
    private var lastEmailTimes: [String: Date] = [:]
    private let minInterval: TimeInterval = 300
    private let maxEmailsPerHour = 20
    private var emailsSentThisHour: [(Date, String)] = []

    // MARK: - Email Queue
    private var emailQueue: [EmailMessage] = []
    private var isProcessingQueue = false

    private init() {
        loadConfiguration()
    }

    // MARK: - Configuration Management

    private func updateIsConfigured() {
        let wasConfigured = isConfigured
        isConfigured = !apiKey.isEmpty && !fromEmail.isEmpty
        if isConfigured != wasConfigured {
            print("📊 Brevo configuration: \(isConfigured ? "CONFIGURED" : "NOT CONFIGURED")")
        }
    }

    private func updateConfiguration() {
        updateIsConfigured()
        saveConfiguration()
    }

    private func saveConfiguration() {
        guard !isLoading else { return }

        do {
            if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try KeychainService.shared.store(
                    apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                    for: KeychainService.Keys.brevoAPIKey
                )
                // Flag that the user has explicitly entered a Brevo API key via the config UI.
                // loadConfiguration() only loads the key when this flag is set, preventing
                // stale migrated Mailjet keys from being forwarded to Brevo.
                UserDefaults.standard.set(true, forKey: "brevo_key_explicitly_set")
            } else {
                try? KeychainService.shared.delete(for: KeychainService.Keys.brevoAPIKey)
                UserDefaults.standard.removeObject(forKey: "brevo_key_explicitly_set")
            }
        } catch {
            print("❌ Failed to save Brevo API key to Keychain: \(error.localizedDescription)")
        }

        UserDefaults.standard.set(
            fromEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: "brevo_from_email"
        )
        UserDefaults.standard.set(
            fromName.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: "brevo_from_name"
        )
    }

    private func loadConfiguration() {
        isLoading = true

        do {
            // Only load a stored key if the user explicitly configured it via the UI.
            // If the flag is absent the slot may contain a stale Mailjet key from an older
            // migration path — delete it so the user is prompted to enter a Brevo key.
            if UserDefaults.standard.bool(forKey: "brevo_key_explicitly_set") {
                apiKey = try KeychainService.shared.retrieve(for: KeychainService.Keys.brevoAPIKey) ?? ""
            } else {
                try? KeychainService.shared.delete(for: KeychainService.Keys.brevoAPIKey)
                apiKey = ""
            }
        } catch {
            print("❌ Failed to load Brevo API key from Keychain: \(error.localizedDescription)")
            apiKey = ""
        }

        // Migrate sender settings from Mailjet if Brevo settings not yet present
        fromEmail = UserDefaults.standard.string(forKey: "brevo_from_email")
            ?? UserDefaults.standard.string(forKey: "mailjet_from_email")
            ?? ""
        fromName = UserDefaults.standard.string(forKey: "brevo_from_name")
            ?? UserDefaults.standard.string(forKey: "mailjet_from_name")
            ?? "UPS Monitoring"

        loadRecipients()

        isLoading = false
        // Update isConfigured without calling saveConfiguration() — loading is not a user action
        // and we must not re-persist a potentially-stale key back into Keychain.
        updateIsConfigured()
    }

    func reloadConfiguration() {
        loadConfiguration()
    }

    private func saveRecipients() {
        if let data = try? JSONEncoder().encode(recipients) {
            UserDefaults.standard.set(data, forKey: "brevo_recipients")
        }
    }

    private func loadRecipients() {
        // Fall back to old Mailjet key for one-time migration
        let data = UserDefaults.standard.data(forKey: "brevo_recipients")
            ?? UserDefaults.standard.data(forKey: "mailjet_recipients")
        if let data, let decoded = try? JSONDecoder().decode([EmailRecipient].self, from: data) {
            recipients = decoded
        }
    }

    // MARK: - Email Sending

    func sendEmail(_ message: EmailMessage) async throws {
        guard isConfigured else { throw BrevoError.notConfigured }
        guard !recipients.isEmpty else { throw BrevoError.noRecipients }

        try await checkRateLimit(for: message.alertType)

        let targetRecipients = recipients.filter {
            $0.isEnabled && $0.alertTypes.contains(message.alertType)
        }
        guard !targetRecipients.isEmpty else { throw BrevoError.noEnabledRecipients }

        let payload = buildEmailPayload(message: message, recipients: targetRecipients)
        try await sendToBrevoAPI(payload: payload)
        await updateRateLimit(for: message.alertType)
    }

    private func checkRateLimit(for alertType: EmailAlertType) async throws {
        if alertType == .test || alertType == .report { return }

        let oneHourAgo = Date().addingTimeInterval(-3600)
        emailsSentThisHour = emailsSentThisHour.filter { $0.0 > oneHourAgo }

        if emailsSentThisHour.count >= maxEmailsPerHour { throw BrevoError.rateLimitExceeded }

        if let lastTime = lastEmailTimes[alertType.rawValue],
           Date().timeIntervalSince(lastTime) < minInterval {
            throw BrevoError.tooFrequent
        }
    }

    private func updateRateLimit(for alertType: EmailAlertType) async {
        if alertType == .test || alertType == .report { return }
        lastEmailTimes[alertType.rawValue] = Date()
        emailsSentThisHour.append((Date(), alertType.rawValue))
    }

    private func buildEmailPayload(message: EmailMessage, recipients: [EmailRecipient]) -> [String: Any] {
        let toArray = recipients.map { r in
            ["email": r.email, "name": r.name.isEmpty ? r.email : r.name]
        }
        return [
            "sender": ["email": fromEmail, "name": fromName],
            "to": toArray,
            "subject": message.subject,
            "textContent": message.textContent,
            "htmlContent": message.htmlContent
        ]
    }

    private func sendToBrevoAPI(payload: [String: Any]) async throws {
        let url = URL(string: "https://api.brevo.com/v3/smtp/email")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 201 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Brevo API Error: \(errorData)")
            }
            throw BrevoError.apiError(httpResponse.statusCode)
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
                    print("✅ Email sent via Brevo: \(message.subject)")
                } catch {
                    print("❌ Failed to send email via Brevo: \(error.localizedDescription)")
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            await MainActor.run { isProcessingQueue = false }
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
        let message = EmailMessage(
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
                    <p style="text-align: center; color: #666; font-size: 14px;">UPS Monitoring System</p>
                </div>
            </body>
            </html>
            """,
            deviceName: nil,
            deviceData: nil
        )
        try await sendEmail(message)
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

enum BrevoError: LocalizedError {
    case notConfigured
    case noRecipients
    case noEnabledRecipients
    case rateLimitExceeded
    case tooFrequent
    case apiError(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Brevo is not configured. Please set your API key and from email address."
        case .noRecipients:
            return "No email recipients configured."
        case .noEnabledRecipients:
            return "No enabled recipients for this alert type."
        case .rateLimitExceeded:
            return "Email rate limit exceeded. Too many emails sent this hour."
        case .tooFrequent:
            return "Email sent too frequently. Please wait before sending the same alert type."
        case .apiError(let code):
            return "Brevo API error: HTTP \(code)"
        }
    }
}
