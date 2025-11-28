//
//  USBDeviceListView.swift
//  UPS Monitoring
//
//  Created on 11/27/25.
//

import SwiftUI

struct USBDeviceListView: View {
    @ObservedObject var usbMonitor: USBUPSMonitor
    @ObservedObject var monitoringService: UPSMonitoringService
    @Binding var hoveredCard: String?
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingAddUSBDevice = false
    @State private var selectedUSBDevice: USBUPSDevice?
    
    var body: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "usb-devices") {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("USB Connected UPS Devices")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Text("Directly connected via USB to this Mac")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // Connected count badge
                        Text("\(usbMonitor.connectedUSBDevices.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.green, Color.mint],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        
                        Text("USB")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Device list
                if usbMonitor.connectedUSBDevices.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "cable.connector")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(.secondary)
                        
                        Text("No USB UPS Devices Detected")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Connect a UPS via USB to this Mac for automatic detection")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 40)
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 12) {
                        ForEach(usbMonitor.connectedUSBDevices) { device in
                            USBDeviceRow(
                                device: device,
                                status: usbMonitor.usbStatusData[device.serialNumber],
                                hoveredCard: $hoveredCard,
                                isAlreadyMonitored: isDeviceAlreadyMonitored(device),
                                onAddToMonitoring: {
                                    selectedUSBDevice = device
                                    showingAddUSBDevice = true
                                }
                            )
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddUSBDevice) {
            if let device = selectedUSBDevice {
                AddUSBDeviceSheet(
                    usbDevice: device,
                    monitoringService: monitoringService,
                    isPresented: $showingAddUSBDevice
                )
            }
        }
    }
    
    private func isDeviceAlreadyMonitored(_ usbDevice: USBUPSDevice) -> Bool {
        return monitoringService.devices.contains { device in
            device.connectionType == .usb && device.upsName == usbDevice.serialNumber
        }
    }
}

// MARK: - USB Device Row

struct USBDeviceRow: View {
    let device: USBUPSDevice
    let status: UPSStatus?
    @Binding var hoveredCard: String?
    let isAlreadyMonitored: Bool
    let onAddToMonitoring: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var showingDetails = false
    
    private var cardId: String { "usb-device-\(device.id)" }
    
    var body: some View {
        HStack(spacing: 20) {
            // Status and info
            HStack(spacing: 16) {
                // USB icon with status
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.green.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    VStack(spacing: 2) {
                        Image(systemName: "cable.connector")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.green, Color.mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Status dot
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(device.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    HStack(spacing: 8) {
                        Text(device.manufacturer)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text("S/N: \(device.serialNumber.prefix(12))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Status info
            if let status = status {
                HStack(spacing: 20) {
                    // Battery charge
                    if let charge = status.batteryCharge {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(charge))%")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(chargeColor(charge))
                            
                            Text("Battery")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Runtime
                    if let runtime = status.formattedRuntime {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(runtime)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("Runtime")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Status badge
                    Text(status.status)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(statusColor(status.status))
                        )
                }
            }
            
            // Actions
            HStack(spacing: 8) {
                Button(action: { showingDetails.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .opacity(isHovered ? 1 : 0)
                        )
                }
                .buttonStyle(.plain)
                
                if isAlreadyMonitored {
                    Text("Monitoring")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.green.gradient)
                        )
                } else {
                    LiquidGlassButton(
                        "Add to Monitoring",
                        icon: "plus.circle.fill",
                        style: .secondary
                    ) {
                        onAddToMonitoring()
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.4 : 0.2),
                                    Color.green.opacity(isHovered ? 0.3 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
                hoveredCard = hovering ? cardId : nil
            }
        }
        .popover(isPresented: $showingDetails) {
            USBDeviceDetailsPopover(device: device, status: status)
        }
    }
    
    private func chargeColor(_ charge: Double) -> Color {
        if charge > 50 {
            return .green
        } else if charge > 20 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func statusColor(_ status: String) -> LinearGradient {
        switch status.lowercased() {
        case "online", "normal":
            return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        case "on battery":
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [.gray, .secondary], startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - USB Device Details Popover

struct USBDeviceDetailsPopover: View {
    let device: USBUPSDevice
    let status: UPSStatus?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("USB Device Details")
                .font(.system(size: 18, weight: .bold))
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(label: "Name", value: device.name)
                DetailRow(label: "Manufacturer", value: device.manufacturer)
                DetailRow(label: "Model", value: device.model)
                DetailRow(label: "Serial Number", value: device.serialNumber)
                DetailRow(label: "Vendor ID", value: String(format: "0x%04X", device.vendorID))
                DetailRow(label: "Product ID", value: String(format: "0x%04X", device.productID))
                
                if let status = status {
                    Divider()
                    
                    if let voltage = status.batteryVoltage {
                        DetailRow(label: "Battery Voltage", value: String(format: "%.1f V", voltage))
                    }
                    if let outputVoltage = status.outputVoltage {
                        DetailRow(label: "Output Voltage", value: String(format: "%.1f V", outputVoltage))
                    }
                    if let isCharging = status.isCharging {
                        DetailRow(label: "Charging", value: isCharging ? "Yes" : "No")
                    }
                    if let outputSource = status.outputSource {
                        DetailRow(label: "Power Source", value: outputSource)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Add USB Device Sheet

struct AddUSBDeviceSheet: View {
    let usbDevice: USBUPSDevice
    @ObservedObject var monitoringService: UPSMonitoringService
    @Binding var isPresented: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var deviceName: String
    @State private var showingSuccess = false
    
    init(usbDevice: USBUPSDevice, monitoringService: UPSMonitoringService, isPresented: Binding<Bool>) {
        self.usbDevice = usbDevice
        self.monitoringService = monitoringService
        self._isPresented = isPresented
        self._deviceName = State(initialValue: usbDevice.name)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - Fixed at top
            VStack(spacing: 8) {
                Image(systemName: "cable.connector")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Add USB UPS to Monitoring")
                    .font(.system(size: 24, weight: .bold))
                
                Text("This device is connected directly to your Mac")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
            
            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Device info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Device Information")
                            .font(.system(size: 16, weight: .semibold))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "Manufacturer", value: usbDevice.manufacturer)
                            InfoRow(label: "Model", value: usbDevice.model)
                            InfoRow(label: "Serial Number", value: usbDevice.serialNumber)
                            InfoRow(label: "Vendor ID", value: String(format: "0x%04X", usbDevice.vendorID))
                            InfoRow(label: "Product ID", value: String(format: "0x%04X", usbDevice.productID))
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Name")
                            .font(.system(size: 14, weight: .medium))
                        
                        TextField("Enter device name", text: $deviceName)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("This name will appear in your monitoring dashboard")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    // Info message
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("USB devices are monitored automatically while connected")
                                .font(.system(size: 12, weight: .medium))
                            Text("Data is read directly from the device via USB HID and macOS Power Source API")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            
            Divider()
            
            // Actions - Fixed at bottom
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Add to Monitoring") {
                    addUSBDeviceToMonitoring()
                }
                .buttonStyle(.borderedProminent)
                .disabled(deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 550, height: 500)
        .alert("Device Added", isPresented: $showingSuccess) {
            Button("OK") {
                isPresented = false
            }
        } message: {
            Text("The USB UPS device has been added to your monitoring dashboard.")
        }
    }
    
    private func addUSBDeviceToMonitoring() {
        // Create a proper USB device entry
        let newDevice = UPSDevice(
            name: deviceName.trimmingCharacters(in: .whitespacesAndNewlines),
            host: "", // Not used for USB devices
            port: 0,  // Not used for USB devices
            connectionType: .usb,
            username: nil,
            password: nil,
            community: nil,
            upsName: usbDevice.serialNumber // Use serial number to match with live USB data
        )
        
        monitoringService.addDevice(newDevice)
        showingSuccess = true
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}
