//
//  UPSStatusView.swift
//  UPS Monitoring
//
//  Created by Curtis Netterville on 9/17/25.
//

import SwiftUI

struct UPSStatusView: View {
    let device: UPSDevice
    let status: UPSStatus?
    @State private var hoveredCard: String? = nil
    
    var body: some View {
        ZStack {
            // Subtle liquid glass background
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.blue.opacity(0.05), location: 0.0),
                    .init(color: Color.purple.opacity(0.03), location: 0.5),
                    .init(color: Color.cyan.opacity(0.04), location: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "ups-status-main") {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with glass effect
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.primary, Color.blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("\(device.connectionType.rawValue) • \(device.host)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        GlassStatusBadge(
                            (status?.isOnline ?? false) ? "Online" : "Offline",
                            status: (status?.isOnline ?? false) ? .online : .offline
                        )
                    }
                    
                    if let status = status {
                        if status.isOnline {
                            VStack(alignment: .leading, spacing: 16) {
                                // Battery Information with enhanced glass effect
                                if let batteryCharge = status.batteryCharge, batteryCharge > 0 {
                                    LiquidGlassBatteryStatusView(
                                        charge: batteryCharge,
                                        runtime: status.batteryRuntime,
                                        status: status,
                                        hoveredCard: $hoveredCard
                                    )
                                }
                                
                                // Key Metrics Grid with glass cards
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 12) {
                                    if let runtime = status.batteryRuntime {
                                        LiquidGlassMetricCard(
                                            title: "Runtime",
                                            value: "\(runtime) min",
                                            icon: "clock.fill",
                                            color: runtime < 15 ? Color.red : runtime < 30 ? Color.orange : Color.green
                                        )
                                    }
                                    
                                    if let load = status.load {
                                        LiquidGlassMetricCard(
                                            title: "Load",
                                            value: "\(Int(load))%",
                                            icon: "gauge.high",
                                            color: load > 80 ? Color.red : load > 60 ? Color.orange : Color.green
                                        )
                                    }
                                    
                                    if let inputVoltage = status.inputVoltage {
                                        let isNormal = inputVoltage >= 110 && inputVoltage <= 130
                                        LiquidGlassMetricCard(
                                            title: "Input V",
                                            value: "\(Int(inputVoltage))V",
                                            icon: "powerplug.fill",
                                            color: isNormal ? Color.green : Color.orange
                                        )
                                    }
                                    
                                    if let outputVoltage = status.outputVoltage {
                                        let isNormal = outputVoltage >= 110 && outputVoltage <= 130
                                        LiquidGlassMetricCard(
                                            title: "Output V",
                                            value: "\(Int(outputVoltage))V",
                                            icon: "poweroutlet.type.a.fill",
                                            color: isNormal ? Color.green : Color.orange
                                        )
                                    }
                                }
                                
                                // Additional metrics if available
                                if let temperature = status.temperature, temperature > 0 {
                                    LiquidGlassMetricCard(
                                        title: "Temperature",
                                        value: "\(Int(temperature))°C",
                                        icon: "thermometer.medium",
                                        color: temperature > 40 ? Color.red : temperature > 30 ? Color.orange : Color.green
                                    )
                                }
                                
                                // Status alerts
                                statusAlertsSection(for: status)
                                
                                // Last updated
                                HStack {
                                    Text("Last updated")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.tertiary)
                                        .textCase(.uppercase)
                                        .tracking(0.5)
                                    
                                    Spacer()
                                    
                                    Text(status.lastUpdate.formatted(date: .omitted, time: .shortened))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            // Offline state with glass styling
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    Color.red.opacity(0.3),
                                                    Color.red.opacity(0.1),
                                                    Color.clear
                                                ],
                                                center: .center,
                                                startRadius: 10,
                                                endRadius: 40
                                            )
                                        )
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.title)
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.orange, Color.red],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .symbolEffect(.bounce, value: status.isOnline)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Status: \(status.status)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("Last update: \(status.lastUpdate.formatted(date: .omitted, time: .shortened))")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }
                    } else {
                        // No data state with glass effect
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color.gray.opacity(0.3),
                                                Color.gray.opacity(0.1),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 10,
                                            endRadius: 30
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "questionmark.circle")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("No data available")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private func statusAlertsSection(for status: UPSStatus) -> some View {
        VStack(spacing: 8) {
            if let alarmsPresent = status.alarmsPresent, alarmsPresent > 0 {
                GlassStatusBadge(
                    "\(alarmsPresent) active alarm\(alarmsPresent == 1 ? "" : "s")",
                    status: .error
                )
            }
            
            if let outputSource = status.outputSource, outputSource == "Battery" {
                GlassStatusBadge(
                    "Running on battery power",
                    status: .warning
                )
            }
        }
    }
}

// MARK: - Liquid Glass Battery Status View

struct LiquidGlassBatteryStatusView: View {
    let charge: Double
    let runtime: Int?
    let status: UPSStatus?
    @Binding var hoveredCard: String?
    @State private var animatedCharge: Double = 0
    @State private var isHovered = false
    
    private var batteryColor: Color {
        if charge > 50 { return .green }
        else if charge > 20 { return .orange }
        else { return .red }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        batteryColor.opacity(0.3),
                                        batteryColor.opacity(0.1)
                                    ],
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 18
                                )
                            )
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "battery.100")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(batteryColor)
                    }
                    
                    Text("Battery: \(Int(animatedCharge))%")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                }
                
                Spacer()
                
                if let runtime = runtime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text("\(runtime) min")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
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
            
            // Enhanced Glass Progress Bar
            GlassProgressBar(value: animatedCharge, total: 100, color: batteryColor)
                .frame(height: 8)
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(isHovered ? 0.7 : 0.5)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                batteryColor.opacity(isHovered ? 0.1 : 0.05),
                                batteryColor.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                batteryColor.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .shadow(
            color: batteryColor.opacity(isHovered ? 0.15 : 0.08),
            radius: isHovered ? 8 : 4,
            x: 0,
            y: isHovered ? 4 : 2
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.easeInOut(duration: 0.8), value: animatedCharge)
        .onAppear {
            animatedCharge = charge
        }
        .onChange(of: charge) { oldValue, newValue in
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedCharge = newValue
            }
        }
        .onHover { hovered in
            isHovered = hovered
            hoveredCard = hovered ? "battery-status" : nil
        }
    }
}

#Preview {
    let sampleDevice = UPSDevice(
        name: "Main UPS",
        host: "192.168.1.100",
        port: 3493,
        connectionType: .nut
    )
    
    var sampleStatus = UPSStatus(deviceId: sampleDevice.id)
    sampleStatus.isOnline = true
    sampleStatus.batteryCharge = 85
    sampleStatus.batteryRuntime = 45
    sampleStatus.inputVoltage = 120
    sampleStatus.outputVoltage = 120
    sampleStatus.load = 35
    sampleStatus.temperature = 25
    sampleStatus.status = "Online"
    
    return UPSStatusView(device: sampleDevice, status: sampleStatus)
        .frame(width: 400, height: 500)
        .padding()
}