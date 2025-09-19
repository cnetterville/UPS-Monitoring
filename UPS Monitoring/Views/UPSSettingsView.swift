//
//  UPSSettingsView.swift
//  UPS Monitoring
//
//  Created by Curtis Netterville on 9/17/25.
//

import SwiftUI
import Network
import SwiftSnmpKit

struct MacOSSettingsView: View {
    @ObservedObject var monitoringService: UPSMonitoringService
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddDevice = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            .background(.regularMaterial)
            
            Divider()
            
            // Content
            Form {
                Section {
                    ForEach(monitoringService.devices) { device in
                        MacOSDeviceSettingsRow(device: device, monitoringService: monitoringService)
                    }
                    .onDelete(perform: deleteDevices)
                    
                    if monitoringService.devices.count < 2 {
                        Button(action: { showingAddDevice = true }) {
                            Label("Add UPS Device", systemImage: "plus")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.blue)
                    }
                } header: {
                    HStack {
                        Text("UPS Devices")
                        Spacer()
                        Text("\(monitoringService.devices.count) of 2")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    if monitoringService.devices.count >= 2 {
                        Text("Maximum of 2 devices supported.")
                            .foregroundStyle(.secondary)
                    }
                }
                
                if !monitoringService.devices.isEmpty {
                    Section {
                        Toggle("Automatic Monitoring", isOn: Binding(
                            get: { monitoringService.isMonitoring },
                            set: { newValue in
                                if newValue {
                                    monitoringService.startMonitoring()
                                } else {
                                    monitoringService.stopMonitoring()
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                    } header: {
                        Text("Monitoring")
                    } footer: {
                        Text("Automatically monitors all devices every 30 seconds when enabled.")
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(.background)
        }
        .frame(width: 550, height: 600)
        .sheet(isPresented: $showingAddDevice) {
            MacOSAddDeviceView(monitoringService: monitoringService)
        }
    }
    
    private func deleteDevices(offsets: IndexSet) {
        for offset in offsets {
            let device = monitoringService.devices[offset]
            monitoringService.removeDevice(device)
        }
    }
}

struct MacOSDeviceSettingsRow: View {
    let device: UPSDevice
    let monitoringService: UPSMonitoringService
    @State private var showingEditDevice = false
    @State private var showingConnectivityTest = false
    @State private var showingDebugInfo = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(device.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(device.connectionType.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: Capsule())
                        .foregroundStyle(.tint)
                    
                    Text(device.host)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    
                    Text(":\(device.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if device.connectionType == .snmp {
                    Button("Debug") {
                        showingDebugInfo = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button("Test") {
                    showingConnectivityTest = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Edit") {
                    showingEditDevice = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .sheet(isPresented: $showingEditDevice) {
            MacOSEditDeviceView(device: device, monitoringService: monitoringService)
        }
        .sheet(isPresented: $showingConnectivityTest) {
            MacOSConnectivityTestView(device: device)
        }
        .sheet(isPresented: $showingDebugInfo) {
            DebugInfoView(device: device)
        }
    }
}

struct MacOSAddDeviceView: View {
    @ObservedObject var monitoringService: UPSMonitoringService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var host = ""
    @State private var port = 3493
    @State private var connectionType: UPSDevice.ConnectionType = .nut
    @State private var username = ""
    @State private var password = ""
    @State private var community = "public"
    @State private var upsName = "ups"
    @State private var batteryInstallDate: Date?
    @State private var batteryModel = ""
    @State private var batteryNotes = ""
    
    private var isFormValid: Bool {
        !name.isEmpty && !host.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            formView
        }
        .frame(width: 500, height: 550)
    }
    
    private var headerView: some View {
        HStack {
            Text("Add UPS Device")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Add Device") {
                    saveDevice()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
            }
        }
        .padding(20)
        .background(.regularMaterial)
    }
    
    private var formView: some View {
        Form {
            deviceInfoSection
            
            if connectionType == .nut {
                nutConfigSection
            } else {
                snmpConfigSection
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(.background)
    }
    
    private var deviceInfoSection: some View {
        Section("Device Information") {
            LabeledContent("Device Name") {
                TextField("Enter a name for this UPS", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            LabeledContent("Host/IP Address") {
                TextField("192.168.1.100", text: $host)
                    .textFieldStyle(.roundedBorder)
            }
            
            LabeledContent("Connection Type") {
                connectionTypePicker
            }
        }
    }
    
    private var connectionTypePicker: some View {
        Picker("Connection Type", selection: $connectionType) {
            ForEach(UPSDevice.ConnectionType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: connectionType) { oldValue, newValue in
            // Automatically set the correct default port when type changes
            port = newValue == .nut ? 3493 : 161
        }
    }
    
    private var nutConfigSection: some View {
        Section {
            LabeledContent("UPS Name") {
                TextField("ups", text: $upsName)
                    .textFieldStyle(.roundedBorder)
            }
            
            LabeledContent("Username") {
                TextField("Optional", text: $username)
                    .textFieldStyle(.roundedBorder)
            }
            
            LabeledContent("Password") {
                SecureField("Optional", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
        } header: {
            Text("NUT Configuration")
        } footer: {
            Text("Network UPS Tools (NUT) configuration for communicating with UPS servers.")
        }
    }
    
    private var snmpConfigSection: some View {
        Section {
            LabeledContent("Community String") {
                TextField("public", text: $community)
                    .textFieldStyle(.roundedBorder)
            }
        } header: {
            Text("SNMP Configuration")
        } footer: {
            Text("SNMP v1 configuration. Most UPS devices use 'public' as the default community string.")
        }
    }
    
    private func saveDevice() {
        let device = UPSDevice(
            name: name,
            host: host,
            port: port,
            connectionType: connectionType,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            community: connectionType == .snmp ? community : nil,
            upsName: connectionType == .nut ? upsName : nil,
            batteryInstallDate: batteryInstallDate,
            batteryModel: batteryModel.isEmpty ? nil : batteryModel,
            batteryNotes: batteryNotes.isEmpty ? nil : batteryNotes
        )
        
        monitoringService.addDevice(device)
    }
}

struct MacOSEditDeviceView: View {
    let device: UPSDevice
    @ObservedObject var monitoringService: UPSMonitoringService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var host: String
    @State private var port: Int
    @State private var connectionType: UPSDevice.ConnectionType
    @State private var username: String
    @State private var password: String
    @State private var community: String
    @State private var upsName: String
    @State private var batteryInstallDate: Date?
    @State private var batteryModel: String
    @State private var batteryNotes: String
    
    init(device: UPSDevice, monitoringService: UPSMonitoringService) {
        self.device = device
        self.monitoringService = monitoringService
        
        _name = State(initialValue: device.name)
        _host = State(initialValue: device.host)
        _port = State(initialValue: device.port)
        _connectionType = State(initialValue: device.connectionType)
        _username = State(initialValue: device.username ?? "")
        _password = State(initialValue: device.password ?? "")
        _community = State(initialValue: device.community ?? "public")
        _upsName = State(initialValue: device.upsName ?? "ups")
        _batteryInstallDate = State(initialValue: device.batteryInstallDate)
        _batteryModel = State(initialValue: device.batteryModel ?? "")
        _batteryNotes = State(initialValue: device.batteryNotes ?? "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit UPS Device")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button("Save Changes") {
                        updateDevice()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || host.isEmpty)
                }
            }
            .padding(20)
            .background(.regularMaterial)
            
            Divider()
            
            // Form content
            Form {
                Section("Device Information") {
                    LabeledContent("Device Name") {
                        TextField("Enter a name for this UPS", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    LabeledContent("Host/IP Address") {
                        TextField("192.168.1.100", text: $host)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    LabeledContent("Connection Type") {
                        Picker("Connection Type", selection: $connectionType) {
                            ForEach(UPSDevice.ConnectionType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: connectionType) { oldValue, newValue in
                            // Automatically set the correct default port when type changes
                            port = newValue == .nut ? 3493 : 161
                        }
                    }
                    
                    LabeledContent("Port") {
                        TextField("Port", value: $port, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 100)
                    }
                }
                
                if connectionType == .nut {
                    Section {
                        LabeledContent("UPS Name") {
                            TextField("ups", text: $upsName)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        LabeledContent("Username") {
                            TextField("Optional", text: $username)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        LabeledContent("Password") {
                            SecureField("Optional", text: $password)
                                .textFieldStyle(.roundedBorder)
                        }
                    } header: {
                        Text("NUT Configuration")
                    }
                } else {
                    Section {
                        LabeledContent("Community String") {
                            TextField("public", text: $community)
                                .textFieldStyle(.roundedBorder)
                        }
                    } header: {
                        Text("SNMP Configuration")
                    }
                }
                
                // Battery tracking section
                Section {
                    LabeledContent("Install Date") {
                        DatePicker("Battery Install Date", 
                                 selection: Binding(
                                    get: { batteryInstallDate ?? Date() },
                                    set: { batteryInstallDate = $0 }
                                 ),
                                 displayedComponents: .date)
                        .labelsHidden()
                    }
                    
                    LabeledContent("Battery Model") {
                        TextField("Optional", text: $batteryModel)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    LabeledContent("Notes") {
                        TextField("Optional notes", text: $batteryNotes)
                            .textFieldStyle(.roundedBorder)
                    }
                } header: {
                    Text("Battery Tracking")
                } footer: {
                    Text("Manual tracking for battery replacement planning.")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(.background)
        }
        .frame(width: 500, height: 550)
    }
    
    private func updateDevice() {
        var updatedDevice = device
        updatedDevice.name = name
        updatedDevice.host = host
        updatedDevice.port = port
        updatedDevice.connectionType = connectionType
        updatedDevice.username = username.isEmpty ? nil : username
        updatedDevice.password = password.isEmpty ? nil : password
        updatedDevice.community = connectionType == .snmp ? community : nil
        updatedDevice.upsName = connectionType == .nut ? upsName : nil
        updatedDevice.batteryInstallDate = batteryInstallDate
        updatedDevice.batteryModel = batteryModel.isEmpty ? nil : batteryModel
        updatedDevice.batteryNotes = batteryNotes.isEmpty ? nil : batteryNotes
        
        monitoringService.updateDevice(updatedDevice)
    }
}

struct MacOSConnectivityTestView: View {
    let device: UPSDevice
    @State private var testResults: [String] = []
    @State private var isRunning = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Connectivity Test")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(20)
            .background(.regularMaterial)
            
            Divider()
            
            // Content
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Testing: \(device.name)")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text("\(device.connectionType.rawValue) connection to \(device.host):\(device.port)")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(testResults, id: \.self) { result in
                            Text(result)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(
                                    result.hasPrefix("❌") ? .red :
                                    result.hasPrefix("✅") ? .green :
                                    result.hasPrefix("⚠️") ? .orange : .primary
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.separator.opacity(0.3), lineWidth: 0.5)
                )
                
                HStack {
                    Button("Run Test") {
                        runConnectivityTest()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)
                    
                    Button("Clear Results") {
                        testResults.removeAll()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.8)
                            .controlSize(.small)
                    }
                }
            }
            .padding(20)
            .background(.background)
        }
        .frame(width: 600, height: 500)
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
        
        let connection = NWConnection(
            host: NWEndpoint.Host(device.host),
            port: NWEndpoint.Port(integerLiteral: UInt16(device.port)),
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
            case .failure(let error):
                addResult("❌ SNMP failed: \(error)")
                addResult("💡 Try different community strings: public, private, admin")
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
                testNUTCommands(connection: connection)
            } else {
                addResult("❌ TCP connection failed: \(connection.state)")
                addResult("💡 Check if NUT server is running")
            }
        }
        
        connection.cancel()
    }
    
    private func testNUTCommands(connection: NWConnection) {
        let command = "LIST UPS\n"
        let data = command.data(using: .utf8)!
        
        addResult("📤 Sending: LIST UPS")
        
        connection.send(content: data, completion: .contentProcessed { error in
            Task { @MainActor in
                if let error = error {
                    self.addResult("❌ Failed to send NUT command: \(error)")
                } else {
                    self.addResult("✅ NUT command sent")
                    
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 2048) { data, _, _, error in
                        Task { @MainActor in
                            if let error = error {
                                self.addResult("❌ NUT response error: \(error)")
                            } else if let data = data, let response = String(data: data, encoding: .utf8) {
                                self.addResult("📥 NUT response received")
                                let lines = response.components(separatedBy: .newlines)
                                for line in lines.prefix(5) {
                                    if !line.isEmpty {
                                        self.addResult("   \(line)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        })
    }
    
    @MainActor
    private func addResult(_ message: String) {
        testResults.append(message)
    }
}

#Preview {
    MacOSSettingsView(monitoringService: UPSMonitoringService())
}