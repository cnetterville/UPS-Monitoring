//
//  AsyncSemaphore.swift
//  UPS Monitoring
//
//  Created by Assistant on 12/19/24.
//

import Foundation

/// A semaphore that works with async/await to limit concurrent operations
actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.value = value
    }
    
    func wait() async {
        if value > 0 {
            value -= 1
            return
        }
        
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    func signal() {
        if waiters.isEmpty {
            value += 1
        } else {
            let waiter = waiters.removeFirst()
            waiter.resume()
        }
    }
    
    /// Execute a closure with automatic semaphore management
    func withSemaphore<T>(_ operation: @escaping () async throws -> T) async rethrows -> T {
        await wait()
        
        do {
            let result = try await operation()
            signal()
            return result
        } catch {
            signal()
            throw error
        }
    }
}