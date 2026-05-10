//
//  UPSDetailWidget.swift
//  UPS Monitoring Widget
//
//  Medium widget showing top UPS devices in a compact list.
//

import WidgetKit
import SwiftUI

struct UPSDetailProvider: TimelineProvider {
    func placeholder(in context: Context) -> UPSDetailEntry {
        UPSDetailEntry(date: Date(), data: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (UPSDetailEntry) -> Void) {
        completion(UPSDetailEntry(date: Date(), data: WidgetSharedData.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UPSDetailEntry>) -> Void) {
        let entry = UPSDetailEntry(date: Date(), data: WidgetSharedData.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct UPSDetailEntry: TimelineEntry {
    let date: Date
    let data: WidgetSharedData?
}

struct UPSDetailWidgetView: View {
    let entry: UPSDetailEntry

    var body: some View {
        if let data = entry.data, !data.devices.isEmpty {
            detailView(data)
        } else {
            emptyView
        }
    }

    @ViewBuilder
    private func detailView(_ data: WidgetSharedData) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.blue.gradient)

                Text("UPS Monitor")
                    .font(.system(size: 11, weight: .bold))

                Spacer()

                Circle()
                    .fill(data.onlineCount == data.totalCount ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)

                Text("\(data.onlineCount)/\(data.totalCount) Online")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            ForEach(data.devices.prefix(4)) { device in
                deviceRow(device)
            }

            if data.devices.count > 4 {
                Text("+\(data.devices.count - 4) more")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .containerBackground(for: .widget) {
            Color(.windowBackgroundColor).opacity(0.5)
        }
    }

    @ViewBuilder
    private func deviceRow(_ device: WidgetDeviceData) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor(device))
                .frame(width: 7, height: 7)

            Text(device.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)

            Spacer(minLength: 4)

            HStack(spacing: 2) {
                Image(systemName: batteryIcon(device.batteryCharge ?? 0))
                    .font(.system(size: 9))
                    .foregroundStyle(batteryColor(device.batteryCharge ?? 0))

                Text("\(Int(device.batteryCharge ?? 0))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .frame(width: 54, alignment: .trailing)

            HStack(spacing: 2) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(loadColor(device.load ?? 0))

                Text("\(Int(device.load ?? 0))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .frame(width: 40, alignment: .trailing)

            HStack(spacing: 2) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                    .foregroundStyle(.cyan)

                Text(device.formattedRuntime ?? "--")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .lineLimit(1)
            }
            .frame(width: 62, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(statusColor(device).opacity(0.06))
        )
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

    private func batteryIcon(_ charge: Double) -> String {
        switch charge {
        case 75...: return "battery.100"
        case 50..<75: return "battery.75"
        case 25..<50: return "battery.50"
        default: return "battery.25"
        }
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
        .description("Top UPS devices at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    UPSDetailWidget()
} timeline: {
    UPSDetailEntry(date: Date(), data: WidgetSharedData(
        devices: [
            WidgetDeviceData(id: UUID(), name: "Server Room UPS", isOnline: true, batteryCharge: 98, load: 32, formattedRuntime: "45 min", temperature: 28, outputSource: "Normal", inputVoltage: 120, outputVoltage: 120, outputPower: 384, alarmsPresent: 0, isCharging: false, lastUpdate: Date()),
            WidgetDeviceData(id: UUID(), name: "Network Closet", isOnline: true, batteryCharge: 95, load: 28, formattedRuntime: "52 min", temperature: 26, outputSource: "Normal", inputVoltage: 121, outputVoltage: 120, outputPower: 280, alarmsPresent: 0, isCharging: false, lastUpdate: Date())
        ],
        lastRefresh: Date()
    ))
}
