//
//  UPSMonitoringService.swift
//  UPS Monitoring
//
//  Created by Curtis Netterville on 9/17/25.
//

import Foundation
import Network
import SwiftSnmpKit
import Combine

@MainActor
class UPSMonitoringService: ObservableObject {
    @Published var devices: [UPSDevice] = []
    @Published var statusData: [UUID: UPSStatus] = [:]
    @Published var isMonitoring = false
    @Published var lastRefreshTime: Date? = nil
    @Published var isLoading = false
    
    private var monitoringTimer: Timer?
    private let updateInterval: TimeInterval = 30.0 // 30 seconds
    
    // SNMP OIDs for UPS monitoring (RFC 1628 - UPS MIB + CyberPower specific)
    private struct UPSOIDs {
        // Basic UPS Info
        static let upsIdentName = "1.3.6.1.2.1.33.1.1.5.0"
        static let upsIdentModel = "1.3.6.1.2.1.33.1.1.3.0"
        static let upsIdentManufacturer = "1.3.6.1.2.1.33.1.1.1.0"
        static let upsStatus = "1.3.6.1.2.1.33.1.4.1.0" // Fixed: was duplicate of manufacturer
        
        // Battery Info (CyberPower typically reports these accurately)
        static let batteryStatus = "1.3.6.1.2.1.33.1.2.1.0"
        static let batteryCharge = "1.3.6.1.2.1.33.1.2.4.0"
        static let batteryRuntime = "1.3.6.1.2.1.33.1.2.3.0"
        static let batteryRuntimeAlt1 = "1.3.6.1.2.1.33.1.2.3" // Without .0
        static let batteryRuntimeAlt2 = "1.3.6.1.4.1.3808.1.1.1.2.2.4.0" // CyberPower specific
        static let batteryRuntimeAlt3 = "1.3.6.1.4.1.3808.1.1.1.2.2.3.0" // CyberPower alternative
        static let batteryEstimatedTime = "1.3.6.1.2.1.33.1.2.3.1.3.1" // Estimated minutes remaining
        static let batteryVoltage = "1.3.6.1.2.1.33.1.2.5.0"
        static let batteryTemperature = "1.3.6.1.2.1.33.1.2.7.0"
        static let batteryLastReplaceDate = "1.3.6.1.2.1.33.1.2.11.0"  // Battery replace date
        static let batteryNextReplaceDate = "1.3.6.1.2.1.33.1.2.12.0" // Next replace date
        static let batteryCurrent = "1.3.6.1.2.1.33.1.2.6.0" // Battery current (for charging detection)
        
        // Input Info
        static let inputLineVoltage = "1.3.6.1.2.1.33.1.3.3.1.3.1"
        static let inputFrequency = "1.3.6.1.2.1.33.1.3.3.1.2.1"
        static let inputLineBads = "1.3.6.1.2.1.33.1.3.1.0"  // Power failures
        
        // Output Info
        static let outputSource = "1.3.6.1.2.1.33.1.4.1.0"
        static let outputVoltage = "1.3.6.1.2.1.33.1.4.4.1.2.1"
        static let outputFrequency = "1.3.6.1.2.1.33.1.4.2.0" // Fixed: was duplicate of voltage
        static let outputLoad = "1.3.6.1.2.1.33.1.4.4.1.5.1"
        static let outputPower = "1.3.6.1.2.1.33.1.4.4.1.4.1"
        
        // UPS Environment
        static let upsTemperature = "1.3.6.1.2.1.33.1.2.7.0"
        static let upsAlarmsPresent = "1.3.6.1.2.1.33.1.6.1.0"
        
        // CyberPower Specific (some models)
        static let upsEstimatedMinutesRemaining = "1.3.6.1.2.1.33.1.2.3.0"
        static let upsSecondsOnBattery = "1.3.6.1.2.1.33.1.1.2.0"
    }
    
    init() {
        loadDevices()
        // Don't trigger immediate refresh in init - let the UI handle it
    }
    
    func addDevice(_ device: UPSDevice) {
        devices.append(device)
        statusData[device.id] = UPSStatus(deviceId: device.id)
        saveDevices()
    }
    
    func removeDevice(_ device: UPSDevice) {
        devices.removeAll { $0.id == device.id }
        statusData.removeValue(forKey: device.id)
        saveDevices()
    }
    
    func updateDevice(_ device: UPSDevice) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
            saveDevices()
        }
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // Initial update
        Task {
            await updateAllDevices()
        }
        
        // Schedule periodic updates
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.updateAllDevices()
            }
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    func refreshAllDevices() async {
        // Don't refresh if already loading to prevent multiple concurrent refreshes
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Force an immediate update of all devices, regardless of monitoring state
        await updateAllDevices()
        lastRefreshTime = Date()
    }
    
    func triggerImmediateRefresh() {
        // Only refresh if we have devices and not already refreshing
        guard !devices.isEmpty && !isLoading else { return }
        
        Task {
            await refreshAllDevices()
        }
    }
    
    private func updateAllDevices() async {
        // Process devices in parallel but limit concurrency to avoid overwhelming the system
        await withTaskGroup(of: Void.self) { group in
            for device in devices where device.isEnabled {
                group.addTask {
                    await self.updateDeviceStatus(device)
                }
            }
        }
        lastRefreshTime = Date()
    }
    
    private func updateDeviceStatus(_ device: UPSDevice) async {
        do {
            let status: UPSStatus
            
            switch device.connectionType {
            case .nut:
                status = try await queryNUTDevice(device)
            case .snmp:
                status = try await querySNMPDevice(device)
            }
            
            statusData[device.id] = status
            
        } catch {
            var errorStatus = statusData[device.id] ?? UPSStatus(deviceId: device.id)
            errorStatus.isOnline = false
            errorStatus.status = "Error: \(error.localizedDescription)"
            errorStatus.lastUpdate = Date()
            statusData[device.id] = errorStatus
        }
    }
    
    private func queryNUTDevice(_ device: UPSDevice) async throws -> UPSStatus {
        return try await withCheckedThrowingContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(device.host),
                port: NWEndpoint.Port(integerLiteral: UInt16(device.port)),
                using: .tcp
            )
            
            // Use an actor to manage the state safely
            actor ResumeManager {
                private var hasResumed = false
                
                func resumeOnce(_ result: Result<UPSStatus, Error>, continuation: CheckedContinuation<UPSStatus, Error>) {
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(with: result)
                }
            }
            
            let resumeManager = ResumeManager()
            
            connection.start(queue: .global())
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("✅ NUT connection ready")
                    Task {
                        await self.sendNUTCommands(connection: connection, device: device) { result in
                            connection.cancel()
                            Task {
                                await resumeManager.resumeOnce(result, continuation: continuation)
                            }
                        }
                    }
                case .failed(let error):
                    print("❌ NUT connection failed: \(error)")
                    connection.cancel()
                    Task {
                        await resumeManager.resumeOnce(.failure(UPSError.networkError(error.localizedDescription)), continuation: continuation)
                    }
                case .cancelled:
                    print("🔄 NUT connection cancelled")
                    Task {
                        await resumeManager.resumeOnce(.failure(UPSError.connectionFailed), continuation: continuation)
                    }
                default:
                    print("🔄 NUT connection state: \(state)")
                    break
                }
            }
            
            // Reduce timeout to 10 seconds to prevent long hangs
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                print("⏰ NUT connection timeout")
                connection.cancel()
                Task {
                    await resumeManager.resumeOnce(.failure(UPSError.timeout), continuation: continuation)
                }
            }
        }
    }
    
    private func sendNUTCommands(connection: NWConnection, device: UPSDevice, completion: @escaping (Result<UPSStatus, Error>) -> Void) async {
        var status = UPSStatus(deviceId: device.id)
        status.lastUpdate = Date()
        
        let upsName = device.upsName ?? "ups"
        print("🔍 Testing NUT connection to \(device.host):\(device.port), UPS name: '\(upsName)'")
        
        // Use an actor to manage completion state
        actor CompletionManager {
            private var hasCompleted = false
            
            func completeOnce(_ result: Result<UPSStatus, Error>, completion: @escaping (Result<UPSStatus, Error>) -> Void) {
                guard !hasCompleted else { return }
                hasCompleted = true
                completion(result)
            }
        }
        
        let completionManager = CompletionManager()
        
        // First, try to list available UPS devices
        let listCommand = "LIST UPS\n"
        guard let listData = listCommand.data(using: .utf8) else {
            Task {
                await completionManager.completeOnce(.failure(UPSError.invalidResponse), completion: completion)
            }
            return
        }
        
        connection.send(content: listData, completion: .contentProcessed { error in
            if let error = error {
                Task {
                    await completionManager.completeOnce(.failure(UPSError.networkError(error.localizedDescription)), completion: completion)
                }
                return
            }
            
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                if let error = error {
                    Task {
                        await completionManager.completeOnce(.failure(UPSError.networkError(error.localizedDescription)), completion: completion)
                    }
                    return
                }
                
                guard let data = data, let response = String(data: data, encoding: .utf8) else {
                    Task {
                        await completionManager.completeOnce(.failure(UPSError.invalidResponse), completion: completion)
                    }
                    return
                }
                
                // Check if our UPS name is in the list or if we got any UPS at all
                let lines = response.components(separatedBy: .newlines)
                var foundUPS = false
                var availableUPS: [String] = []
                
                for line in lines {
                    if line.hasPrefix("UPS ") {
                        let components = line.components(separatedBy: " ")
                        if components.count >= 2 {
                            let upsNameInList = components[1]
                            availableUPS.append(upsNameInList)
                            if upsNameInList == upsName {
                                foundUPS = true
                            }
                        }
                    }
                }
                
                if !foundUPS && !availableUPS.isEmpty {
                    // Try using the first available UPS
                    if let firstUPS = availableUPS.first {
                        Task { @MainActor in
                            await self.getNUTVariables(connection: connection, device: device, upsName: firstUPS) { result in
                                Task {
                                    await completionManager.completeOnce(result, completion: completion)
                                }
                            }
                        }
                        return
                    }
                }
                
                if foundUPS || availableUPS.isEmpty {
                    // Use the specified UPS name or continue anyway if no UPS list returned
                    Task { @MainActor in
                        await self.getNUTVariables(connection: connection, device: device, upsName: upsName) { result in
                            Task {
                                await completionManager.completeOnce(result, completion: completion)
                            }
                        }
                    }
                } else {
                    Task {
                        await completionManager.completeOnce(.failure(UPSError.connectionFailed), completion: completion)
                    }
                }
            }
        })
        
        // Timeout reduced to 20 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 20) {
            Task {
                await completionManager.completeOnce(.failure(UPSError.timeout), completion: completion)
            }
        }
    }
    
    private func getNUTVariables(connection: NWConnection, device: UPSDevice, upsName: String, completion: @escaping (Result<UPSStatus, Error>) -> Void) async {
        var status = UPSStatus(deviceId: device.id)
        status.lastUpdate = Date()
        
        let responsesLock = NSLock()
        var responses: [String: String] = [:]
        
        // Use an actor to manage completion state
        actor CompletionManager {
            private var hasCompleted = false
            
            func completeOnce(_ result: Result<UPSStatus, Error>, completion: @escaping (Result<UPSStatus, Error>) -> Void) {
                guard !hasCompleted else { return }
                hasCompleted = true
                completion(result)
            }
        }
        
        let completionManager = CompletionManager()
        
        // Comprehensive list of NUT variables for CyberPower UPS devices
        let commands = [
            "LIST VAR \(upsName)",
            "GET VAR \(upsName) device.mfr",
            "GET VAR \(upsName) device.model", 
            "GET VAR \(upsName) ups.id",
            "GET VAR \(upsName) ups.status",
            "GET VAR \(upsName) battery.charge",
            "GET VAR \(upsName) battery.runtime",
            "GET VAR \(upsName) battery.voltage",
            "GET VAR \(upsName) battery.current", // For charging detection
            "GET VAR \(upsName) battery.charge.restart",
            "GET VAR \(upsName) input.voltage",
            "GET VAR \(upsName) output.voltage",
            "GET VAR \(upsName) ups.load"
        ]
        
        let commandIndexLock = NSLock()
        var commandIndex = 0
        
        nonisolated func sendNextCommand() {
            let currentIndex = commandIndexLock.withLock {
                let current = commandIndex
                commandIndex += 1
                return current
            }
            
            guard currentIndex < commands.count else {
                // Parse all responses
                let finalResponses = responsesLock.withLock { responses }
                
                status.isOnline = !finalResponses.isEmpty
                
                // Basic parsing
                if let manufacturer = finalResponses["device.mfr"] {
                    status.manufacturer = manufacturer
                }
                if let model = finalResponses["device.model"] {
                    status.model = model
                }
                if let chargeStr = finalResponses["battery.charge"], let charge = Double(chargeStr) {
                    status.batteryCharge = charge
                }
                
                // Additional NUT data parsing
                if let runtimeStr = finalResponses["battery.runtime"], let runtime = Double(runtimeStr) {
                    let runtimeMinutes = Int(runtime / 60) // Convert seconds to minutes
                    
                    // Always store the runtime, let the UI decide how to display it
                    status.batteryRuntime = runtimeMinutes
                    
                    // If runtime is very high, it usually means "unlimited" or charging
                    if runtimeMinutes > 10000 {
                        status.isCharging = true
                    }
                }
                
                if let voltageStr = finalResponses["battery.voltage"], let voltage = Double(voltageStr) {
                    status.batteryVoltage = voltage
                }
                
                // Check for charging indicators
                if let currentStr = finalResponses["battery.current"], let current = Double(currentStr) {
                    // Positive current typically indicates charging, negative indicates discharging
                    status.isCharging = current > 0
                }
                
                if let inputVoltageStr = finalResponses["input.voltage"], let inputVoltage = Double(inputVoltageStr) {
                    status.inputVoltage = inputVoltage
                }
                
                if let outputVoltageStr = finalResponses["output.voltage"], let outputVoltage = Double(outputVoltageStr) {
                    status.outputVoltage = outputVoltage
                }
                
                if let loadStr = finalResponses["ups.load"], let load = Double(loadStr) {
                    status.load = load
                }
                
                if let serialNumber = finalResponses["ups.serial"] {
                    // Store serial number in upsName field for display
                    if status.upsName == nil {
                        status.upsName = serialNumber
                    }
                }
                
                // Status parsing with charging detection
                if let upsStatus = finalResponses["ups.status"] {
                    let flags = upsStatus.uppercased().components(separatedBy: " ")
                    
                    // Check for charging indicators in status
                    if flags.contains("CHRG") || flags.contains("CHARGING") {
                        status.isCharging = true
                        status.batteryStatus = .batteryCharging
                    }
                    
                    if flags.contains("OB") {
                        status.status = flags.contains("LB") ? "On Battery (Low)" : "On Battery"
                        status.outputSource = "Battery"
                        status.isCharging = false // Can't be charging while on battery
                        status.batteryStatus = flags.contains("LB") ? .batteryLow : .batteryDischarging
                    } else if flags.contains("OL") {
                        status.status = "Online"
                        status.outputSource = "Normal"
                        
                        // If online and not explicitly discharging, likely charging or maintaining
                        if status.isCharging == nil {
                            // Check if battery is at full charge
                            if let charge = status.batteryCharge, charge >= 95 {
                                status.isCharging = false
                                status.batteryStatus = .batteryNormal
                            } else {
                                status.isCharging = true
                                status.batteryStatus = .batteryCharging
                            }
                        }
                    } else {
                        status.status = upsStatus
                        status.outputSource = "Unknown"
                    }
                } else {
                    // Default charging logic if no explicit status
                    if status.outputSource == "Normal" && status.isCharging == nil {
                        if let charge = status.batteryCharge, charge < 95 {
                            status.isCharging = true
                            status.batteryStatus = .batteryCharging
                        }
                    }
                }
                
                Task {
                    await completionManager.completeOnce(.success(status), completion: completion)
                }
                return
            }
            
            let command = commands[currentIndex] + "\n"
            guard let data = command.data(using: .utf8) else {
                sendNextCommand()
                return
            }
            
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    print("❌ Failed to send command: \(error)")
                    sendNextCommand()
                    return
                }
                
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                    if let error = error {
                        print("❌ Failed to receive response: \(error)")
                        sendNextCommand()
                        return
                    }
                    
                    if let data = data, let response = String(data: data, encoding: .utf8) {
                        responsesLock.withLock {
                            let lines = response.components(separatedBy: .newlines)
                            for line in lines {
                                if line.hasPrefix("VAR ") {
                                    let components = line.components(separatedBy: " ")
                                    if components.count >= 4 {
                                        let key = components[2]
                                        let value = components[3...].joined(separator: " ")
                                            .trimmingCharacters(in: .whitespacesAndNewlines)
                                            .replacingOccurrences(of: "\"", with: "")
                                        responses[key] = value
                                    }
                                }
                            }
                        }
                    }
                    
                    sendNextCommand()
                }
            })
        }
        
        sendNextCommand()
        
        // Timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + 30) {
            Task {
                await completionManager.completeOnce(.failure(UPSError.timeout), completion: completion)
            }
        }
    }
    
    private func querySNMPDevice(_ device: UPSDevice) async throws -> UPSStatus {
        let community = device.community ?? "public"
        
        guard let snmpSender = SnmpSender.shared else {
            throw UPSError.connectionFailed
        }
        
        var status = UPSStatus(deviceId: device.id)
        status.lastUpdate = Date()
        status.isOnline = false
        
        // Test basic connectivity first
        do {
            let result = await snmpSender.send(
                host: device.host,
                command: .getRequest,
                community: community,
                oid: "1.3.6.1.2.1.1.1.0" // System description OID
            )
            
            switch result {
            case .success(_):
                status.isOnline = true
                status.status = "Online"
                
                // Get UPS manufacturer with fallbacks
                await getSNMPValue(snmpSender, device.host, community, UPSOIDs.upsIdentManufacturer) { value in
                    status.manufacturer = value
                }
                
                // Fallback for CyberPower devices - they sometimes use different OIDs
                if status.manufacturer == nil {
                    await getSNMPValue(snmpSender, device.host, community, "1.3.6.1.2.1.1.1.0") { value in
                        // Extract manufacturer from system description
                        if let value = value {
                            if value.lowercased().contains("cyberpower") {
                                status.manufacturer = "CyberPower"
                            } else if value.lowercased().contains("apc") {
                                status.manufacturer = "APC"
                            } else if value.lowercased().contains("tripp") {
                                status.manufacturer = "Tripp Lite"
                            }
                        }
                    }
                }
                
                // Get UPS model with better parsing
                await getSNMPValue(snmpSender, device.host, community, UPSOIDs.upsIdentModel) { value in
                    status.model = value
                }
                
                // Get UPS name/identifier
                await getSNMPValue(snmpSender, device.host, community, UPSOIDs.upsIdentName) { value in
                    status.upsName = value
                }
                
                // Get battery charge with proper validation
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.batteryCharge) { value in
                    if value >= 0 && value <= 100 {
                        status.batteryCharge = Double(value)
                    }
                }
                
                // Get battery status (includes charging information)
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.batteryStatus) { value in
                    if let batteryStatus = BatteryStatus(rawValue: Int(value)) {
                        status.batteryStatus = batteryStatus
                        
                        // Determine charging status from battery status
                        switch batteryStatus {
                        case .batteryCharging:
                            status.isCharging = true
                        case .batteryDischarging:
                            status.isCharging = false
                        case .batteryNormal:
                            // If normal and on AC power, likely maintaining/trickle charging
                            status.isCharging = (status.outputSource != "Battery")
                        default:
                            break
                        }
                    }
                }
                
                // Get battery runtime - CyberPower returns minutes directly for this OID
                var runtimeFound = false
                
                // Try standard UPS-MIB OID first
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.batteryRuntime) { value in
                    if value > 0 {
                        // CyberPower UPS returns minutes directly for this OID
                        let runtimeMinutes = Int(value)
                        print("✅ SNMP Runtime (standard): \(value) minutes")
                        status.batteryRuntime = runtimeMinutes
                        runtimeFound = true
                    } else {
                        print("⚠️ SNMP Runtime (standard): returned \(value)")
                    }
                }
                
                // Try alternative OID if standard didn't work
                if !runtimeFound {
                    await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.batteryRuntimeAlt1) { value in
                        if value > 0 {
                            // Try as minutes first, then as seconds if value seems too high
                            let runtimeMinutes = value < 1000 ? Int(value) : Int(value) / 60
                            print("✅ SNMP Runtime (alt1): \(value) = \(runtimeMinutes) minutes")
                            status.batteryRuntime = runtimeMinutes
                            runtimeFound = true
                        } else {
                            print("⚠️ SNMP Runtime (alt1): returned \(value)")
                        }
                    }
                }
                
                // Try CyberPower specific OID
                if !runtimeFound {
                    await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.batteryRuntimeAlt2) { value in
                        if value > 0 {
                            let runtimeMinutes = value < 1000 ? Int(value) : Int(value) / 60
                            print("✅ SNMP Runtime (CyberPower 1): \(value) = \(runtimeMinutes) minutes")
                            status.batteryRuntime = runtimeMinutes
                            runtimeFound = true
                        } else {
                            print("⚠️ SNMP Runtime (CyberPower 1): returned \(value)")
                        }
                    }
                }
                
                // Try another CyberPower specific OID
                if !runtimeFound {
                    await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.batteryRuntimeAlt3) { value in
                        if value > 0 {
                            let runtimeMinutes = value < 1000 ? Int(value) : Int(value) / 60
                            print("✅ SNMP Runtime (CyberPower 2): \(value) = \(runtimeMinutes) minutes")
                            status.batteryRuntime = runtimeMinutes
                            runtimeFound = true
                        } else {
                            print("⚠️ SNMP Runtime (CyberPower 2): returned \(value)")
                        }
                    }
                }
                
                // Try estimated time remaining (likely already in minutes)
                if !runtimeFound {
                    await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.batteryEstimatedTime) { value in
                        if value > 0 {
                            print("✅ SNMP Runtime (estimated): \(value) minutes")
                            status.batteryRuntime = Int(value)
                            runtimeFound = true
                        } else {
                            print("⚠️ SNMP Runtime (estimated): returned \(value)")
                        }
                    }
                }
                
                if !runtimeFound {
                    print("❌ No valid SNMP runtime found from any OID")
                }
                
                // Get battery current (for charging detection)
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.batteryCurrent) { value in
                    if value != 0 {
                        // Current direction can indicate charging vs discharging
                        // Implementation varies by manufacturer, but typically:
                        // Positive = charging, Negative = discharging
                        let current = Double(value) / 10.0 // Often in tenths of amps
                        
                        if current > 0.1 {
                            status.isCharging = true
                        } else if current < -0.1 {
                            status.isCharging = false
                        }
                    }
                }
                
                // Get battery voltage with proper scaling
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.batteryVoltage) { value in
                    if value > 0 {
                        // CyberPower typically reports in centivolts (hundredths)
                        if value > 1000 {
                            status.batteryVoltage = Double(value) / 100.0
                        } else {
                            status.batteryVoltage = Double(value) / 10.0
                        }
                    }
                }
                
                // Get UPS status with proper parsing
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.upsStatus) { value in
                    status.status = self.parseUPSStatus(Int(value))
                    status.outputSource = self.parseOutputSource(Int(value))
                    
                    // Additional charging logic based on UPS status
                    if status.isCharging == nil {
                        switch Int(value) {
                        case 2: // Online
                            if let charge = status.batteryCharge, charge < 95 {
                                status.isCharging = true
                            } else {
                                status.isCharging = false // Maintenance mode
                            }
                        case 3: // On Battery
                            status.isCharging = false
                        default:
                            break
                        }
                    }
                }
                
                // Get input voltage with corrected scaling
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.inputLineVoltage) { value in
                    if value > 0 {
                        status.inputVoltage = self.parseVoltage(value, expectedRange: 100...300)
                    }
                }
                
                // Try alternative input voltage OID for CyberPower
                if status.inputVoltage == nil || (status.inputVoltage ?? 0) < 50 {
                    await getSNMPIntValue(snmpSender, device.host, community, "1.3.6.1.2.1.33.1.3.3.1.3.0") { value in
                        if value > 0 {
                            status.inputVoltage = self.parseVoltage(value, expectedRange: 100...300)
                        }
                    }
                }
                
                // Get output voltage with corrected scaling
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.outputVoltage) { value in
                    if value > 0 {
                        status.outputVoltage = self.parseVoltage(value, expectedRange: 100...300)
                    }
                }
                
                // Try alternative output voltage OID
                if status.outputVoltage == nil || (status.outputVoltage ?? 0) < 50 {
                    await getSNMPIntValue(snmpSender, device.host, community, "1.3.6.1.2.2.33.1.4.4.1.2.0") { value in
                        if value > 0 {
                            status.outputVoltage = self.parseVoltage(value, expectedRange: 100...300)
                        }
                    }
                }
                
                // Get input frequency
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.inputFrequency) { value in
                    if value > 0 {
                        // Frequency is usually reported in tenths of Hz
                        status.inputFrequency = Double(value) / 10.0
                    }
                }
                
                // Get output frequency
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.outputFrequency) { value in
                    if value > 0 {
                        status.outputFrequency = Double(value) / 10.0
                    }
                }
                
                // Get load percentage
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.outputLoad) { value in
                    if value >= 0 && value <= 100 {
                        status.load = Double(value)
                    }
                }
                
                // Get output power
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.outputPower) { value in
                    if value > 0 {
                        status.outputPower = Double(value)
                    }
                }
                
                // Get temperature
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.upsTemperature) { value in
                    if value > 0 {
                        status.temperature = Double(value)
                    }
                }
                
                // Get number of alarms
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.upsAlarmsPresent) { value in
                    status.alarmsPresent = Int(value)
                }
                
                // Get seconds on battery
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.upsSecondsOnBattery) { value in
                    if value > 0 {
                        status.secondsOnBattery = Int(value)
                    }
                }
                
                // Get power failures count
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.inputLineBads) { value in
                    status.powerFailures = Int(value)
                }
                
            case .failure(let error):
                print("❌ SNMP connection failed: \(error)")
                status.isOnline = false
                
                // Provide more specific error messages
                if error.localizedDescription.contains("Connection refused") {
                    status.status = "SNMP service not running or port blocked"
                } else if error.localizedDescription.contains("timeout") || error.localizedDescription.contains("Timeout") {
                    status.status = "SNMP timeout - check network connectivity"
                } else if error.localizedDescription.contains("No route to host") {
                    status.status = "Host unreachable"
                } else if error.localizedDescription.contains("Network is unreachable") {
                    status.status = "Network unreachable"
                } else {
                    status.status = "SNMP error: \(error.localizedDescription)"
                }
                
                throw UPSError.networkError(status.status)
            }
            
        } catch {
            print("❌ SNMP query error: \(error)")
            status.isOnline = false
            status.status = "Connection failed: \(error.localizedDescription)"
            throw error
        }
        
        return status
    }
    
    private func parseVoltage(_ rawValue: Int64, expectedRange: ClosedRange<Double>) -> Double {
        let value = Double(rawValue)
        
        // Try different scaling factors to get voltage in expected range
        let scalingFactors: [Double] = [1.0, 0.1, 0.01, 10.0]
        
        for factor in scalingFactors {
            let scaledValue = value * factor
            if expectedRange.contains(scaledValue) {
                return scaledValue
            }
        }
        
        // If no scaling factor works, return the value divided by 10 (most common case)
        return value / 10.0
    }
    
    
    private func parseUPSStatus(_ statusValue: Int) -> String {
        switch statusValue {
        case 1: return "Unknown"
        case 2: return "Online"
        case 3: return "On Battery"
        case 4: return "On Boost"
        case 5: return "Sleeping"
        case 6: return "On Fault"
        case 7: return "No Communications Established"
        case 8: return "Emergency Power Off"
        default: return "Status \(statusValue)"
        }
    }
    
    private func parseOutputSource(_ sourceValue: Int) -> String {
        switch sourceValue {
        case 1: return "Unknown"
        case 2: return "AC"
        case 3: return "Normal"
        case 4: return "Bypass"
        case 5: return "Battery"
        case 6: return "Booster"
        case 7: return "Reducer"
        default: return "Source \(sourceValue)"
        }
    }
    
    private func parseNUTStatus(_ statusString: String) -> String {
        let flags = statusString.uppercased().components(separatedBy: " ")
        if flags.contains("OB") {
            return "On Battery"
        }
        if flags.contains("OL") {
            return "Online"
        }
        return statusString
    }
    
    private func determineOutputSource(from statusString: String) -> String {
        let flags = statusString.uppercased().components(separatedBy: " ")
        if flags.contains("OB") {
            return "Battery"
        }
        if flags.contains("OL") {
            return "Normal"
        }
        return "Unknown"
    }

    private func loadDevices() {
        if let data = UserDefaults.standard.data(forKey: "UPSDevices"),
           let devices = try? JSONDecoder().decode([UPSDevice].self, from: data) {
            self.devices = devices
            
            for device in devices {
                statusData[device.id] = UPSStatus(deviceId: device.id)
            }
        }
    }
    
    private func saveDevices() {
        if let data = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(data, forKey: "UPSDevices")
        }
    }
    
    // MARK: - SNMP Helper Functions
    
    private func getSNMPValue(_ snmpSender: SnmpSender, _ host: String, _ community: String, _ oid: String, completion: @escaping (String?) -> Void) async {
        let result = await snmpSender.send(
            host: host,
            command: .getRequest,
            community: community,
            oid: oid
        )
        
        switch result {
        case .success(let binding):
            let stringValue = extractStringFromBinding(binding)
            completion(stringValue)
        case .failure:
            completion(nil)
        }
    }
    
    private func getSNMPIntValue(_ snmpSender: SnmpSender, _ host: String, _ community: String, _ oid: String, completion: @escaping (Int64) -> Void) async {
        let result = await snmpSender.send(
            host: host,
            command: .getRequest,
            community: community,
            oid: oid
        )
        
        switch result {
        case .success(let binding):
            let intValue = extractIntFromBinding(binding)
            print("🔍 SNMP OID \(oid): extracted value = \(intValue)")
            if intValue != 0 {
                completion(intValue)
            }
        case .failure(let error):
            print("❌ SNMP OID \(oid) failed: \(error)")
            break
        }
    }
    
    private func extractStringFromBinding(_ binding: Any) -> String? {
        let mirror = Mirror(reflecting: binding)
        
        for child in mirror.children {
            if child.label == "value" {
                let valueString = String(describing: child.value)
                
                // Handle OctetString format specifically
                if valueString.contains("OctetString:") {
                    let components = valueString.components(separatedBy: "OctetString:")
                    if components.count > 1 {
                        let extractedValue = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !extractedValue.isEmpty && extractedValue != "nil" {
                            return extractedValue
                        }
                    }
                }
                
                // Handle other ASN.1 string types
                if valueString.contains("String:") {
                    if let range = valueString.range(of: "String:", options: .backwards) {
                        let extractedValue = String(valueString[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !extractedValue.isEmpty && extractedValue != "nil" {
                            return extractedValue
                        }
                    }
                }
                
                // Try reflection approach
                let valueMirror = Mirror(reflecting: child.value)
                for valueChild in valueMirror.children {
                    if let stringValue = valueChild.value as? String, !stringValue.isEmpty {
                        return stringValue
                    }
                    
                    if let dataValue = valueChild.value as? Data {
                        if let stringValue = String(data: dataValue, encoding: .utf8), !stringValue.isEmpty {
                            return stringValue
                        }
                    }
                }
                
                // Fallback string parsing
                if !valueString.isEmpty && valueString != "nil" && !valueString.contains("endOfMibView") {
                    let cleanValue = valueString
                        .replacingOccurrences(of: "Optional(", with: "")
                        .replacingOccurrences(of: ")", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !cleanValue.isEmpty && cleanValue != "nil" {
                        return cleanValue
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractIntFromBinding(_ binding: Any) -> Int64 {
        let mirror = Mirror(reflecting: binding)
        
        for child in mirror.children {
            if child.label == "value" {
                let valueString = String(describing: child.value)
                print("🔍 SNMP binding value string: '\(valueString)'")
                
                // Handle Integer format
                if valueString.contains("Integer:") {
                    let components = valueString.components(separatedBy: "Integer:")
                    if components.count > 1 {
                        let intString = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if let intValue = Int64(intString) {
                            print("✅ Parsed Integer: \(intValue)")
                            return intValue
                        }
                    }
                }
                
                // Handle Counter format
                if valueString.contains("Counter:") {
                    let components = valueString.components(separatedBy: "Counter:")
                    if components.count > 1 {
                        let intString = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if let intValue = Int64(intString) {
                            print("✅ Parsed Counter: \(intValue)")
                            return intValue
                        }
                    }
                }
                
                // Handle Gauge format
                if valueString.contains("Gauge:") {
                    let components = valueString.components(separatedBy: "Gauge:")
                    if components.count > 1 {
                        let intString = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if let intValue = Int64(intString) {
                            print("✅ Parsed Gauge: \(intValue)")
                            return intValue
                        }
                    }
                }
                
                // Handle Gauge32 format (this was missing!)
                if valueString.contains("Gauge32:") {
                    let components = valueString.components(separatedBy: "Gauge32:")
                    if components.count > 1 {
                        let intString = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if let intValue = Int64(intString) {
                            print("✅ Parsed Gauge32: \(intValue)")
                            return intValue
                        }
                    }
                }
                
                // Handle TimeTicks format (common for runtime)
                if valueString.contains("TimeTicks:") {
                    let components = valueString.components(separatedBy: "TimeTicks:")
                    if components.count > 1 {
                        let intString = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        if let intValue = Int64(intString) {
                            print("✅ Parsed TimeTicks: \(intValue)")
                            return intValue
                        }
                    }
                }
                
                // Try reflection approach
                let valueMirror = Mirror(reflecting: child.value)
                for valueChild in valueMirror.children {
                    if let intValue = valueChild.value as? Int64 {
                        print("✅ Reflected Int64: \(intValue)")
                        return intValue
                    }
                    if let intValue = valueChild.value as? Int {
                        print("✅ Reflected Int: \(intValue)")
                        return Int64(intValue)
                    }
                    if let intValue = valueChild.value as? UInt64 {
                        print("✅ Reflected UInt64: \(intValue)")
                        return Int64(intValue)
                    }
                    if let intValue = valueChild.value as? UInt {
                        print("✅ Reflected UInt: \(intValue)")
                        return Int64(intValue)
                    }
                }
                
                // Try direct parsing
                if let intValue = Int64(valueString) {
                    print("✅ Direct parsed: \(intValue)")
                    return intValue
                }
                
                print("❌ Could not extract integer from: '\(valueString)'")
            }
        }
        
        return 0
    }
}