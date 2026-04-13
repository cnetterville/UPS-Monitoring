//
//  USBUPSMonitor.swift
//  UPS Monitoring
//
//  Created on 11/27/25.
//

import Foundation
import IOKit
import IOKit.hid
import IOKit.ps
import Combine

/// Monitors USB-connected UPS devices using IOKit HID and Power Source APIs
@MainActor
class USBUPSMonitor: ObservableObject {
    @Published var connectedUSBDevices: [USBUPSDevice] = []
    @Published var usbStatusData: [String: UPSStatus] = [:] // Keyed by serial number
    
    private var hidManager: IOHIDManager?
    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var monitoringTimer: Timer?
    private var registeredDevices: [String: IOHIDDevice] = [:] // serial -> device
    private var devicesWithExclusiveAccess: Set<String> = [] // Serials of devices we can't access via HID
    
    init() {
        setupHIDMonitoring()
        setupPowerSourceMonitoring()
    }
    
    nonisolated deinit {
        // Clean up synchronously - we can't call async methods in deinit
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        
        if let timer = monitoringTimer {
            timer.invalidate()
        }
    }
    
    // MARK: - HID Device Monitoring
    
    private func setupHIDMonitoring() {
        // Create HID Manager
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        
        hidManager = manager
        
        // Set up matching criteria for UPS devices (Power Device Usage Page)
        // Usage Page: 0x84 (Power Device), Usage: 0x04 (UPS)
        let matchingDict: [String: Any] = [
            kIOHIDDeviceUsagePageKey: 0x84,  // Power Device
            kIOHIDDeviceUsageKey: 0x04       // UPS
        ]
        
        IOHIDManagerSetDeviceMatching(manager, matchingDict as CFDictionary)
        
        // Register callbacks
        let matchingCallback: IOHIDDeviceCallback = { context, result, sender, device in
            guard let context = context else { return }
            let monitor = Unmanaged<USBUPSMonitor>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                monitor.deviceConnected(device)
            }
        }
        
        let removalCallback: IOHIDDeviceCallback = { context, result, sender, device in
            guard let context = context else { return }
            let monitor = Unmanaged<USBUPSMonitor>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                monitor.deviceDisconnected(device)
            }
        }
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        IOHIDManagerRegisterDeviceMatchingCallback(manager, matchingCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, removalCallback, context)
        
        // Schedule with run loop
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        
        // Open the manager
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult != kIOReturnSuccess {
            print("Failed to open HID Manager: \(openResult)")
        }
    }
    
    private func setupPowerSourceMonitoring() {
        // Monitor macOS power source changes
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        let callback: IOPowerSourceCallbackType = { context in
            guard let context = context else { return }
            let monitor = Unmanaged<USBUPSMonitor>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                monitor.powerSourceChanged()
            }
        }
        
        // Create run loop source for power source changes
        powerSourceRunLoopSource = IOPSNotificationCreateRunLoopSource(callback, context).takeRetainedValue()
        
        if let source = powerSourceRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
        
        // Initial scan
        scanPowerSources()
    }
    
    // MARK: - Device Connection Handling
    
    private func deviceConnected(_ device: IOHIDDevice) {
        print("🔌 USB UPS device connected via HID callback")
        
        guard let upsDevice = createUSBUPSDevice(from: device) else {
            print("❌ Failed to create USB UPS device")
            return
        }
        
        print("✅ Device info: \(upsDevice.name) by \(upsDevice.manufacturer)")
        print("   Serial: \(upsDevice.serialNumber)")
        print("   VID:PID: \(String(format: "%04X", upsDevice.vendorID)):\(String(format: "%04X", upsDevice.productID))")
        
        // Check if we already have a device with the same name but different serial
        // (This can happen if Power Source API created it first)
        if let existingDevice = connectedUSBDevices.first(where: { $0.name == upsDevice.name && $0.serialNumber != upsDevice.serialNumber }) {
            print("   ⚠️ Found existing device with same name but different serial:")
            print("      Existing serial: \(existingDevice.serialNumber)")
            print("      HID serial: \(upsDevice.serialNumber)")
            print("   ℹ️ Updating existing device to use HID serial")
            
            // Remove the old device
            connectedUSBDevices.removeAll { $0.serialNumber == existingDevice.serialNumber }
            
            // Migrate status data from old serial to new serial
            if let oldStatus = usbStatusData[existingDevice.serialNumber] {
                usbStatusData[upsDevice.serialNumber] = oldStatus
                usbStatusData.removeValue(forKey: existingDevice.serialNumber)
                print("   📦 Migrated status from '\(existingDevice.serialNumber)' to '\(upsDevice.serialNumber)'")
            }
        }
        
        // Also check for name-only matches (in case device was already added with this exact name)
        if connectedUSBDevices.first(where: { $0.name == upsDevice.name && $0.serialNumber == upsDevice.serialNumber }) != nil {
            print("   ℹ️ Device '\(upsDevice.name)' already in list with matching serial")
            // Device already exists, just update HID reference
            registeredDevices[upsDevice.serialNumber] = device
            
            // Make sure status exists and is marked online
            if var existingStatus = usbStatusData[upsDevice.serialNumber] {
                existingStatus.isOnline = true
                existingStatus.status = existingStatus.status == "Disconnected" ? "Online" : existingStatus.status
                existingStatus.lastUpdate = Date()
                usbStatusData[upsDevice.serialNumber] = existingStatus
            }
            return
        }
        
        // Store the HID device reference
        registeredDevices[upsDevice.serialNumber] = device
        
        // Add to our list if not already present
        if !connectedUSBDevices.contains(where: { $0.serialNumber == upsDevice.serialNumber }) {
            connectedUSBDevices.append(upsDevice)
            print("   📝 Added to connectedUSBDevices list")
            
            // Create initial status with online flag set
            var status = UPSStatus(deviceId: UUID()) // We'll use serial as key instead
            status.manufacturer = upsDevice.manufacturer
            status.model = upsDevice.model
            status.upsName = upsDevice.name
            status.isOnline = true // Mark as online immediately since we just connected
            status.status = "Online" // Set initial status to Online
            status.lastUpdate = Date()
            usbStatusData[upsDevice.serialNumber] = status
            print("   💾 Created initial status entry with key: \(upsDevice.serialNumber)")
            
            // Trigger initial update to get real data
            updateDeviceStatus(upsDevice, device: device)
            print("   🔄 Triggered initial status update")
        } else {
            print("   ℹ️ Device already in connectedUSBDevices list")
        }
    }
    
    private func deviceDisconnected(_ device: IOHIDDevice) {
        print("USB UPS device disconnected")
        
        // Find and mark device as offline (or remove it entirely)
        if let serial = getDeviceSerial(device) {
            // Option 1: Mark as offline but keep in list
            if var status = usbStatusData[serial] {
                status.isOnline = false
                status.status = "Disconnected"
                status.lastUpdate = Date()
                usbStatusData[serial] = status
            }
            
            // Option 2: Remove completely (current behavior)
            connectedUSBDevices.removeAll { $0.serialNumber == serial }
            usbStatusData.removeValue(forKey: serial)
            registeredDevices.removeValue(forKey: serial)
        }
    }
    
    // MARK: - Device Info Extraction
    
    private func createUSBUPSDevice(from hidDevice: IOHIDDevice) -> USBUPSDevice? {
        let manufacturer = getStringProperty(hidDevice, key: kIOHIDManufacturerKey) ?? "Unknown"
        let product = getStringProperty(hidDevice, key: kIOHIDProductKey) ?? "Unknown UPS"
        let vendorID = getIntProperty(hidDevice, key: kIOHIDVendorIDKey) ?? 0
        let productID = getIntProperty(hidDevice, key: kIOHIDProductIDKey) ?? 0
        
        // Try to get real serial number, but if it's empty or not available, use a stable identifier
        var serialNumber = getStringProperty(hidDevice, key: kIOHIDSerialNumberKey)
        
        // If serial is nil or empty, create a stable identifier from name + transport
        if serialNumber == nil || serialNumber?.isEmpty == true {
            // Use same format as Power Source API for consistency
            serialNumber = "\(product)_USB"
            print("   ℹ️ No HID serial available, using stable identifier: \(serialNumber!)")
        }
        
        return USBUPSDevice(
            name: product,
            manufacturer: manufacturer,
            model: product,
            serialNumber: serialNumber!,
            vendorID: vendorID,
            productID: productID
        )
    }
    
    private func getStringProperty(_ device: IOHIDDevice, key: String) -> String? {
        guard let property = IOHIDDeviceGetProperty(device, key as CFString) else {
            return nil
        }
        return property as? String
    }
    
    private func getIntProperty(_ device: IOHIDDevice, key: String) -> Int? {
        guard let property = IOHIDDeviceGetProperty(device, key as CFString) else {
            return nil
        }
        return property as? Int
    }
    
    private func getDeviceSerial(_ device: IOHIDDevice) -> String? {
        return getStringProperty(device, key: kIOHIDSerialNumberKey)
    }
    
    // MARK: - Status Updates
    
    func startMonitoring() {
        // Start periodic updates
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateAllDeviceStatuses()
            }
        }
        
        // Trigger immediate update
        updateAllDeviceStatuses()
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        
        if let source = powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
    }
    
    private func updateAllDeviceStatuses() {
        for upsDevice in connectedUSBDevices {
            if let hidDevice = registeredDevices[upsDevice.serialNumber] {
                updateDeviceStatus(upsDevice, device: hidDevice)
            }
        }
        
        // Also check power sources API
        scanPowerSources()
    }
    
    private func updateDeviceStatus(_ upsDevice: USBUPSDevice, device: IOHIDDevice) {
        guard var status = usbStatusData[upsDevice.serialNumber] else {
            print("⚠️ No status found for device: \(upsDevice.serialNumber)")
            print("   Available keys in usbStatusData: \(usbStatusData.keys.joined(separator: ", "))")
            return
        }
        
        print("📊 Updating status for \(upsDevice.name) (\(upsDevice.serialNumber))")
        print("   Current status: \(status.status), isOnline: \(status.isOnline)")
        
        status.lastUpdate = Date()
        status.isOnline = true
        
        // Skip HID reading if we know this device has exclusive access elsewhere
        if devicesWithExclusiveAccess.contains(upsDevice.serialNumber) {
            print("   ℹ️ Using Power Source API only (device has exclusive access)")
            usbStatusData[upsDevice.serialNumber] = status
            return
        }
        
        // Read HID elements for UPS data
        // Get all elements from the device
        guard let elements = IOHIDDeviceCopyMatchingElements(device, nil, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] else {
            print("   ⚠️ Could not get HID elements, falling back to Power Source API")
            usbStatusData[upsDevice.serialNumber] = status
            return
        }
        
        var hidReadSuccessful = false
        
        for element in elements {
            let usagePage = IOHIDElementGetUsagePage(element)
            let usage = IOHIDElementGetUsage(element)
            
            // Power Device Usage Page (0x84)
            if usagePage == 0x84 {
                var valueRef: Unmanaged<IOHIDValue>!
                let result = IOHIDDeviceGetValue(device, element, &valueRef)
                
                // Check for exclusive access error
                if result == kIOReturnExclusiveAccess {
                    if !devicesWithExclusiveAccess.contains(upsDevice.serialNumber) {
                        print("   ⚠️ Device has exclusive access (macOS system UPS daemon), using Power Source API instead")
                        devicesWithExclusiveAccess.insert(upsDevice.serialNumber)
                    }
                    break // Stop trying to read HID values
                }
                
                guard result == kIOReturnSuccess else {
                    continue
                }
                
                hidReadSuccessful = true
                let value = valueRef.takeUnretainedValue()
                let intValue = IOHIDValueGetIntegerValue(value)
                
                // Log significant values
                if [0x30, 0x35, 0x44, 0x45, 0x61, 0x65, 0xD0, 0xD1].contains(usage) {
                    print("   HID 0x84:\(String(format: "%02X", usage)) = \(intValue)")
                }
                
                // Map common UPS HID usages
                switch usage {
                case 0x30: // Voltage
                    status.batteryVoltage = Double(intValue) / 10.0
                case 0x35: // PercentRemaining
                    status.batteryCharge = Double(intValue)
                case 0x40: // ConfigVoltage (output)
                    status.outputVoltage = Double(intValue)
                case 0x42: // ConfigCurrent
                    break // Could track current
                case 0x44: // Charging
                    status.isCharging = intValue != 0
                case 0x45: // Discharging
                    if intValue != 0 {
                        status.isCharging = false
                        status.outputSource = "Battery"
                    }
                case 0x58: // ShutdownImminent
                    if intValue != 0 {
                        status.batteryStatus = .batteryLow
                    }
                case 0x61: // Good
                    if intValue != 0 {
                        status.status = "Online"
                    }
                case 0x65: // ACPresent
                    if intValue == 0 {
                        status.outputSource = "Battery"
                    } else {
                        status.outputSource = "Normal"
                    }
                case 0x66: // BatteryPresent
                    break // Battery is present
                case 0x68: // Overload
                    if intValue != 0 {
                        status.status = "Overload"
                    }
                case 0x69: // VoltageNotRegulated
                    break
                case 0xD0: // RemainingCapacity
                    status.batteryCharge = Double(intValue)
                case 0xD1: // RunTimeToEmpty
                    status.batteryRuntime = Int(intValue) / 60 // Convert seconds to minutes
                default:
                    break
                }
            }
            // Battery System Usage Page (0x85)
            else if usagePage == 0x85 {
                var valueRef: Unmanaged<IOHIDValue>!
                let result = IOHIDDeviceGetValue(device, element, &valueRef)
                
                // Check for exclusive access error
                if result == kIOReturnExclusiveAccess {
                    if !devicesWithExclusiveAccess.contains(upsDevice.serialNumber) {
                        print("   ⚠️ Device has exclusive access, using Power Source API instead")
                        devicesWithExclusiveAccess.insert(upsDevice.serialNumber)
                    }
                    break
                }
                
                guard result == kIOReturnSuccess else {
                    continue
                }
                
                hidReadSuccessful = true
                let value = valueRef.takeUnretainedValue()
                let intValue = IOHIDValueGetIntegerValue(value)
                
                switch usage {
                case 0x29: // RelativeStateOfCharge
                    status.batteryCharge = Double(intValue)
                case 0x66: // RemainingCapacity
                    status.batteryCharge = Double(intValue)
                case 0x68: // RunTimeToEmpty
                    status.batteryRuntime = Int(intValue) / 60
                default:
                    break
                }
            }
        }
        
        // Set default status if not set
        if status.status == "Unknown" || status.status == "Connected" || status.status == "Reading data..." {
            if let outputSource = status.outputSource, outputSource == "Battery" {
                status.status = "On Battery"
            } else {
                status.status = "Online"
            }
        }
        
        // Ensure isOnline is set correctly
        status.isOnline = true
        
        if hidReadSuccessful {
            print("💾 Final status (from HID): \(status.status), Online: \(status.isOnline), Charge: \(status.batteryCharge ?? -1)%")
        } else {
            print("💾 Final status (will use Power Source API): \(status.status), Online: \(status.isOnline)")
        }
        
        print("   Saving status to key: \(upsDevice.serialNumber)")
        usbStatusData[upsDevice.serialNumber] = status
        print("   ✅ Status saved. Dictionary now has \(usbStatusData.count) entries")
    }
    
    // MARK: - Helper Methods
    
    /// Find USB status by multiple matching strategies
    /// This is more resilient to name changes and serial mismatches
    func findUSBStatus(forDeviceWithSerial serial: String, name: String? = nil, model: String? = nil) -> UPSStatus? {
        // Strategy 1: Exact serial match (most reliable)
        if let status = usbStatusData[serial] {
            print("   ✅ Found USB status by exact serial match: \(serial)")
            return status
        }
        
        // Strategy 2: Try to find by matching connected device name/model
        if let name = name {
            if let connectedDevice = connectedUSBDevices.first(where: { 
                $0.serialNumber == serial || $0.name == name || $0.model == name 
            }) {
                if let status = usbStatusData[connectedDevice.serialNumber] {
                    print("   ✅ Found USB status by device name match: \(connectedDevice.serialNumber)")
                    return status
                }
            }
        }
        
        // Strategy 3: Try model-based match
        if let model = model {
            if let connectedDevice = connectedUSBDevices.first(where: { 
                $0.model == model && (name == nil || $0.name == name)
            }) {
                if let status = usbStatusData[connectedDevice.serialNumber] {
                    print("   ✅ Found USB status by model match: \(connectedDevice.serialNumber)")
                    return status
                }
            }
        }
        
        print("   ❌ No USB status found for serial: \(serial), name: \(name ?? "nil"), model: \(model ?? "nil")")
        return nil
    }
    
    // MARK: - Power Source API (Alternative/Supplemental)
    
    private func powerSourceChanged() {
        scanPowerSources()
    }
    
    private func scanPowerSources() {
        // Use IOKit Power Source API to get UPS info
        guard let powerSourcesInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let powerSourcesList = IOPSCopyPowerSourcesList(powerSourcesInfo)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }
        
        print("🔍 Scanning Power Sources API...")
        
        for source in powerSourcesList {
            guard let description = IOPSGetPowerSourceDescription(powerSourcesInfo, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            // Check if this is a UPS
            guard let type = description[kIOPSTypeKey] as? String,
                  type == kIOPSUPSType else {
                continue
            }
            
            // Try to match with our HID devices or create a new entry
            let name = description[kIOPSNameKey] as? String ?? "USB UPS"
            let isPresent = description[kIOPSIsPresentKey] as? Bool ?? false
            
            // Try to extract serial number (various possible keys)
            // Note: IOKit doesn't provide a standard serial number key for UPS devices via Power Source API
            // We'll have to rely on the Transport ID or hardware serial if available
            var serialNumber = description["Serial Number"] as? String
            if serialNumber == nil {
                serialNumber = description["Hardware Serial Number"] as? String
            }
            if serialNumber == nil {
                // Try using the transport ID as a fallback unique identifier
                if let transportID = description[kIOPSTransportTypeKey] as? String {
                    serialNumber = "\(name)_\(transportID)"
                }
            }
            if serialNumber == nil {
                // Last resort: use the name as the identifier
                serialNumber = name
            }
            
            // Debug: Print all available keys to help identify the serial number key
            print("   Found UPS: \(name), Present: \(isPresent)")
            print("   Available keys: \(description.keys.joined(separator: ", "))")
            print("   Serial: \(serialNumber ?? "nil")")
            
            guard isPresent else { continue }
            
            // Extract UPS info
            let capacity = description[kIOPSCurrentCapacityKey] as? Int
            let maxCapacity = description[kIOPSMaxCapacityKey] as? Int
            let timeToEmpty = description[kIOPSTimeToEmptyKey] as? Int
            let voltage = description[kIOPSVoltageKey] as? Int
            let isCharging = description[kIOPSIsChargingKey] as? Bool
            let powerSourceState = description[kIOPSPowerSourceStateKey] as? String
            
            // Calculate charge percentage
            var chargePercent: Double? = nil
            if let capacity = capacity, let maxCapacity = maxCapacity, maxCapacity > 0 {
                chargePercent = Double(capacity) / Double(maxCapacity) * 100.0
            }
            
            // Try to find matching device by serial number first, then by name
            var matchedSerial: String?
            
            // First, try to match by serial number if available
            if let serialNumber = serialNumber {
                // Check if we already have this device with this exact serial
                if let existingDevice = connectedUSBDevices.first(where: { $0.serialNumber == serialNumber }) {
                    matchedSerial = existingDevice.serialNumber
                    print("   ✅ Matched to existing device by serial: \(matchedSerial!)")
                } 
                // Try to match by name (in case HID callback created device with different serial)
                else if let existingDevice = connectedUSBDevices.first(where: { $0.name == name || $0.model == name }) {
                    matchedSerial = existingDevice.serialNumber
                    print("   ✅ Matched to existing device by name (serial mismatch)")
                    print("      Existing serial: \(existingDevice.serialNumber)")
                    print("      Power Source serial: \(serialNumber)")
                }
                // No existing device found, create a new one
                else {
                    let newDevice = USBUPSDevice(
                        name: name,
                        manufacturer: "Unknown",
                        model: name,
                        serialNumber: serialNumber,
                        vendorID: 0,
                        productID: 0
                    )
                    connectedUSBDevices.append(newDevice)
                    matchedSerial = serialNumber
                    print("   📝 Added UPS to connectedUSBDevices from Power Source API")
                }
            } else {
                // Fallback: Try to match by name
                for device in connectedUSBDevices {
                    if device.name == name || device.model == name {
                        matchedSerial = device.serialNumber
                        print("   ✅ Matched to existing device by name (no serial available)")
                        break
                    }
                }
            }
            
            // If we found or created a match, update/create its status
            if let serial = matchedSerial {
                var status = usbStatusData[serial] ?? UPSStatus(deviceId: UUID())
                
                // Mark as online and set basic info
                status.isOnline = true
                status.upsName = name
                status.manufacturer = status.manufacturer ?? "Unknown"
                status.model = status.model ?? name
                status.lastUpdate = Date()
                
                print("   📦 Updating device \(serial) from Power Source API")
                
                if let chargePercent = chargePercent {
                    status.batteryCharge = chargePercent
                    print("      Battery: \(Int(chargePercent))%")
                }
                if let timeToEmpty = timeToEmpty, timeToEmpty != Int(kIOPSTimeRemainingUnknown) {
                    status.batteryRuntime = timeToEmpty
                    print("      Runtime: \(timeToEmpty) min")
                }
                if let voltage = voltage {
                    status.batteryVoltage = Double(voltage) / 1000.0 // mV to V
                    print("      Voltage: \(Double(voltage) / 1000.0)V")
                }
                if let isCharging = isCharging {
                    status.isCharging = isCharging
                    print("      Charging: \(isCharging)")
                }
                if let powerSourceState = powerSourceState {
                    switch powerSourceState {
                    case kIOPSACPowerValue:
                        status.outputSource = "Normal"
                        status.status = "Online"
                        print("      State: AC Power (Online)")
                    case kIOPSBatteryPowerValue:
                        status.outputSource = "Battery"
                        status.status = "On Battery"
                        print("      State: Battery Power")
                    default:
                        status.status = powerSourceState
                        print("      State: \(powerSourceState)")
                    }
                }
                
                usbStatusData[serial] = status
                print("   ✅ Status saved for serial: \(serial)")
            } else {
                print("   ⚠️ Could not determine serial number for UPS '\(name)'")
            }
        }
    }
}

// MARK: - USB UPS Device Model

struct USBUPSDevice: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let manufacturer: String
    let model: String
    let serialNumber: String
    let vendorID: Int
    let productID: Int
    
    static func == (lhs: USBUPSDevice, rhs: USBUPSDevice) -> Bool {
        return lhs.serialNumber == rhs.serialNumber
    }
}
