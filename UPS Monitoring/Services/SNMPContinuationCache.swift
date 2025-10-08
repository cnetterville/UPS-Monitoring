import Foundation

actor SNMPContinuationCache<ResultType> {
    private var continuations: [UInt32: CheckedContinuation<ResultType, Error>] = [:]
    
    func store(id: UInt32, continuation: CheckedContinuation<ResultType, Error>) {
        continuations[id] = continuation
    }
    
    func take(id: UInt32) -> CheckedContinuation<ResultType, Error>? {
        continuations.removeValue(forKey: id)
    }
}