//
//  EnergyStatsView.swift
//  UPS Monitoring
//
//  Created by AI Assistant
//

import SwiftUI

struct EnergyStatsView: View {
    let device: UPSDevice
    let status: UPSStatus
    @ObservedObject var monitoringService: UPSMonitoringService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Power Usage", systemImage: "bolt.circle.fill")
                    .font(.headline)
                    .foregroundColor(.yellow)
                
                Spacer()
            }
            
            // Current Power
            if let currentPower = status.outputPower {
                HStack {
                    Text("Current Power:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(currentPower, specifier: "%.1f") W")
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            
            // Load Information
            if let load = status.load, let currentPower = status.outputPower {
                HStack {
                    Text("Load Percentage:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(load))%")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                // Estimated power consumption per hour
                HStack {
                    Text("Estimated per Hour:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(currentPower, specifier: "%.1f") Wh")
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                
                // Estimated power consumption per day
                HStack {
                    Text("Estimated per Day:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(currentPower * 24 / 1000, specifier: "%.2f") kWh")
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                
                // Estimated cost per day (assuming $0.12/kWh)
                let dailyCost = (currentPower * 24 / 1000) * 0.12
                HStack {
                    Text("Est. Daily Cost:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("$\(dailyCost, specifier: "%.2f")")
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            } else {
                Text("Power information not available from this UPS")
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            // Note about power monitoring
            VStack(alignment: .leading, spacing: 4) {
                Text("Note: Power calculations are estimates based on current load.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("For accurate energy tracking, consider using a smart power meter.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
}

struct EnergyStatsView_Previews: PreviewProvider {
    static var previews: some View {
        let device = UPSDevice(name: "Test UPS", host: "192.168.1.100", port: 161, connectionType: .snmp)
        var status = UPSStatus(deviceId: device.id)
        status.outputPower = 450.0
        status.load = 75.0
        
        return EnergyStatsView(
            device: device,
            status: status,
            monitoringService: UPSMonitoringService()
        )
        .padding()
    }
}