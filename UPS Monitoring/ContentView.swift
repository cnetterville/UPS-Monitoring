//
//  ContentView.swift
//  UPS Monitoring
//
//  Created by Curtis Netterville on 9/17/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var monitoringService = UPSMonitoringService()
    @State private var showingSettings = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 16) {
                Text("Devices")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                if monitoringService.devices.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "poweroutlet.type.a")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        
                        Text("No devices")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    List(monitoringService.devices) { device in
                        MacOSSidebarDeviceRow(
                            device: device,
                            status: monitoringService.statusData[device.id]
                        )
                    }
                    .listStyle(.sidebar)
                }
                
                Spacer()
                
                // Status footer
                VStack(spacing: 8) {
                    if monitoringService.isMonitoring {
                        HStack {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .symbolEffect(.variableColor.iterative)
                                .foregroundStyle(.green)
                            Text("Monitoring Active")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button("Settings") {
                        showingSettings = true
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .keyboardShortcut(",", modifiers: .command)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 350)
        } detail: {
            // Main detail view
            Group {
                if monitoringService.devices.isEmpty {
                    MacOSEmptyStateView {
                        showingSettings = true
                    }
                } else {
                    MacOSDeviceDetailView(
                        devices: monitoringService.devices,
                        statusData: monitoringService.statusData
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
        }
        .navigationTitle("UPS Monitoring")
        .sheet(isPresented: $showingSettings) {
            MacOSSettingsView(monitoringService: monitoringService)
        }
        .onAppear {
            // Set up menu bar manager with monitoring service
            MenuBarManager.shared.setMonitoringService(monitoringService)
            
            if !monitoringService.devices.isEmpty && !monitoringService.isMonitoring {
                monitoringService.startMonitoring()
            }
        }
        .onDisappear {
            // Don't stop monitoring when ContentView disappears since the app continues running in menu bar
            // monitoringService.stopMonitoring()
            
            // Notify menu bar manager that window is closing
            MenuBarManager.shared.windowDidClose()
        }
        .frame(minWidth: 900, minHeight: 650)
    }
}

struct MacOSSidebarDeviceRow: View {
    let device: UPSDevice
    let status: UPSStatus?
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(status?.isOnline == true ? .green : .red)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(device.connectionType.rawValue) • \(device.host)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
            
            if let batteryCharge = status?.batteryCharge {
                Text("\(Int(batteryCharge))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

struct MacOSEmptyStateView: View {
    let onAddDevice: () -> Void
    
    var body: some View {
        ContentUnavailableView {
            Label("No UPS Devices", systemImage: "poweroutlet.type.a")
        } description: {
            Text("Add UPS devices to monitor their status, battery levels, and power metrics in real time.")
        } actions: {
            Button("Add UPS Device", action: onAddDevice)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("n", modifiers: .command)
        }
    }
}

struct MacOSDeviceDetailView: View {
    let devices: [UPSDevice]
    let statusData: [UUID: UPSStatus]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20)
            ], spacing: 24) {
                ForEach(devices) { device in
                    MacOSDeviceCard(
                        device: device,
                        status: statusData[device.id]
                    )
                }
            }
            .padding(24)
        }
        .background(.background)
    }
}

struct MacOSDeviceCard: View {
    let device: UPSDevice
    let status: UPSStatus?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(device.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 8) {
                        Text(device.connectionType.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.tint.opacity(0.15), in: Capsule())
                            .foregroundStyle(.tint)
                        
                        Text(device.host)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                
                Spacer()
                
                MacOSStatusBadge(isOnline: status?.isOnline ?? false)
            }
            .padding(20)
            
            Divider()
            
            // Content
            if let status = status, status.isOnline {
                VStack(spacing: 20) {
                    // UPS Info section
                    if let manufacturer = status.manufacturer, let model = status.model {
                        VStack(spacing: 4) {
                            Text("\(manufacturer) \(model)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            
                            if let upsName = status.upsName {
                                Text(upsName)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    
                    // Battery section
                    if let batteryCharge = status.batteryCharge, batteryCharge > 0 {
                        MacOSBatteryView(
                            charge: batteryCharge,
                            runtime: status.batteryRuntime
                        )
                    }
                    
                    // Status alerts (if any issues)
                    statusAlertsView(for: status, device: device)
                    
                    // Metrics grid
                    let metrics = buildMetrics(from: status)
                    if !metrics.isEmpty {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(metrics, id: \.title) { metric in
                                MacOSMetricCard(metric: metric)
                            }
                        }
                    }
                    
                    // Statistics summary
                    statisticsSummary(for: status, device: device)
                    
                    // Last updated
                    HStack {
                        Text("Last updated")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        
                        Spacer()
                        
                        Text(status.lastUpdate, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(20)
            } else {
                // Offline state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                        .symbolEffect(.bounce, value: status?.isOnline)
                    
                    VStack(spacing: 6) {
                        Text(status?.status ?? "Offline")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text("Check device connection and network settings")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator.opacity(0.5), lineWidth: 0.5)
        )
    }
    
    private func buildMetrics(from status: UPSStatus) -> [MacOSMetric] {
        var metrics: [MacOSMetric] = []
        
        // Load percentage
        if let load = status.load {
            metrics.append(MacOSMetric(
                title: "Load",
                value: "\(Int(load))%",
                icon: "gauge.high",
                color: load > 80 ? .red : load > 60 ? .orange : .green
            ))
        }
        
        // Power output
        if let power = status.outputPower, power > 0 {
            metrics.append(MacOSMetric(
                title: "Power",
                value: "\(Int(power))W",
                icon: "bolt.circle.fill",
                color: .yellow
            ))
        }
        
        // Input voltage
        if let inputVoltage = status.inputVoltage, inputVoltage > 0 {
            let isNormal = inputVoltage >= 110 && inputVoltage <= 125 // Typical range
            metrics.append(MacOSMetric(
                title: "Input",
                value: "\(Int(inputVoltage))V",
                icon: "powerplug.fill",
                color: isNormal ? .green : .orange
            ))
        }
        
        // Output voltage
        if let outputVoltage = status.outputVoltage, outputVoltage > 0 {
            let isNormal = outputVoltage >= 110 && outputVoltage <= 125
            metrics.append(MacOSMetric(
                title: "Output",
                value: "\(Int(outputVoltage))V",
                icon: "poweroutlet.type.a.fill",
                color: isNormal ? .green : .orange
            ))
        }
        
        // Input frequency
        if let frequency = status.inputFrequency, frequency > 0 {
            let isNormal = frequency >= 59.0 && frequency <= 61.0 // 60Hz ±1
            metrics.append(MacOSMetric(
                title: "Frequency",
                value: String(format: "%.1fHz", frequency),
                icon: "waveform",
                color: isNormal ? .green : .orange
            ))
        }
        
        // Battery voltage
        if let batteryVoltage = status.batteryVoltage, batteryVoltage > 0 {
            metrics.append(MacOSMetric(
                title: "Batt Voltage",
                value: String(format: "%.1fV", batteryVoltage),
                icon: "battery.50",
                color: .blue
            ))
        }
        
        // Temperature
        if let temperature = status.temperature, temperature > 0 {
            let color: Color = temperature > 40 ? .red : temperature > 30 ? .orange : .green
            metrics.append(MacOSMetric(
                title: "Temperature",
                value: "\(Int(temperature))°C",
                icon: "thermometer.medium",
                color: color
            ))
        }
        
        // Output source
        if let outputSource = status.outputSource {
            let color: Color = outputSource == "Battery" ? .red : 
                              outputSource == "Bypass" ? .orange : .green
            metrics.append(MacOSMetric(
                title: "Source",
                value: outputSource,
                icon: outputSource == "Battery" ? "battery.25" : 
                      outputSource == "Bypass" ? "arrow.triangle.swap" : "powerplug.fill",
                color: color
            ))
        }
        
        return metrics
    }
}

struct MacOSStatusBadge: View {
    let isOnline: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isOnline ? .green : .red)
                .frame(width: 6, height: 6)
            
            Text(isOnline ? "Online" : "Offline")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isOnline ? .green : .red)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(.separator.opacity(0.3), lineWidth: 0.5)
        )
    }
}

struct MacOSBatteryView: View {
    let charge: Double
    let runtime: Int?
    
    private var batteryColor: Color {
        if charge > 50 { return .green }
        else if charge > 20 { return .orange }
        else { return .red }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Battery")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(charge))%")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(batteryColor)
                    .monospacedDigit()
            }
            
            ProgressView(value: charge, total: 100)
                .progressViewStyle(.linear)
                .tint(batteryColor)
                .background(.quaternary, in: Capsule())
            
            if let runtime = runtime, runtime > 0 {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("\(runtime) minutes remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct MacOSMetric {
    let title: String
    let value: String
    let icon: String
    let color: Color
}

struct MacOSMetricCard: View {
    let metric: MacOSMetric
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: metric.icon)
                .font(.title3)
                .foregroundStyle(metric.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                
                Text(metric.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.2), lineWidth: 0.5)
        )
    }
}

private func statusAlertsView(for status: UPSStatus, device: UPSDevice) -> some View {
    VStack(spacing: 8) {
        if let alarmsPresent = status.alarmsPresent, alarmsPresent > 0 {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("\(alarmsPresent) active alarm\(alarmsPresent == 1 ? "" : "s")")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        }
        
        if let outputSource = status.outputSource, outputSource == "Battery" {
            HStack {
                Image(systemName: "battery.25")
                    .foregroundStyle(.orange)
                Text("Running on battery power")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
                
                if let seconds = status.secondsOnBattery {
                    Text("(\(seconds)s)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        }
        
        // Battery age warning using device data
        if let batteryAge = device.batteryAgeInDays, batteryAge > 1095 { // 3+ years
            HStack {
                Image(systemName: "battery.0")
                    .foregroundStyle(.red)
                Text("Battery is \(batteryAge / 365) years old - consider replacement")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        } else if let batteryAge = device.batteryAgeInDays, batteryAge > 730 { // 2+ years
            HStack {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundStyle(.orange)
                Text("Battery is \(batteryAge / 365) years old - monitor closely")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

private func statisticsSummary(for status: UPSStatus, device: UPSDevice) -> some View {
    VStack(spacing: 8) {
        if let powerFailures = status.powerFailures, powerFailures > 0 {
            HStack {
                Text("Power failures detected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(powerFailures)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
        }
        
        // Battery age information
        if let batteryAgeInDays = device.batteryAgeInDays {
            HStack {
                Text("Battery age")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                BatteryAgeText(days: batteryAgeInDays)
            }
        }
        
        // Next replacement date (if battery model/notes exist)
        if let installDate = device.batteryInstallDate {
            let recommendedReplaceDate = Calendar.current.date(byAdding: .year, value: 3, to: installDate)
            
            if let replaceDate = recommendedReplaceDate {
                HStack {
                    Text("Recommended replacement")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(replaceDate, style: .date)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

struct BatteryAgeText: View {
    let days: Int
    
    private var ageInfo: (text: String, color: Color) {
        if days < 365 {
            return ("\(days) days", .green)
        } else if days < 1095 { // 3 years
            let years = days / 365
            let remainingDays = days % 365
            return ("\(years)y \(remainingDays)d", .orange)
        } else {
            let years = days / 365
            return ("\(years) years", .red)
        }
    }
    
    var body: some View {
        Text(ageInfo.text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(ageInfo.color)
            .monospacedDigit()
    }
}

#Preview {
    ContentView()
}