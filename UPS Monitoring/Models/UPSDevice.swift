//
//  UPSDevice.swift
//  UPS Monitoring
//
//  Created by Curtis Netterville on 9/17/25.
//

import Foundation

struct UPSDevice: Identifiable, Codable {
    var id = UUID()
    var name: String
    var host: String
    var port: Int
    var connectionType: ConnectionType
    var username: String?
    var password: String?
    var community: String? // For SNMP
    var upsName: String? // For NUT
    var isEnabled: Bool = true
    
    // Manual battery tracking
    var batteryInstallDate: Date?
    var batteryModel: String?
    var batteryNotes: String?
    
    enum ConnectionType: String, CaseIterable, Codable {
        case nut = "NUT"
        case snmp = "SNMP"
    }
    
    // Computed property for battery age
    var batteryAgeInDays: Int? {
        guard let installDate = batteryInstallDate else { return nil }
        return Calendar.current.dateComponents([.day], from: installDate, to: Date()).day
    }
    
    // Initialize without battery info (for backward compatibility)
    init(name: String, host: String, port: Int, connectionType: ConnectionType, 
         username: String? = nil, password: String? = nil, 
         community: String? = nil, upsName: String? = nil,
         batteryInstallDate: Date? = nil, batteryModel: String? = nil, 
         batteryNotes: String? = nil) {
        self.name = name
        self.host = host
        self.port = port
        self.connectionType = connectionType
        self.username = username
        self.password = password
        self.community = community
        self.upsName = upsName
        self.batteryInstallDate = batteryInstallDate
        self.batteryModel = batteryModel
        self.batteryNotes = batteryNotes
    }
}

struct UPSStatus: Identifiable {
    let id = UUID()
    let deviceId: UUID
    let timestamp: Date
    var isOnline: Bool
    var batteryCharge: Double? // Percentage
    var batteryRuntime: Int? // Minutes
    var batteryVoltage: Double? // Volts
    var batteryTemperature: Double? // Celsius
    var inputVoltage: Double?
    var inputFrequency: Double? // Hz
    var outputVoltage: Double?
    var outputFrequency: Double? // Hz
    var outputPower: Double? // Watts
    var load: Double? // Percentage
    var temperature: Double?
    var status: String
    var lastUpdate: Date
    var manufacturer: String?
    var model: String?
    var upsName: String?
    var outputSource: String? // Normal, Battery, Bypass, etc.
    var powerFailures: Int? // Number of power failures detected
    var secondsOnBattery: Int? // Time on battery power
    var alarmsPresent: Int? // Number of active alarms
    
    init(deviceId: UUID) {
        self.deviceId = deviceId
        self.timestamp = Date()
        self.isOnline = false
        self.status = "Unknown"
        self.lastUpdate = Date()
    }
}

enum UPSError: Error, LocalizedError {
    case connectionFailed
    case authenticationFailed
    case invalidResponse
    case timeout
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to UPS"
        case .authenticationFailed:
            return "Authentication failed"
        case .invalidResponse:
            return "Invalid response from UPS"
        case .timeout:
            return "Connection timeout"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
