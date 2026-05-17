//
//  UPSSummaryWidget.swift
//  UPS Monitoring Widget
//
//  Small widget showing overall UPS fleet status.
//

import WidgetKit
import SwiftUI

struct UPSSummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> UPSSummaryEntry {
        // Read shared data so the placeholder isn't a near-blank view when the
        // system renders it before requesting a snapshot. Falls back to nil
        // when the app hasn't written data yet.
        let data = WidgetSharedData.load()
        return UPSSummaryEntry(date: data?.lastRefresh ?? Date(), data: data)
    }

    func getSnapshot(in context: Context, completion: @escaping (UPSSummaryEntry) -> Void) {
        let data = WidgetSharedData.load()
        completion(UPSSummaryEntry(date: data?.lastRefresh ?? Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UPSSummaryEntry>) -> Void) {
        let data = WidgetSharedData.load()
        let entry = UPSSummaryEntry(date: data?.lastRefresh ?? Date(), data: data)
        // Use .atEnd so WidgetKit re-requests the timeline once the entry's
        // date has aged out, instead of relying on a single hard-coded refresh.
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
}

struct UPSSummaryEntry: TimelineEntry {
    let date: Date
    let data: WidgetSharedData?
}

struct UPSSummaryWidgetView: View {
    let entry: UPSSummaryEntry

    var body: some View {
        if let data = entry.data, !data.devices.isEmpty {
            connectedView(data)
        } else {
            emptyView
        }
    }

    @ViewBuilder
    private func connectedView(_ data: WidgetSharedData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.blue.gradient)

                Text("UPS Monitor")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()
            }

            Spacer(minLength: 2)

            HStack(spacing: 4) {
                Circle()
                    .fill(data.onlineCount == data.totalCount ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)

                Text("\(data.onlineCount)/\(data.totalCount) Online")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 12) {
                if let battery = data.lowestBattery {
                    Label {
                        Text("\(Int(battery))%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    } icon: {
                        Image(systemName: batteryIcon(for: battery))
                            .font(.system(size: 10))
                            .foregroundStyle(batteryColor(for: battery))
                    }
                }

                if let load = data.highestLoad {
                    Label {
                        Text("\(Int(load))%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    } icon: {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(loadColor(for: load))
                    }
                }
            }
            .foregroundStyle(.secondary)

            if data.totalAlerts > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text("\(data.totalAlerts) Alert\(data.totalAlerts > 1 ? "s" : "")")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.red)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text("All Clear")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.green)
            }
        }
        .containerBackground(for: .widget) {
            Color(.windowBackgroundColor).opacity(0.5)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)

            Text("Open UPS Monitor")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .containerBackground(for: .widget) {
            Color(.windowBackgroundColor).opacity(0.5)
        }
    }

    private func batteryIcon(for charge: Double) -> String {
        switch charge {
        case 75...: return "battery.100"
        case 50..<75: return "battery.75"
        case 25..<50: return "battery.50"
        default: return "battery.25"
        }
    }

    private func batteryColor(for charge: Double) -> Color {
        switch charge {
        case 50...: return .green
        case 20..<50: return .orange
        default: return .red
        }
    }

    private func loadColor(for load: Double) -> Color {
        switch load {
        case 0..<60: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

struct UPSSummaryWidget: Widget {
    let kind = "UPSSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UPSSummaryProvider()) { entry in
            UPSSummaryWidgetView(entry: entry)
        }
        .configurationDisplayName("UPS Status")
        .description("Quick overview of your UPS fleet status.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    UPSSummaryWidget()
} timeline: {
    UPSSummaryEntry(date: Date(), data: WidgetSharedData(
        devices: [
            WidgetDeviceData(id: UUID(), name: "Server Room UPS", isOnline: true, batteryCharge: 98, load: 32, formattedRuntime: "45 min", temperature: 28, outputSource: "Normal", inputVoltage: 120, outputVoltage: 120, outputPower: 384, alarmsPresent: 0, isCharging: false, lastUpdate: Date()),
            WidgetDeviceData(id: UUID(), name: "Network Closet", isOnline: true, batteryCharge: 95, load: 28, formattedRuntime: "52 min", temperature: 26, outputSource: "Normal", inputVoltage: 121, outputVoltage: 120, outputPower: 280, alarmsPresent: 0, isCharging: false, lastUpdate: Date())
        ],
        lastRefresh: Date()
    ))
}
