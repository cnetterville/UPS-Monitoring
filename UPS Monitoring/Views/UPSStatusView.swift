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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(device.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Simple status indicator for backward compatibility
                HStack(spacing: 6) {
                    Circle()
                        .fill((status?.isOnline ?? false) ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text((status?.isOnline ?? false) ? "Online" : "Offline")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor((status?.isOnline ?? false) ? .green : .red)
                }
            }
            
            if let status = status {
                VStack(alignment: .leading, spacing: 8) {
                    if status.isOnline {
                        // Battery Information
                        if let batteryCharge = status.batteryCharge, batteryCharge > 0 {
                            BatteryView(charge: batteryCharge)
                        }
                        
                        // Key Metrics Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            if let runtime = status.batteryRuntime {
                                MetricCard(title: "Runtime", value: "\(runtime) min", icon: "clock")
                            }
                            
                            if let load = status.load {
                                MetricCard(title: "Load", value: "\(Int(load))%", icon: "gauge")
                            }
                            
                            if let inputVoltage = status.inputVoltage {
                                MetricCard(title: "Input V", value: "\(Int(inputVoltage))V", icon: "bolt.fill")
                            }
                            
                            if let outputVoltage = status.outputVoltage {
                                MetricCard(title: "Output V", value: "\(Int(outputVoltage))V", icon: "poweroutlet.type.a")
                            }
                        }
                        
                        if let temperature = status.temperature {
                            MetricCard(title: "Temperature", value: "\(Int(temperature))°C", icon: "thermometer")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status: \(status.status)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Last update: \(status.lastUpdate.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("No data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(backgroundColorCompat)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var backgroundColorCompat: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(.windowBackgroundColor)
        #endif
    }
}

struct BatteryView: View {
    let charge: Double
    
    var batteryColor: Color {
        if charge > 50 { return .green }
        else if charge > 20 { return .orange }
        else { return .red }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "battery.100")
                    .foregroundColor(batteryColor)
                
                Text("Battery: \(Int(charge))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: charge, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: batteryColor))
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(backgroundGrayCompat)
        .cornerRadius(8)
    }
    
    private var backgroundGrayCompat: Color {
        #if os(iOS)
        return Color(.systemGray6)
        #else
        return Color(.controlBackgroundColor)
        #endif
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
        .padding()
}