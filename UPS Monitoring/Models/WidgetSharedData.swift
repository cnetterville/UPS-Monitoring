//
//  WidgetSharedData.swift
//  UPS Monitoring
//
//  Shared data model between the main app and widget extension.
//

import Foundation

struct WidgetDeviceData: Codable, Identifiable {
    let id: UUID
    let name: String
    let isOnline: Bool
    let batteryCharge: Double?
    let load: Double?
    let formattedRuntime: String?
    let temperature: Double?
    let outputSource: String?
    let inputVoltage: Double?
    let outputVoltage: Double?
    let outputPower: Double?
    let alarmsPresent: Int?
    let isCharging: Bool?
    let lastUpdate: Date
}

struct WidgetSharedData: Codable {
    let devices: [WidgetDeviceData]
    let lastRefresh: Date

    var onlineCount: Int { devices.filter(\.isOnline).count }
    var totalCount: Int { devices.count }

    var lowestBattery: Double? {
        devices.compactMap(\.batteryCharge).min()
    }

    var highestLoad: Double? {
        devices.compactMap(\.load).max()
    }

    var totalAlerts: Int {
        devices.reduce(0) { sum, device in
            var alerts = device.alarmsPresent ?? 0
            if device.outputSource == "Battery" { alerts += 1 }
            if let charge = device.batteryCharge, charge < 20 { alerts += 1 }
            if !device.isOnline { alerts += 1 }
            return sum + alerts
        }
    }

    static let appGroupID = "group.netterville.com.ups.monitor"
    static let fileName = "widgetData.json"
    static let userDefaultsKey = "widgetData"

    private static var sharedFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static func load() -> WidgetSharedData? {
        if let url = sharedFileURL,
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(WidgetSharedData.self, from: data) {
            return decoded
        }
        if let defaults = UserDefaults(suiteName: appGroupID),
           let data = defaults.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(WidgetSharedData.self, from: data) {
            return decoded
        }
        return nil
    }

    func save() {
        guard let encoded = try? JSONEncoder().encode(self) else { return }
        if let url = Self.sharedFileURL {
            try? encoded.write(to: url, options: .atomic)
        }
        UserDefaults(suiteName: Self.appGroupID)?.set(encoded, forKey: Self.userDefaultsKey)
    }
}
