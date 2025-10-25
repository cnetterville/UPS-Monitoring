//
//  EmailTemplateService.swift
//  UPS Monitoring
//
//  Created by Assistant on 12/19/24.
//

import Foundation

/// Service for generating email templates for different UPS alert types
struct EmailTemplateService {
    
    // MARK: - Critical Alerts
    
    static func createCriticalAlert(
        device: UPSDevice,
        status: UPSStatus?,
        alertType: CriticalAlertType,
        additionalInfo: String? = nil
    ) -> EmailMessage {
        let deviceName = device.name
        let subject = "🚨 CRITICAL UPS Alert: \(deviceName) - \(alertType.title)"
        
        let textContent = """
        CRITICAL UPS ALERT
        
        Device: \(deviceName)
        Alert: \(alertType.title)
        Time: \(Date().formatted())
        
        \(alertType.description)
        
        Device Details:
        - Host: \(device.host):\(device.port)
        - Connection: \(device.connectionType.rawValue)
        
        Current Status:
        \(buildStatusText(status: status))
        
        \(additionalInfo ?? "")
        
        IMMEDIATE ACTION REQUIRED
        Please check your UPS device immediately.
        
        ---
        UPS Monitoring System
        """
        
        let htmlContent = buildCriticalEmailHTML(
            deviceName: deviceName,
            alertType: alertType,
            device: device,
            status: status,
            additionalInfo: additionalInfo
        )
        
        return EmailMessage(
            alertType: .critical,
            subject: subject,
            textContent: textContent,
            htmlContent: htmlContent,
            deviceName: deviceName,
            deviceData: buildDeviceData(device: device, status: status)
        )
    }
    
    // MARK: - Warning Alerts
    
    static func createWarningAlert(
        device: UPSDevice,
        status: UPSStatus?,
        alertType: WarningAlertType,
        value: String? = nil,
        threshold: String? = nil
    ) -> EmailMessage {
        let deviceName = device.name
        let subject = "⚠️ UPS Warning: \(deviceName) - \(alertType.title)"
        
        let valueText = value != nil ? "Current Value: \(value!)" : ""
        let thresholdText = threshold != nil ? "Threshold: \(threshold!)" : ""
        
        let textContent = """
        UPS WARNING ALERT
        
        Device: \(deviceName)
        Warning: \(alertType.title)
        Time: \(Date().formatted())
        
        \(alertType.description)
        
        \(valueText)
        \(thresholdText)
        
        Device Details:
        - Host: \(device.host):\(device.port)
        - Connection: \(device.connectionType.rawValue)
        
        Current Status:
        \(buildStatusText(status: status))
        
        Please monitor this device and consider taking preventive action.
        
        ---
        UPS Monitoring System
        """
        
        let htmlContent = buildWarningEmailHTML(
            deviceName: deviceName,
            alertType: alertType,
            device: device,
            status: status,
            value: value,
            threshold: threshold
        )
        
        return EmailMessage(
            alertType: .warning,
            subject: subject,
            textContent: textContent,
            htmlContent: htmlContent,
            deviceName: deviceName,
            deviceData: buildDeviceData(device: device, status: status)
        )
    }
    
    // MARK: - Maintenance Alerts
    
    static func createMaintenanceAlert(
        device: UPSDevice,
        alertType: MaintenanceAlertType,
        details: String? = nil
    ) -> EmailMessage {
        let deviceName = device.name
        let subject = "🔧 UPS Maintenance: \(deviceName) - \(alertType.title)"
        
        let textContent = """
        UPS MAINTENANCE NOTIFICATION
        
        Device: \(deviceName)
        Maintenance: \(alertType.title)
        Time: \(Date().formatted())
        
        \(alertType.description)
        
        \(details ?? "")
        
        Device Details:
        - Host: \(device.host):\(device.port)
        - Connection: \(device.connectionType.rawValue)
        \(device.batteryInstallDate != nil ? "- Battery Installed: \(device.batteryInstallDate!.formatted(date: .abbreviated, time: .omitted))" : "")
        
        Please schedule maintenance at your convenience.
        
        ---
        UPS Monitoring System
        """
        
        let htmlContent = buildMaintenanceEmailHTML(
            deviceName: deviceName,
            alertType: alertType,
            device: device,
            details: details
        )
        
        return EmailMessage(
            alertType: .maintenance,
            subject: subject,
            textContent: textContent,
            htmlContent: htmlContent,
            deviceName: deviceName,
            deviceData: buildDeviceData(device: device, status: nil)
        )
    }
    
    // MARK: - Status Reports
    
    static func createStatusReport(
        devices: [UPSDevice],
        statusData: [UUID: UPSStatus],
        reportType: ReportType
    ) -> EmailMessage {
        let subject = "📊 UPS Status Report - \(reportType.title) (\(Date().formatted(date: .abbreviated, time: .omitted)))"
        
        let textContent = buildReportText(devices: devices, statusData: statusData, reportType: reportType)
        let htmlContent = buildReportHTML(devices: devices, statusData: statusData, reportType: reportType)
        
        return EmailMessage(
            alertType: .report,
            subject: subject,
            textContent: textContent,
            htmlContent: htmlContent,
            deviceName: nil,
            deviceData: nil
        )
    }
    
    // MARK: - Helper Methods
    
    private static func buildStatusText(status: UPSStatus?) -> String {
        guard let status = status else {
            return "- Status: Device Offline"
        }
        
        var statusLines = ["- Status: \(status.isOnline ? "Online" : "Offline")"]
        
        if let batteryCharge = status.batteryCharge {
            statusLines.append("- Battery: \(Int(batteryCharge))%")
        }
        
        if let runtime = status.formattedRuntime {
            statusLines.append("- Runtime: \(runtime)")
        }
        
        if let load = status.load {
            statusLines.append("- Load: \(Int(load))%")
        }
        
        if let temperature = status.temperature {
            statusLines.append("- Temperature: \(Int(temperature))°C")
        }
        
        if let outputSource = status.outputSource {
            statusLines.append("- Power Source: \(outputSource)")
        }
        
        return statusLines.joined(separator: "\n")
    }
    
    private static func buildDeviceData(device: UPSDevice, status: UPSStatus?) -> [String: Any] {
        var data: [String: Any] = [
            "deviceName": device.name,
            "deviceHost": device.host,
            "devicePort": device.port,
            "connectionType": device.connectionType.rawValue
        ]
        
        if let status = status {
            data["isOnline"] = status.isOnline
            data["batteryCharge"] = status.batteryCharge
            data["load"] = status.load
            data["temperature"] = status.temperature
            data["outputSource"] = status.outputSource
        }
        
        return data
    }
    
    private static func buildReportText(devices: [UPSDevice], statusData: [UUID: UPSStatus], reportType: ReportType) -> String {
        let onlineDevices = devices.filter { statusData[$0.id]?.isOnline == true }
        let offlineDevices = devices.filter { statusData[$0.id]?.isOnline != true }
        
        var report = """
        UPS STATUS REPORT - \(reportType.title.uppercased())
        Generated: \(Date().formatted())
        
        SUMMARY:
        - Total Devices: \(devices.count)
        - Online: \(onlineDevices.count)
        - Offline: \(offlineDevices.count)
        
        """
        
        if !onlineDevices.isEmpty {
            report += "\nONLINE DEVICES:\n"
            report += String(repeating: "-", count: 50) + "\n"
            
            for device in onlineDevices {
                if let status = statusData[device.id] {
                    report += """
                    \(device.name) (\(device.host))
                    \(buildStatusText(status: status).replacingOccurrences(of: "- ", with: "  • "))
                    
                    """
                }
            }
        }
        
        if !offlineDevices.isEmpty {
            report += "\nOFFLINE DEVICES:\n"
            report += String(repeating: "-", count: 50) + "\n"
            
            for device in offlineDevices {
                report += "  • \(device.name) (\(device.host)) - OFFLINE\n"
            }
            report += "\n"
        }
        
        report += """
        
        ---
        UPS Monitoring System
        Report generated automatically
        """
        
        return report
    }
    
    // MARK: - HTML Templates
    
    private static func buildCriticalEmailHTML(
        deviceName: String,
        alertType: CriticalAlertType,
        device: UPSDevice,
        status: UPSStatus?,
        additionalInfo: String?
    ) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Critical UPS Alert</title>
        </head>
        <body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f5f5f5;">
            <div style="max-width: 600px; margin: 0 auto; background-color: white; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                <!-- Header -->
                <div style="background: linear-gradient(135deg, #F44336, #D32F2F); color: white; padding: 20px; text-align: center;">
                    <h1 style="margin: 0; font-size: 24px;">🚨 CRITICAL UPS ALERT</h1>
                    <p style="margin: 10px 0 0 0; opacity: 0.9; font-size: 16px;">\(deviceName)</p>
                </div>
                
                <!-- Alert Info -->
                <div style="padding: 20px; border-left: 5px solid #F44336; background-color: #ffebee;">
                    <h2 style="margin: 0 0 10px 0; color: #F44336; font-size: 18px;">\(alertType.title)</h2>
                    <p style="margin: 0; color: #333; line-height: 1.5;">\(alertType.description)</p>
                    <p style="margin: 10px 0 0 0; color: #666; font-size: 14px;">
                        <strong>Time:</strong> \(Date().formatted())
                    </p>
                </div>
                
                <!-- Device Details -->
                <div style="padding: 20px;">
                    <h3 style="margin: 0 0 15px 0; color: #333; font-size: 16px;">Device Information</h3>
                    <table style="width: 100%; border-collapse: collapse;">
                        <tr style="border-bottom: 1px solid #eee;">
                            <td style="padding: 8px 0; font-weight: bold; color: #666;">Device:</td>
                            <td style="padding: 8px 0; color: #333;">\(deviceName)</td>
                        </tr>
                        <tr style="border-bottom: 1px solid #eee;">
                            <td style="padding: 8px 0; font-weight: bold; color: #666;">Host:</td>
                            <td style="padding: 8px 0; color: #333; font-family: monospace;">\(device.host):\(device.port)</td>
                        </tr>
                        <tr style="border-bottom: 1px solid #eee;">
                            <td style="padding: 8px 0; font-weight: bold; color: #666;">Connection:</td>
                            <td style="padding: 8px 0; color: #333;">\(device.connectionType.rawValue.uppercased())</td>
                        </tr>
                    </table>
                </div>
                
                \(buildStatusHTML(status: status))
                
                \(additionalInfo != nil ? """
                <!-- Additional Information -->
                <div style="padding: 20px; background-color: #f9f9f9;">
                    <h3 style="margin: 0 0 10px 0; color: #333; font-size: 16px;">Additional Information</h3>
                    <p style="margin: 0; color: #333; line-height: 1.5;">\(additionalInfo!)</p>
                </div>
                """ : "")
                
                <!-- Action Required -->
                <div style="padding: 20px; background: linear-gradient(135deg, #FF5722, #F44336); color: white; text-align: center;">
                    <h3 style="margin: 0 0 10px 0; font-size: 18px;">⚡ IMMEDIATE ACTION REQUIRED</h3>
                    <p style="margin: 0; opacity: 0.9;">Please check your UPS device immediately.</p>
                </div>
                
                <!-- Footer -->
                <div style="padding: 20px; text-align: center; background-color: #f5f5f5; border-top: 1px solid #ddd;">
                    <p style="margin: 0; color: #666; font-size: 14px;">UPS Monitoring System</p>
                    <p style="margin: 5px 0 0 0; color: #999; font-size: 12px;">Automated alert generated at \(Date().formatted())</p>
                </div>
            </div>
        </body>
        </html>
        """
    }
    
    private static func buildWarningEmailHTML(
        deviceName: String,
        alertType: WarningAlertType,
        device: UPSDevice,
        status: UPSStatus?,
        value: String?,
        threshold: String?
    ) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>UPS Warning Alert</title>
        </head>
        <body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f5f5f5;">
            <div style="max-width: 600px; margin: 0 auto; background-color: white; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                <!-- Header -->
                <div style="background: linear-gradient(135deg, #FF9800, #F57C00); color: white; padding: 20px; text-align: center;">
                    <h1 style="margin: 0; font-size: 24px;">⚠️ UPS WARNING</h1>
                    <p style="margin: 10px 0 0 0; opacity: 0.9; font-size: 16px;">\(deviceName)</p>
                </div>
                
                <!-- Alert Info -->
                <div style="padding: 20px; border-left: 5px solid #FF9800; background-color: #fff3e0;">
                    <h2 style="margin: 0 0 10px 0; color: #FF9800; font-size: 18px;">\(alertType.title)</h2>
                    <p style="margin: 0 0 10px 0; color: #333; line-height: 1.5;">\(alertType.description)</p>
                    
                    \(value != nil && threshold != nil ? """
                    <div style="margin-top: 15px;">
                        <p style="margin: 0; color: #666;"><strong>Current Value:</strong> <span style="color: #FF9800; font-weight: bold;">\(value!)</span></p>
                        <p style="margin: 5px 0 0 0; color: #666;"><strong>Threshold:</strong> \(threshold!)</p>
                    </div>
                    """ : "")
                    
                    <p style="margin: 15px 0 0 0; color: #666; font-size: 14px;">
                        <strong>Time:</strong> \(Date().formatted())
                    </p>
                </div>
                
                <!-- Device Details -->
                <div style="padding: 20px;">
                    <h3 style="margin: 0 0 15px 0; color: #333; font-size: 16px;">Device Information</h3>
                    <table style="width: 100%; border-collapse: collapse;">
                        <tr style="border-bottom: 1px solid #eee;">
                            <td style="padding: 8px 0; font-weight: bold; color: #666;">Device:</td>
                            <td style="padding: 8px 0; color: #333;">\(deviceName)</td>
                        </tr>
                        <tr style="border-bottom: 1px solid #eee;">
                            <td style="padding: 8px 0; font-weight: bold; color: #666;">Host:</td>
                            <td style="padding: 8px 0; color: #333; font-family: monospace;">\(device.host):\(device.port)</td>
                        </tr>
                        <tr style="border-bottom: 1px solid #eee;">
                            <td style="padding: 8px 0; font-weight: bold; color: #666;">Connection:</td>
                            <td style="padding: 8px 0; color: #333;">\(device.connectionType.rawValue.uppercased())</td>
                        </tr>
                    </table>
                </div>
                
                \(buildStatusHTML(status: status))
                
                <!-- Recommendation -->
                <div style="padding: 20px; background-color: #fff3e0; text-align: center;">
                    <h3 style="margin: 0 0 10px 0; color: #FF9800; font-size: 16px;">📋 Recommendation</h3>
                    <p style="margin: 0; color: #333;">Please monitor this device and consider taking preventive action.</p>
                </div>
                
                <!-- Footer -->
                <div style="padding: 20px; text-align: center; background-color: #f5f5f5; border-top: 1px solid #ddd;">
                    <p style="margin: 0; color: #666; font-size: 14px;">UPS Monitoring System</p>
                    <p style="margin: 5px 0 0 0; color: #999; font-size: 12px;">Automated alert generated at \(Date().formatted())</p>
                </div>
            </div>
        </body>
        </html>
        """
    }
    
    private static func buildMaintenanceEmailHTML(
        deviceName: String,
        alertType: MaintenanceAlertType,
        device: UPSDevice,
        details: String?
    ) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>UPS Maintenance Notification</title>
        </head>
        <body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f5f5f5;">
            <div style="max-width: 600px; margin: 0 auto; background-color: white; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                <!-- Header -->
                <div style="background: linear-gradient(135deg, #2196F3, #1976D2); color: white; padding: 20px; text-align: center;">
                    <h1 style="margin: 0; font-size: 24px;">🔧 UPS MAINTENANCE</h1>
                    <p style="margin: 10px 0 0 0; opacity: 0.9; font-size: 16px;">\(deviceName)</p>
                </div>
                
                <!-- Maintenance Info -->
                <div style="padding: 20px; border-left: 5px solid #2196F3; background-color: #e3f2fd;">
                    <h2 style="margin: 0 0 10px 0; color: #2196F3; font-size: 18px;">\(alertType.title)</h2>
                    <p style="margin: 0; color: #333; line-height: 1.5;">\(alertType.description)</p>
                    
                    \(details != nil ? """
                    <div style="margin-top: 15px; padding: 15px; background-color: white; border-radius: 5px;">
                        <h4 style="margin: 0 0 10px 0; color: #2196F3;">Details:</h4>
                        <p style="margin: 0; color: #333; line-height: 1.5;">\(details!)</p>
                    </div>
                    """ : "")
                    
                    <p style="margin: 15px 0 0 0; color: #666; font-size: 14px;">
                        <strong>Notification Date:</strong> \(Date().formatted())
                    </p>
                </div>
                
                <!-- Device Details -->
                <div style="padding: 20px;">
                    <h3 style="margin: 0 0 15px 0; color: #333; font-size: 16px;">Device Information</h3>
                    <table style="width: 100%; border-collapse: collapse;">
                        <tr style="border-bottom: 1px solid #eee;">
                            <td style="padding: 8px 0; font-weight: bold; color: #666;">Device:</td>
                            <td style="padding: 8px 0; color: #333;">\(deviceName)</td>
                        </tr>
                        <tr style="border-bottom: 1px solid #eee;">
                            <td style="padding: 8px 0; font-weight: bold; color: #666;">Host:</td>
                            <td style="padding: 8px 0; color: #333; font-family: monospace;">\(device.host):\(device.port)</td>
                        </tr>
                        <tr style="border-bottom: 1px solid #eee;">
                            <td style="padding: 8px 0; font-weight: bold; color: #666;">Connection:</td>
                            <td style="padding: 8px 0; color: #333;">\(device.connectionType.rawValue.uppercased())</td>
                        </tr>
                        \(device.batteryInstallDate != nil ? """
                        <tr style="border-bottom: 1px solid #eee;">
                            <td style="padding: 8px 0; font-weight: bold; color: #666;">Battery Installed:</td>
                            <td style="padding: 8px 0; color: #333;">\(device.batteryInstallDate!.formatted(date: .abbreviated, time: .omitted))</td>
                        </tr>
                        """ : "")
                    </table>
                </div>
                
                <!-- Action -->
                <div style="padding: 20px; background-color: #e3f2fd; text-align: center;">
                    <h3 style="margin: 0 0 10px 0; color: #2196F3; font-size: 16px;">📅 Action Required</h3>
                    <p style="margin: 0; color: #333;">Please schedule maintenance at your convenience.</p>
                </div>
                
                <!-- Footer -->
                <div style="padding: 20px; text-align: center; background-color: #f5f5f5; border-top: 1px solid #ddd;">
                    <p style="margin: 0; color: #666; font-size: 14px;">UPS Monitoring System</p>
                    <p style="margin: 5px 0 0 0; color: #999; font-size: 12px;">Automated notification generated at \(Date().formatted())</p>
                </div>
            </div>
        </body>
        </html>
        """
    }
    
    private static func buildReportHTML(devices: [UPSDevice], statusData: [UUID: UPSStatus], reportType: ReportType) -> String {
        let onlineDevices = devices.filter { statusData[$0.id]?.isOnline == true }
        let offlineDevices = devices.filter { statusData[$0.id]?.isOnline != true }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>UPS Status Report</title>
        </head>
        <body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f5f5f5;">
            <div style="max-width: 800px; margin: 0 auto; background-color: white; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                <!-- Header -->
                <div style="background: linear-gradient(135deg, #4CAF50, #388E3C); color: white; padding: 30px; text-align: center;">
                    <h1 style="margin: 0; font-size: 28px;">📊 UPS Status Report</h1>
                    <p style="margin: 15px 0 0 0; opacity: 0.9; font-size: 18px;">\(reportType.title)</p>
                    <p style="margin: 5px 0 0 0; opacity: 0.8; font-size: 14px;">Generated: \(Date().formatted())</p>
                </div>
                
                <!-- Summary -->
                <div style="padding: 30px;">
                    <h2 style="margin: 0 0 20px 0; color: #333; font-size: 20px;">Summary</h2>
                    <div style="display: flex; gap: 20px; margin-bottom: 30px;">
                        <div style="flex: 1; text-align: center; padding: 20px; background-color: #f8f9fa; border-radius: 8px;">
                            <div style="font-size: 32px; font-weight: bold; color: #333; margin-bottom: 5px;">\(devices.count)</div>
                            <div style="color: #666; font-size: 14px;">Total Devices</div>
                        </div>
                        <div style="flex: 1; text-align: center; padding: 20px; background-color: #e8f5e8; border-radius: 8px;">
                            <div style="font-size: 32px; font-weight: bold; color: #4CAF50; margin-bottom: 5px;">\(onlineDevices.count)</div>
                            <div style="color: #666; font-size: 14px;">Online</div>
                        </div>
                        <div style="flex: 1; text-align: center; padding: 20px; background-color: #ffebee; border-radius: 8px;">
                            <div style="font-size: 32px; font-weight: bold; color: #F44336; margin-bottom: 5px;">\(offlineDevices.count)</div>
                            <div style="color: #666; font-size: 14px;">Offline</div>
                        </div>
                    </div>
                </div>
                
                \(!onlineDevices.isEmpty ? """
                <!-- Online Devices -->
                <div style="padding: 0 30px 30px 30px;">
                    <h2 style="margin: 0 0 20px 0; color: #333; font-size: 20px;">✅ Online Devices</h2>
                    <div style="border: 1px solid #ddd; border-radius: 8px; overflow: hidden;">
                        <table style="width: 100%; border-collapse: collapse;">
                            <thead>
                                <tr style="background-color: #f8f9fa;">
                                    <th style="padding: 15px; text-align: left; font-weight: bold; color: #333;">Device</th>
                                    <th style="padding: 15px; text-align: center; font-weight: bold; color: #333;">Battery</th>
                                    <th style="padding: 15px; text-align: center; font-weight: bold; color: #333;">Load</th>
                                    <th style="padding: 15px; text-align: center; font-weight: bold; color: #333;">Runtime</th>
                                    <th style="padding: 15px; text-align: center; font-weight: bold; color: #333;">Source</th>
                                </tr>
                            </thead>
                            <tbody>
                                \(onlineDevices.enumerated().map { index, device in
                                    let status = statusData[device.id]
                                    let isEven = index % 2 == 0
                                    return """
                                    <tr style="background-color: \(isEven ? "white" : "#f8f9fa"); border-top: 1px solid #eee;">
                                        <td style="padding: 15px;">
                                            <div style="font-weight: bold; color: #333;">\(device.name)</div>
                                            <div style="font-size: 12px; color: #666; font-family: monospace;">\(device.host):\(device.port)</div>
                                        </td>
                                        <td style="padding: 15px; text-align: center;">
                                            \(status?.batteryCharge != nil ? """
                                            <div style="font-weight: bold; color: \(getBatteryColor(status!.batteryCharge!));">\(Int(status!.batteryCharge!))%</div>
                                            """ : "<span style='color: #999;'>-</span>")
                                        </td>
                                        <td style="padding: 15px; text-align: center;">
                                            \(status?.load != nil ? """
                                            <div style="font-weight: bold; color: \(getLoadColor(status!.load!));">\(Int(status!.load!))%</div>
                                            """ : "<span style='color: #999;'>-</span>")
                                        </td>
                                        <td style="padding: 15px; text-align: center; font-family: monospace;">
                                            \(status?.formattedRuntime ?? "<span style='color: #999;'>-</span>")
                                        </td>
                                        <td style="padding: 15px; text-align: center;">
                                            \(status?.outputSource != nil ? """
                                            <span style="color: \(getSourceColor(status!.outputSource!)); font-weight: bold;">\(status!.outputSource!)</span>
                                            """ : "<span style='color: #999;'>-</span>")
                                        </td>
                                    </tr>
                                    """
                                }.joined())
                            </tbody>
                        </table>
                    </div>
                </div>
                """ : "")
                
                \(!offlineDevices.isEmpty ? """
                <!-- Offline Devices -->
                <div style="padding: 0 30px 30px 30px;">
                    <h2 style="margin: 0 0 20px 0; color: #333; font-size: 20px;">❌ Offline Devices</h2>
                    <div style="border: 1px solid #ddd; border-radius: 8px; overflow: hidden;">
                        \(offlineDevices.map { device in
                            return """
                            <div style="padding: 15px; border-bottom: 1px solid #eee; background-color: #ffebee;">
                                <div style="font-weight: bold; color: #F44336;">\(device.name)</div>
                                <div style="font-size: 12px; color: #666; font-family: monospace; margin-top: 5px;">\(device.host):\(device.port)</div>
                                <div style="font-size: 12px; color: #999; margin-top: 5px;">Last seen: Unknown</div>
                            </div>
                            """
                        }.joined())
                    </div>
                </div>
                """ : "")
                
                <!-- Footer -->
                <div style="padding: 20px; text-align: center; background-color: #f5f5f5; border-top: 1px solid #ddd;">
                    <p style="margin: 0; color: #666; font-size: 14px;">UPS Monitoring System</p>
                    <p style="margin: 5px 0 0 0; color: #999; font-size: 12px;">Automated report generated at \(Date().formatted())</p>
                    <p style="margin: 10px 0 0 0; color: #999; font-size: 11px;">Next \(reportType.title.lowercased()) report: \(getNextReportDate(reportType: reportType).formatted())</p>
                </div>
            </div>
        </body>
        </html>
        """
    }
    
    private static func buildStatusHTML(status: UPSStatus?) -> String {
        guard let status = status else {
            return """
            <!-- Status -->
            <div style="padding: 20px; background-color: #ffebee;">
                <h3 style="margin: 0 0 10px 0; color: #333; font-size: 16px;">Current Status</h3>
                <p style="margin: 0; color: #F44336; font-weight: bold;">⚠️ Device Offline</p>
            </div>
            """
        }
        
        return """
        <!-- Status -->
        <div style="padding: 20px; background-color: #f9f9f9;">
            <h3 style="margin: 0 0 15px 0; color: #333; font-size: 16px;">Current Status</h3>
            <table style="width: 100%; border-collapse: collapse;">
                <tr style="border-bottom: 1px solid #eee;">
                    <td style="padding: 8px 0; font-weight: bold; color: #666;">Status:</td>
                    <td style="padding: 8px 0; color: \(status.isOnline ? "#4CAF50" : "#F44336"); font-weight: bold;">
                        \(status.isOnline ? "🟢 Online" : "🔴 Offline")
                    </td>
                </tr>
                \(status.batteryCharge != nil ? """
                <tr style="border-bottom: 1px solid #eee;">
                    <td style="padding: 8px 0; font-weight: bold; color: #666;">Battery:</td>
                    <td style="padding: 8px 0; color: \(getBatteryColor(status.batteryCharge!)); font-weight: bold;">
                        \(Int(status.batteryCharge!))% 🔋
                    </td>
                </tr>
                """ : "")
                \(status.formattedRuntime != nil ? """
                <tr style="border-bottom: 1px solid #eee;">
                    <td style="padding: 8px 0; font-weight: bold; color: #666;">Runtime:</td>
                    <td style="padding: 8px 0; color: #333; font-family: monospace;">\(status.formattedRuntime!) ⏱️</td>
                </tr>
                """ : "")
                \(status.load != nil ? """
                <tr style="border-bottom: 1px solid #eee;">
                    <td style="padding: 8px 0; font-weight: bold; color: #666;">Load:</td>
                    <td style="padding: 8px 0; color: \(getLoadColor(status.load!)); font-weight: bold;">
                        \(Int(status.load!))% ⚡
                    </td>
                </tr>
                """ : "")
                \(status.temperature != nil ? """
                <tr style="border-bottom: 1px solid #eee;">
                    <td style="padding: 8px 0; font-weight: bold; color: #666;">Temperature:</td>
                    <td style="padding: 8px 0; color: \(getTempColor(status.temperature!)); font-weight: bold;">
                        \(Int(status.temperature!))°C 🌡️
                    </td>
                </tr>
                """ : "")
                \(status.outputSource != nil ? """
                <tr>
                    <td style="padding: 8px 0; font-weight: bold; color: #666;">Power Source:</td>
                    <td style="padding: 8px 0; color: \(getSourceColor(status.outputSource!)); font-weight: bold;">
                        \(status.outputSource!) 🔌
                    </td>
                </tr>
                """ : "")
            </table>
        </div>
        """
    }
    
    // MARK: - Helper Functions
    
    private static func getBatteryColor(_ charge: Double) -> String {
        if charge > 50 { return "#4CAF50" }
        else if charge > 20 { return "#FF9800" }
        else { return "#F44336" }
    }
    
    private static func getLoadColor(_ load: Double) -> String {
        if load > 80 { return "#F44336" }
        else if load > 60 { return "#FF9800" }
        else { return "#4CAF50" }
    }
    
    private static func getTempColor(_ temp: Double) -> String {
        if temp > 40 { return "#F44336" }
        else if temp > 30 { return "#FF9800" }
        else { return "#4CAF50" }
    }
    
    private static func getSourceColor(_ source: String) -> String {
        switch source {
        case "Battery": return "#F44336"
        case "Bypass": return "#FF9800"
        default: return "#4CAF50"
        }
    }
    
    private static func getNextReportDate(reportType: ReportType) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch reportType {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: now) ?? now
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: now) ?? now
        }
    }
}

// MARK: - Alert Type Definitions

enum CriticalAlertType {
    case deviceOffline
    case powerFailure
    case batteryLow(threshold: Double)
    case batteryDepleted
    case overload
    case criticalAlarm
    
    var title: String {
        switch self {
        case .deviceOffline: return "Device Offline"
        case .powerFailure: return "Power Failure"
        case .batteryLow: return "Battery Low"
        case .batteryDepleted: return "Battery Depleted"
        case .overload: return "System Overload"
        case .criticalAlarm: return "Critical Alarm"
        }
    }
    
    var description: String {
        switch self {
        case .deviceOffline:
            return "The UPS device is not responding and appears to be offline. This could indicate a network issue, device failure, or power problem."
        case .powerFailure:
            return "A power failure has been detected. The UPS is now running on battery power to maintain connected equipment."
        case .batteryLow(let threshold):
            return "The UPS battery charge has dropped below \(Int(threshold))%. The system may shut down soon if power is not restored."
        case .batteryDepleted:
            return "The UPS battery is critically depleted. Connected equipment may lose power imminently."
        case .overload:
            return "The UPS is operating beyond its rated capacity. This can cause system instability and potential equipment damage."
        case .criticalAlarm:
            return "The UPS has reported a critical internal alarm. Professional service may be required."
        }
    }
}

enum WarningAlertType {
    case batteryAging
    case highTemperature(temp: Double)
    case highLoad(load: Double)
    case inputVoltageIssue
    case batteryTestFailed
    case maintenanceRequired
    
    var title: String {
        switch self {
        case .batteryAging: return "Battery Aging"
        case .highTemperature: return "High Temperature"
        case .highLoad: return "High Load"
        case .inputVoltageIssue: return "Input Voltage Issue"
        case .batteryTestFailed: return "Battery Test Failed"
        case .maintenanceRequired: return "Maintenance Required"
        }
    }
    
    var description: String {
        switch self {
        case .batteryAging:
            return "The UPS battery is showing signs of aging and may need replacement soon. Consider scheduling a battery replacement."
        case .highTemperature(let temp):
            return "The UPS internal temperature (\(Int(temp))°C) is higher than normal. High temperatures can reduce equipment lifespan."
        case .highLoad(let load):
            return "The UPS is operating at \(Int(load))% capacity. Consider redistributing the load or upgrading to a higher capacity unit."
        case .inputVoltageIssue:
            return "The input voltage is outside normal parameters. This may indicate electrical supply issues."
        case .batteryTestFailed:
            return "The most recent battery self-test failed. The battery may need inspection or replacement."
        case .maintenanceRequired:
            return "The UPS is indicating that routine maintenance is required. Schedule service to ensure optimal performance."
        }
    }
}

enum MaintenanceAlertType {
    case batteryReplacement(age: Int)
    case scheduledMaintenance
    case firmwareUpdate
    case calibrationRequired
    case filterReplacement
    
    var title: String {
        switch self {
        case .batteryReplacement: return "Battery Replacement Due"
        case .scheduledMaintenance: return "Scheduled Maintenance"
        case .firmwareUpdate: return "Firmware Update Available"
        case .calibrationRequired: return "Calibration Required"
        case .filterReplacement: return "Filter Replacement"
        }
    }
    
    var description: String {
        switch self {
        case .batteryReplacement(let age):
            return "The UPS battery is \(age) years old and should be replaced. Typical battery life is 3-5 years depending on usage and environment."
        case .scheduledMaintenance:
            return "Routine maintenance is due for this UPS unit. Regular maintenance helps ensure reliable operation and extends equipment life."
        case .firmwareUpdate:
            return "A firmware update is available for this UPS. Updates often include performance improvements and security patches."
        case .calibrationRequired:
            return "The UPS battery runtime calibration should be performed to ensure accurate remaining time estimates."
        case .filterReplacement:
            return "The UPS air filter should be cleaned or replaced to maintain proper cooling and prevent dust buildup."
        }
    }
}

enum ReportType: CaseIterable {
    case daily
    case weekly
    case monthly
    
    var title: String {
        switch self {
        case .daily: return "Daily Report"
        case .weekly: return "Weekly Report"
        case .monthly: return "Monthly Report"
        }
    }
}