//
//  AppDelegate.swift
//  UPS Monitoring
//
//  Created by Curtis Netterville on 9/17/25.
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit the app when the last window is closed - keep running in menu bar
        
        // Let MenuBarManager handle dock icon visibility based on user preference
        MenuBarManager.shared.windowDidClose()
        
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When app icon is clicked in dock (if visible), show the main window
        if !flag {
            // Let MenuBarManager handle showing the window properly
            MenuBarManager.shared.windowWillShow()
            NSApp.activate(ignoringOtherApps: true)
            
            // Find and show the main window
            for window in NSApp.windows {
                if window.contentView is NSHostingView<ContentView> || window.title.contains("UPS Monitoring") {
                    window.makeKeyAndOrderFront(nil)
                    return true
                }
            }
        }
        return true
    }
}