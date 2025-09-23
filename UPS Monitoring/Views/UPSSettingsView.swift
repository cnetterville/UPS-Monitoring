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
    @State private var selectedTab = "devices"
    @State private var hoveredCard: String? = nil
    
    var body: some View {
        ZStack {
            // Liquid Glass Background
            LiquidGlassBackground()
            
            VStack(spacing: 0) {
                // Glass Header
                LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "settings-header") {
                    HStack {
                        Text("Settings")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.primary, Color.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Spacer()
                        
                        LiquidGlassButton("Done", style: .primary) {
                            dismiss()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(20)
                
                HStack(spacing: 0) {
                    // Glass Sidebar
                    VStack(alignment: .leading, spacing: 0) {
                        liquidGlassSidebarButton(
                            title: "Devices",
                            icon: "poweroutlet.type.a",
                            isSelected: selectedTab == "devices"
                        ) {
                            selectedTab = "devices"
                        }
                        
                        liquidGlassSidebarButton(
                            title: "Notifications",
                            icon: "bell",
                            isSelected: selectedTab == "notifications"
                        ) {
                            selectedTab = "notifications"
                        }
                        
                        Spacer()
                    }
                    .frame(width: 200)
                    .padding(.vertical, 20)
                    
                    // Content area
                    VStack {
                        switch selectedTab {
                        case "devices":
                            devicesSettingsView
                        case "notifications":
                            NotificationSettingsView()
                        default:
                            devicesSettingsView
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 750, height: 600)
        .sheet(isPresented: $showingAddDevice) {
            MacOSAddDeviceView(monitoringService: monitoringService)
        }
    }
    
    @ViewBuilder
    private func liquidGlassSidebarButton(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        isSelected ?
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.secondary, Color.secondary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 16)
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.blue.opacity(0.2),
                                                Color.cyan.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.blue.opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
    }
    
    private var devicesSettingsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // UPS Devices Section
                LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "devices-section") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("UPS Devices")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(monitoringService.devices.count) of 2")
                                .font(.system(size: 12, weight: .semibold))
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
                        
                        VStack(spacing: 12) {
                            ForEach(monitoringService.devices) { device in
                                LiquidGlassDeviceSettingsRow(
                                    device: device,
                                    monitoringService: monitoringService,
                                    hoveredCard: $hoveredCard
                                )
                            }
                            
                            if monitoringService.devices.count < 2 {
                                HStack {
                                    LiquidGlassButton(
                                        "Add UPS Device",
                                        icon: "plus.circle.fill",
                                        style: .primary
                                    ) {
                                        showingAddDevice = true
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        
                        if monitoringService.devices.count >= 2 {
                            Text("Maximum of 2 devices supported in this version.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                    }
                }
                
                if !monitoringService.devices.isEmpty {
                    // Monitoring Section
                    LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "monitoring-section") {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Monitoring")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Automatic Monitoring")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        Text("Continuously monitors all devices every 30 seconds")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    LiquidGlassToggle(
                                        isOn: Binding(
                                            get: { monitoringService.isMonitoring },
                                            set: { newValue in
                                                if newValue {
                                                    monitoringService.startMonitoring()
                                                } else {
                                                    monitoringService.stopMonitoring()
                                                }
                                            }
                                        )
                                    )
                                }
                            }
                        }
                    }
                }
                
                Spacer(minLength: 24)
            }
            .padding(24)
        }
    }
}

// Remove Debug button for SNMP devices and improve button layout
struct LiquidGlassDeviceSettingsRow: View {
    let device: UPSDevice
    let monitoringService: UPSMonitoringService
    @Binding var hoveredCard: String?
    @State private var showingEditDevice = false
    @State private var showingConnectivityTest = false
    @State private var isHovered = false
    
    private var cardId: String { "device-settings-\(device.id)" }
    
    var body: some View {
        HStack(spacing: 20) {
            // Device info with glass styling
            VStack(alignment: .leading, spacing: 8) {
                Text(device.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text(device.connectionType.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.blue, Color.cyan],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 0.8
                                        )
                                )
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("\(device.host):\(device.port)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 20)
            
            // Only show Test and Edit buttons (removed Debug button)
            HStack(spacing: 12) {
                LiquidGlassButton(
                    "Test",
                    icon: "network",
                    style: .secondary
                ) {
                    showingConnectivityTest = true
                }
                
                LiquidGlassButton(
                    "Edit",
                    icon: "pencil",
                    style: .secondary
                ) {
                    showingEditDevice = true
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(isHovered ? 0.7 : 0.5)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.15 : 0.1),
                                Color.white.opacity(0.02)
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
                                Color.blue.opacity(0.2)
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
            color: Color.black.opacity(isHovered ? 0.1 : 0.05),
            radius: isHovered ? 8 : 4,
            x: 0,
            y: isHovered ? 4 : 2
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovered in
            isHovered = hovered
            hoveredCard = hovered ? cardId : nil
        }
        .sheet(isPresented: $showingEditDevice) {
            MacOSEditDeviceView(device: device, monitoringService: monitoringService)
        }
        .sheet(isPresented: $showingConnectivityTest) {
            MacOSConnectivityTestView(device: device)
        }
    }
}

// MARK: - Add Device View with Liquid Glass

struct MacOSAddDeviceView: View {
    @ObservedObject var monitoringService: UPSMonitoringService
    @Environment(\.dismiss) private var dismiss
    @State private var hoveredCard: String? = nil
    
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
        ZStack {
            LiquidGlassBackground()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 20) {
                        deviceInfoSection
                        
                        if connectionType == .nut {
                            nutConfigSection
                        } else {
                            snmpConfigSection
                        }
                        
                        batteryTrackingSection
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private var headerView: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "add-header") {
            HStack {
                Text("Add UPS Device")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.primary, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Spacer()
                
                HStack(spacing: 12) {
                    LiquidGlassButton("Cancel", style: .secondary) {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    LiquidGlassButton(
                        "Add Device",
                        icon: "plus.circle.fill",
                        style: isFormValid ? .primary : .secondary
                    ) {
                        saveDevice()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isFormValid)
                }
            }
        }
        .padding(20)
    }
    
    private var deviceInfoSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "device-info") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Device Information")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    LabeledContent("Device Name") {
                        TextField("Enter a name for this UPS", text: $name)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    
                    LabeledContent("Host/IP Address") {
                        TextField("192.168.1.100", text: $host)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    
                    LabeledContent("Connection Type") {
                        connectionTypePicker
                    }
                    
                    LabeledContent("Port") {
                        TextField("Port", value: $port, format: .number)
                            .textFieldStyle(GlassTextFieldStyle())
                            .frame(maxWidth: 100)
                    }
                }
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .onChange(of: connectionType) { oldValue, newValue in
            port = newValue == .nut ? 3493 : 161
        }
    }
    
    private var nutConfigSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "nut-config") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NUT Configuration")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Network UPS Tools (NUT) configuration for communicating with UPS servers.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    LabeledContent("UPS Name") {
                        TextField("ups", text: $upsName)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    
                    LabeledContent("Username") {
                        TextField("Optional", text: $username)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    
                    LabeledContent("Password") {
                        SecureField("Optional", text: $password)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                }
            }
        }
    }
    
    private var snmpConfigSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "snmp-config") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SNMP Configuration")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("SNMP v1 configuration. Most UPS devices use 'public' as the default community string.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                LabeledContent("Community String") {
                    TextField("public", text: $community)
                        .textFieldStyle(GlassTextFieldStyle())
                }
            }
        }
    }
    
    private var batteryTrackingSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "battery-tracking") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Battery Tracking")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Optional battery information for replacement planning.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    LabeledContent("Install Date") {
                        DatePicker("Battery Install Date", 
                                 selection: Binding(
                                    get: { batteryInstallDate ?? Date() },
                                    set: { batteryInstallDate = $0 }
                                 ),
                                 displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                    
                    LabeledContent("Battery Model") {
                        TextField("Optional", text: $batteryModel)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                    
                    LabeledContent("Notes") {
                        TextField("Optional notes", text: $batteryNotes)
                            .textFieldStyle(GlassTextFieldStyle())
                    }
                }
            }
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

// MARK: - Glass Text Field Style

struct GlassTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 14))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.blue.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
    }
}

// Rest of the edit and connectivity test views would follow similar patterns...
// For brevity, keeping the existing implementations but they could be enhanced with glass styling

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