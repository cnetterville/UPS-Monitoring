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
        static let batteryVoltage = "1.3.6.1.2.1.33.1.2.5.0"
        static let batteryTemperature = "1.3.6.1.2.1.33.1.2.7.0"
        static let batteryLastReplaceDate = "1.3.6.1.2.1.33.1.2.11.0"  // Battery replace date
        static let batteryNextReplaceDate = "1.3.6.1.2.1.33.1.2.12.0" // Next replace date
        
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
    
    private func updateAllDevices() async {
        for device in devices where device.isEnabled {
            await updateDeviceStatus(device)
        }
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
            
            // Timeout after 15 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 15) {
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
                print("❌ Failed to send LIST UPS command: \(error)")
                Task {
                    await completionManager.completeOnce(.failure(UPSError.networkError(error.localizedDescription)), completion: completion)
                }
                return
            }
            
            print("✅ Sent LIST UPS command")
            
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                if let error = error {
                    print("❌ Failed to receive LIST UPS response: \(error)")
                    Task {
                        await completionManager.completeOnce(.failure(UPSError.networkError(error.localizedDescription)), completion: completion)
                    }
                    return
                }
                
                guard let data = data, let response = String(data: data, encoding: .utf8) else {
                    print("❌ Invalid LIST UPS response data")
                    Task {
                        await completionManager.completeOnce(.failure(UPSError.invalidResponse), completion: completion)
                    }
                    return
                }
                
                print("📋 NUT LIST UPS response: \(response)")
                
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
                                print("✅ Found UPS '\(upsName)' in server list")
                            }
                        }
                    }
                }
                
                if !foundUPS && !availableUPS.isEmpty {
                    print("⚠️ UPS '\(upsName)' not found in server list")
                    print("📋 Available UPS devices: \(availableUPS)")
                    // Try using the first available UPS
                    if let firstUPS = availableUPS.first {
                        print("🔄 Trying first available UPS: '\(firstUPS)'")
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
        
        // Add a timeout for this specific operation
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
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
                print("📊 Parsing NUT responses: \(finalResponses)")
                
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
                    status.batteryRuntime = Int(runtime / 60) // Convert seconds to minutes
                }
                
                if let voltageStr = finalResponses["battery.voltage"], let voltage = Double(voltageStr) {
                    status.batteryVoltage = voltage
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
                
                // Status parsing inline
                if let upsStatus = finalResponses["ups.status"] {
                    let flags = upsStatus.uppercased().components(separatedBy: " ")
                    if flags.contains("OB") {
                        status.status = flags.contains("LB") ? "On Battery (Low)" : "On Battery"
                        status.outputSource = "Battery"
                    } else if flags.contains("OL") {
                        status.status = "Online"
                        status.outputSource = "Normal"
                    } else {
                        status.status = upsStatus
                        status.outputSource = "Unknown"
                    }
                }
                
                print("✅ NUT query completed")
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
            print("❌ SNMP Sender not initialized")
            throw UPSError.connectionFailed
        }
        
        print("🔍 Querying SNMP device: \(device.host):\(device.port) with community '\(community)'")
        
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
            case .success(let binding):
                print("✅ SNMP connection successful: \(binding)")
                status.isOnline = true
                status.status = "Online"
                
                // Try to get UPS manufacturer
                await getSNMPValue(snmpSender, device.host, community, UPSOIDs.upsIdentManufacturer) { value in
                    status.manufacturer = value
                }
                
                // Try to get UPS model
                await getSNMPValue(snmpSender, device.host, community, UPSOIDs.upsIdentModel) { value in
                    status.model = value
                }
                
                // Try to get UPS name
                await getSNMPValue(snmpSender, device.host, community, UPSOIDs.upsIdentName) { value in
                    status.upsName = value
                }
                
                // Try to get battery charge
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.batteryCharge) { value in
                    status.batteryCharge = Double(value)
                }
                
                // Try to get battery runtime (convert from seconds to minutes)
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.batteryRuntime) { value in
                    status.batteryRuntime = Int(value) / 60
                }
                
                // Try to get UPS status
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.upsStatus) { value in
                    status.status = self.parseUPSStatus(Int(value))
                }
                
                // Try to get input voltage
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.inputLineVoltage) { value in
                    status.inputVoltage = self.determineVoltageScale(value, dataType: "input")
                }
                
                // Try to get output voltage
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.outputVoltage) { value in
                    status.outputVoltage = self.determineVoltageScale(value, dataType: "output")
                }
                
                // Try to get load percentage
                await getSNMPIntValue(snmpSender, device.host, community, UPSOIDs.outputLoad) { value in
                    status.load = Double(value)
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
    
    // Helper function to get SNMP string values safely
    private func getSNMPValue(_ sender: SnmpSender, _ host: String, _ community: String, _ oid: String, completion: @escaping (String) -> Void) async {
        let result = await sender.send(
            host: host,
            command: .getRequest,
            community: community,
            oid: oid
        )
        
        if case .success(let binding) = result {
            let stringValue = String(describing: binding)
            
            // Parse the SNMP response to extract just the value
            // Format is typically: "OID: Type: Value" or just "Value"
            if let range = stringValue.range(of: ": ") {
                let afterFirstColon = String(stringValue[range.upperBound...])
                if let secondRange = afterFirstColon.range(of: ": ") {
                    // Format: "OID: Type: Value"
                    let cleanValue = String(afterFirstColon[secondRange.upperBound...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanValue.isEmpty && cleanValue != "nil" {
                        completion(cleanValue)
                    }
                } else {
                    // Format: "OID: Value"
                    let cleanValue = afterFirstColon
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanValue.isEmpty && cleanValue != "nil" {
                        completion(cleanValue)
                    }
                }
            } else {
                // Just the value directly
                let cleanValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanValue.isEmpty && cleanValue != "nil" {
                    completion(cleanValue)
                }
            }
        }
    }
    
    // Helper function to get SNMP integer values safely
    private func getSNMPIntValue(_ sender: SnmpSender, _ host: String, _ community: String, _ oid: String, completion: @escaping (Int64) -> Void) async {
        let result = await sender.send(
            host: host,
            command: .getRequest,
            community: community,
            oid: oid
        )
        
        if case .success(let binding) = result {
            let stringValue = String(describing: binding)
            
            // Parse the SNMP response to extract just the numeric value
            // Format is typically: "OID: Type: Value" or just "Value"
            var numericString = ""
            
            if let range = stringValue.range(of: ": ") {
                let afterFirstColon = String(stringValue[range.upperBound...])
                if let secondRange = afterFirstColon.range(of: ": ") {
                    // Format: "OID: Type: Value"
                    numericString = String(afterFirstColon[secondRange.upperBound...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    // Format: "OID: Value"
                    numericString = afterFirstColon
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else {
                // Just the value directly
                numericString = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Extract only the numeric part (in case there are units or extra text)
            let cleanNumeric = numericString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            
            if let intValue = Int64(cleanNumeric), intValue > 0 {
                completion(intValue)
            }
        }
    }
    
    private func determineVoltageScale(_ rawValue: Int64, dataType: String) -> Double {
        let value = Double(rawValue)
        if dataType == "battery" {
            return value / 1000.0
        }
        return value / 10.0
    }
    
    private func parseUPSStatus(_ statusValue: Int) -> String {
        switch statusValue {
        case 2: return "Online"
        case 3: return "On Battery"
        default: return "Unknown"
        }
    }
    
    private func parseOutputSource(_ sourceValue: Int) -> String {
        switch sourceValue {
        case 3: return "Normal"
        case 5: return "Battery"
        default: return "Unknown"
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
}