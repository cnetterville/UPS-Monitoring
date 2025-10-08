import SwiftUI

struct DeviceDiscoveryView: View {
    @ObservedObject var discoveryService: DiscoveryService

    @State private var subnet: String = ""
    @State private var community: String = "public"
    @State private var protocolSelection: UPSDevice.ConnectionType = .snmp
    @Environment(\.dismiss) var dismiss
    @ObservedObject var monitoringService: UPSMonitoringService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Network Device Discovery").font(.title2).bold()
            HStack {
                Picker("Protocol", selection: $protocolSelection) {
                    Text("SNMP").tag(UPSDevice.ConnectionType.snmp)
                    Text("NUT").tag(UPSDevice.ConnectionType.nut)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                TextField("e.g. 192.168.87", text: $subnet)
                    .onChange(of: subnet) { _, newValue in
                        // Enforce max 11 chars (enough for 255.255.255)
                        if newValue.count > 11 { subnet = String(newValue.prefix(11)) }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Subnet regex validation
            let subnetPattern = #"^\d{1,3}\.\d{1,3}\.\d{1,3}$"#
            let isValidSubnet = subnet.range(of: subnetPattern, options: .regularExpression) != nil

            if !subnet.isEmpty && !isValidSubnet {
                Text("Enter a valid subnet prefix, e.g. 192.168.87")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(discoveryService.isScanning ? "Scanning..." : "Start Discovery") {
                Task {
                    if protocolSelection == .snmp {
                        await discoveryService.discoverSNMPDevices(subnet: subnet, community: community)
                    } else {
                        await discoveryService.discoverNUTDevices(subnet: subnet)
                    }
                }
            }
            .disabled(discoveryService.isScanning || !isValidSubnet)
            .padding(.vertical)

            Divider()

            if discoveryService.isScanning {
                ProgressView("Scanning network...")
            } else if discoveryService.discoveredDevices.isEmpty {
                Text("No devices discovered yet.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Found Devices")
                    .font(.headline)
                List {
                    ForEach(discoveryService.discoveredDevices) { device in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.host)
                                    .bold()
                                if let manu = device.manufacturer {
                                    Text(manu).font(.caption)
                                }
                                if let mod = device.model {
                                    Text(mod).font(.caption2)
                                }
                                Text(device.type == .snmp ? "SNMP" : "NUT")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Add") {
                                // Add to monitoring service
                                let newDevice = UPSDevice(
                                    name: device.manufacturer ?? device.model ?? device.host,
                                    host: device.host,
                                    port: device.type == .snmp ? 161 : 3493,
                                    connectionType: device.type,
                                    community: protocolSelection == .snmp ? community : nil,
                                    upsName: device.type == .nut ? "ups" : nil
                                )
                                monitoringService.addDevice(newDevice)
                            }
                            .disabled(monitoringService.devices.contains(where: { $0.host == device.host }))
                        }
                    }
                }
            }

            Spacer()
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 480)
    }
}