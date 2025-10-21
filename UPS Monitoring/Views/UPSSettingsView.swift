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
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingAddDevice = false
    @State private var selectedTab = "devices"
    @State private var hoveredCard: String? = nil
    @State private var showingDiscovery = false
    @State private var showingQuitConfirmation = false
    @StateObject private var discoveryService = DiscoveryService()
    
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
                                    colors: [
                                        colorScheme == .dark ? Color.white : Color.black,
                                        Color.blue.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            LiquidGlassButton("Quit App", icon: "power", style: .secondary) {
                                showingQuitConfirmation = true
                            }
                            
                            LiquidGlassButton("Done", style: .primary) {
                                dismiss()
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                    }
                }
                .padding(20)
                
                HStack(spacing: 0) {
                    // Glass Sidebar
                    VStack(alignment: .leading, spacing: 0) {
                        liquidGlassSidebarButton(
                            title: "Devices",
                            icon: "battery.100percent",
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
                    .padding(.trailing, 20)
                }
            }
        }
        .frame(width: 850, height: 720)
        .sheet(isPresented: $showingAddDevice) {
            MacOSAddDeviceView(monitoringService: monitoringService)
        }
        .sheet(isPresented: $showingDiscovery) {
            DeviceDiscoveryView(discoveryService: discoveryService, monitoringService: monitoringService)
        }
        .confirmationDialog(
            "Quit UPS Monitoring?",
            isPresented: $showingQuitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("All monitoring will stop and the app will close.")
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
                    .foregroundColor(isSelected ? (colorScheme == .dark ? .white : .black) : .secondary)
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
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
                            Spacer()
                            
                            Text("\(monitoringService.devices.count) of 4")
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
                            
                            if monitoringService.devices.count < 4 {
                                HStack {
                                    LiquidGlassButton(
                                        "Add UPS Device",
                                        icon: "plus.circle.fill",
                                        style: .primary
                                    ) {
                                        showingAddDevice = true
                                    }

                                    Spacer()
                                    Button("Discover on Network") {
                                        showingDiscovery = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                        
                        if monitoringService.devices.count >= 4 {
                            Text("Maximum of 4 devices supported.")
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
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
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
            }
            .padding(24)
        }
        .clipped()
    }
}

// Remove Debug button for SNMP devices and improve button layout
struct LiquidGlassDeviceSettingsRow: View {
    let device: UPSDevice
    let monitoringService: UPSMonitoringService
    @Binding var hoveredCard: String?
    @Environment(\.colorScheme) private var colorScheme
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
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
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
                    
                    Text("\(device.host):\(device.port.formatted(.number.grouping(.never)))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(minWidth: 200, alignment: .leading)
            
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
                
                LiquidGlassButton(
                    "Delete",
                    icon: "trash",
                    style: .destructive
                ) {
                    monitoringService.removeDevice(device)
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
    @Environment(\.colorScheme) private var colorScheme
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
                            colors: [
                                colorScheme == .dark ? Color.white : Color.black,
                                Color.blue.opacity(0.8)
                            ],
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
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
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
                        TextField("Port", value: $port, format: .number.grouping(.never))
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
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
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
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
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
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
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
                        TextField("Port", value: $port, format: .number.grouping(.never))
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
                    
                    Text("\(device.connectionType.rawValue) connection to \(device.host):\(device.port.formatted(.number.grouping(.never)))")
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
        addResult("📍 Target: \(device.connectionType.rawValue) - \(device.host):\(device.port.formatted(.number.grouping(.never)))")
        
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
        
        // Wait longer for connection and check state more carefully
        var attempts = 0
        while attempts < 10 && connection.state != .ready && connection.state != .failed(NWError.dns(DNSServiceErrorType(kDNSServiceErr_NoError))) {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            attempts += 1
        }
        
        await MainActor.run {
            switch connection.state {
            case .ready:
                addResult("✅ TCP connection established")
                testNUTCommands(connection: connection)
            case .failed(let error):
                addResult("❌ TCP connection failed: \(error)")
                addResult("💡 Check if NUT server is running on port \(device.port)")
            case .waiting(let error):
                addResult("⏳ Connection waiting: \(error)")
                addResult("💡 Connection timed out - check firewall/network")
            default:
                addResult("❓ Connection state: \(connection.state)")
                addResult("💡 Try using SNMP instead if device doesn't support NUT")
            }
        }
        
        // Clean up connection after a delay
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            connection.cancel()
        }
    }
    
    private func testNUTCommands(connection: NWConnection) {
        let upsName = device.upsName ?? "ups"
        let command = "LIST VAR \(upsName)\n"
        let data = command.data(using: .utf8)!
        
        addResult("📤 Sending: LIST VAR \(upsName)")
        
        // Check if connection is still ready before sending
        guard connection.state == .ready else {
            addResult("❌ Connection not ready for sending commands")
            return
        }
        
        connection.send(content: data, completion: .contentProcessed { error in
            Task { @MainActor in
                if let error = error {
                    self.addResult("❌ Failed to send NUT command: \(error)")
                    self.addResult("💡 The NUT server may not be responding or may require authentication")
                } else {
                    self.addResult("✅ NUT command sent successfully")
                    
                    // Set a timeout for receiving data
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                        Task { @MainActor in
                            if let error = error {
                                self.addResult("❌ NUT response error: \(error)")
                                self.addResult("💡 UPS '\(upsName)' may not exist or server requires login")
                            } else if let data = data, let response = String(data: data, encoding: .utf8) {
                                let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                                self.addResult("📥 NUT response received (\(data.count) bytes)")
                                
                                if trimmedResponse.starts(with: "ERR") {
                                    self.addResult("❌ NUT Error: \(trimmedResponse)")
                                    if trimmedResponse.contains("UNKNOWN-UPS") {
                                        self.addResult("💡 UPS '\(upsName)' not found. Try 'LIST UPS' first to see available UPS devices")
                                        self.testListUPS(connection: connection)
                                    } else if trimmedResponse.contains("ACCESS-DENIED") {
                                        self.addResult("💡 Access denied. Check username/password configuration")
                                    }
                                } else {
                                    let lines = response.components(separatedBy: .newlines)
                                    let validLines = lines.filter { !$0.isEmpty && !$0.hasPrefix("BEGIN") && !$0.hasPrefix("END") }
                                    
                                    if validLines.isEmpty {
                                        self.addResult("⚠️ Empty response - UPS '\(upsName)' may not have variables")
                                    } else {
                                        self.addResult("📊 UPS Variables (\(validLines.count) found):")
                                        for line in validLines {
                                            self.addResult("   \(line)")
                                        }
                                    }
                                }
                            } else {
                                self.addResult("❌ No data received from NUT server")
                            }
                        }
                    }
                }
            }
        })
    }
    
    private func testListUPS(connection: NWConnection) {
        let command = "LIST UPS\n"
        let data = command.data(using: .utf8)!
        
        addResult("📤 Sending: LIST UPS (to see available UPS devices)")
        
        connection.send(content: data, completion: .contentProcessed { error in
            Task { @MainActor in
                if let error = error {
                    self.addResult("❌ Failed to send LIST UPS command: \(error)")
                } else {
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 2048) { data, _, _, error in
                        Task { @MainActor in
                            if let data = data, let response = String(data: data, encoding: .utf8) {
                                let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                                self.addResult("📋 Available UPS devices:")
                                let lines = response.components(separatedBy: .newlines)
                                let validLines = lines.filter { !$0.isEmpty && !$0.hasPrefix("BEGIN") && !$0.hasPrefix("END") }
                                
                                if validLines.isEmpty {
                                    self.addResult("   No UPS devices found")
                                } else {
                                    for line in validLines {
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