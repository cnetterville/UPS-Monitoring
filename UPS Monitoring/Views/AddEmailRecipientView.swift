//
//  AddEmailRecipientView.swift
//  UPS Monitoring
//
//  Created by Assistant on 12/19/24.
//

import SwiftUI

struct AddEmailRecipientView: View {
    let mailjetService: MailjetService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredCard: String? = nil
    
    @State private var name = ""
    @State private var email = ""
    @State private var isEnabled = true
    @State private var selectedAlertTypes: Set<EmailAlertType> = Set(EmailAlertType.allCases)
    
    private var isFormValid: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }
    
    var body: some View {
        ZStack {
            LiquidGlassBackground()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 20) {
                        recipientInfoSection
                        alertTypesSection
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private var headerView: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "add-recipient-header") {
            HStack {
                Text("Add Email Recipient")
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
                
                Spacer()
                
                HStack(spacing: 12) {
                    LiquidGlassButton("Cancel", style: .secondary) {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    LiquidGlassButton(
                        "Add Recipient",
                        icon: "plus.circle.fill",
                        style: isFormValid ? .primary : .secondary
                    ) {
                        saveRecipient()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isFormValid)
                }
            }
        }
        .padding(20)
    }
    
    private var recipientInfoSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "recipient-info") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recipient Information")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                VStack(spacing: 12) {
                    LabeledContent("Name (Optional)") {
                        TextField("Full name", text: $name)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    
                    LabeledContent("Email Address") {
                        TextField("email@example.com", text: $email)
                            .textFieldStyle(GlassTextFieldStyle())
                            .disableAutocorrection(true)
                    }
                    
                    LabeledContent("Status") {
                        HStack {
                            LiquidGlassToggle(isOn: $isEnabled)
                            
                            Text(isEnabled ? "Enabled" : "Disabled")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isEnabled ? .green : .gray)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    private var alertTypesSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "alert-types") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Alert Types")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Spacer()
                    
                    Text("\(selectedAlertTypes.count) of \(EmailAlertType.allCases.count) selected")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Text("Select which types of alerts this recipient should receive")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    ForEach(EmailAlertType.allCases, id: \.self) { alertType in
                        AlertTypeToggleRow(
                            alertType: alertType,
                            isSelected: selectedAlertTypes.contains(alertType)
                        ) { isSelected in
                            if isSelected {
                                selectedAlertTypes.insert(alertType)
                            } else {
                                selectedAlertTypes.remove(alertType)
                            }
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    LiquidGlassButton("Select All", style: .secondary) {
                        selectedAlertTypes = Set(EmailAlertType.allCases)
                    }
                    
                    LiquidGlassButton("Select None", style: .secondary) {
                        selectedAlertTypes.removeAll()
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private func saveRecipient() {
        let recipient = EmailRecipient(
            name: name,
            email: email,
            isEnabled: isEnabled,
            alertTypes: selectedAlertTypes
        )
        
        mailjetService.addRecipient(recipient)
    }
}

struct AlertTypeToggleRow: View {
    let alertType: EmailAlertType
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle(!isSelected)
            } label: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color(alertType.color) : Color.clear)
                    .frame(width: 16, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(alertType.color), lineWidth: 2)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alertType.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text(alertType.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .opacity(isHovered ? 0.6 : 0.3)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? Color(alertType.color).opacity(0.5) : Color.white.opacity(0.2),
                            lineWidth: isSelected ? 1.5 : 0.8
                        )
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onHover { hovered in
            isHovered = hovered
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle(!isSelected)
        }
    }
}

struct EditEmailRecipientView: View {
    @State private var recipient: EmailRecipient
    let mailjetService: MailjetService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredCard: String? = nil
    
    @State private var name: String
    @State private var email: String
    @State private var isEnabled: Bool
    @State private var selectedAlertTypes: Set<EmailAlertType>
    
    init(recipient: EmailRecipient, mailjetService: MailjetService) {
        self.recipient = recipient
        self.mailjetService = mailjetService
        self._name = State(initialValue: recipient.name)
        self._email = State(initialValue: recipient.email)
        self._isEnabled = State(initialValue: recipient.isEnabled)
        self._selectedAlertTypes = State(initialValue: recipient.alertTypes)
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }
    
    var body: some View {
        ZStack {
            LiquidGlassBackground()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 20) {
                        recipientInfoSection
                        alertTypesSection
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private var headerView: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "edit-recipient-header") {
            HStack {
                Text("Edit Email Recipient")
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
                
                Spacer()
                
                HStack(spacing: 12) {
                    LiquidGlassButton("Cancel", style: .secondary) {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    LiquidGlassButton(
                        "Save Changes",
                        icon: "checkmark.circle.fill",
                        style: isFormValid ? .primary : .secondary
                    ) {
                        updateRecipient()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isFormValid)
                }
            }
        }
        .padding(20)
    }
    
    private var recipientInfoSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "recipient-info") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recipient Information")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                VStack(spacing: 12) {
                    LabeledContent("Name (Optional)") {
                        TextField("Full name", text: $name)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    
                    LabeledContent("Email Address") {
                        TextField("email@example.com", text: $email)
                            .textFieldStyle(GlassTextFieldStyle())
                            .disableAutocorrection(true)
                    }
                    
                    LabeledContent("Status") {
                        HStack {
                            LiquidGlassToggle(isOn: $isEnabled)
                            
                            Text(isEnabled ? "Enabled" : "Disabled")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isEnabled ? .green : .gray)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    private var alertTypesSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "alert-types") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Alert Types")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Spacer()
                    
                    Text("\(selectedAlertTypes.count) of \(EmailAlertType.allCases.count) selected")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Text("Select which types of alerts this recipient should receive")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    ForEach(EmailAlertType.allCases, id: \.self) { alertType in
                        AlertTypeToggleRow(
                            alertType: alertType,
                            isSelected: selectedAlertTypes.contains(alertType)
                        ) { isSelected in
                            if isSelected {
                                selectedAlertTypes.insert(alertType)
                            } else {
                                selectedAlertTypes.remove(alertType)
                            }
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    LiquidGlassButton("Select All", style: .secondary) {
                        selectedAlertTypes = Set(EmailAlertType.allCases)
                    }
                    
                    LiquidGlassButton("Select None", style: .secondary) {
                        selectedAlertTypes.removeAll()
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private func updateRecipient() {
        var updatedRecipient = recipient
        updatedRecipient.name = name
        updatedRecipient.email = email
        updatedRecipient.isEnabled = isEnabled
        updatedRecipient.alertTypes = selectedAlertTypes
        
        mailjetService.updateRecipient(updatedRecipient)
    }
}