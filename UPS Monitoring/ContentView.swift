//
//  ContentView.swift
//  UPS Monitoring
//
//  Created by Curtis Netterville on 9/17/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var monitoringService = UPSMonitoringService()
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab = "monitoring"
    @State private var isRefreshing = false
    @State private var hoveredCard: String? = nil
    @State private var showingNUTDebug = false
    @State private var selectedDeviceForDebug: UPSDevice?
    @State private var showingAddDevice = false
    @State private var showingDiscovery = false
    @State private var showingQuitConfirmation = false
    @StateObject private var discoveryService = DiscoveryService()
    
    var body: some View {
        ZStack {
            // Liquid glass animated background
            LiquidGlassBackground()
            
            VStack(spacing: 0) {
                // Header Section
                headerSection
                
                // Tab Navigation
                tabNavigation
                
                // Main Content Area
                Group {
                    switch selectedTab {
                    case "monitoring":
                        monitoringView
                    case "devices":
                        devicesManagementView
                    case "notifications":
                        notificationsView
                    default:
                        monitoringView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("")
        .onAppear {
            // Set up menu bar manager with monitoring service
            MenuBarManager.shared.setMonitoringService(monitoringService)
            
            // Initialize notification service with monitoring service
            NotificationService.shared.initialize(with: monitoringService)
            
            // Only start monitoring and refresh if we have devices
            if !monitoringService.devices.isEmpty {
                // Start monitoring first (this will trigger initial refresh)
                if !monitoringService.isMonitoring {
                    monitoringService.startMonitoring()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            selectedTab = "devices"
        }
        .frame(minWidth: 900, minHeight: 650)
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "main-header") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UPS Monitoring")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
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
                    
                    HStack(spacing: 16) {
                        Text("Real-time device status and management")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if monitoringService.isMonitoring {
                            HStack(spacing: 6) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .symbolEffect(.variableColor.iterative)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.green, Color.mint],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .font(.caption)
                                
                                Text("Monitoring Active")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.green)
                            }
                        }
                        
                        if let lastRefresh = monitoringService.lastRefreshTime {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                Text("Updated \(lastRefresh, style: .relative)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    LiquidGlassButton(
                        "Refresh",
                        icon: "arrow.clockwise",
                        style: .secondary
                    ) {
                        isRefreshing = true
                        Task {
                            await monitoringService.refreshAllDevices()
                            isRefreshing = false
                        }
                    }
                    .disabled(isRefreshing || monitoringService.isLoading)
                    
                    LiquidGlassButton(
                        "Quit App",
                        icon: "power",
                        style: .destructive
                    ) {
                        showingQuitConfirmation = true
                    }
                }
            }
        }
        .padding(20)
    }
    
    // MARK: - Tab Navigation
    
    private var tabNavigation: some View {
        HStack(spacing: 0) {
            tabButton(
                title: "Monitoring",
                icon: "chart.line.uptrend.xyaxis",
                isSelected: selectedTab == "monitoring"
            ) {
                selectedTab = "monitoring"
            }
            
            tabButton(
                title: "Devices",
                icon: "battery.100percent",
                isSelected: selectedTab == "devices"
            ) {
                selectedTab = "devices"
            }
            
            tabButton(
                title: "Notifications",
                icon: "bell",
                isSelected: selectedTab == "notifications"
            ) {
                selectedTab = "notifications"
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private func tabButton(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? (colorScheme == .dark ? .white : .black) : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
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
                                        lineWidth: 1
                                    )
                            )
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
    }
    
    // MARK: - Monitoring View
    
    private var monitoringView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if monitoringService.devices.isEmpty {
                    // Empty state
                    LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "empty-monitoring") {
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color.blue.opacity(0.3),
                                                Color.blue.opacity(0.1),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 20,
                                            endRadius: 60
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "poweroutlet.type.a")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.blue, Color.cyan, Color.mint],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            VStack(spacing: 12) {
                                Text("No UPS Devices")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
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
                                Text("Add your first UPS device to start monitoring")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .padding(.horizontal, 20)
                                LiquidGlassButton(
                                    "Go to Devices Tab",
                                    icon: "plus.circle.fill",
                                    style: .primary
                                ) {
                                    selectedTab = "devices"
                                }
                            }
                        }
                    }
                } else {
                    // Device grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 20),
                        GridItem(.flexible(), spacing: 20)
                    ], spacing: 24) {
                        ForEach(monitoringService.devices) { device in
                            LiquidGlassDeviceCard(
                                device: device,
                                status: monitoringService.statusData[device.id],
                                monitoringService: monitoringService,
                                hoveredCard: $hoveredCard
                            )
                        }
                    }
                    
                    // Show loading indicator if service is loading
                    if monitoringService.isLoading {
                        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "loading-indicator") {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .controlSize(.small)
                                
                                Text("Refreshing device status...")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Devices Management View
    
    private var devicesManagementView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Device Management Section
                LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "device-management") {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("UPS Devices")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
                            Spacer()
                            
                            Text("\(monitoringService.devices.count) devices")
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
                        
                        if monitoringService.devices.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "poweroutlet.type.a")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundStyle(.secondary)
                                
                                Text("No devices configured")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Add your first UPS device to start monitoring")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 40)
                            .frame(maxWidth: .infinity)

                        } else {
                            VStack(spacing: 12) {
                                ForEach(monitoringService.devices) { device in
                                    DeviceManagementRow(
                                        device: device,
                                        monitoringService: monitoringService,
                                        hoveredCard: $hoveredCard
                                    )
                                }
                            }
                        }
                        
                        HStack(spacing: 12) {
                            LiquidGlassButton(
                                "Add UPS Device",
                                icon: "plus.circle.fill",
                                style: .primary
                            ) {
                                showingAddDevice = true
                            }
                            .disabled(monitoringService.devices.count >= 4)

                            LiquidGlassButton(
                                "Discover Devices",
                                icon: "magnifyingglass",
                                style: .secondary
                            ) {
                                showingDiscovery = true
                            }
                            
                            Spacer()
                        }

                        if monitoringService.devices.count >= 4 {
                            Text("Maximum of 4 devices supported.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Monitoring Settings Section
                if !monitoringService.devices.isEmpty {
                    LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "monitoring-settings") {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Monitoring Settings")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Automatic Monitoring")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("Continuously monitors all devices every 30 seconds")
                                        .font(.system(size: 13))
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
    }
    
    // MARK: - Notifications View
    
    private var notificationsView: some View {
        NotificationSettingsView()
    }
}

// MARK: - Device Management Row

struct DeviceManagementRow: View {
    let device: UPSDevice
    let monitoringService: UPSMonitoringService
    @Binding var hoveredCard: String?
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingEditDevice = false
    @State private var showingConnectivityTest = false
    @State private var isHovered = false
    
    private var cardId: String { "device-mgmt-\(device.id)" }
    private var status: UPSStatus? { monitoringService.statusData[device.id] }
    
    var body: some View {
        HStack(spacing: 20) {
            // Status indicator and device info
            HStack(spacing: 16) {
                // Animated status indicator
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            (status?.isOnline == true ? Color.green : Color.red).opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    if monitoringService.isLoading {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(0.8)
                    } else {
                        Circle()
                            .fill(status?.isOnline == true ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                            .shadow(
                                color: (status?.isOnline == true ? Color.green : Color.red).opacity(0.6),
                                radius: 4
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(device.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    HStack(spacing: 8) {
                        Text(device.connectionType.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
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
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Status info
            if let status = status, status.isOnline {
                if let batteryCharge = status.batteryCharge, batteryCharge > 0 && batteryCharge < 100 {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(batteryCharge))%")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(
                                batteryCharge > 50 ? .green :
                                batteryCharge > 20 ? .orange : .red
                            )
                        
                        GlassProgressBar(
                            value: batteryCharge,
                            total: 100,
                            color: batteryCharge > 50 ? .green :
                                   batteryCharge > 20 ? .orange : .red
                        )
                        .frame(width: 60, height: 4)
                    }
                } else {
                    Text("Online")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                        .textCase(.uppercase)
                        .tracking(0.3)
                }
            } else {
                Text("Offline")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
            
            // Action buttons
            HStack(spacing: 8) {
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
                    "",
                    icon: "trash",
                    style: .destructive
                ) {
                    monitoringService.removeDevice(device)
                }
            }
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(isHovered ? 0.7 : 0.5)
                
                RoundedRectangle(cornerRadius: 16)
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
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            (status?.isOnline == true ? Color.green : Color.red).opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                        lineWidth: 1
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

// MARK: - Reused Components from Original

struct LiquidGlassDeviceCard: View {
    let device: UPSDevice
    let status: UPSStatus?
    let monitoringService: UPSMonitoringService
    @Binding var hoveredCard: String?
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingEnergyStats = false
    
    private var cardId: String { "device-card-\(device.id)" }
    
    var body: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: cardId) {
            VStack(spacing: 0) {
                // Header with glass effect
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(device.name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
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
                        
                        HStack(spacing: 8) {
                            Text(device.connectionType.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.horizontal, 8)
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
                                                    lineWidth: 1
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
                            
                            Text(device.host)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        GlassStatusBadge(
                            status?.isOnline == true ? "Online" : "Offline",
                            status: status?.isOnline == true ? .online : .offline
                        )
                        
                        if status?.isOnline == true {
                            LiquidGlassButton(
                                "Energy",
                                icon: "chart.line.uptrend.xyaxis",
                                style: .secondary
                            ) {
                                showingEnergyStats = true
                            }
                        }
                    }
                }
                .padding(.bottom, 16)
                
                // Content with glass sections
                if let status = status, status.isOnline {
                    VStack(spacing: 16) {
                        // UPS Info section with glass background
                        if hasUPSInfo(status) {
                            VStack(spacing: 8) {
                                upsInfoSection(for: status)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                        }
                        
                        // Battery section with enhanced glass effect
                        if let batteryCharge = status.batteryCharge, batteryCharge > 0 {
                            LiquidGlassBatteryView(
                                charge: batteryCharge,
                                runtime: status.batteryRuntime,
                                status: status,
                                hoveredCard: $hoveredCard,
                                deviceId: device.id
                            )
                        }
                        
                        // Status alerts
                        statusAlertsView(for: status, device: device)
                        
                        // Metrics grid with glass cards
                        let metrics = buildMetrics(from: status)
                        if !metrics.isEmpty {
                            // Use a more flexible layout that doesn't create empty spaces
                            VStack(spacing: 12) {
                                ForEach(0..<((metrics.count + 1) / 2), id: \.self) { row in
                                    HStack(spacing: 12) {
                                        let startIndex = row * 2
                                        let endIndex = min(startIndex + 2, metrics.count)
                                        
                                        ForEach(startIndex..<endIndex, id: \.self) { index in
                                            LiquidGlassMetricCard(
                                                title: metrics[index].title,
                                                value: metrics[index].value,
                                                icon: metrics[index].icon,
                                                color: metrics[index].color
                                            )
                                        }
                                        
                                        // Only add spacer if we have an odd number and this is the last row
                                        if endIndex - startIndex == 1 && endIndex == metrics.count {
                                            Spacer()
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Statistics summary with glass styling
                        statisticsSummary(for: status, device: device)
                        
                        // Last updated with subtle glass effect
                        HStack {
                            Text("Last updated")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            Spacer()
                            
                            Text(status.lastUpdate, style: .relative)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)

                    }
                } else {
                    // Offline state with glass effect
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.orange.opacity(0.3),
                                            Color.orange.opacity(0.1),
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
                                .symbolEffect(.bounce, value: status?.isOnline)
                        }
                        
                        VStack(spacing: 6) {
                            Text(status?.status ?? "Offline")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Check device connection and network settings")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .sheet(isPresented: $showingEnergyStats) {
            EnergyStatsView(
                device: device,
                status: status,
                monitoringService: monitoringService
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func hasUPSInfo(_ status: UPSStatus) -> Bool {
        return status.manufacturer != nil || status.model != nil || status.upsName != nil
    }
    
    private func upsInfoSection(for status: UPSStatus) -> some View {
        VStack(spacing: 4) {
            if let manufacturer = status.manufacturer {
                if let model = status.model {
                    Text("\(manufacturer) \(model)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    if let upsName = status.upsName, upsName != model && !upsName.isEmpty {
                        Text(upsName)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(manufacturer)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    if let upsName = status.upsName, !upsName.isEmpty {
                        Text(upsName)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let model = status.model {
                Text(model)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                
                if let upsName = status.upsName, upsName != model && !upsName.isEmpty {
                    Text(upsName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else if let upsName = status.upsName, !upsName.isEmpty {
                Text(upsName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
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
        
        // Battery Runtime
        if let formattedRuntime = status.formattedRuntime {
            let color: Color = {
                if formattedRuntime == "∞" {
                    return .blue
                }
                
                if let runtime = status.batteryRuntime {
                    return runtime < 15 ? .red : runtime < 30 ? .orange : .green
                }
                return .blue
            }()
            
            metrics.append(MacOSMetric(
                title: "Runtime",
                value: formattedRuntime,
                icon: formattedRuntime == "∞" ? "infinity" : "clock.fill",
                color: color
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
            let isNormal = inputVoltage >= 110 && inputVoltage <= 130
            let displayVoltage = inputVoltage < 10 ? String(format: "%.1fV", inputVoltage) : "\(Int(inputVoltage))V"
            metrics.append(MacOSMetric(
                title: "Input",
                value: displayVoltage,
                icon: "powerplug.fill",
                color: isNormal ? .green : .orange
            ))
        }
        
        // Output voltage
        if let outputVoltage = status.outputVoltage, outputVoltage > 0 {
            let isNormal = outputVoltage >= 110 && outputVoltage <= 130
            let displayVoltage = outputVoltage < 10 ? String(format: "%.1fV", outputVoltage) : "\(Int(outputVoltage))V"
            metrics.append(MacOSMetric(
                title: "Output",
                value: displayVoltage,
                icon: "poweroutlet.type.a.fill",
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

extension Animation {
    func repeatWhile<T: Equatable>(_ condition: T) -> Animation {
        return condition as? Bool == true ? self.repeatForever() : self
    }
}

// MARK: - Supporting Types

struct MacOSMetric {
    let title: String
    let value: String
    let icon: String
    let color: Color
}

struct LiquidGlassBatteryView: View {
    let charge: Double
    let runtime: Int?
    let status: UPSStatus?
    @Binding var hoveredCard: String?
    let deviceId: UUID
    @Environment(\.colorScheme) private var colorScheme
    @State private var animatedCharge: Double = 0
    @State private var isHovered = false
    
    private var cardId: String { "battery-\(deviceId)" }
    
    private var batteryColor: Color {
        if charge > 50 { return .green }
        else if charge > 20 { return .orange }
        else { return .red }
    }
    
    private var chargingStatusInfo: (text: String, icon: String, color: Color)? {
        guard let status = status else { return nil }
        
        if let isCharging = status.isCharging {
            if isCharging {
                return ("Charging", "bolt.fill", .green)
            } else if status.outputSource == "Battery" {
                return ("Discharging", "minus.circle.fill", .orange)
            } else {
                return ("Full", "checkmark.circle.fill", .blue)
            }
        } else if let batteryStatus = status.batteryStatus {
            switch batteryStatus {
            case .batteryCharging:
                return ("Charging", "bolt.fill", .green)
            case .batteryDischarging:
                return ("Discharging", "minus.circle.fill", .orange)
            case .batteryLow:
                return ("Low", "exclamationmark.triangle.fill", .red)
            case .batteryNormal:
                return ("Normal", "checkmark.circle.fill", .green)
            default:
                return (batteryStatus.description, "battery.50", .secondary)
            }
        } else if status.outputSource == "Battery" {
            return ("On Battery", "battery.25", .orange)
        }
        
        return nil
    }
    
    var body: some View {
        VStack(spacing: 16) {
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
                                    endRadius: 20
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "battery.100")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [batteryColor, batteryColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Text("Battery")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                
                Spacer()
                
                Text("\(Int(animatedCharge))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [batteryColor, batteryColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .monospacedDigit()
            }
            
            // Enhanced Glass Progress Bar
            GlassProgressBar(value: animatedCharge, total: 100, color: batteryColor)
                .frame(height: 16)
            
            // Battery status info with glass styling
            HStack(spacing: 16) {
                if let chargingInfo = chargingStatusInfo {
                    HStack(spacing: 6) {
                        Image(systemName: chargingInfo.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(chargingInfo.color)
                            .symbolEffect(.pulse, isActive: chargingInfo.text == "Charging")
                        
                        Text(chargingInfo.text)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(chargingInfo.color)
                            .textCase(.uppercase)
                            .tracking(0.3)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(chargingInfo.color.opacity(0.3), lineWidth: 0.8)
                            )
                    )
                }
                
                Spacer()
                
                if let status = status, let formattedRuntime = status.formattedRuntime {
                    HStack(spacing: 6) {
                        Image(systemName: formattedRuntime == "∞" ? "infinity" : "clock")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        Text(formattedRuntime)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 0.8)
                            )
                    )
                }
            }
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(isHovered ? 0.8 : 0.6)
                
                RoundedRectangle(cornerRadius: 16)
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
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                batteryColor.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .shadow(
            color: batteryColor.opacity(isHovered ? 0.2 : 0.1),
            radius: isHovered ? 12 : 8,
            x: 0,
            y: isHovered ? 6 : 4
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
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
            hoveredCard = hovered ? cardId : nil
        }
    }
}

struct LiquidGlassMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                
                Text(title)
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
        
        // Battery age warning using device data
        if let batteryAge = device.batteryAgeInDays, batteryAge > 1095 { // 3+ years
            GlassStatusBadge(
                "Battery is \(batteryAge / 365) years old - consider replacement",
                status: .error
            )
        } else if let batteryAge = device.batteryAgeInDays, batteryAge > 730 { // 2+ years
            GlassStatusBadge(
                "Battery is \(batteryAge / 365) years old - monitor closely",
                status: .warning
            )
        }
    }
}

private func statisticsSummary(for status: UPSStatus, device: UPSDevice) -> some View {
    let hasContent = (status.powerFailures != nil && status.powerFailures! > 0) ||
                    (device.batteryAgeInDays != nil) ||
                    (device.batteryInstallDate != nil)
    
    return Group {
        if hasContent {
            VStack(spacing: 8) {
                if let powerFailures = status.powerFailures, powerFailures > 0 {
                    HStack {
                        Text("Power failures detected")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.3)
                        
                        Spacer()
                        
                        Text("\(powerFailures)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
                
                // Battery age information
                if let batteryAgeInDays = device.batteryAgeInDays {
                    HStack {
                        Text("Battery age")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.3)
                        
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
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.3)
                            
                            Spacer()
                            
                            Text(replaceDate, style: .date)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
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
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(ageInfo.color)
    }
}