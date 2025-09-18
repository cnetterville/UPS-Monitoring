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
    var batteryStatus: BatteryStatus? // Charging, discharging, etc.
    var isCharging: Bool? // Whether battery is currently charging
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
    
    // Computed property for formatted runtime
    var formattedRuntime: String? {
        guard let runtime = batteryRuntime else { 
            // If no runtime but we know we're charging and online, show unlimited
            if let isCharging = isCharging, isCharging && outputSource != "Battery" {
                return "∞"
            }
            return nil 
        }
        
        // Handle unlimited/very high runtime when charging
        if runtime > 600 || (runtime > 120 && isCharging == true && outputSource != "Battery") {
            return "∞"
        }
        
        if runtime < 60 {
            return "\(runtime) min"
        } else {
            let hours = runtime / 60
            let minutes = runtime % 60
            if minutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(minutes)m"
            }
        }
    }
    
    // Computed property for battery status description
    var batteryStatusDescription: String {
        if let isCharging = isCharging {
            if isCharging {
                return "Charging"
            } else if outputSource == "Battery" {
                return "Discharging"
            } else {
                return "Full/Maintenance"
            }
        } else if let batteryStatus = batteryStatus {
            return batteryStatus.description
        } else if outputSource == "Battery" {
            return "On Battery"
        } else {
            return "Unknown"
        }
    }
    
    init(deviceId: UUID) {
        self.deviceId = deviceId
        self.timestamp = Date()
        self.isOnline = false
        self.status = "Unknown"
        self.lastUpdate = Date()
    }
}

enum BatteryStatus: Int, CaseIterable, Codable, CustomStringConvertible {
    case unknown = 1
    case batteryNormal = 2
    case batteryLow = 3
    case batteryDepleted = 4
    case batteryDischarging = 5
    case batteryFailure = 6
    case batteryCharging = 7  // Added for charging detection
    
    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .batteryNormal: return "Normal"
        case .batteryLow: return "Low"
        case .batteryDepleted: return "Depleted"
        case .batteryDischarging: return "Discharging"
        case .batteryFailure: return "Failure"
        case .batteryCharging: return "Charging"
        }
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