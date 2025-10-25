//
//  AppDelegate.swift
//  UPS Monitoring
//
//  Created by Curtis Netterville on 9/17/25.
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 App finished launching")
        
        // Initialize MenuBarManager which handles the menu bar icon
        _ = MenuBarManager.shared
        print("📋 MenuBarManager initialized")
        
        // Initialize notification service and monitoring service
        Task { @MainActor in
            _ = NotificationService.shared
            
            // Initialize monitoring service
            let monitoringService = UPSMonitoringService()
            MenuBarManager.shared.setMonitoringService(monitoringService)
            NotificationService.shared.initialize(with: monitoringService)
            
            // Start monitoring if devices are configured
            if !monitoringService.devices.isEmpty {
                monitoringService.startMonitoring()
            }
            
            print("⚙️ Services initialized")
        }
        
        // Create the main window programmatically right away but keep it hidden
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.createMainWindow()
            
            // Set activation policy to accessory after window is created
            NSApp.setActivationPolicy(.accessory)
            print("🔧 Set activation policy to accessory")
        }
    }
    
    private func createMainWindow() {
        print("🏗️ Creating main window")
        
        let contentView = ContentView()
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "UPS Monitoring"
        window.contentViewController = hostingController
        window.center()
        
        // Store reference but don't show it yet
        self.mainWindow = window
        
        print("✅ Main window created and stored")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit the app when the last window is closed - keep running in menu bar
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When app is reopened, show the main window
        if !flag {
            showMainWindow()
        }
        return true
    }
    
    // Public method that MenuBarManager can call to show the main window
    func showMainWindow() {
        print("🎯 showMainWindow called")
        
        // Change activation policy to regular to show windows
        NSApp.setActivationPolicy(.regular)
        print("📱 Changed activation policy to regular")
        
        // Use stored window reference
        if let mainWindow = mainWindow {
            print("✅ Showing stored main window")
            mainWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            print("❌ No stored window, creating new one")
            createMainWindow()
            if let mainWindow = mainWindow {
                mainWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}