//
//  EmailRecipientRow.swift
//  UPS Monitoring
//
//  Created by Assistant on 12/19/24.
//

import SwiftUI

struct EmailRecipientRow: View {
    let recipient: EmailRecipient
    let mailjetService: MailjetService
    @Binding var hoveredCard: String?
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var showingEditRecipient = false
    
    private var cardId: String { "recipient-\(recipient.id)" }
    
    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            Circle()
                .fill(recipient.isEnabled ? .green : .gray)
                .frame(width: 8, height: 8)
                .shadow(color: recipient.isEnabled ? .green : .gray, radius: 2)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recipient.name.isEmpty ? recipient.email : recipient.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    if !recipient.name.isEmpty {
                        Text("(\(recipient.email))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 4) {
                    ForEach(Array(recipient.alertTypes.prefix(3)), id: \.self) { alertType in
                        Text(alertType.rawValue)
                            .font(.system(size: 9, weight: .medium))
                            .textCase(.uppercase)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(alertType.color).opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(Color(alertType.color), lineWidth: 0.5)
                                    )
                            )
                            .foregroundColor(Color(alertType.color))
                    }
                    
                    if recipient.alertTypes.count > 3 {
                        Text("+\(recipient.alertTypes.count - 3)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                LiquidGlassButton(
                    "",
                    icon: "pencil",
                    style: .secondary
                ) {
                    showingEditRecipient = true
                }
                
                LiquidGlassButton(
                    "",
                    icon: "trash",
                    style: .destructive
                ) {
                    mailjetService.removeRecipient(recipient)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .opacity(isHovered ? 0.6 : 0.4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.blue.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovered in
            isHovered = hovered
            hoveredCard = hovered ? cardId : nil
        }
        .sheet(isPresented: $showingEditRecipient) {
            EditEmailRecipientView(recipient: recipient, mailjetService: mailjetService)
        }
    }
}

// Color extension for EmailAlertType
extension Color {
    init(_ hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let rgbValue = UInt32(hex, radix: 16)
        let r = Double((rgbValue! & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue! & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue! & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}