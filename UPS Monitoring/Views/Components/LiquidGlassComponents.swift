//
//  LiquidGlassComponents.swift
//  UPS Monitoring
//
//  Liquid Glass UI Components
//

import SwiftUI

// MARK: - Liquid Glass Card

struct LiquidGlassCard<Content: View>: View {
    @Binding var hoveredCard: String?
    let cardId: String
    let content: Content
    @State private var isHovered = false
    
    init(hoveredCard: Binding<String?>, cardId: String, @ViewBuilder content: () -> Content) {
        self._hoveredCard = hoveredCard
        self.cardId = cardId
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                ZStack {
                    // Animated background blur
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .opacity(isHovered ? 0.8 : 0.6)
                        .animation(.easeInOut(duration: 0.3), value: isHovered)
                    
                    // Glass shimmer effect
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.3 : 0.1),
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(isHovered ? 0.2 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(isHovered ? 1.0 : 0.7)
                        .animation(.easeInOut(duration: 0.4), value: isHovered)
                    
                    // Border glow
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.6 : 0.3),
                                    Color.blue.opacity(isHovered ? 0.4 : 0.1),
                                    Color.cyan.opacity(isHovered ? 0.3 : 0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isHovered ? 1.5 : 1
                        )
                        .animation(.easeInOut(duration: 0.3), value: isHovered)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(
                color: Color.black.opacity(isHovered ? 0.15 : 0.08),
                radius: isHovered ? 20 : 10,
                x: 0,
                y: isHovered ? 8 : 4
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
            .onHover { hovered in
                isHovered = hovered
                hoveredCard = hovered ? cardId : nil
            }
    }
}

// MARK: - Liquid Glass Button

struct LiquidGlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let style: GlassButtonStyle
    @State private var isPressed = false
    @State private var isHovered = false
    
    enum GlassButtonStyle {
        case primary, secondary, destructive, success
        
        var colors: (primary: Color, secondary: Color, glow: Color) {
            switch self {
            case .primary:
                return (.blue, .cyan, .blue)
            case .secondary:
                return (.gray, .white, .gray)
            case .destructive:
                return (.red, .pink, .red)
            case .success:
                return (.green, .mint, .green)
            }
        }
    }
    
    init(_ title: String, icon: String? = nil, style: GlassButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: icon != nil ? 6 : 0) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.9),
                        style.colors.primary.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .padding(.horizontal, icon != nil ? 12 : 16)
            .padding(.vertical, 8)
            .frame(minWidth: 44, minHeight: 32)
            .background(
                ZStack {
                    // Main glass background
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .opacity(isHovered ? 0.8 : 0.6)
                    
                    // Gradient overlay
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [
                                    style.colors.primary.opacity(isHovered ? 0.3 : 0.2),
                                    style.colors.secondary.opacity(isHovered ? 0.2 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Border
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    style.colors.glow.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                }
            )
            .scaleEffect(isPressed ? 0.96 : (isHovered ? 1.02 : 1.0))
            .shadow(
                color: style.colors.glow.opacity(isHovered ? 0.3 : 0.1),
                radius: isHovered ? 6 : 3,
                x: 0,
                y: isHovered ? 3 : 2
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovered in
            isHovered = hovered
        }
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
    }
}

// MARK: - Liquid Glass Toggle

struct LiquidGlassToggle: View {
    @Binding var isOn: Bool
    @State private var isHovered = false
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                // Track
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        (isOn ? Color.green : Color.gray).opacity(0.3),
                                        (isOn ? Color.mint : Color.secondary).opacity(0.1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        (isOn ? Color.green : Color.gray).opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .frame(width: 50, height: 28)
                
                // Thumb
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.8),
                                        Color.white.opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        (isOn ? Color.green : Color.gray).opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .frame(width: 24, height: 24)
                    .shadow(
                        color: (isOn ? Color.green : Color.gray).opacity(0.3),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
                    .offset(x: isOn ? -2 : 2)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovered in
            isHovered = hovered
        }
    }
}

// MARK: - Glass Progress Bar

struct GlassProgressBar: View {
    let value: Double
    let total: Double
    let color: Color
    @State private var animatedValue: Double = 0
    
    init(value: Double, total: Double = 100, color: Color = .blue) {
        self.value = value
        self.total = total
        self.color = color
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .opacity(0.4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.gray.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
                
                // Progress fill
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.8),
                                color.opacity(0.6),
                                color.opacity(0.9)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        // Glass highlight
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color.opacity(0.4), lineWidth: 1)
                    )
                    .frame(width: max(8, geometry.size.width * (animatedValue / total)))
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
        .frame(height: 12)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { oldValue, newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedValue = newValue
            }
        }
    }
}

// MARK: - Glass Metric Card

struct GlassMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with glass background
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        color.opacity(0.3),
                                        color.opacity(0.1)
                                    ],
                                    center: .topLeading,
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
                                        color.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(isHovered ? 0.8 : 0.6)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.2 : 0.1),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(
            color: color.opacity(isHovered ? 0.2 : 0.1),
            radius: isHovered ? 8 : 4,
            x: 0,
            y: isHovered ? 4 : 2
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovered in
            isHovered = hovered
        }
    }
}

// MARK: - Glass Status Badge

struct GlassStatusBadge: View {
    let title: String
    let status: BadgeStatus
    @State private var isHovered = false
    
    enum BadgeStatus {
        case online, offline, warning, error, success
        
        var color: Color {
            switch self {
            case .online, .success: return .green
            case .offline, .error: return .red
            case .warning: return .orange
            }
        }
        
        var icon: String {
            switch self {
            case .online: return "checkmark.circle.fill"
            case .offline: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
    }
    
    init(_ title: String, status: BadgeStatus) {
        self.title = title
        self.status = status
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
                .shadow(color: status.color.opacity(0.6), radius: 2)
                .scaleEffect(isHovered ? 1.2 : 1.0)
            
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [status.color, status.color.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
                
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                status.color.opacity(0.2),
                                status.color.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                status.color.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .shadow(
            color: status.color.opacity(isHovered ? 0.3 : 0.1),
            radius: isHovered ? 6 : 3,
            x: 0,
            y: isHovered ? 3 : 1
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovered in
            isHovered = hovered
        }
    }
}

// MARK: - Supporting Extensions

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

// MARK: - Animated Background

struct LiquidGlassBackground: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.blue.opacity(0.15), location: 0.0),
                    .init(color: Color.purple.opacity(0.08), location: 0.3),
                    .init(color: Color.cyan.opacity(0.12), location: 0.6),
                    .init(color: Color.mint.opacity(0.06), location: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated overlay
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.pink.opacity(0.08), location: 0.0),
                    .init(color: Color.orange.opacity(0.04), location: 0.5),
                    .init(color: Color.yellow.opacity(0.06), location: 1.0)
                ]),
                startPoint: UnitPoint(x: 0.0 + animationOffset, y: 0.0),
                endPoint: UnitPoint(x: 1.0 + animationOffset, y: 1.0)
            )
            .opacity(0.7)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: true)) {
                animationOffset = 0.5
            }
        }
    }
}