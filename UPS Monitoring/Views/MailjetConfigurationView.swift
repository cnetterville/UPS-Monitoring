//
//  MailjetConfigurationView.swift
//  UPS Monitoring
//
//  Created by Assistant on 12/19/24.
//

import SwiftUI
import UserNotifications

struct MailjetConfigurationView: View {
    @ObservedObject var mailjetService: MailjetService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredCard: String? = nil
    
    @State private var apiKey: String = ""
    @State private var apiSecret: String = ""
    @State private var fromEmail: String = ""
    @State private var fromName: String = ""
    @State private var showingApiKey = false
    @State private var showingApiSecret = false
    @State private var hasLoadedInitialValues = false
    
    var body: some View {
        ZStack {
            LiquidGlassBackground()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Information section
                        infoSection
                        
                        // API Configuration section
                        apiConfigSection
                        
                        // Sender Configuration section
                        senderConfigSection
                        
                        // Test section (if configured)
                        if isFormValid {
                            testSection
                        }
                        
                        // Debug section (in development)
                        #if DEBUG
                        debugSection
                        #endif
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 600, height: 700)
        .onAppear {
            loadCurrentSettings()
        }
        .onChange(of: mailjetService.isLoading) { _, isLoading in
            if !isLoading && !hasLoadedInitialValues {
                loadCurrentSettings()
            }
        }
    }
    
    private var headerView: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "mailjet-config-header") {
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
                    
                    Text("Mailjet Configuration")
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
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "mailjet-info") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                    
                    Text("About Mailjet")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mailjet is an email service that enables your UPS Monitoring app to send professional email alerts and reports.")
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
                            Text("Sign up for a free Mailjet account at mailjet.com")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("2.")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.blue)
                            Text("Get your API key and secret from the API Key Management page")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("3.")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.blue)
                            Text("Verify your sender email address in Mailjet")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 8)
                    
                    HStack(spacing: 8) {
                        LiquidGlassButton(
                            "Open Mailjet.com",
                            icon: "safari",
                            style: .secondary
                        ) {
                            if let url = URL(string: "https://www.mailjet.com") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        
                        LiquidGlassButton(
                            "API Documentation",
                            icon: "doc.text",
                            style: .secondary
                        ) {
                            if let url = URL(string: "https://dev.mailjet.com") {
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
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack {
                            if showingApiKey {
                                TextField("Your Mailjet API Key", text: $apiKey)
                                    .textFieldStyle(GlassTextFieldStyle())
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                SecureField("Your Mailjet API Key", text: $apiKey)
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
                        Text("API Secret")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack {
                            if showingApiSecret {
                                TextField("Your Mailjet API Secret", text: $apiSecret)
                                    .textFieldStyle(GlassTextFieldStyle())
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                SecureField("Your Mailjet API Secret", text: $apiSecret)
                                    .textFieldStyle(GlassTextFieldStyle())
                            }
                            
                            Button {
                                showingApiSecret.toggle()
                            } label: {
                                Image(systemName: showingApiSecret ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
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
                        Text("Your API credentials are stored securely in the macOS Keychain and are never transmitted except to Mailjet's servers.")
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
                        
                        Text("Must be verified in your Mailjet account")
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
        !apiSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !fromEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        fromEmail.contains("@") &&
        fromEmail.contains(".") &&
        !fromName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func loadCurrentSettings() {
        print("🔄 Loading current settings from MailjetService...")
        print("   - Service is loading: \(mailjetService.isLoading)")
        print("   - Service API Key: \(mailjetService.apiKey.isEmpty ? "EMPTY" : "[HIDDEN]")")
        print("   - Service API Secret: \(mailjetService.apiSecret.isEmpty ? "EMPTY" : "[HIDDEN]")")
        print("   - Service From Email: '\(mailjetService.fromEmail)'")
        print("   - Service From Name: '\(mailjetService.fromName)'")
        
        // Don't load if service is still loading from keychain
        guard !mailjetService.isLoading else {
            print("⏳ Service is still loading, waiting...")
            return
        }
        
        apiKey = mailjetService.apiKey
        apiSecret = mailjetService.apiSecret
        fromEmail = mailjetService.fromEmail
        fromName = mailjetService.fromName
        hasLoadedInitialValues = true
        
        print("✅ View state updated with current values")
        print("   - View API Key: \(apiKey.isEmpty ? "EMPTY" : "[HIDDEN]")")
        print("   - View API Secret: \(apiSecret.isEmpty ? "EMPTY" : "[HIDDEN]")")
        print("   - View From Email: '\(fromEmail)'")
        print("   - View From Name: '\(fromName)'")
    }
    
    private func saveConfiguration() {
        let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedApiSecret = apiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFromEmail = fromEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFromName = fromName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("💾 Saving configuration from view...")
        print("   - Saving API Key: \(trimmedApiKey.isEmpty ? "EMPTY" : "[HIDDEN]")")
        print("   - Saving API Secret: \(trimmedApiSecret.isEmpty ? "EMPTY" : "[HIDDEN]")")
        print("   - Saving From Email: '\(trimmedFromEmail)'")
        print("   - Saving From Name: '\(trimmedFromName)'")
        
        // Show keychain access message if this is the first time saving credentials
        let isFirstTimeSetup = mailjetService.apiKey.isEmpty && mailjetService.apiSecret.isEmpty
        
        if isFirstTimeSetup && (!trimmedApiKey.isEmpty || !trimmedApiSecret.isEmpty) {
            // This will trigger the keychain access prompt
            print("🔐 First time saving credentials - Keychain access will be requested")
        }
        
        mailjetService.apiKey = trimmedApiKey
        mailjetService.apiSecret = trimmedApiSecret
        mailjetService.fromEmail = trimmedFromEmail
        mailjetService.fromName = trimmedFromName
        
        print("✅ Configuration saved to MailjetService")
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
                        Text("• Is Loading: \(mailjetService.isLoading ? "YES" : "NO")")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("• Is Configured: \(mailjetService.isConfigured ? "YES" : "NO")")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("• API Key Set: \(mailjetService.apiKey.isEmpty ? "NO" : "YES")")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("• API Secret Set: \(mailjetService.apiSecret.isEmpty ? "NO" : "YES")")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("• From Email: '\(mailjetService.fromEmail)'")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("• From Name: '\(mailjetService.fromName)'")
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
                        mailjetService.reloadConfiguration()
                        hasLoadedInitialValues = false
                        loadCurrentSettings()
                    }
                    
                    LiquidGlassButton(
                        "Print Debug",
                        icon: "printer",
                        style: .secondary
                    ) {
                        print("=== MAILJET DEBUG INFO ===")
                        print("Service - API Key: \(mailjetService.apiKey.isEmpty ? "EMPTY" : "[HIDDEN]")")
                        print("Service - API Secret: \(mailjetService.apiSecret.isEmpty ? "EMPTY" : "[HIDDEN]")")
                        print("Service - From Email: '\(mailjetService.fromEmail)'")
                        print("Service - From Name: '\(mailjetService.fromName)'")
                        print("Service - Is Loading: \(mailjetService.isLoading)")
                        print("Service - Is Configured: \(mailjetService.isConfigured)")
                        print("View - API Key: \(apiKey.isEmpty ? "EMPTY" : "[HIDDEN]")")
                        print("View - API Secret: \(apiSecret.isEmpty ? "EMPTY" : "[HIDDEN]")")
                        print("View - From Email: '\(fromEmail)'")
                        print("View - From Name: '\(fromName)'")
                        print("View - Has Loaded Initial: \(hasLoadedInitialValues)")
                        print("========================")
                    }
                    
                    Spacer()
                }
            }
        }
    }
    #endif
    
    private func sendTestEmail() {
        // Temporarily apply the settings for testing
        let originalApiKey = mailjetService.apiKey
        let originalApiSecret = mailjetService.apiSecret
        let originalFromEmail = mailjetService.fromEmail
        let originalFromName = mailjetService.fromName
        
        mailjetService.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        mailjetService.apiSecret = apiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        mailjetService.fromEmail = fromEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        mailjetService.fromName = fromName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                try await mailjetService.sendTestEmail()
                
                // Show success notification
                DispatchQueue.main.async {
                    let content = UNMutableNotificationContent()
                    content.title = "Test Email Sent"
                    content.body = "Check your email for the test message from Mailjet"
                    content.sound = .default
                    
                    let request = UNNotificationRequest(identifier: "mailjet_test_success", content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request)
                }
            } catch {
                // Restore original settings on error
                mailjetService.apiKey = originalApiKey
                mailjetService.apiSecret = originalApiSecret
                mailjetService.fromEmail = originalFromEmail
                mailjetService.fromName = originalFromName
                
                // Show error notification
                DispatchQueue.main.async {
                    let content = UNMutableNotificationContent()
                    content.title = "Test Email Failed"
                    content.body = error.localizedDescription
                    content.sound = .default
                    
                    let request = UNNotificationRequest(identifier: "mailjet_test_error", content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request)
                }
            }
        }
    }
}