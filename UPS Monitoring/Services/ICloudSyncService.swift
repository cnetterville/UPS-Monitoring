//
//  ICloudSyncService.swift
//  UPS Monitoring
//

import Foundation

/// Syncs the UPS device list via `NSUbiquitousKeyValueStore`.
///
/// Conflict policy: **the cloud wins**. On launch and whenever the store reports
/// an external change, the cloud-side value replaces the local copy. Local edits
/// are pushed up best-effort but never override a cloud value we have not yet
/// observed (the next external-change notification will re-assert the cloud
/// version if a write race occurred).
@MainActor
final class ICloudSyncService {
    static let shared = ICloudSyncService()

    private let store = NSUbiquitousKeyValueStore.default
    private let devicesKey = "UPSDevices"
    private let devicesUpdatedKey = "UPSDevicesUpdatedAt"

    /// Called on the main actor whenever the cloud-side device list changes
    /// externally and should overwrite the local copy.
    var onRemoteDevicesChanged: (([UPSDevice]) -> Void)?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChangeExternally(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        store.synchronize()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Devices

    /// Returns the cloud-stored device list, or `nil` if the cloud has no value.
    func loadDevices() -> [UPSDevice]? {
        guard let data = store.data(forKey: devicesKey) else { return nil }
        do {
            return try JSONDecoder().decode([UPSDevice].self, from: data)
        } catch {
            print("☁️ Failed to decode devices from iCloud: \(error)")
            return nil
        }
    }

    /// Pushes the device list to iCloud. No-op on encode failure.
    func saveDevices(_ devices: [UPSDevice]) {
        do {
            let data = try JSONEncoder().encode(devices)
            store.set(data, forKey: devicesKey)
            store.set(Date().timeIntervalSince1970, forKey: devicesUpdatedKey)
            store.synchronize()
            print("☁️ Synced \(devices.count) device(s) to iCloud")
        } catch {
            print("☁️ Failed to encode devices for iCloud: \(error)")
        }
    }

    // MARK: - External change handling

    @objc private func storeDidChangeExternally(_ note: Notification) {
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
    }
}
