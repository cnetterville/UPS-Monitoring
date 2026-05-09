import SwiftUI

// MARK: - Content Card (Standard Material per HIG - glass is NOT for content layer)

struct LiquidGlassCard<Content: View>: View {
    @Binding var hoveredCard: String?
    let cardId: String
    let content: Content

    init(hoveredCard: Binding<String?>, cardId: String, @ViewBuilder content: () -> Content) {
        self._hoveredCard = hoveredCard
        self.cardId = cardId
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.separator.opacity(0.3), lineWidth: 0.5)
            )
    }
}

// MARK: - Button (Real Liquid Glass)

struct LiquidGlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let style: Variant

    enum Variant {
        case primary, secondary, destructive, success
    }

    init(_ title: String, icon: String? = nil, style: Variant = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    @ViewBuilder
    var body: some View {
        switch style {
        case .primary:
            makeButton().buttonStyle(.glassProminent)
        case .secondary:
            makeButton().buttonStyle(.glass)
        case .destructive:
            makeButton().buttonStyle(.glass(.regular.tint(.red)))
        case .success:
            makeButton().buttonStyle(.glass(.regular.tint(.green)))
        }
    }

    private func makeButton() -> some View {
        Button(action: action) {
            HStack(spacing: icon != nil && !title.isEmpty ? 6 : 0) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                if !title.isEmpty {
                    Text(title)
                }
            }
        }
    }
}

// MARK: - Toggle (Standard SwiftUI)

struct LiquidGlassToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn)
            .toggleStyle(.switch)
            .labelsHidden()
    }
}

// MARK: - Progress Bar

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
                    .fill(color.opacity(0.15))

                RoundedRectangle(cornerRadius: 8)
                    .fill(color.gradient)
                    .frame(width: max(8, geometry.size.width * (animatedValue / total)))
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

// MARK: - Status Badge

struct GlassStatusBadge: View {
    let title: String
    let status: BadgeStatus

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
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(status.color)
                .textCase(.uppercase)
                .tracking(0.4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(status.color.opacity(0.1), in: Capsule())
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

// MARK: - Background (no-op, let system handle)

struct LiquidGlassBackground: View {
    var body: some View {
        Color.clear
            .ignoresSafeArea()
    }
}
