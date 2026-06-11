//
//  BrevoConfigurationView.swift
//  UPS Monitoring
//

import SwiftUI
import UserNotifications

struct BrevoConfigurationView: View {
    @ObservedObject var brevoService: BrevoService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredCard: String? = nil

    @State private var apiKey: String = ""
    @State private var fromEmail: String = ""
    @State private var fromName: String = ""
    @State private var showingApiKey = false
    @State private var hasLoadedInitialValues = false

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            VStack(spacing: 0) {
                headerView

                ScrollView {
                    VStack(spacing: 24) {
                        infoSection
                        apiConfigSection
                        senderConfigSection

                        if isFormValid {
                            testSection
                        }

                        #if DEBUG
                        debugSection
                        #endif
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 600, height: 650)
        .onAppear {
            loadCurrentSettings()
        }
        .onChange(of: brevoService.isLoading) { _, isLoading in
            if !isLoading && !hasLoadedInitialValues {
                loadCurrentSettings()
            }
        }
    }

    private var headerView: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "brevo-config-header") {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Brevo Configuration")
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
                }

                Spacer()

                HStack(spacing: 12) {
                    LiquidGlassButton("Cancel", style: .secondary) {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    LiquidGlassButton(
                        "Save Configuration",
                        icon: "checkmark.shield.fill",
                        style: isFormValid ? .primary : .secondary
                    ) {
                        saveConfiguration()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isFormValid)
                }
            }
        }
        .padding(20)
    }

    private var infoSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "brevo-info") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)

                    Text("About Brevo")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Brevo is a transactional email service that enables your UPS Monitoring app to send professional email alerts and reports.")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)

                    Text("To get started:")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("1.")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.blue)
                            Text("Sign up for a free Brevo account at brevo.com")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Text("2.")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.blue)
                            Text("Generate an API key from Settings → SMTP & API → API Keys")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Text("3.")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.blue)
                            Text("Verify your sender email address in Brevo")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 8)

                    HStack(spacing: 8) {
                        LiquidGlassButton(
                            "Open Brevo.com",
                            icon: "safari",
                            style: .secondary
                        ) {
                            if let url = URL(string: "https://www.brevo.com") {
                                NSWorkspace.shared.open(url)
                            }
                        }

                        LiquidGlassButton(
                            "API Documentation",
                            icon: "doc.text",
                            style: .secondary
                        ) {
                            if let url = URL(string: "https://developers.brevo.com") {
                                NSWorkspace.shared.open(url)
                            }
                        }

                        Spacer()
                    }
                }
            }
        }
    }

    private var apiConfigSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "api-config") {
            VStack(alignment: .leading, spacing: 16) {
                Text("API Configuration")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    HStack {
                        if showingApiKey {
                            TextField("Your Brevo API Key", text: $apiKey)
                                .textFieldStyle(GlassTextFieldStyle())
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("Your Brevo API Key", text: $apiKey)
                                .textFieldStyle(GlassTextFieldStyle())
                        }

                        Button {
                            showingApiKey.toggle()
                        } label: {
                            Image(systemName: showingApiKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "shield.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 12))

                        Text("Security Note")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your API key is stored securely in the macOS Keychain and is never transmitted except to Brevo's servers.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Text("• macOS will prompt you for keychain access when saving credentials for the first time")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)

                        Text("• You can grant or deny this access - denying will prevent email notifications")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                }
                .padding(.leading, 20)
            }
        }
    }

    private var senderConfigSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "sender-config") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sender Configuration")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Text("This information will appear as the sender in all email alerts")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("From Email Address")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)

                        TextField("alerts@yourdomain.com", text: $fromEmail)
                            .textFieldStyle(GlassTextFieldStyle())
                            .disableAutocorrection(true)

                        Text("Must be a verified sender in your Brevo account")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("From Name")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)

                        TextField("UPS Monitoring System", text: $fromName)
                            .textFieldStyle(GlassTextFieldStyle())

                        Text("This name will appear as the sender in email clients")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var testSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "test-section") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)

                    Text("Configuration Ready")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.green)
                }

                Text("Your configuration looks complete. You can test the email service before saving.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    LiquidGlassButton(
                        "Send Test Email",
                        icon: "paperplane.fill",
                        style: .success
                    ) {
                        sendTestEmail()
                    }

                    Spacer()

                    Text("Test emails will be sent to configured recipients")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
    }

    private var isFormValid: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !fromEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        fromEmail.contains("@") &&
        fromEmail.contains(".") &&
        !fromName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadCurrentSettings() {
        guard !brevoService.isLoading else { return }
        apiKey = brevoService.apiKey
        fromEmail = brevoService.fromEmail
        fromName = brevoService.fromName
        hasLoadedInitialValues = true
    }

    private func saveConfiguration() {
        brevoService.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        brevoService.fromEmail = fromEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        brevoService.fromName = fromName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    #if DEBUG
    private var debugSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "debug-section") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "ladybug")
                        .font(.system(size: 20))
                        .foregroundStyle(.orange)

                    Text("Debug Information")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Service State:")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Is Loading: \(brevoService.isLoading ? "YES" : "NO")")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)

                        Text("• Is Configured: \(brevoService.isConfigured ? "YES" : "NO")")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)

                        Text("• API Key Set: \(brevoService.apiKey.isEmpty ? "NO" : "YES")")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)

                        Text("• From Email: '\(brevoService.fromEmail)'")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)

                        Text("• From Name: '\(brevoService.fromName)'")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)

                        Text("• Has Loaded Initial: \(hasLoadedInitialValues ? "YES" : "NO")")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    LiquidGlassButton(
                        "Reload Config",
                        icon: "arrow.clockwise",
                        style: .secondary
                    ) {
                        brevoService.reloadConfiguration()
                        hasLoadedInitialValues = false
                        loadCurrentSettings()
                    }

                    LiquidGlassButton(
                        "Print Debug",
                        icon: "printer",
                        style: .secondary
                    ) {
                        print("=== BREVO DEBUG INFO ===")
                        print("Service - API Key: \(brevoService.apiKey.isEmpty ? "EMPTY" : "[HIDDEN]")")
                        print("Service - From Email: '\(brevoService.fromEmail)'")
                        print("Service - From Name: '\(brevoService.fromName)'")
                        print("Service - Is Loading: \(brevoService.isLoading)")
                        print("Service - Is Configured: \(brevoService.isConfigured)")
                        print("View - API Key: \(apiKey.isEmpty ? "EMPTY" : "[HIDDEN]")")
                        print("View - From Email: '\(fromEmail)'")
                        print("View - From Name: '\(fromName)'")
                        print("View - Has Loaded Initial: \(hasLoadedInitialValues)")
                        print("=======================")
                    }

                    Spacer()
                }
            }
        }
    }
    #endif

    private func sendTestEmail() {
        let originalApiKey = brevoService.apiKey
        let originalFromEmail = brevoService.fromEmail
        let originalFromName = brevoService.fromName

        brevoService.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        brevoService.fromEmail = fromEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        brevoService.fromName = fromName.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                try await brevoService.sendTestEmail()

                DispatchQueue.main.async {
                    let content = UNMutableNotificationContent()
                    content.title = "Test Email Sent"
                    content.body = "Check your email for the test message from Brevo"
                    content.sound = .default
                    let request = UNNotificationRequest(identifier: "brevo_test_success", content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request)
                }
            } catch {
                brevoService.apiKey = originalApiKey
                brevoService.fromEmail = originalFromEmail
                brevoService.fromName = originalFromName

                DispatchQueue.main.async {
                    let content = UNMutableNotificationContent()
                    content.title = "Test Email Failed"
                    content.body = error.localizedDescription
                    content.sound = .default
                    let request = UNNotificationRequest(identifier: "brevo_test_error", content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request)
                }
            }
        }
    }
}
