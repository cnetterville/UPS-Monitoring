//
//  NUTDebugView.swift
//  UPS Monitoring
//
//  Created by AI Assistant
//

import SwiftUI
import Network

struct NUTDebugView: View {
    let device: UPSDevice
    @State private var nutVariables: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Querying NUT variables...")
                        .padding()
                } else if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                } else if nutVariables.isEmpty {
                    Text("No variables found")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(nutVariables, id: \.self) { variable in
                            Text(variable)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
                
                Spacer()
                
                Button("Query NUT Variables") {
                    queryNUTVariables()
                }
                .disabled(isLoading)
                .padding()
            }
            .navigationTitle("NUT Debug")
        }
        .onAppear {
            queryNUTVariables()
        }
    }
    
    private func queryNUTVariables() {
        isLoading = true
        errorMessage = nil
        nutVariables = []
        
        Task {
            await performNUTQuery()
        }
    }
    
    private func performNUTQuery() async {
        let connection = NWConnection(
            host: NWEndpoint.Host(device.host),
            port: NWEndpoint.Port(integerLiteral: UInt16(device.port)),
            using: .tcp
        )
        
        await withCheckedContinuation { continuation in
            connection.start(queue: .global())
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let upsName = device.upsName ?? "ups"
                    let command = "LIST VAR \(upsName)\n"
                    
                    guard let data = command.data(using: .utf8) else {
                        DispatchQueue.main.async {
                            self.errorMessage = "Failed to encode command"
                            self.isLoading = false
                        }
                        connection.cancel()
                        continuation.resume()
                        return
                    }
                    
                    connection.send(content: data, completion: .contentProcessed { error in
                        if let error = error {
                            DispatchQueue.main.async {
                                self.errorMessage = "Send error: \(error.localizedDescription)"
                                self.isLoading = false
                            }
                            connection.cancel()
                            continuation.resume()
                            return
                        }
                        
                        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, error in
                            defer {
                                connection.cancel()
                                continuation.resume()
                            }
                            
                            if let error = error {
                                DispatchQueue.main.async {
                                    self.errorMessage = "Receive error: \(error.localizedDescription)"
                                    self.isLoading = false
                                }
                                return
                            }
                            
                            guard let data = data, let response = String(data: data, encoding: .utf8) else {
                                DispatchQueue.main.async {
                                    self.errorMessage = "Invalid response"
                                    self.isLoading = false
                                }
                                return
                            }
                            
                            DispatchQueue.main.async {
                                self.parseNUTResponse(response)
                                self.isLoading = false
                            }
                        }
                    })
                    
                case .failed(let error):
                    DispatchQueue.main.async {
                        self.errorMessage = "Connection failed: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                    connection.cancel()
                    continuation.resume()
                    
                case .cancelled:
                    DispatchQueue.main.async {
                        self.errorMessage = "Connection cancelled"
                        self.isLoading = false
                    }
                    continuation.resume()
                    
                default:
                    break
                }
            }
            
            // Timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                connection.cancel()
                DispatchQueue.main.async {
                    if self.isLoading {
                        self.errorMessage = "Connection timeout"
                        self.isLoading = false
                    }
                }
                continuation.resume()
            }
        }
    }
    
    private func parseNUTResponse(_ response: String) {
        let lines = response.components(separatedBy: .newlines)
        var variables: [String] = []
        
        for line in lines {
            if line.hasPrefix("VAR ") {
                let components = line.components(separatedBy: " ")
                if components.count >= 3 {
                    let variableName = components[2]
                    let value = components.count > 3 ? components[3...].joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\"", with: "") : ""
                    
                    variables.append("\(variableName) = \(value)")
                }
            }
        }
        
        // Sort variables for easier reading
        self.nutVariables = variables.sorted()
    }
}

struct NUTDebugView_Previews: PreviewProvider {
    static var previews: some View {
        let device = UPSDevice(name: "Test UPS", host: "192.168.1.100", port: 3493, connectionType: .nut)
        NUTDebugView(device: device)
    }
}