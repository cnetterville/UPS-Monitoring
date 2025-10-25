import SwiftUI

@main
struct UPS_MonitoringApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Store the AppDelegate reference for access by other components
        AppDelegateReference.shared = appDelegate
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// Helper class to store AppDelegate reference
class AppDelegateReference {
    static var shared: AppDelegate?
}