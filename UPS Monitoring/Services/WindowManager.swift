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
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            
            // First, try to find any existing main window (exclude system windows)
            for window in NSApp.windows {
                if self.isMainWindow(window) {
                    window.makeKeyAndOrderFront(nil)
                    return
                }
            }
            
            // If no window found, try to trigger SwiftUI to create one
            self.requestNewWindow()
        }
    }
    
    func showSettings() {
        // Show the main window first
        showMainWindow()
        
        // Post notification to show settings
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .showSettings, object: nil)
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
        
        // Check window properties to identify our main window
        let hasContent = window.contentView != nil
        let isResizable = window.styleMask.contains(.resizable)
        let isTitled = window.styleMask.contains(.titled)
        let hasTitle = window.title.contains("UPS") || window.title == "UPS Monitoring"
        
        // Our main window should be resizable and titled, or have SwiftUI content
        return hasContent && (
            (isResizable && isTitled) ||
            hasTitle ||
            window.contentView is NSHostingView<ContentView> ||
            window.identifier?.rawValue == "main"
        )
    }
    
    private func requestNewWindow() {
        // Method 1: Try using Cmd+N keyboard shortcut
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: NSPoint.zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "n",
            charactersIgnoringModifiers: "n",
            isARepeat: false,
            keyCode: 45 // 'n' key
        )
        
        if let event = event {
            NSApp.sendEvent(event)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.activateNewestWindow()
            }
            return
        }
        
        // Method 2: Try menu item approach
        if let fileMenu = NSApp.mainMenu?.items.first(where: { $0.title == "File" }),
           let submenu = fileMenu.submenu {
            for item in submenu.items {
                if item.keyEquivalent == "n" && item.keyEquivalentModifierMask.contains(.command) {
                    if let action = item.action, let target = item.target {
                        NSApp.sendAction(action, to: target, from: item)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self.activateNewestWindow()
                        }
                        return
                    }
                }
            }
        }
        
        // Method 3: Just activate the app (fallback)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            for window in NSApp.windows {
                if self.isMainWindow(window) {
                    window.makeKeyAndOrderFront(nil)
                    return
                }
            }
            // If still no window found, just activate the app
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func activateNewestWindow() {
        for window in NSApp.windows {
            if self.isMainWindow(window) {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showSettings = Notification.Name("ShowSettings")
}