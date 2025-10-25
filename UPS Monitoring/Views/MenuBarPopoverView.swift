//
//  MenuBarPopoverView.swift
//  UPS Monitoring
//
//  Created by Alex on 12/19/24.
//

import SwiftUI
import AppKit

struct MenuBarPopoverView: View {
    @ObservedObject var monitoringService: UPSMonitoringService
    @State private var hoveredCard: String? = nil
    let onShowApp: () -> Void
    let onQuit: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with overall status
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            Spacer(minLength: 8)
            
            // Content
            Group {
                if monitoringService.devices.isEmpty {
                    emptyStateSection
                } else if monitoringService.isLoading {
                    loadingSection
                } else {
                    devicesSection
                }
            }
            .padding(.horizontal, 16)
            
            Spacer(minLength: 8)
            
            // Footer with actions
            footerSection
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(width: 320, height: 450)
        .background(
            ZStack {
                // Subtle animated background
                LiquidGlassBackground()
                    .opacity(0.3)
                
                // Main background
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(0.95)
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 8)
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Title with status
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "battery.100")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("UPS Monitoring")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                overallStatusBadge
            }
            
            // Summary info
            if !monitoringService.devices.isEmpty {
                summaryInfo
            }
        }
    }
    
    private var overallStatusBadge: some View {
        let overallStatus = getOverallStatus()
        return GlassStatusBadge(
            overallStatus.text,
            status: overallStatus.badgeStatus
        )
    }
    
    private var summaryInfo: some View {
        HStack(spacing: 16) {
            // Online devices count
            VStack(spacing: 2) {
                Text("\(onlineDevicesCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                
                Text("Online")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            
            Rectangle()
                .fill(.separator.opacity(0.3))
                .frame(width: 1, height: 30)
            
            // Total devices count
            VStack(spacing: 2) {
                Text("\(enabledDevicesCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Total")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            
            Spacer()
            
            // Average battery level (if available)
            if let avgBattery = averageBatteryLevel {
                VStack(spacing: 2) {
                    Text("\(Int(avgBattery))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            avgBattery > 50 ? Color.green : 
                            avgBattery > 20 ? Color.orange : Color.red
                        )
                    
                    Text("Avg Battery")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(0.5)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "battery.100")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.cyan.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 6) {
                Text("No UPS Devices")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Add devices in settings to start monitoring")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            
            Text("Loading device status...")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
    
    private var devicesSection: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(monitoringService.devices.filter { $0.isEnabled }) { device in
                    MenuBarDeviceRow(
                        device: device,
                        status: monitoringService.statusData[device.id],
                        hoveredCard: $hoveredCard
                    )
                }
            }
        }
        .frame(maxHeight: 250)
    }
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            // Action buttons
            HStack(spacing: 12) {
                LiquidGlassButton(
                    "Show App",
                    icon: "app.dashed",
                    style: .primary
                ) {
                    onShowApp()
                }
                
                LiquidGlassButton(
                    "Quit",
                    icon: "xmark.circle",
                    style: .destructive
                ) {
                    onQuit()
                }
            }
            
            // Last update info
            if let lastRefresh = monitoringService.lastRefreshTime {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    
                    Text("Updated \(lastRefresh, style: .relative)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var onlineDevicesCount: Int {
        monitoringService.devices.filter { device in
            guard let status = monitoringService.statusData[device.id] else { return false }
            return device.isEnabled && status.isOnline
        }.count
    }
    
    private var enabledDevicesCount: Int {
        monitoringService.devices.filter { $0.isEnabled }.count
    }
    
    private var averageBatteryLevel: Double? {
        let onlineDevices = monitoringService.devices.compactMap { device -> Double? in
            guard device.isEnabled,
                  let status = monitoringService.statusData[device.id],
                  status.isOnline,
                  let batteryCharge = status.batteryCharge else { return nil }
            return batteryCharge
        }
        
        guard !onlineDevices.isEmpty else { return nil }
        return onlineDevices.reduce(0, +) / Double(onlineDevices.count)
    }
    
    private func getOverallStatus() -> (text: String, badgeStatus: GlassStatusBadge.BadgeStatus) {
        guard !monitoringService.devices.isEmpty else {
            return ("No Devices", .offline)
        }
        
        guard monitoringService.isMonitoring else {
            return ("Offline", .offline)
        }
        
        let enabledDevices = monitoringService.devices.filter { $0.isEnabled }
        guard !enabledDevices.isEmpty else {
            return ("No Devices", .offline)
        }
        
        var hasOnlineDevices = false
        var hasCriticalIssues = false
        var hasWarnings = false
        
        for device in enabledDevices {
            guard let status = monitoringService.statusData[device.id] else { continue }
            
            if status.isOnline {
                hasOnlineDevices = true
                
                // Check for critical issues
                if let charge = status.batteryCharge, charge < 20 {
                    hasCriticalIssues = true
                }
                if let outputSource = status.outputSource, outputSource == "Battery" {
                    hasCriticalIssues = true
                }
                if let alarms = status.alarmsPresent, alarms > 0 {
                    hasCriticalIssues = true
                }
                
                // Check for warnings
                if let charge = status.batteryCharge, charge < 50 && charge >= 20 {
                    hasWarnings = true
                }
                if let load = status.load, load > 80 {
                    hasWarnings = true
                }
            } else {
                hasWarnings = true // Offline device is a warning
            }
        }
        
        if !hasOnlineDevices {
            return ("All Offline", .offline)
        } else if hasCriticalIssues {
            return ("Critical", .error)
        } else if hasWarnings {
            return ("Warning", .warning)
        } else {
            return ("All Good", .success)
        }
    }
}

// MARK: - MenuBar Device Row Component

struct MenuBarDeviceRow: View {
    let device: UPSDevice
    let status: UPSStatus?
    @Binding var hoveredCard: String?
    @State private var isHovered = false
    
    private var cardId: String { "menubar-device-\(device.id)" }
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(
                                (status?.isOnline == true ? Color.green : Color.red).opacity(0.3),
                                lineWidth: 1
                            )
                    )
                
                Circle()
                    .fill(status?.isOnline == true ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                    .shadow(
                        color: (status?.isOnline == true ? Color.green : Color.red).opacity(0.6),
                        radius: 2
                    )
            }
            
            // Device info
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Text(device.host)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
            
            // Load and Runtime info (instead of just status)
            if let status = status, status.isOnline {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        // Load percentage
                        if let load = status.load {
                            Text("\(Int(load))%")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(
                                    load > 80 ? .red :
                                    load > 60 ? .orange : .green
                                )
                        } else {
                            Text("--")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("load")
                            .font(.system(size: 8, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        // Runtime
                        if let runtime = status.formattedRuntime {
                            Text(runtime)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.primary)
                        } else {
                            Text("--")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("runtime")
                            .font(.system(size: 8, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Offline")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.red)
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .opacity(isHovered ? 0.6 : 0.3)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovered in
            isHovered = hovered
            hoveredCard = hovered ? cardId : nil
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MenuBarPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        let mockService = UPSMonitoringService()
        
        MenuBarPopoverView(
            monitoringService: mockService,
            onShowApp: { print("Show app") },
            onQuit: { print("Quit") }
        )
        .preferredColorScheme(.dark)
    }
}
#endif