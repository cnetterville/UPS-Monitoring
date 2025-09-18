//
//  DebugInfoView.swift
//  UPS Monitoring
//
//  Created by Curtis Netterville on 9/17/25.
//

import SwiftUI
import SwiftSnmpKit

struct DebugInfoView: View {
    let device: UPSDevice
    @State private var debugData: [String: String] = [:]
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Debug Info: \(device.name)")
                .font(.headline)
            
            Text("\(device.connectionType.rawValue) - \(device.host):\(device.port)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button("Query Raw \(device.connectionType.rawValue) Data") {
                queryRawData()
            }
            .disabled(isLoading)
            
            if isLoading {
                ProgressView("Querying...")
            }
            
            if !debugData.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(debugData.keys.sorted(), id: \.self) { key in
                            HStack {
                                Text(key)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .frame(width: 250, alignment: .leading)
                                
                                Text(debugData[key] ?? "")
                                    .font(.caption)
                                    .fontDesign(.monospaced)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .padding()
        .frame(width: 600, height: 500)
    }
    
    private func queryRawData() {
        isLoading = true
        debugData.removeAll()
        
        if device.connectionType == .snmp {
            queryRawSNMPData()
        } else {
            queryRawNUTData()
        }
    }
    
    private func queryRawSNMPData() {
        guard let snmpSender = SnmpSender.shared else { 
            debugData["Error"] = "SNMP sender not available"
            isLoading = false
            return 
        }
        
        let oidsToTest = [
            ("1.3.6.1.2.1.1.1.0", "sysDescr"),
            ("1.3.6.1.2.1.33.1.1.1.0", "upsStatus"),
            ("1.3.6.1.2.1.33.1.1.1.0", "manufacturer"),
            ("1.3.6.1.2.1.33.1.1.3.0", "model"),
            ("1.3.6.1.2.1.33.1.2.4.0", "batteryCharge"),
            ("1.3.6.1.2.1.33.1.2.3.0", "batteryRuntime"),
            ("1.3.6.1.2.1.33.1.2.5.0", "batteryVoltage (millivolts)"),
            ("1.3.6.1.2.1.33.1.2.11.0", "batteryLastReplaceDate - CHECK THIS"),
            ("1.3.6.1.2.1.33.1.2.12.0", "batteryNextReplaceDate - CHECK THIS"),
            ("1.3.6.1.2.1.33.1.3.3.1.3.1", "inputVoltage"),
            ("1.3.6.1.2.1.33.1.4.4.1.2.1", "outputVoltage"),
            ("1.3.6.1.2.1.33.1.4.4.1.5.1", "outputLoad"),
            ("1.3.6.1.2.1.33.1.2.7.0", "upsTemperature")
        ]
        
        Task {
            for (oid, name) in oidsToTest {
                let result = await snmpSender.send(
                    host: device.host,
                    command: .getRequest,
                    community: device.community ?? "public",
                    oid: oid
                )
                
                await MainActor.run {
                    switch result {
                    case .success(let binding):
                        debugData["\(name) (\(oid))"] = "\(binding.value)"
                        
                        // Special note for battery date fields
                        if name.contains("batteryLastReplaceDate") || name.contains("batteryNextReplaceDate") {
                            debugData["\(name) - RESULT"] = "✅ FOUND: \(binding.value)"
                        }
                    case .failure(let error):
                        debugData["\(name) (\(oid))"] = "ERROR: \(error)"
                        
                        // Special note for missing battery date fields
                        if name.contains("batteryLastReplaceDate") || name.contains("batteryNextReplaceDate") {
                            debugData["\(name) - RESULT"] = "❌ NOT SUPPORTED"
                        }
                    }
                }
            }
            
            await MainActor.run {
                debugData["BATTERY DATE CONCLUSION"] = "Most UPS devices don't provide battery date info via SNMP/NUT"
                isLoading = false
            }
        }
    }
    
    private func queryRawNUTData() {
        // For NUT, we'll simulate what we'd get - in a real implementation 
        // you'd connect via TCP and send the NUT commands
        debugData["Note"] = "NUT debug would require TCP connection simulation"
        debugData["Connection"] = "\(device.host):\(device.port)"
        debugData["UPS Name"] = device.upsName ?? "ups"
        debugData["Commands to test"] = "LIST VAR, GET VAR battery.charge, etc."
        
        isLoading = false
    }
}