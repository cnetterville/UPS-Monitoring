import Foundation
import Network
import SwiftSnmpKit
import Combine

struct DiscoveredUPSDevice: Identifiable {
    let id = UUID()
    let host: String
    let type: UPSDevice.ConnectionType
    let manufacturer: String?
    let model: String?
}

@MainActor
class DiscoveryService: ObservableObject {
    @Published var discoveredDevices: [DiscoveredUPSDevice] = []
    @Published var isScanning = false
    
    private let maxConcurrentScans = 10 // Limit concurrent network operations
    private let scanDelay: TimeInterval = 0.1 // Delay between batches

    func discoverSNMPDevices(subnet: String, community: String = "public") async {
        isScanning = true
        discoveredDevices = []
        
        // Use semaphore to limit concurrent operations
        let semaphore = AsyncSemaphore(value: maxConcurrentScans)
        
        await withTaskGroup(of: DiscoveredUPSDevice?.self) { group in
            for i in 1...254 {
                let ip = "\(subnet).\(i)"
                group.addTask {
                    await semaphore.withSemaphore {
                        // Add small delay to prevent network flooding
                        try? await Task.sleep(nanoseconds: UInt64(self.scanDelay * 1_000_000_000))
                        
                        let result = await SNMPDiscovery.snmpPing(host: ip, community: community)
                        return result
                    }
                }
            }
            for await result in group {
                if let device = result {
                    discoveredDevices.append(device)
                }
            }
        }
        isScanning = false
    }

    func discoverNUTDevices(subnet: String) async {
        isScanning = true
        discoveredDevices = []
        
        // Use semaphore to limit concurrent operations
        let semaphore = AsyncSemaphore(value: maxConcurrentScans)
        
        await withTaskGroup(of: DiscoveredUPSDevice?.self) { group in
            for i in 1...254 {
                let ip = "\(subnet).\(i)"
                group.addTask {
                    await semaphore.withSemaphore {
                        // Add small delay to prevent network flooding
                        try? await Task.sleep(nanoseconds: UInt64(self.scanDelay * 1_000_000_000))
                        
                        let result = await NUTDiscovery.nutPing(host: ip)
                        return result
                    }
                }
            }
            for await result in group {
                if let device = result {
                    discoveredDevices.append(device)
                }
            }
        }
        isScanning = false
    }
}

enum SNMPDiscovery {
    /// Attempts to discover a UPS via SNMP at the given host.
    static func snmpPing(host: String, community: String) async -> DiscoveredUPSDevice? {
        // Note: We'll try to fetch the UPS manufacturer OID, and check for a valid response.
        let oid = "1.3.6.1.2.1.33.1.1.1.0" // Standard UPS-MIB Manufacturer OID

        guard let snmpSender = SnmpSender.shared else { return nil }

        let result = await snmpSender.send(
            host: host,
            command: .getRequest,
            community: community,
            oid: oid
        )

        if case .success(let binding) = result {
            let manufacturer = extractStringFromBinding(binding)
            if let manufacturer, !manufacturer.isEmpty, manufacturer != "noSuchObject" {
                // Optionally get model as well here, using another OID
                let modelResult = await snmpSender.send(
                    host: host,
                    command: .getRequest,
                    community: community,
                    oid: "1.3.6.1.2.1.33.1.1.3.0"
                )
                var model: String? = nil
                if case .success(let mb) = modelResult {
                    model = extractStringFromBinding(mb)
                }
                return DiscoveredUPSDevice(
                    host: host,
                    type: .snmp,
                    manufacturer: manufacturer,
                    model: model
                )
            }
        }
        return nil
    }

    // Utility function (copies what you do in your service)
    private static func extractStringFromBinding(_ binding: Any) -> String? {
        let mirror = Mirror(reflecting: binding)
        for child in mirror.children where child.label == "value" {
            let str = String(describing: child.value)
            return str.replacingOccurrences(of: "Optional(", with: "").replacingOccurrences(of: ")", with: "")
        }
        return nil
    }
}

enum NUTDiscovery {
    /// Attempts to discover a UPS running NUT at the given host.
    static func nutPing(host: String) async -> DiscoveredUPSDevice? {
        let port: UInt16 = 3493
        let timeout: TimeInterval = 2.0
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return nil }
        
        return await withCheckedContinuation { cont in
            let connection = NWConnection(host: .init(host), port: nwPort, using: .tcp)
            
            // Use an actor to safely manage completion state
            actor CompletionTracker {
                private var hasCompleted = false
                
                func tryComplete() -> Bool {
                    if hasCompleted {
                        return false
                    }
                    hasCompleted = true
                    return true
                }
            }
            
            let completionTracker = CompletionTracker()
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    // Send LIST UPS
                    let command = "LIST UPS\n"
                    connection.send(content: command.data(using: .utf8), completion: .contentProcessed { _ in })
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 2048) { data, _, _, _ in
                        Task {
                            if await completionTracker.tryComplete() {
                                if let data, let str = String(data: data, encoding: .utf8), str.contains("UPS") {
                                    cont.resume(returning: DiscoveredUPSDevice(host: host, type: .nut, manufacturer: nil, model: nil))
                                } else {
                                    cont.resume(returning: nil)
                                }
                                connection.cancel()
                            }
                        }
                    }
                case .failed, .cancelled:
                    Task {
                        if await completionTracker.tryComplete() {
                            cont.resume(returning: nil)
                        }
                    }
                default:
                    break
                }
            }
            connection.start(queue: .global())

            // Timeout: cancel the connection after 'timeout' seconds
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if await completionTracker.tryComplete() {
                    cont.resume(returning: nil)
                    connection.cancel()
                }
            }
        }
    }
}