//
//  UPSDetailWidget.swift
//  UPS Monitoring Widget
//
//  Medium widget showing detailed status for the most critical device.
//

import WidgetKit
import SwiftUI

struct UPSDetailProvider: TimelineProvider {
    func placeholder(in context: Context) -> UPSDetailEntry {
        UPSDetailEntry(date: Date(), device: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (UPSDetailEntry) -> Void) {
        let device = WidgetSharedData.load()?.devices.sorted(by: prioritySort).first
        completion(UPSDetailEntry(date: Date(), device: device))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UPSDetailEntry>) -> Void) {
        let device = WidgetSharedData.load()?.devices.sorted(by: prioritySort).first
        let entry = UPSDetailEntry(date: Date(), device: device)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func prioritySort(_ a: WidgetDeviceData, _ b: WidgetDeviceData) -> Bool {
        if !a.isOnline && b.isOnline { return true }
        if a.isOnline && !b.isOnline { return false }
        let aCharge = a.batteryCharge ?? 100
        let bCharge = b.batteryCharge ?? 100
        return aCharge < bCharge
    }
}

struct UPSDetailEntry: TimelineEntry {
    let date: Date
    let device: WidgetDeviceData?
}

struct UPSDetailWidgetView: View {
    let entry: UPSDetailEntry

    var body: some View {
        if let device = entry.device {
            deviceView(device)
        } else {
            emptyView
        }
    }

    @ViewBuilder
    private func deviceView(_ device: WidgetDeviceData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)

                    Text(device.outputSource == "Battery" ? "On Battery" : device.isOnline ? "Online" : "Offline")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(statusColor(device))
                }

                Spacer()

                Circle()
                    .fill(statusColor(device))
                    .frame(width: 10, height: 10)
                    .shadow(color: statusColor(device).opacity(0.5), radius: 4)
            }

            Spacer(minLength: 8)

            HStack(spacing: 16) {
                gaugeView(
                    value: device.batteryCharge ?? 0,
                    icon: "battery.100",
                    label: "Battery",
                    color: batteryColor(device.batteryCharge ?? 0)
                )

                gaugeView(
                    value: device.load ?? 0,
                    icon: "bolt.fill",
                    label: "Load",
                    color: loadColor(device.load ?? 0)
                )

                VStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.cyan)

                    Text(device.formattedRuntime ?? "--")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("Runtime")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 8)

            HStack(spacing: 0) {
                if let inputV = device.inputVoltage {
                    metricPill(label: "In", value: "\(Int(inputV))V")
                }
                if let outputV = device.outputVoltage {
                    metricPill(label: "Out", value: "\(Int(outputV))V")
                }
                if let temp = device.temperature {
                    metricPill(label: "Temp", value: "\(Int(temp))°C")
                }
                if let power = device.outputPower {
                    metricPill(label: "Power", value: "\(Int(power))W")
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(.windowBackgroundColor).opacity(0.5)
        }
    }

    @ViewBuilder
    private func gaugeView(value: Double, icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: min(value / 100, 1.0))
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(value))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .frame(width: 44, height: 44)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func metricPill(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("No UPS Devices")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Open UPS Monitor to configure")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .containerBackground(for: .widget) {
            Color(.windowBackgroundColor).opacity(0.5)
        }
    }

    private func statusColor(_ device: WidgetDeviceData) -> Color {
        if !device.isOnline { return .red }
        if device.outputSource == "Battery" { return .orange }
        return .green
    }

    private func batteryColor(_ charge: Double) -> Color {
        switch charge {
        case 50...: return .green
        case 20..<50: return .orange
        default: return .red
        }
    }

    private func loadColor(_ load: Double) -> Color {
        switch load {
        case 0..<60: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

struct UPSDetailWidget: Widget {
    let kind = "UPSDetailWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UPSDetailProvider()) { entry in
            UPSDetailWidgetView(entry: entry)
        }
        .configurationDisplayName("UPS Device")
        .description("Detailed status of your most critical UPS device.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    UPSDetailWidget()
} timeline: {
    UPSDetailEntry(date: Date(), device: WidgetDeviceData(id: UUID(), name: "Server Room UPS", isOnline: true, batteryCharge: 98, load: 32, formattedRuntime: "45 min", temperature: 28, outputSource: "Normal", inputVoltage: 120, outputVoltage: 120, outputPower: 384, alarmsPresent: 0, isCharging: false, lastUpdate: Date()))
}
