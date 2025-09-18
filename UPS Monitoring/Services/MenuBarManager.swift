//
//  MenuBarManager.swift
//  UPS Monitoring
//
//  Created by Curtis Netterville on 9/17/25.
//

import SwiftUI
import AppKit
import Combine
import ServiceManagement

class MenuBarManager: ObservableObject {
    private var statusBarItem: NSStatusItem?
    private weak var monitoringService: UPSMonitoringService?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var showDockIcon: Bool {
        didSet {
            UserDefaults.standard.set(showDockIcon, forKey: "ShowDockIcon")
            updateDockIconVisibility()
        }
    }
    
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "LaunchAtLogin")
            updateLoginItem()
        }
    }
    
    // Singleton instance to be accessed by AppDelegate
    static let shared = MenuBarManager()
    
    private init() {
        // Load preferences from UserDefaults
        self.showDockIcon = UserDefaults.standard.object(forKey: "ShowDockIcon") as? Bool ?? true
        self.launchAtLogin = UserDefaults.standard.object(forKey: "LaunchAtLogin") as? Bool ?? false
        
        setupMenuBar()
        updateDockIconVisibility()
        
        // Set initial login item status
        if launchAtLogin {
            updateLoginItem()
        }
    }
    
    func setMonitoringService(_ service: UPSMonitoringService) {
        self.monitoringService = service
        observeUPSStatus()
        updateMenuBarIcon()
        updateMenu()
    }
    
    // Public method for AppDelegate to check dock preference
    func shouldShowDockIcon() -> Bool {
        return showDockIcon
    }
    
    // Public method for when window is shown - temporarily show dock icon
    func windowWillShow() {
        NSApp.setActivationPolicy(.regular)
    }
    
    // Public method for when window is closed - respect user preference
    func windowDidClose() {
        updateDockIconVisibility()
    }
    
    private func updateDockIconVisibility() {
        DispatchQueue.main.async {
            if self.showDockIcon {
                NSApp.setActivationPolicy(.regular)
            } else {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(launchAtLogin ? "enable" : "disable") launch at login: \(error)")
            }
        } else {
            // Fallback for older macOS versions
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.nettervile.ups.monitor.UPS-Monitoring"
            
            if launchAtLogin {
                // Add to login items
                let script = """
                tell application "System Events"
                    make new login item at end of login items with properties {path:"\(Bundle.main.bundlePath)", hidden:false}
                end tell
                """
                
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(nil)
                }
            } else {
                // Remove from login items
                let script = """
                tell application "System Events"
                    delete every login item whose name is "UPS Monitoring"
                end tell
                """
                
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(nil)
                }
            }
        }
    }
    
    private func setupMenuBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusBarButton = statusBarItem?.button {
            statusBarButton.image = NSImage(systemSymbolName: "poweroutlet.type.a", accessibilityDescription: "UPS Status")
            statusBarButton.image?.isTemplate = true
            
            // Create the menu
            let menu = NSMenu()
            
            // Status item
            let statusMenuItem = NSMenuItem(title: "Loading...", action: nil, keyEquivalent: "")
            statusMenuItem.isEnabled = false
            menu.addItem(statusMenuItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // Show app item
            let showAppItem = NSMenuItem(title: "Show UPS Monitoring", action: #selector(showApp), keyEquivalent: "")
            showAppItem.target = self
            menu.addItem(showAppItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // Preferences submenu
            let preferencesSubmenu = NSMenu()
            
            // Dock icon toggle
            let dockIconItem = NSMenuItem(title: "Show Dock Icon", action: #selector(toggleDockIcon), keyEquivalent: "")
            dockIconItem.target = self
            preferencesSubmenu.addItem(dockIconItem)
            
            // Launch at login toggle  
            let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
            loginItem.target = self
            preferencesSubmenu.addItem(loginItem)
            
            let preferencesMenuItem = NSMenuItem(title: "Preferences", action: nil, keyEquivalent: "")
            preferencesMenuItem.submenu = preferencesSubmenu
            menu.addItem(preferencesMenuItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // Quit item
            let quitItem = NSMenuItem(title: "Quit UPS Monitoring", action: #selector(quitApp), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
            
            statusBarItem?.menu = menu
        }
    }
    
    private func observeUPSStatus() {
        guard let monitoringService = monitoringService else { return }
        
        // Clear existing subscriptions
        cancellables.removeAll()
        
        // Observe devices changes
        monitoringService.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
                self?.updateMenu()
            }
            .store(in: &cancellables)
        
        // Observe status data changes
        monitoringService.$statusData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
                self?.updateMenu()
            }
            .store(in: &cancellables)
        
        // Observe monitoring state changes
        monitoringService.$isMonitoring
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
                self?.updateMenu()
            }
            .store(in: &cancellables)
    }
    
    private func updateMenuBarIcon() {
        guard let statusBarButton = statusBarItem?.button,
              let monitoringService = monitoringService else { return }
        
        let overallStatus = getOverallStatus()
        
        // Update icon based on status - use different icons instead of colors
        let iconName: String
        
        switch overallStatus {
        case .good:
            iconName = "poweroutlet.type.a.fill"  // Filled = good
        case .warning:
            iconName = "poweroutlet.type.a"       // Outline = warning
        case .critical:
            iconName = "exclamationmark.triangle.fill" // Warning symbol = critical
        case .offline:
            iconName = "poweroutlet.type.a"       // Outline = offline (will appear dimmed)
        }
        
        // Set the image as template (black/white based on system theme)
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "UPS Status") {
            statusBarButton.image = image
            statusBarButton.image?.isTemplate = true  // Let macOS handle the coloring
        }
        
        // Update tooltip with color information since icon can't show it
        statusBarButton.toolTip = getStatusTooltipWithStatus(overallStatus)
    }
    
    private func updateMenu() {
        guard let menu = statusBarItem?.menu,
              let monitoringService = monitoringService else { return }
        
        // Update status item (first item)
        if let statusItem = menu.items.first {
            statusItem.title = getOverallStatusText()
        }
        
        // Update preferences submenu items
        if let preferencesMenuItem = menu.items.first(where: { $0.title == "Preferences" }),
           let preferencesSubmenu = preferencesMenuItem.submenu {
            
            // Update dock icon toggle
            if let dockIconItem = preferencesSubmenu.items.first(where: { $0.title.contains("Dock Icon") }) {
                dockIconItem.title = showDockIcon ? "Hide Dock Icon" : "Show Dock Icon"
                dockIconItem.state = showDockIcon ? .on : .off
            }
            
            // Update launch at login toggle
            if let loginItem = preferencesSubmenu.items.first(where: { $0.title == "Launch at Login" }) {
                loginItem.state = launchAtLogin ? .on : .off
            }
        }
        
        // Clear existing device items (keep the fixed items)
        let fixedItemsCount = 6 // Status, separator, Show App, separator, Preferences, separator
        while menu.items.count > fixedItemsCount + 1 { // +1 for quit item
            menu.removeItem(at: fixedItemsCount)
        }
        
        // Add device items
        if !monitoringService.devices.isEmpty {
            for device in monitoringService.devices where device.isEnabled {
                let deviceStatus = monitoringService.statusData[device.id]
                let menuItem = createDeviceMenuItem(device: device, status: deviceStatus)
                menu.insertItem(menuItem, at: menu.items.count - 1) // Insert before quit item
            }
        } else {
            let noDevicesItem = NSMenuItem(title: "No devices configured", action: nil, keyEquivalent: "")
            noDevicesItem.isEnabled = false
            menu.insertItem(noDevicesItem, at: menu.items.count - 1)
        }
    }
    
    private func createDeviceMenuItem(device: UPSDevice, status: UPSStatus?) -> NSMenuItem {
        let isOnline = status?.isOnline ?? false
        let batteryLevel = status?.batteryCharge.map { Int($0) }
        
        var title = device.name
        
        if isOnline {
            if let batteryLevel = batteryLevel {
                title += " - \(batteryLevel)%"
                
                // Add status indicators
                if let outputSource = status?.outputSource, outputSource == "Battery" {
                    title += " (On Battery)"
                }
            }
        } else {
            title += " - Offline"
        }
        
        let menuItem = NSMenuItem(title: title, action: #selector(showApp), keyEquivalent: "")
        menuItem.target = self
        
        return menuItem
    }
    
    private func getOverallStatus() -> OverallStatus {
        guard let monitoringService = monitoringService else { return .offline }
        guard !monitoringService.devices.isEmpty else { return .offline }
        guard monitoringService.isMonitoring else { return .offline }
        
        var hasOnlineDevices = false
        var hasCriticalIssues = false
        var hasWarnings = false
        
        for device in monitoringService.devices where device.isEnabled {
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
            return .offline
        } else if hasCriticalIssues {
            return .critical
        } else if hasWarnings {
            return .warning
        } else {
            return .good
        }
    }
    
    private func getOverallStatusText() -> String {
        guard let monitoringService = monitoringService else { return "Loading..." }
        
        let onlineCount = monitoringService.devices.filter { device in
            guard let status = monitoringService.statusData[device.id] else { return false }
            return device.isEnabled && status.isOnline
        }.count
        
        let totalEnabledCount = monitoringService.devices.filter { $0.isEnabled }.count
        
        if totalEnabledCount == 0 {
            return "No devices configured"
        } else if onlineCount == 0 {
            return "All devices offline"
        } else if onlineCount == totalEnabledCount {
            let overallStatus = getOverallStatus()
            switch overallStatus {
            case .good:
                return "All systems normal"
            case .warning:
                return "Warning - Check devices"
            case .critical:
                return "Critical - Immediate attention needed"
            case .offline:
                return "All devices offline"
            }
        } else {
            return "\(onlineCount)/\(totalEnabledCount) devices online"
        }
    }
    
    private func getStatusTooltipWithStatus(_ status: OverallStatus) -> String {
        guard let monitoringService = monitoringService else { return "UPS Monitoring" }
        
        let statusText = getOverallStatusText()
        let statusIndicator = switch status {
        case .good: "🟢"
        case .warning: "🟠" 
        case .critical: "🔴"
        case .offline: "⚪"
        }
        
        var details: [String] = []
        
        for device in monitoringService.devices where device.isEnabled {
            guard let deviceStatus = monitoringService.statusData[device.id] else { continue }
            
            var deviceInfo = device.name
            
            if deviceStatus.isOnline {
                if let charge = deviceStatus.batteryCharge {
                    deviceInfo += " - \(Int(charge))%"
                }
                if let outputSource = deviceStatus.outputSource, outputSource == "Battery" {
                    deviceInfo += " (On Battery)"
                }
            } else {
                deviceInfo += " - Offline"
            }
            
            details.append(deviceInfo)
        }
        
        let fullStatus = "\(statusIndicator) \(statusText)"
        
        if details.isEmpty {
            return fullStatus
        } else {
            return fullStatus + "\n" + details.joined(separator: "\n")
        }
    }
    
    @objc private func showApp() {
        // Temporarily show dock icon when showing the main window
        windowWillShow()
        NSApp.activate(ignoringOtherApps: true)
        
        // Find and show the main window
        for window in NSApp.windows {
            if window.contentView is NSHostingView<ContentView> || window.title.contains("UPS Monitoring") {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }
    
    @objc private func toggleDockIcon() {
        showDockIcon.toggle()
    }
    
    @objc private func toggleLaunchAtLogin() {
        launchAtLogin.toggle()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    enum OverallStatus {
        case good
        case warning
        case critical
        case offline
    }
}