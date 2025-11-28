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
        print("🔌 USB UPS device connected")
        
        guard let upsDevice = createUSBUPSDevice(from: device) else {
            print("❌ Failed to create USB UPS device")
            return
        }
        
        print("✅ Device info: \(upsDevice.name) by \(upsDevice.manufacturer)")
        print("   Serial: \(upsDevice.serialNumber)")
        print("   VID:PID: \(String(format: "%04X", upsDevice.vendorID)):\(String(format: "%04X", upsDevice.productID))")
        
        // Store the HID device reference
        registeredDevices[upsDevice.serialNumber] = device
        
        // Add to our list if not already present
        if !connectedUSBDevices.contains(where: { $0.serialNumber == upsDevice.serialNumber }) {
            connectedUSBDevices.append(upsDevice)
            
            // Create initial status with online flag set
            var status = UPSStatus(deviceId: UUID()) // We'll use serial as key instead
            status.manufacturer = upsDevice.manufacturer
            status.model = upsDevice.model
            status.upsName = upsDevice.name
            status.isOnline = true // Mark as online immediately since we just connected
            status.status = "Connected" // Set initial status
            status.lastUpdate = Date()
            usbStatusData[upsDevice.serialNumber] = status
            
            // Trigger initial update to get real data
            updateDeviceStatus(upsDevice, device: device)
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
        let serialNumber = getStringProperty(hidDevice, key: kIOHIDSerialNumberKey) ?? UUID().uuidString
        let vendorID = getIntProperty(hidDevice, key: kIOHIDVendorIDKey) ?? 0
        let productID = getIntProperty(hidDevice, key: kIOHIDProductIDKey) ?? 0
        
        return USBUPSDevice(
            name: product,
            manufacturer: manufacturer,
            model: product,
            serialNumber: serialNumber,
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
            return
        }
        
        print("📊 Updating status for \(upsDevice.name) (\(upsDevice.serialNumber))")
        
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
        if status.status == "Unknown" || status.status == "Connected" {
            if let outputSource = status.outputSource, outputSource == "Battery" {
                status.status = "On Battery"
            } else {
                status.status = "Online"
            }
        }
        
        if hidReadSuccessful {
            print("💾 Final status (from HID): \(status.status), Online: \(status.isOnline), Charge: \(status.batteryCharge ?? -1)%")
        } else {
            print("💾 Final status (will use Power Source API): \(status.status), Online: \(status.isOnline)")
        }
        
        usbStatusData[upsDevice.serialNumber] = status
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
            
            print("   Found UPS: \(name), Present: \(isPresent)")
            
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
            
            // Try to find matching device by name
            var matchedSerial: String?
            for device in connectedUSBDevices {
                if device.name == name || device.model == name {
                    matchedSerial = device.serialNumber
                    break
                }
            }
            
            // If we found a match, update its status
            if let serial = matchedSerial, var status = usbStatusData[serial] {
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
            } else {
                print("   ⚠️ Could not match UPS '\(name)' to any registered device")
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
