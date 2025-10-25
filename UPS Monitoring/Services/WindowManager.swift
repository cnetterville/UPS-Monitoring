//
//  WindowManager.swift
//  UPS Monitoring
//
//  Created by Assistant on 12/19/24.
//

import SwiftUI
import AppKit
import Combine

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    private init() {}
    
    func showMainWindow() {
        // Use the AppDelegate's showMainWindow method for consistency
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showMainWindow()
        } else {
            // Fallback to direct window management
            fallbackShowMainWindow()
        }
    }
    
    func showSettings() {
        // Show the main window first
        showMainWindow()
        
        // Post notification to show settings tab
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .showSettings, object: nil)
        }
    }
    
    private func fallbackShowMainWindow() {
        DispatchQueue.main.async {
            // Temporarily change activation policy to show windows
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            
            // Find and show the main window
            for window in NSApp.windows {
                if self.isMainWindow(window) {
                    window.makeKeyAndOrderFront(nil)
                    return
                }
            }
        }
    }
    
    private func isMainWindow(_ window: NSWindow) -> Bool {
        // Filter out system windows that can't become key
        guard window.contentView != nil else { return false }
        guard window.canBecomeKey else { return false }
        
        // Exclude status bar windows by checking class name
        let className = NSStringFromClass(type(of: window))
        guard !className.contains("StatusBar") else { return false }
        guard !className.contains("MenuBar") else { return false }
        guard !className.contains("Popover") else { return false }
        
        // Check window properties to identify our main window
        let hasContent = window.contentView != nil
        let isResizable = window.styleMask.contains(.resizable)
        let isTitled = window.styleMask.contains(.titled)
        
        // Our main window should be resizable and titled
        return hasContent && isResizable && isTitled
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showSettings = Notification.Name("ShowSettings")
}