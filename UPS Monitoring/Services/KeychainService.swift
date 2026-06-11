//
//  KeychainService.swift
//  UPS Monitoring
//
//  Created by Assistant on 12/19/24.
//

import Foundation
import Security

/// Service for securely storing and retrieving sensitive data from the macOS Keychain
class KeychainService {
    static let shared = KeychainService()
    
    private init() {}
    
    private let serviceName = "com.yourcompany.upsmonitoring"
    
    // MARK: - Public Methods
    
    /// Store a string value in the keychain
    func store(_ value: String, for key: String) throws {
        let data = value.data(using: .utf8)!
        try storeData(data, for: key)
    }
    
    /// Retrieve a string value from the keychain
    func retrieve(for key: String) throws -> String? {
        guard let data = try retrieveData(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Store data in the keychain
    func storeData(_ data: Data, for key: String) throws {
        // Delete any existing item first
        try? delete(for: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.operationFailed(status)
        }
        
        print("🔐 Stored \(key) in Keychain")
    }
    
    /// Retrieve data from the keychain
    func retrieveData(for key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.operationFailed(status)
        }
        
        print("🔐 Retrieved \(key) from Keychain")
        return result as? Data
    }
    
    /// Delete an item from the keychain
    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        // Don't throw error if item doesn't exist
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.operationFailed(status)
        }
        
        print("🔐 Deleted \(key) from Keychain")
    }
    
    /// Check if an item exists in the keychain
    func exists(for key: String) -> Bool {
        do {
            return try retrieveData(for: key) != nil
        } catch {
            return false
        }
    }
    
    /// Update an existing item in the keychain
    func update(_ value: String, for key: String) throws {
        let data = value.data(using: .utf8)!
        try updateData(data, for: key)
    }
    
    /// Update an existing data item in the keychain
    func updateData(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        
        if status == errSecItemNotFound {
            // Item doesn't exist, store it instead
            try storeData(data, for: key)
            return
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.operationFailed(status)
        }
        
        print("🔐 Updated \(key) in Keychain")
    }
    
    // MARK: - Syncable (iCloud Keychain) helpers
    
    /// Store a string in the keychain marked `kSecAttrSynchronizable` so it
    /// syncs via iCloud Keychain when the user has it enabled. Used for device
    /// credentials so they travel with the iCloud-synced device list.
    func storeSyncable(_ value: String, for key: String) throws {
        let data = value.data(using: .utf8)!
        // Delete any existing copy (in either synchronizable or local form).
        try? deleteSyncable(for: key)
        try? delete(for: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: kCFBooleanTrue!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.operationFailed(status)
        }
    }
    
    /// Retrieve a string stored with `storeSyncable`. Falls back to the
    /// local-only variant for backward compatibility.
    func retrieveSyncable(for key: String) throws -> String? {
        let syncQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kCFBooleanTrue!
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(syncQuery as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        if status != errSecItemNotFound {
            throw KeychainError.operationFailed(status)
        }
        // Fall back to non-synchronizable copy if present.
        return try retrieve(for: key)
    }
    
    /// Delete a syncable item.
    func deleteSyncable(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanTrue!
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.operationFailed(status)
        }
    }
    
    /// Clear all items for this service from the keychain
    func clearAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.operationFailed(status)
        }
        
        print("🔐 Cleared all items from Keychain")
    }
}

// MARK: - KeychainError

enum KeychainError: Error, LocalizedError {
    case operationFailed(OSStatus)
    case invalidData
    case itemNotFound
    
    var errorDescription: String? {
        switch self {
        case .operationFailed(let status):
            return "Keychain operation failed with status: \(status) (\(SecCopyErrorMessageString(status, nil) ?? "Unknown error" as CFString))"
        case .invalidData:
            return "Invalid data provided to keychain operation"
        case .itemNotFound:
            return "Item not found in keychain"
        }
    }
}

// MARK: - Keychain Keys

extension KeychainService {
    struct Keys {
        static let mailjetAPIKey = "mailjet_api_key"
        static let mailjetAPISecret = "mailjet_api_secret"
        static let brevoAPIKey = "brevo_api_key"
        
        // Add more keys as needed for other sensitive data
        static let smtpPassword = "smtp_password"
        static let pushoverToken = "pushover_token"
        static let pushoverUserKey = "pushover_user_key"
        
        static func devicePassword(_ deviceID: UUID) -> String { "device_pw_\(deviceID.uuidString)" }
        static func deviceUsername(_ deviceID: UUID) -> String { "device_user_\(deviceID.uuidString)" }
    }
    
    // MARK: - Device credentials
    
    /// Persist `username` and `password` for a device into the iCloud-syncable
    /// keychain. Passing `nil` removes the stored value.
    func storeDeviceCredentials(deviceID: UUID, username: String?, password: String?) {
        do {
            if let username, !username.isEmpty {
                try storeSyncable(username, for: Keys.deviceUsername(deviceID))
            } else {
                try? deleteSyncable(for: Keys.deviceUsername(deviceID))
                try? delete(for: Keys.deviceUsername(deviceID))
            }
            if let password, !password.isEmpty {
                try storeSyncable(password, for: Keys.devicePassword(deviceID))
            } else {
                try? deleteSyncable(for: Keys.devicePassword(deviceID))
                try? delete(for: Keys.devicePassword(deviceID))
            }
        } catch {
            print("🔐 Failed to store device credentials for \(deviceID): \(error)")
        }
    }
    
    /// Load `username` and `password` for a device from the keychain.
    func loadDeviceCredentials(deviceID: UUID) -> (username: String?, password: String?) {
        let user = try? retrieveSyncable(for: Keys.deviceUsername(deviceID))
        let pass = try? retrieveSyncable(for: Keys.devicePassword(deviceID))
        return (user ?? nil, pass ?? nil)
    }
    
    /// Delete both credential entries for a device.
    func deleteDeviceCredentials(deviceID: UUID) {
        try? deleteSyncable(for: Keys.deviceUsername(deviceID))
        try? deleteSyncable(for: Keys.devicePassword(deviceID))
        try? delete(for: Keys.deviceUsername(deviceID))
        try? delete(for: Keys.devicePassword(deviceID))
    }
}