//
//  ConnectivityTestView.swift
//  UPS Monitoring
//
//  Created by Curtis Netterville on 9/17/25.
//

import SwiftUI
import Network
import SwiftSnmpKit

struct ConnectivityTestView: View {
    let device: UPSDevice
    @State private var testResults: [String] = []
    @State private var isRunning = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connectivity Test: \(device.name)")
                .font(.headline)
            
            Text("Testing connection to \(device.host):\(device.port)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(testResults, id: \.self) { result in
                        Text(result)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundColor(result.hasPrefix("❌") ? Color.red : 
                                           result.hasPrefix("✅") ? Color.green : Color.primary)
                    }
                }
            }
            .frame(maxHeight: 300)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            
            HStack {
                Button("Run Test") {
                    runConnectivityTest()
                }
                .disabled(isRunning)
                
                Button("Clear") {
                    testResults.removeAll()
                }
                
                Spacer()
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func runConnectivityTest() {
        testResults.removeAll()
        isRunning = true
        
        addResult("🚀 Starting connectivity test...")
        addResult("📍 Target: \(device.connectionType.rawValue) - \(device.host):\(device.port)")
        
        Task {
            // Basic network connectivity test
            await testBasicConnectivity()
            
            // Protocol-specific tests
            if device.connectionType == .snmp {
                await testSNMP()
            } else {
                await testNUT()
            }
            
            await MainActor.run {
                addResult("🏁 Test completed")
                isRunning = false
            }
        }
    }
    
    private func testBasicConnectivity() async {
        await MainActor.run {
            addResult("🔍 Testing basic network connectivity...")
        }
        
        // Simple network test
        let host = device.host
        let port = device.port
        
        await MainActor.run {
            addResult("📡 Attempting to connect to \(host):\(port)...")
        }
        
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port)),
            using: .tcp
        )
        
        connection.start(queue: DispatchQueue.global())
        
        // Wait a moment for connection
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        await MainActor.run {
            switch connection.state {
            case .ready:
                addResult("✅ TCP connection successful")
            case .failed(let error):
                addResult("❌ TCP connection failed: \(error)")
            case .waiting(let error):
                addResult("⏳ Connection waiting: \(error)")
            default:
                addResult("❓ Connection state: \(connection.state)")
            }
        }
        
        connection.cancel()
    }
    
    private func testSNMP() async {
        await MainActor.run {
            addResult("🔍 Testing SNMP connectivity...")
        }
        
        guard let snmpSender = SnmpSender.shared else {
            await MainActor.run {
                addResult("❌ SNMP sender not available")
            }
            return
        }
        
        let community = device.community ?? "public"
        await MainActor.run {
            addResult("📝 Using community string: '\(community)'")
        }
        
        // Test with system OID
        let result = await snmpSender.send(
            host: device.host,
            command: .getRequest,
            community: community,
            oid: "1.3.6.1.2.1.1.1.0"
        )
        
        await MainActor.run {
            switch result {
            case .success(let binding):
                addResult("✅ SNMP response received")
                addResult("📄 System Description: \(binding)")
                addResult("💡 Device supports SNMP, trying UPS-specific OIDs...")
            case .failure(let error):
                addResult("❌ SNMP failed: \(error)")
                addResult("💡 Try different community string or check SNMP settings")
                
                // Suggest common alternatives
                addResult("🔧 Common community strings to try:")
                addResult("   • public (default)")
                addResult("   • private")
                addResult("   • admin")
                addResult("   • community")
            }
        }
        
        // Test UPS OID if SNMP worked
        if case .success = result {
            let upsResult = await snmpSender.send(
                host: device.host,
                command: .getRequest,
                community: community,
                oid: "1.3.6.1.2.1.33.1.1.1.0"
            )
            
            await MainActor.run {
                switch upsResult {
                case .success(let upsBinding):
                    addResult("✅ UPS SNMP data available")
                    addResult("📊 UPS Status: \(upsBinding)")
                case .failure(let error):
                    addResult("⚠️ UPS-specific SNMP failed: \(error)")
                    addResult("💡 Device responds to SNMP but may not support UPS MIB")
                }
            }
        }
    }
    
    private func testNUT() async {
        await MainActor.run {
            addResult("🔍 Testing NUT connectivity...")
        }
        
        let connection = NWConnection(
            host: NWEndpoint.Host(device.host),
            port: NWEndpoint.Port(integerLiteral: UInt16(device.port)),
            using: .tcp
        )
        
        connection.start(queue: DispatchQueue.global())
        
        // Wait for connection state
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        await MainActor.run {
            if connection.state == .ready {
                addResult("✅ TCP connection established")
            } else {
                addResult("❌ TCP connection failed: \(connection.state)")
                addResult("💡 Check if NUT server is running on \(device.host):\(device.port)")
                addResult("🔧 Try these commands on the server:")
                addResult("   • sudo systemctl status nut-server")
                addResult("   • sudo netstat -tlnp | grep :3493")
            }
        }
        
        if connection.state == .ready {
            // Test NUT commands
            await testNUTCommands(connection: connection)
        }
        
        connection.cancel()
    }
    
    private func testNUTCommands(connection: NWConnection) async {
        // Send LIST UPS command
        let command = "LIST UPS\n"
        let data = command.data(using: .utf8)!
        
        await MainActor.run {
            addResult("📤 Sending: LIST UPS")
        }
        
        await withCheckedContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                Task { @MainActor in
                    if let error = error {
                        self.addResult("❌ Failed to send NUT command: \(error)")
                        continuation.resume()
                    } else {
                        self.addResult("✅ NUT command sent")
                        
                        connection.receive(minimumIncompleteLength: 1, maximumLength: 2048) { data, _, _, error in
                            Task { @MainActor in
                                if let error = error {
                                    self.addResult("❌ NUT response error: \(error)")
                                } else if let data = data, let response = String(data: data, encoding: .utf8) {
                                    self.addResult("📥 NUT response:")
                                    let lines = response.components(separatedBy: .newlines)
                                    for line in lines.prefix(10) {
                                        if !line.isEmpty {
                                            self.addResult("   \(line)")
                                        }
                                    }
                                    
                                    if response.contains("UPS") {
                                        self.addResult("✅ Found UPS devices!")
                                    } else {
                                        self.addResult("⚠️ No UPS devices found")
                                    }
                                }
                                continuation.resume()
                            }
                        }
                    }
                }
            })
        }
    }
    
    @MainActor
    private func addResult(_ message: String) {
        testResults.append(message)
    }
}

#Preview {
    ConnectivityTestView(device: UPSDevice(
        name: "Test UPS",
        host: "192.168.1.100",
        port: 161,
        connectionType: .snmp
    ))
}