//
//  PushoverService.swift
//  UPS Monitoring
//
//  Created by Assistant on 5/9/26.
//

import Foundation
import Combine

@MainActor
class PushoverService: ObservableObject {
    static let shared = PushoverService()

    @Published var isConfigured = false
    @Published var isLoading = false
    @Published var appToken: String = "" {
        didSet {
            if !isLoading { updateConfiguration() }
        }
    }
    @Published var userKey: String = "" {
        didSet {
            if !isLoading { updateConfiguration() }
        }
    }

    private var lastNotificationTimes: [String: Date] = [:]
    private let minInterval: TimeInterval = 300

    private init() {
        loadConfiguration()
    }

    // MARK: - Configuration

    private func updateConfiguration() {
        isConfigured = !appToken.isEmpty && !userKey.isEmpty
        saveConfiguration()
    }

    private func saveConfiguration() {
        guard !isLoading else { return }

        do {
            let trimmedToken = appToken.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedKey = userKey.trimmingCharacters(in: .whitespacesAndNewlines)

            if !trimmedToken.isEmpty {
                try KeychainService.shared.store(trimmedToken, for: KeychainService.Keys.pushoverToken)
            } else {
                try? KeychainService.shared.delete(for: KeychainService.Keys.pushoverToken)
            }

            if !trimmedKey.isEmpty {
                try KeychainService.shared.store(trimmedKey, for: KeychainService.Keys.pushoverUserKey)
            } else {
                try? KeychainService.shared.delete(for: KeychainService.Keys.pushoverUserKey)
            }
        } catch {
            print("Failed to save Pushover credentials: \(error.localizedDescription)")
        }
    }

    private func loadConfiguration() {
        isLoading = true

        do {
            appToken = try KeychainService.shared.retrieve(for: KeychainService.Keys.pushoverToken) ?? ""
            userKey = try KeychainService.shared.retrieve(for: KeychainService.Keys.pushoverUserKey) ?? ""
        } catch {
            appToken = ""
            userKey = ""
        }

        isLoading = false
        updateConfiguration()
    }

    func reloadConfiguration() {
        loadConfiguration()
    }

    // MARK: - Sending Notifications

    func sendNotification(title: String, message: String, priority: PushoverPriority = .normal) async throws {
        guard isConfigured else {
            throw PushoverError.notConfigured
        }

        let now = Date()
        let key = "\(title):\(priority.rawValue)"
        if priority != .normal, let last = lastNotificationTimes[key], now.timeIntervalSince(last) < minInterval {
            throw PushoverError.tooFrequent
        }

        let url = URL(string: "https://api.pushover.net/1/messages.json")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "token", value: appToken.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "user", value: userKey.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "message", value: message),
            URLQueryItem(name: "priority", value: String(priority.rawValue)),
            URLQueryItem(name: "sound", value: priority == .high ? "siren" : "pushover")
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if let responseData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Pushover response (\(httpResponse.statusCode)): \(responseData)")
                if httpResponse.statusCode != 200 {
                    if let errors = responseData["errors"] as? [String] {
                        throw PushoverError.apiError(errors.joined(separator: ", "))
                    }
                    throw PushoverError.httpError(httpResponse.statusCode)
                }
            } else if httpResponse.statusCode != 200 {
                throw PushoverError.httpError(httpResponse.statusCode)
            }
        }

        lastNotificationTimes[key] = now
    }

    func queueNotification(title: String, message: String, priority: PushoverPriority = .normal) {
        Task {
            do {
                try await sendNotification(title: title, message: message, priority: priority)
            } catch {
                print("Pushover notification failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Test

    func sendTestNotification() async throws {
        try await sendNotification(
            title: "UPS Monitoring - Test",
            message: "Pushover notifications are working correctly.\n\nSent at: \(Date().formatted())"
        )
    }
}

// MARK: - Supporting Types

enum PushoverPriority: Int {
    case lowest = -2
    case low = -1
    case normal = 0
    case high = 1
}

enum PushoverError: LocalizedError {
    case notConfigured
    case tooFrequent
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Pushover is not configured. Please set your app token and user key."
        case .tooFrequent:
            return "Notification sent too frequently. Please wait before sending the same alert type."
        case .httpError(let code):
            return "Pushover API error: HTTP \(code)"
        case .apiError(let message):
            return "Pushover API error: \(message)"
        }
    }
}
