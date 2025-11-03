# UPS Monitoring

A powerful macOS application for monitoring UPS (Uninterruptible Power Supply) devices in real-time. Built with SwiftUI and supporting both NUT (Network UPS Tools) and SNMP protocols.

![UPS Monitoring](https://img.shields.io/badge/Platform-macOS-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

### 🔋 Real-time UPS Monitoring
- **Battery Status**: Real-time battery charge level, runtime estimates, and charging status
- **Power Metrics**: Input/output voltage, power consumption, load percentage, and frequency
- **System Status**: Online/battery status, alarms, and power failure tracking
- **Energy Tracking**: Cumulative energy consumption, peak power, and efficiency metrics

### 🌐 Multi-Protocol Support
- **NUT Protocol**: Connect to Network UPS Tools servers
- **SNMP Protocol**: Direct SNMP monitoring with RFC 1628 UPS MIB support
- **Device Discovery**: Automatic network discovery of compatible devices
- **Multi-device Support**: Monitor up to 4 UPS devices simultaneously

### 📱 Modern User Interface
- **Liquid Glass Design**: Beautiful translucent interface with dynamic animations
- **Menu Bar Integration**: Quick status overview in the menu bar
- **Dashboard View**: Comprehensive monitoring dashboard
- **Device Management**: Easy device configuration and settings

### 🔔 Smart Notifications
- **Native macOS Notifications**: System notifications for critical events
- **Email Alerts**: Configurable email notifications via Mailjet
- **Customizable Triggers**: Set thresholds for battery levels, power events, and alarms
- **Report Scheduling**: Automated status reports

### 📊 Advanced Features
- **Energy Statistics**: Track power consumption over time
- **Battery Age Tracking**: Monitor battery health and replacement schedules
- **Connectivity Testing**: Built-in network connectivity diagnostics
- **Data Persistence**: Historical data storage and analysis

## Requirements

- **macOS**: 12.0 or later
- **Xcode**: 14.0 or later (for building from source)
- **Network Access**: For connecting to UPS devices
- **UPS Compatibility**: NUT-compatible or SNMP-enabled UPS devices

## Supported UPS Brands

The application has been tested with:
- **CyberPower**: Full SNMP and NUT support
- **APC**: SNMP and NUT support
- **Tripp Lite**: SNMP and NUT support
- **Ubiquiti**: NUT support (with special handling for firmware bugs)
- **Generic**: Any RFC 1628 compliant SNMP device

## Installation

### Download Release
1. Download the latest release from the [Releases](https://github.com/yourusername/ups-monitoring/releases) page
2. Drag `UPS Monitoring.app` to your Applications folder
3. Launch the application

### Build from Source
