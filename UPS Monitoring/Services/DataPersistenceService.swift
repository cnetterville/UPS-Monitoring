//
//  DataPersistenceService.swift
//  UPS Monitoring
//
//  Created by AI Assistant on 9/17/25.
//

import Foundation
import SwiftUI

@MainActor
class DataPersistenceService {
    static let shared = DataPersistenceService()
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    
    // MARK: - File URLs
    private var powerSamplesURL: URL {
        documentsDirectory.appendingPathComponent("PowerSamples.json")
    }
    
    private var deviceStatisticsURL: URL {
        documentsDirectory.appendingPathComponent("DeviceStatistics.json")
    }
    
    // MARK: - In-memory caches
    private var powerSamples: [String: [PowerSampleData]] = [:]
    private var deviceStatistics: [String: [DeviceStatisticsData]] = [:]
    
    private var isDirty = false
    private var lastSaveTime = Date()
    private let saveInterval: TimeInterval = 60.0 // Save every minute instead of immediately
    private var saveTimer: Timer?
    private let maxSamplesPerDevice = 10080 // 1 week at 1-minute intervals
    
    // MARK: - Initialization
    
    private init() {
        // Get documents directory
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Load existing data
        loadPowerSamples()
        loadDeviceStatistics()
        
        // Start batched save timer instead of continuous cleanup
        startBatchedSaveTimer()
        
        // Schedule cleanup less frequently (weekly instead of daily)
        schedulePeriodicCleanup()
    }
    
    // Batched saving to reduce I/O
    private func startBatchedSaveTimer() {
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.saveIfNeeded()
            }
        }
    }
    
    private func saveIfNeeded() async {
        guard isDirty else { return }
        
        isDirty = false
        lastSaveTime = Date()
        
        // Perform saves asynchronously to avoid blocking main thread
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                self.savePowerSamples()
            }
            group.addTask { @MainActor in
                self.saveDeviceStatistics()
            }
        }
    }
    
    // Schedule cleanup less frequently
    private func schedulePeriodicCleanup() {
        // Run cleanup weekly instead of continuously
        Timer.scheduledTimer(withTimeInterval: 7 * 24 * 60 * 60, repeats: true) { _ in
            Task { @MainActor in
                await self.cleanupOldData()
            }
        }
    }
    
    // MARK: - Power Sample Management
    
    func savePowerSample(deviceId: UUID, power: Double, voltage: Double?, current: Double?, load: Double?) {
        let sample = PowerSampleData(
            id: UUID(),
            deviceId: deviceId,
            timestamp: Date(),
            powerWatts: power,
            voltageV: voltage,
            currentA: current,
            loadPercent: load
        )
        
        let deviceKey = deviceId.uuidString
        if powerSamples[deviceKey] == nil {
            powerSamples[deviceKey] = []
        }
        
        powerSamples[deviceKey]?.append(sample)
        
        // Limit samples per device to prevent memory bloat
        if let sampleCount = powerSamples[deviceKey]?.count, sampleCount > maxSamplesPerDevice {
            powerSamples[deviceKey]?.removeFirst(sampleCount - maxSamplesPerDevice)
        }
        
        // Mark as dirty instead of immediate save
        isDirty = true
    }
    
    func savePowerSamples(for deviceId: UUID, samples: [PowerSample]) {
        let deviceKey = deviceId.uuidString
        if powerSamples[deviceKey] == nil {
            powerSamples[deviceKey] = []
        }
        
        let sampleData = samples.map { sample in
            PowerSampleData(
                id: UUID(),
                deviceId: deviceId,
                timestamp: sample.timestamp,
                powerWatts: sample.powerWatts,
                voltageV: sample.voltageV,
                currentA: sample.currentA,
                loadPercent: sample.loadPercent
            )
        }
        
        powerSamples[deviceKey]?.append(contentsOf: sampleData)
        savePowerSamples()
    }
    
    func fetchPowerSamples(for deviceId: UUID, since startDate: Date, until endDate: Date = Date()) -> [PowerSample] {
        let deviceKey = deviceId.uuidString
        guard let samples = powerSamples[deviceKey] else { return [] }
        
        return samples
            .filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
            .map { data in
                PowerSample(
                    timestamp: data.timestamp,
                    powerWatts: data.powerWatts,
                    voltageV: data.voltageV,
                    currentA: data.currentA,
                    loadPercent: data.loadPercent
                )
            }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    func getLatestPowerSample(for deviceId: UUID) -> PowerSample? {
        let deviceKey = deviceId.uuidString
        guard let samples = powerSamples[deviceKey],
              let latest = samples.max(by: { $0.timestamp < $1.timestamp }) else { return nil }
        
        return PowerSample(
            timestamp: latest.timestamp,
            powerWatts: latest.powerWatts,
            voltageV: latest.voltageV,
            currentA: latest.currentA,
            loadPercent: latest.loadPercent
        )
    }
    
    // MARK: - Device Statistics Management
    
    func saveDeviceStatistics(deviceId: UUID, status: UPSStatus) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let deviceKey = deviceId.uuidString
        
        if deviceStatistics[deviceKey] == nil {
            deviceStatistics[deviceKey] = []
        }
        
        // Check if we already have stats for today
        if let existingIndex = deviceStatistics[deviceKey]?.firstIndex(where: {
            calendar.isDate($0.date, inSameDayAs: today)
        }) {
            // Update existing stats
            updateStatistics(&deviceStatistics[deviceKey]![existingIndex], with: status)
        } else {
            // Create new stats for today
            let newStats = DeviceStatisticsData(
                id: UUID(),
                deviceId: deviceId,
                date: today,
                lastUpdate: Date()
            )
            deviceStatistics[deviceKey]?.append(newStats)
            
            if let lastIndex = deviceStatistics[deviceKey]?.count {
                updateStatistics(&deviceStatistics[deviceKey]![lastIndex - 1], with: status)
            }
        }
        
        saveDeviceStatistics()
    }
    
    private func updateStatistics(_ stats: inout DeviceStatisticsData, with status: UPSStatus) {
        stats.lastUpdate = Date()
        
        // Update power and energy data
        if let power = status.outputPower {
            stats.totalPowerSamples += 1
            
            let timeIntervalHours = 1.0 / 60.0 // Assuming samples every minute = 1/60 hours
            let powerKW = power / 1000.0 // Convert watts to kilowatts
            let energyKWh = powerKW * timeIntervalHours // kW × hours = kWh
            stats.totalPowerWh += energyKWh * 1000.0 // Convert back to Wh for storage consistency
            
            stats.peakPowerW = max(stats.peakPowerW, power)
            stats.minPowerW = stats.minPowerW == 0 ? power : min(stats.minPowerW, power)
            stats.averagePowerW = (stats.totalPowerWh / 1000.0) / (Double(stats.totalPowerSamples) / 60.0) // Total kWh / total hours
        }
        
        // Update load data
        if let load = status.load {
            stats.peakLoadPercent = max(stats.peakLoadPercent, load)
            stats.minLoadPercent = stats.minLoadPercent == 0 ? load : min(stats.minLoadPercent, load)
        }
        
        // Update battery data
        if let charge = status.batteryCharge {
            stats.minBatteryCharge = stats.minBatteryCharge == 0 ? charge : min(stats.minBatteryCharge, charge)
        }
        
        // Update runtime tracking
        if status.outputSource == "Battery" {
            stats.totalBatteryTime += 1
        }
        
        // Update power failures
        if let failures = status.powerFailures {
            stats.powerFailures = failures
        }
        
        // Track uptime
        if status.isOnline {
            stats.uptimeMinutes += 1
        }
    }
    
    func fetchDeviceStatistics(for deviceId: UUID, since startDate: Date) -> [DeviceStatisticsData] {
        let deviceKey = deviceId.uuidString
        guard let stats = deviceStatistics[deviceKey] else { return [] }
        
        return stats
            .filter { $0.date >= startDate }
            .sorted { $0.date < $1.date }
    }
    
    // MARK: - Energy Data for Charts
    
    func getEnergyDataPoints(for deviceId: UUID, timeRange: EnergyStatsView.TimeRange) -> [EnergyDataPoint] {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-timeRange.interval)
        
        // Determine the appropriate interval for data points
        let intervalMinutes: Int
        switch timeRange {
        case .hour:
            intervalMinutes = 1 // 1-minute intervals
        case .day:
            intervalMinutes = 15 // 15-minute intervals
        case .week:
            intervalMinutes = 60 // 1-hour intervals
        case .month:
            intervalMinutes = 240 // 4-hour intervals
        }
        
        var dataPoints: [EnergyDataPoint] = []
        var currentTime = startDate
        
        while currentTime < endDate {
            let nextTime = currentTime.addingTimeInterval(TimeInterval(intervalMinutes * 60))
            
            // Get power samples for this interval
            let samples = fetchPowerSamples(for: deviceId, since: currentTime, until: nextTime)
            
            if !samples.isEmpty {
                let avgPower = samples.map(\.powerWatts).reduce(0, +) / Double(samples.count)
                let avgLoad = samples.compactMap(\.loadPercent).reduce(0, +) / Double(max(1, samples.compactMap(\.loadPercent).count))
                
                dataPoints.append(EnergyDataPoint(
                    timestamp: currentTime,
                    power: avgPower,
                    loadPercentage: avgLoad
                ))
            }
            
            currentTime = nextTime
        }
        
        return dataPoints
    }
    
    // MARK: - Historical Analytics
    
    func calculateEnergyMetrics(for deviceId: UUID, timeRange: EnergyStatsView.TimeRange) -> EnergyMetrics {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-timeRange.interval)
        
        let samples = fetchPowerSamples(for: deviceId, since: startDate, until: endDate)
        let statistics = fetchDeviceStatistics(for: deviceId, since: startDate)
        
        var totalEnergyWh: Double = 0
        var peakPowerW: Double = 0
        var averagePowerW: Double = 0
        var averageLoad: Double = 0
        var peakLoad: Double = 0
        let averageEfficiency: Double = 92.5 // Default efficiency
        
        if !samples.isEmpty {
            for i in 1..<samples.count {
                let timeDiffHours = samples[i].timestamp.timeIntervalSince(samples[i-1].timestamp) / 3600.0 // Convert seconds to hours
                let avgPowerW = (samples[i].powerWatts + samples[i-1].powerWatts) / 2.0 // Average power in watts
                let avgPowerKW = avgPowerW / 1000.0 // Convert watts to kilowatts
                let energyKWh = avgPowerKW * timeDiffHours // kW × hours = kWh
                totalEnergyWh += energyKWh * 1000.0 // Convert kWh to Wh for consistency
            }
            
            averagePowerW = samples.map(\.powerWatts).reduce(0, +) / Double(samples.count)
            peakPowerW = samples.map(\.powerWatts).max() ?? 0
            
            let loadSamples = samples.compactMap(\.loadPercent)
            if !loadSamples.isEmpty {
                averageLoad = loadSamples.reduce(0, +) / Double(loadSamples.count)
                peakLoad = loadSamples.max() ?? 0
            }
        }
        
        // Aggregate statistics from daily stats
        let totalPowerFailures = statistics.reduce(0) { $0 + $1.powerFailures }
        let totalUptimeMinutes = statistics.reduce(0) { $0 + $1.uptimeMinutes }
        
        return EnergyMetrics(
            totalEnergyWh: totalEnergyWh,
            averagePowerW: averagePowerW,
            peakPowerW: peakPowerW,
            averageLoad: averageLoad,
            peakLoad: peakLoad,
            averageEfficiency: averageEfficiency,
            powerFailures: totalPowerFailures,
            uptimeMinutes: totalUptimeMinutes
        )
    }
    
    // MARK: - File I/O
    
    private func savePowerSamples() {
        do {
            let data = try JSONEncoder().encode(powerSamples)
            try data.write(to: powerSamplesURL)
        } catch {
            print("Failed to save power samples: \(error)")
        }
    }
    
    private func loadPowerSamples() {
        do {
            let data = try Data(contentsOf: powerSamplesURL)
            powerSamples = try JSONDecoder().decode([String: [PowerSampleData]].self, from: data)
        } catch {
            print("Failed to load power samples: \(error)")
            powerSamples = [:]
        }
    }
    
    private func saveDeviceStatistics() {
        do {
            let data = try JSONEncoder().encode(deviceStatistics)
            try data.write(to: deviceStatisticsURL)
        } catch {
            print("Failed to save device statistics: \(error)")
        }
    }
    
    private func loadDeviceStatistics() {
        do {
            let data = try Data(contentsOf: deviceStatisticsURL)
            deviceStatistics = try JSONDecoder().decode([String: [DeviceStatisticsData]].self, from: data)
        } catch {
            print("Failed to load device statistics: \(error)")
            deviceStatistics = [:]
        }
    }
    
    // MARK: - Data Cleanup
    
    private func startPeriodicCleanup() async {
        // Run cleanup every 24 hours
        while !Task.isCancelled {
            await cleanupOldData()
            
            // Sleep for 24 hours
            try? await Task.sleep(nanoseconds: 24 * 60 * 60 * 1_000_000_000)
        }
    }
    
    private func cleanupOldData() async {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .month, value: -6, to: Date())! // Keep 6 months of data
        
        // Clean up old power samples
        for (deviceKey, samples) in powerSamples {
            powerSamples[deviceKey] = samples.filter { $0.timestamp >= cutoffDate }
        }
        
        // Clean up old statistics (keep 1 year)
        let statsDate = calendar.date(byAdding: .year, value: -1, to: Date())!
        for (deviceKey, stats) in deviceStatistics {
            deviceStatistics[deviceKey] = stats.filter { $0.date >= statsDate }
        }
        
        savePowerSamples()
        saveDeviceStatistics()
        print("Cleaned up old data successfully")
    }
    
    // MARK: - Export Functionality
    
    func exportEnergyData(for deviceId: UUID, timeRange: EnergyStatsView.TimeRange) -> URL? {
        let samples = fetchPowerSamples(for: deviceId, since: Date().addingTimeInterval(-timeRange.interval))
        let metrics = calculateEnergyMetrics(for: deviceId, timeRange: timeRange)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var csvContent = "Timestamp,Power (W),Voltage (V),Current (A),Load (%)\n"
        
        for sample in samples {
            let timestamp = dateFormatter.string(from: sample.timestamp)
            let voltage = sample.voltageV?.description ?? ""
            let current = sample.currentA?.description ?? ""
            let load = sample.loadPercent?.description ?? ""
            
            csvContent += "\(timestamp),\(sample.powerWatts),\(voltage),\(current),\(load)\n"
        }
        
        // Add summary
        csvContent += "\n\nSummary\n"
        csvContent += "Total Energy (Wh),\(metrics.totalEnergyWh)\n"
        csvContent += "Average Power (W),\(metrics.averagePowerW)\n"
        csvContent += "Peak Power (W),\(metrics.peakPowerW)\n"
        csvContent += "Average Load (%),\(metrics.averageLoad)\n"
        csvContent += "Peak Load (%),\(metrics.peakLoad)\n"
        
        // Write to temporary file
        let tempDirectory = fileManager.temporaryDirectory
        let fileName = "UPS_Energy_Data_\(dateFormatter.string(from: Date()).replacingOccurrences(of: " ", with: "_")).csv"
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to export data: \(error)")
            return nil
        }
    }
}

// MARK: - Data Models

struct PowerSampleData: Codable {
    let id: UUID
    let deviceId: UUID
    let timestamp: Date
    let powerWatts: Double
    let voltageV: Double?
    let currentA: Double?
    let loadPercent: Double?
}

struct DeviceStatisticsData: Codable {
    let id: UUID
    let deviceId: UUID
    let date: Date
    var lastUpdate: Date
    var totalPowerWh: Double = 0
    var averagePowerW: Double = 0
    var peakPowerW: Double = 0
    var minPowerW: Double = 0
    var peakLoadPercent: Double = 0
    var minLoadPercent: Double = 0
    var minBatteryCharge: Double = 0
    var totalBatteryTime: Int = 0
    var powerFailures: Int = 0
    var uptimeMinutes: Int = 0
    var totalPowerSamples: Int = 0
}

// MARK: - Supporting Types

struct EnergyMetrics {
    let totalEnergyWh: Double
    let averagePowerW: Double
    let peakPowerW: Double
    let averageLoad: Double
    let peakLoad: Double
    let averageEfficiency: Double
    let powerFailures: Int
    let uptimeMinutes: Int
    
    var totalEnergyKWh: Double {
        return totalEnergyWh / 1000.0
    }
    
    var uptimeHours: Double {
        return Double(uptimeMinutes) / 60.0
    }
    
    var dailyAverageKWh: Double {
        let uptimeHours = max(1, Double(uptimeMinutes) / 60.0)
        let dailyHours = uptimeHours / max(1, uptimeHours / 24.0)
        return totalEnergyKWh / max(1, dailyHours)
    }
}