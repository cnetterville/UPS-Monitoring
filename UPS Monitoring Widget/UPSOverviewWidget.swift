//
//  UPSOverviewWidget.swift
//  UPS Monitoring Widget
//
//  Large widget showing all UPS devices at a glance.
//

import WidgetKit
import SwiftUI

struct UPSOverviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> UPSOverviewEntry {
        UPSOverviewEntry(date: Date(), data: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (UPSOverviewEntry) -> Void) {
        completion(UPSOverviewEntry(date: Date(), data: WidgetSharedData.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UPSOverviewEntry>) -> Void) {
        let entry = UPSOverviewEntry(date: Date(), data: WidgetSharedData.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct UPSOverviewEntry: TimelineEntry {
    let date: Date
    let data: WidgetSharedData?
}

struct UPSOverviewWidgetView: View {
    let entry: UPSOverviewEntry

    var body: some View {
        if let data = entry.data, !data.devices.isEmpty {
            overviewView(data)
        } else {
            emptyView
        }
    }

    @ViewBuilder
    private func overviewView(_ data: WidgetSharedData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.blue.gradient)

                Text("UPS Monitor")
                    .font(.system(size: 15, weight: .bold))

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(data.onlineCount == data.totalCount ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)

                    Text("\(data.onlineCount)/\(data.totalCount) Online")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .opacity(0.5)

            ForEach(data.devices.prefix(5)) { device in
                deviceRow(device)
            }

            if data.devices.count > 5 {
                Text("+\(data.devices.count - 5) more")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Text("Updated \(entry.date.formatted(date: .omitted, time: .shortened))")
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
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(device))
                .frame(width: 7, height: 7)

            Text(device.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)

            Spacer()

            if let charge = device.batteryCharge {
                HStack(spacing: 3) {
                    Image(systemName: batteryIcon(charge))
                        .font(.system(size: 9))
                        .foregroundStyle(batteryColor(charge))

                    Text("\(Int(charge))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .frame(width: 48, alignment: .trailing)
            }

            if let load = device.load {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(loadColor(load))

                    Text("\(Int(load))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .frame(width: 44, alignment: .trailing)
            }

            if let runtime = device.formattedRuntime {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundStyle(.cyan)

                    Text(runtime)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .lineLimit(1)
                }
                .frame(width: 52, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(statusColor(device).opacity(0.06))
        )
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No UPS Devices")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Open UPS Monitor to add and configure your UPS devices")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
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

struct UPSOverviewWidget: Widget {
    let kind = "UPSOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UPSOverviewProvider()) { entry in
            UPSOverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("UPS Overview")
        .description("All your UPS devices at a glance.")
        .supportedFamilies([.systemLarge])
    }
}

#Preview(as: .systemLarge) {
    UPSOverviewWidget()
} timeline: {
    UPSOverviewEntry(date: Date(), data: WidgetSharedData(
        devices: [
            WidgetDeviceData(id: UUID(), name: "Server Room UPS", isOnline: true, batteryCharge: 98, load: 32, formattedRuntime: "45 min", temperature: 28, outputSource: "Normal", inputVoltage: 120, outputVoltage: 120, outputPower: 384, alarmsPresent: 0, isCharging: false, lastUpdate: Date()),
            WidgetDeviceData(id: UUID(), name: "Network Closet", isOnline: true, batteryCharge: 95, load: 28, formattedRuntime: "52 min", temperature: 26, outputSource: "Normal", inputVoltage: 121, outputVoltage: 120, outputPower: 280, alarmsPresent: 0, isCharging: false, lastUpdate: Date()),
            WidgetDeviceData(id: UUID(), name: "Office UPS", isOnline: false, batteryCharge: 45, load: 0, formattedRuntime: nil, temperature: nil, outputSource: nil, inputVoltage: nil, outputVoltage: nil, outputPower: nil, alarmsPresent: 1, isCharging: nil, lastUpdate: Date().addingTimeInterval(-300))
        ],
        lastRefresh: Date()
    ))
}
