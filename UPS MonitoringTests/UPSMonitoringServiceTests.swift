import XCTest
@testable import UPS_Monitoring

final class UPSMonitoringServiceTests: XCTestCase {
    func testAddEditRemoveDevice() {
        let service = UPSMonitoringService()
        let device = UPSDevice(name: "Test UPS", host: "192.168.0.10", port: 3493, connectionType: .nut)

        // Add
        service.addDevice(device)
        XCTAssertEqual(service.devices.count, 1)
        XCTAssertEqual(service.devices.first?.name, "Test UPS")

        // Edit
        var edited = device
        edited.name = "Edited UPS"
        service.updateDevice(edited)
        XCTAssertEqual(service.devices.first?.name, "Edited UPS")

        // Remove
        service.removeDevice(edited)
        XCTAssertEqual(service.devices.count, 0)
    }
}