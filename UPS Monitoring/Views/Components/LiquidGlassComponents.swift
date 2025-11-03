import SwiftUI

// MARK: - Liquid Glass Card (Softened)
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
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .opacity(isHovered ? 0.43 : 0.32)

                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.08 : 0.035),
                                    Color.white.opacity(0.01),
                                    Color.white.opacity(isHovered ? 0.07 : 0.025)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(isHovered ? 0.35 : 0.22)

                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.16 : 0.09),
                                    Color.blue.opacity(isHovered ? 0.10 : 0.03),
                                    Color.cyan.opacity(isHovered ? 0.09 : 0.025)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isHovered ? 1.0 : 0.7
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .scaleEffect(isHovered ? 1.012 : 1.0)
            .shadow(
                color: Color.black.opacity(isHovered ? 0.045 : 0.022),
                radius: isHovered ? 7 : 3,
                x: 0, y: isHovered ? 2 : 1
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
            .onHover { hovered in
                isHovered = hovered
                hoveredCard = hovered ? cardId : nil
            }
    }
}

// MARK: - Liquid Glass Button (Softened)

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
            case .primary:     return (.blue, .cyan, .blue)
            case .secondary:   return (.gray, .white, .gray)
            case .destructive: return (.red, .pink, .red)
            case .success:     return (.green, .mint, .green)
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
                        Color.white.opacity(0.93),
                        style.colors.primary.opacity(0.81)
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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .opacity(isHovered ? 0.38 : 0.28)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [
                                    style.colors.primary.opacity(isHovered ? 0.10 : 0.03),
                                    style.colors.secondary.opacity(isHovered ? 0.05 : 0.01)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.11),
                                    style.colors.glow.opacity(0.09)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.65
                        )
                }
            )
            .scaleEffect(isPressed ? 0.96 : (isHovered ? 1.011 : 1.0))
            .shadow(
                color: style.colors.glow.opacity(isHovered ? 0.11 : 0.045),
                radius: isHovered ? 3.5 : 1.5,
                x: 0, y: isHovered ? 2 : 1
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovered in isHovered = hovered }
        .pressEvents { isPressed = true } onRelease: { isPressed = false }
    }
}

// MARK: - Liquid Glass Toggle (unchanged for subtlety)

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
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(0.17)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        (isOn ? Color.green : Color.gray).opacity(0.097),
                                        (isOn ? Color.mint : Color.secondary).opacity(0.04)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                (isOn ? Color.green : Color.gray).opacity(0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
                    .frame(width: 50, height: 28)

                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.8),
                                        Color.white.opacity(0.3)
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
                                        Color.white.opacity(0.55),
                                        (isOn ? Color.green : Color.gray).opacity(0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .frame(width: 24, height: 24)
                    .shadow(
                        color: (isOn ? Color.green : Color.gray).opacity(0.11),
                        radius: 2,
                        x: 0,
                        y: 1
                    )
                    .offset(x: isOn ? -2 : 2)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 0.17), value: isHovered)
        .onHover { hovered in isHovered = hovered }
    }
}

// MARK: - Glass Progress Bar (gentler)

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
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .opacity(0.13)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.05),
                                        Color.gray.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.25
                            )
                    )
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.61),
                                color.opacity(0.45),
                                color.opacity(0.69)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                Color.white.opacity(0.02),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color.opacity(0.23), lineWidth: 0.65)
                    )
                    .frame(width: max(8, geometry.size.width * (animatedValue / total)))
                    .shadow(color: color.opacity(0.16), radius: 2.3, x: 0, y: 1)
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
                .shadow(color: status.color.opacity(0.35), radius: 1.5)
                .scaleEffect(isHovered ? 1.12 : 1.0)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [status.color, status.color.opacity(0.69)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .textCase(.uppercase)
                .tracking(0.44)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .opacity(0.12)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                status.color.opacity(0.08),
                                status.color.opacity(0.029)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                status.color.opacity(0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .shadow(
            color: status.color.opacity(isHovered ? 0.05 : 0.022),
            radius: isHovered ? 1.4 : 0.8,
            x: 0, y: 0
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovered in isHovered = hovered }
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

// MARK: - Animated LiquidGlass Background (CPU Optimized)

struct LiquidGlassBackground: View {
    @State private var animationOffset: CGFloat = 0
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.blue.opacity(0.08), location: 0.0), // Reduced opacity
                    .init(color: Color.purple.opacity(0.04), location: 0.3),
                    .init(color: Color.cyan.opacity(0.06), location: 0.6),
                    .init(color: Color.mint.opacity(0.03), location: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            if isVisible {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.pink.opacity(0.03), location: 0.0), // Reduced opacity
                        .init(color: Color.orange.opacity(0.02), location: 0.5),
                        .init(color: Color.yellow.opacity(0.03), location: 1.0)
                    ]),
                    startPoint: UnitPoint(x: 0.0 + animationOffset, y: 0.0),
                    endPoint: UnitPoint(x: 1.0 + animationOffset, y: 1.0)
                )
                .opacity(0.25) // Reduced opacity
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Delay animation start and make it much slower to reduce CPU usage
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.linear(duration: 40).repeatForever(autoreverses: true)) { // Increased from 20s to 40s
                    animationOffset = 0.2 // Reduced from 0.28
                }
                isVisible = true
            }
        }
    }
}