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
    private var popover: NSPopover?
    private weak var monitoringService: UPSMonitoringService?
    private var cancellables = Set<AnyCancellable>()
    
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
        self.launchAtLogin = UserDefaults.standard.object(forKey: "LaunchAtLogin") as? Bool ?? false
        
        setupMenuBar()
        setupPopover()
        // Always run as accessory app (no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Set initial login item status
        if launchAtLogin {
            updateLoginItem()
        }
    }
    
    func setMonitoringService(_ service: UPSMonitoringService) {
        self.monitoringService = service
        observeUPSStatus()
        updateMenuBarIcon()
        
        // Reset notification data when monitoring service changes
        NotificationService.shared.resetNotificationData()
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
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 450)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.appearance = NSAppearance(named: .vibrantDark)
    }
    
    private func setupMenuBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusBarButton = statusBarItem?.button {
            statusBarButton.image = NSImage(systemSymbolName: "battery.100", accessibilityDescription: "UPS Status")
            statusBarButton.image?.isTemplate = true
            
            // Set up left click action only
            statusBarButton.action = #selector(statusBarButtonClicked)
            statusBarButton.target = self
        }
    }
    
    @objc private func statusBarButtonClicked() {
        // Left click only - show/hide popover
        togglePopover()
    }
    
    private func togglePopover() {
        guard let statusBarButton = statusBarItem?.button else { return }
        
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            // Update popover content
            updatePopoverContent()
            popover?.show(relativeTo: statusBarButton.bounds, of: statusBarButton, preferredEdge: .minY)
            
            // Make sure the popover window is properly focused
            if let popoverWindow = popover?.contentViewController?.view.window {
                NSApp.activate(ignoringOtherApps: true)
                popoverWindow.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    private func updatePopoverContent() {
        guard let monitoringService = monitoringService else { return }
        
        let popoverView = MenuBarPopoverView(
            monitoringService: monitoringService,
            onShowApp: { [weak self] in
                self?.popover?.performClose(nil)
                self?.showApp()
            },
            onQuit: { [weak self] in
                self?.popover?.performClose(nil)
                self?.quitApp()
            }
        )
        
        let hostingController = NSHostingController(rootView: popoverView)
        hostingController.view.frame = NSRect(origin: .zero, size: NSSize(width: 320, height: 450))
        
        popover?.contentViewController = hostingController
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
            }
            .store(in: &cancellables)
        
        // Observe status data changes
        monitoringService.$statusData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)
        
        // Observe monitoring state changes
        monitoringService.$isMonitoring
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)
    }
    
    private func updateMenuBarIcon() {
        guard let statusBarButton = statusBarItem?.button else { return }

        let overallStatus = getOverallStatus()

        // Use battery icon
        let iconName = "battery.100"
        
        // Get the color based on status for the battery
        let batteryColor: NSColor
        switch overallStatus {
        case .good:
            batteryColor = NSColor.systemGreen
        case .warning:
            batteryColor = NSColor.systemOrange  
        case .critical:
            batteryColor = NSColor.systemRed
        case .offline:
            batteryColor = NSColor.systemGray
        }
        
        // Create the battery icon
        guard let batteryImage = NSImage(systemSymbolName: iconName, accessibilityDescription: "Battery Status") else { return }
        
        // Configure the battery icon size
        let iconSize = NSSize(width: 18, height: 12)
        let batteryIcon = batteryImage.copy() as! NSImage
        batteryIcon.size = iconSize
        
        // Create text attributes for "UPS" - keep it white
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        
        let upsText = NSAttributedString(string: "UPS", attributes: textAttributes)
        let textSize = upsText.size()
        
        // Calculate total size (icon + spacing + text)
        let spacing: CGFloat = 1
        let totalSize = NSSize(
            width: max(iconSize.width, textSize.width),
            height: iconSize.height + spacing + textSize.height
        )
        
        // Create the composite image
        let compositeImage = NSImage(size: totalSize)
        compositeImage.lockFocus()
        
        // Draw the battery icon at the top, centered
        let batteryRect = NSRect(
            x: (totalSize.width - iconSize.width) / 2,
            y: textSize.height + spacing,
            width: iconSize.width,
            height: iconSize.height
        )
        
        // Tint the battery icon with status color
        batteryColor.set()
        batteryIcon.draw(in: batteryRect)
        batteryRect.fill(using: .sourceAtop)
        
        // Draw the "UPS" text at the bottom, centered (white)
        let textRect = NSRect(
            x: (totalSize.width - textSize.width) / 2,
            y: 0,
            width: textSize.width,
            height: textSize.height
        )
        
        upsText.draw(in: textRect)
        
        compositeImage.unlockFocus()
        
        statusBarButton.image = compositeImage
        statusBarButton.image?.isTemplate = false
        
        // Update tooltip with status information
        statusBarButton.toolTip = "UPS Monitoring - \(getOverallStatusText())"
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
    
    @objc private func showApp() {
        WindowManager.shared.showMainWindow()
    }
    
    @objc private func toggleLaunchAtLogin() {
        launchAtLogin.toggle()
    }
    
    @objc private func toggleNotifications() {
        NotificationService.shared.notificationsEnabled.toggle()
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