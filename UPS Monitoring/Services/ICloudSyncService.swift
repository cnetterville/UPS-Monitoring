//
//  ICloudSyncService.swift
//  UPS Monitoring
//

import Combine
import Foundation

/// Syncs the UPS device list via `NSUbiquitousKeyValueStore`.
///
/// Conflict policy: **the cloud wins**. On launch and whenever the store reports
/// an external change, the cloud-side value replaces the local copy. Local edits
/// are pushed up best-effort but never override a cloud value we have not yet
/// observed (the next external-change notification will re-assert the cloud
/// version if a write race occurred).
@MainActor
final class ICloudSyncService: ObservableObject {
    static let shared = ICloudSyncService()

    private let store = NSUbiquitousKeyValueStore.default
    private let devicesKey = "UPSDevices"
    private let devicesUpdatedKey = "UPSDevicesUpdatedAt"
    private let enabledDefaultsKey = "iCloudSyncEnabled"
    private let lastSyncedDefaultsKey = "iCloudLastSyncedAt"

    /// Called on the main actor whenever the cloud-side device list changes
    /// externally and should overwrite the local copy.
    var onRemoteDevicesChanged: (([UPSDevice]) -> Void)?
    
    /// Most recent time we successfully synced with iCloud (either pushed or pulled).
    @Published private(set) var lastSyncedAt: Date?
    
    /// Whether the user is signed into iCloud on this device.
    var isAccountAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// User-facing toggle. When `false`, this service neither reads from nor
    /// writes to iCloud, and remote-change notifications are ignored.
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledDefaultsKey)
            if isEnabled {
                // Pull cloud state immediately so "cloud wins" still holds when re-enabled.
                store.synchronize()
                if let cloudDevices = loadDevicesIgnoringEnabledFlag() {
                    onRemoteDevicesChanged?(cloudDevices)
                    markSynced()
                }
            }
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: enabledDefaultsKey) == nil {
            defaults.set(true, forKey: enabledDefaultsKey)
        }
        self.isEnabled = defaults.bool(forKey: enabledDefaultsKey)
        let storedSyncTime = defaults.double(forKey: lastSyncedDefaultsKey)
        self.lastSyncedAt = storedSyncTime > 0 ? Date(timeIntervalSince1970: storedSyncTime) : nil
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChangeExternally(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        store.synchronize()
    }
    
    /// Manually re-pulls cloud state and re-applies it. Used by the "Sync Now"
    /// button in the iCloud settings panel.
    func syncNow() {
        guard isEnabled else { return }
        store.synchronize()
        if let devices = loadDevicesIgnoringEnabledFlag() {
            onRemoteDevicesChanged?(devices)
            markSynced()
        }
    }
    
    private func markSynced() {
        let now = Date()
        lastSyncedAt = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastSyncedDefaultsKey)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Devices

    /// Returns the cloud-stored device list, or `nil` if the cloud has no value
    /// or sync is disabled.
    func loadDevices() -> [UPSDevice]? {
        guard isEnabled else { return nil }
        return loadDevicesIgnoringEnabledFlag()
    }

    private func loadDevicesIgnoringEnabledFlag() -> [UPSDevice]? {
        guard let data = store.data(forKey: devicesKey) else { return nil }
        do {
            return try JSONDecoder().decode([UPSDevice].self, from: data)
        } catch {
            print("☁️ Failed to decode devices from iCloud: \(error)")
            return nil
        }
    }

    /// Pushes the device list to iCloud. No-op when sync is disabled or on encode failure.
    func saveDevices(_ devices: [UPSDevice]) {
        guard isEnabled else { return }
        do {
            let data = try JSONEncoder().encode(devices)
            store.set(data, forKey: devicesKey)
            store.set(Date().timeIntervalSince1970, forKey: devicesUpdatedKey)
            store.synchronize()
            markSynced()
            print("☁️ Synced \(devices.count) device(s) to iCloud")
        } catch {
            print("☁️ Failed to encode devices for iCloud: \(error)")
        }
    }

    // MARK: - External change handling

    @objc private func storeDidChangeExternally(_ note: Notification) {
        guard isEnabled else { return }
        let reason = (note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int) ?? -1
        let changedKeys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []

        // Quota violations don't deliver new data — nothing to apply.
        if reason == NSUbiquitousKeyValueStoreQuotaViolationChange { return }

        guard changedKeys.contains(devicesKey) || reason == NSUbiquitousKeyValueStoreInitialSyncChange || reason == NSUbiquitousKeyValueStoreAccountChange else {
            return
        }

        guard let devices = loadDevices() else { return }
        print("☁️ Applying \(devices.count) device(s) from iCloud (reason: \(reason))")
        onRemoteDevicesChanged?(devices)
        markSynced()
    }
}
