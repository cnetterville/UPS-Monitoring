//
//  AppDelegate.swift
//  UPS Monitoring
//
//  Created by Curtis Netterville on 9/17/25.
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the window on startup - we want the app to start in menu bar only
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.windows.forEach { window in
                window.orderOut(nil)
            }
        }
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
        WindowManager.shared.showMainWindow()
    }
}