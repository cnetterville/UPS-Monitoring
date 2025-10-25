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
        print("🔍 AppDelegate instance: \(self)")
        print("🔍 NSApp.delegate: \(String(describing: NSApp.delegate))")
        
        // Store reference for MenuBarManager to access
        AppDelegateReference.shared = self
        
        // Initialize MenuBarManager which handles the menu bar icon
        let menuBarManager = MenuBarManager.shared
        menuBarManager.setAppDelegate(self)
        print("📋 MenuBarManager initialized")
        
        // Initialize notification service and monitoring service
        Task { @MainActor in
            _ = NotificationService.shared
            
            // Initialize monitoring service
            let monitoringService = UPSMonitoringService()
            menuBarManager.setMonitoringService(monitoringService)
            NotificationService.shared.initialize(with: monitoringService)
            
            // Start monitoring if devices are configured
            if !monitoringService.devices.isEmpty {
                monitoringService.startMonitoring()
            }
            
            print("⚙️ Services initialized")
        }
        
        // Set activation policy to accessory immediately and keep it that way
        NSApp.setActivationPolicy(.accessory)
        print("🔧 Set activation policy to accessory")
        
        // Create and show the main window right away
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.createAndShowMainWindow()
        }
    }
    
    private func createAndShowMainWindow() {
        print("🏗️ Creating and showing main window")
        
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
        
        // Set self as the window delegate to handle window events
        window.delegate = self
        
        // Store and show the window
        self.mainWindow = window
        window.makeKeyAndOrderFront(nil)
        
        // Activate the app to bring window to front, but keep accessory policy
        NSApp.activate(ignoringOtherApps: true)
        
        print("✅ Main window created and shown")
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
        print("🎯 AppDelegate.showMainWindow called")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { 
                print("❌ Self is nil in showMainWindow")
                return 
            }
            
            // Don't change activation policy - keep it as accessory
            print("📱 Keeping activation policy as accessory")
            
            // Check if we have a valid existing window
            if let existingWindow = self.mainWindow {
                print("✅ Showing existing window")
                existingWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            
            // Create a new window if we don't have one
            print("🔄 No existing window, creating new one")
            self.createAndShowMainWindow()
        }
    }
}

// MARK: - NSWindowDelegate
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        print("🔧 Window will close")
        // No need to change activation policy since we're keeping it as accessory
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Instead of actually closing, just hide the window
        sender.orderOut(nil)
        print("🙈 Window hidden instead of closed")
        
        // Return false to prevent actual closing
        return false
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        print("🎯 Window became key")
    }
    
    func windowDidResignKey(_ notification: Notification) {
        print("👋 Window resigned key")
    }
}

// Make AppDelegate accessible globally with better debugging
extension AppDelegate {
    static var shared: AppDelegate? {
        // Try multiple ways to get the AppDelegate
        if let reference = AppDelegateReference.shared {
            print("🎯 Found AppDelegate via AppDelegateReference")
            return reference
        }
        
        if let delegate = NSApp.delegate as? AppDelegate {
            print("🎯 Found AppDelegate via NSApp.delegate cast")
            return delegate
        }
        
        print("❌ Could not find AppDelegate anywhere")
        print("🔍 NSApp.delegate type: \(type(of: NSApp.delegate))")
        print("🔍 NSApp.delegate: \(String(describing: NSApp.delegate))")
        return nil
    }
}