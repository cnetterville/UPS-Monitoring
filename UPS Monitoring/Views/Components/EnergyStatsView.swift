//
//  EnergyStatsView.swift
//  UPS Monitoring
//
//  Created by AI Assistant on 9/17/25.
//

import SwiftUI
import Charts

struct EnergyStatsView: View {
    let device: UPSDevice
    let status: UPSStatus?
    @ObservedObject var monitoringService: UPSMonitoringService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var hoveredCard: String? = nil
    @State private var selectedTimeRange: TimeRange = .hour
    @State private var energyData: [EnergyDataPoint] = []
    @State private var energyMetrics: EnergyMetrics? = nil
    @State private var isLoading = true
    
    private let dataService = DataPersistenceService.shared
    
    enum TimeRange: String, CaseIterable {
        case hour = "1H"
        case day = "24H"
        case week = "7D"
        case month = "30D"
        
        var title: String {
            switch self {
            case .hour: return "Last Hour"
            case .day: return "Last 24 Hours"
            case .week: return "Last Week"
            case .month: return "Last Month"
            }
        }
        
        var interval: TimeInterval {
            switch self {
            case .hour: return 3600
            case .day: return 86400
            case .week: return 604800
            case .month: return 2592000
            }
        }
    }
    
    var body: some View {
        ZStack {
            LiquidGlassBackground()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Current consumption summary
                        currentConsumptionView
                        
                        // Time range picker
                        timeRangePickerView
                        
                        // Power consumption chart
                        powerChartView
                        
                        // Load pattern chart
                        loadPatternView
                        
                        // Energy efficiency metrics
                        efficiencyMetricsView
                        
                        // Historical statistics
                        historicalStatsView
                        
                        // Cost estimation (if configured)
                        costEstimationView
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 900, height: 700)
        .onAppear {
            loadEnergyData()
        }
        .onChange(of: selectedTimeRange) { oldValue, newValue in
            loadEnergyData()
        }
    }
    
    private var headerView: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "energy-header") {
            HStack {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.yellow.opacity(0.4),
                                        Color.orange.opacity(0.2),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 30
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.yellow, Color.orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Energy Statistics")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        colorScheme == .dark ? Color.white : Color.black,
                                        Color.yellow.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text(device.name)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                LiquidGlassButton("Close", icon: "xmark", style: .secondary) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
    }
    
    private var currentConsumptionView: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "current-consumption") {
            VStack(alignment: .leading, spacing: 20) {
                Text("Current Consumption")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                HStack(spacing: 24) {
                    // Real-time power consumption
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.circle.fill")
                                .foregroundStyle(Color.yellow)
                            Text("Power Draw")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        if let power = status?.outputPower, power > 0 {
                            Text("\(Int(power))W")
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.yellow, Color.orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        } else {
                            Text("--W")
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Load percentage with circular progress
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .trim(from: 0, to: (status?.load ?? 0) / 100)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.green,
                                            (status?.load ?? 0) > 70 ? Color.orange : Color.green,
                                            (status?.load ?? 0) > 90 ? Color.red : Color.green
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 1), value: status?.load)
                            
                            VStack(spacing: 2) {
                                Text("\(Int(status?.load ?? 0))%")
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                
                                Text("Load")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // Efficiency indicator
                if let inputVoltage = status?.inputVoltage,
                   let outputVoltage = status?.outputVoltage,
                   let power = status?.outputPower,
                   inputVoltage > 0 && outputVoltage > 0 && power > 0 {
                    
                    let efficiency = min((outputVoltage / inputVoltage) * 100, 100)
                    
                    HStack {
                        Text("Efficiency:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(String(format: "%.1f%%", efficiency))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(
                                efficiency > 90 ? .green :
                                efficiency > 80 ? .orange : .red
                            )
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    private var timeRangePickerView: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "time-range") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Time Range")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                HStack(spacing: 12) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Button {
                            selectedTimeRange = range
                        } label: {
                            Text(range.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(
                                    selectedTimeRange == range ? .white : .secondary
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            selectedTimeRange == range ?
                                            LinearGradient(
                                                colors: [Color.blue, Color.cyan],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ) :
                                            LinearGradient(
                                                colors: [Color.clear],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    selectedTimeRange == range ?
                                                    Color.clear :
                                                    Color.secondary.opacity(0.3),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTimeRange)
                    }
                }
            }
        }
    }
    
    private var powerChartView: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "power-chart") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Power Consumption")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading chart data...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(height: 200)
                } else if energyData.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.downtrend.xyaxis")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        
                        Text("No data available")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("Energy data will appear here once monitoring has been active for longer.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(height: 200)
                } else {
                    Chart(energyData) { dataPoint in
                        LineMark(
                            x: .value("Time", dataPoint.timestamp),
                            y: .value("Power", dataPoint.power)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        
                        AreaMark(
                            x: .value("Time", dataPoint.timestamp),
                            y: .value("Power", dataPoint.power)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.yellow.opacity(0.3),
                                    Color.orange.opacity(0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: selectedTimeRange == .hour ? 1 : 4)) { _ in
                            AxisTick()
                            AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisTick()
                            AxisValueLabel {
                                if let power = value.as(Double.self) {
                                    Text("\(Int(power))W")
                                }
                            }
                        }
                    }
                    .chartYScale(domain: 0...(energyData.map(\.power).max() ?? 100) * 1.1)
                }
            }
        }
    }
    
    private var loadPatternView: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "load-pattern") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Load Pattern")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                if !energyData.isEmpty {
                    Chart(energyData) { dataPoint in
                        BarMark(
                            x: .value("Time", dataPoint.timestamp),
                            y: .value("Load", dataPoint.loadPercentage)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    dataPoint.loadPercentage > 80 ? Color.red :
                                    dataPoint.loadPercentage > 60 ? Color.orange : Color.green,
                                    (dataPoint.loadPercentage > 80 ? Color.red :
                                     dataPoint.loadPercentage > 60 ? Color.orange : Color.green).opacity(0.6)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .frame(height: 150)
                    .chartYScale(domain: 0...100)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: selectedTimeRange == .hour ? 1 : 6)) { _ in
                            AxisTick()
                            AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisTick()
                            AxisValueLabel {
                                if let load = value.as(Double.self) {
                                    Text("\(Int(load))%")
                                }
                            }
                        }
                    }
                } else {
                    Text("Load pattern data will appear here")
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var efficiencyMetricsView: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "efficiency-metrics") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Efficiency Metrics")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    // Average efficiency
                    MetricTile(
                        title: "Avg Efficiency",
                        value: calculateAverageEfficiency(),
                        unit: "%",
                        icon: "gauge.high",
                        color: .green
                    )
                    
                    // Energy consumed
                    MetricTile(
                        title: "Energy Used",
                        value: String(format: "%.2f", calculateEnergyConsumed()),
                        unit: "kWh",
                        icon: "bolt.circle",
                        color: .yellow
                    )
                    
                    // Peak load
                    MetricTile(
                        title: "Peak Load",
                        value: String(format: "%.0f", calculatePeakLoad()),
                        unit: "%",
                        icon: "arrow.up.circle",
                        color: .red
                    )
                    
                    // Average load
                    MetricTile(
                        title: "Avg Load",
                        value: String(format: "%.0f", calculateAverageLoad()),
                        unit: "%",
                        icon: "minus.circle",
                        color: .blue
                    )
                }
            }
        }
    }
    
    private var historicalStatsView: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "historical-stats") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Historical Statistics")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Spacer()
                    
                    LiquidGlassButton("Export CSV", icon: "square.and.arrow.up", style: .secondary) {
                        exportData()
                    }
                }
                
                VStack(spacing: 12) {
                    StatRow(
                        title: "Total Runtime",
                        value: formatDuration(getTotalRuntime()),
                        icon: "clock"
                    )
                    
                    StatRow(
                        title: "Power Events",
                        value: "\(energyMetrics?.powerFailures ?? 0)",
                        icon: "exclamationmark.triangle"
                    )
                    
                    StatRow(
                        title: "Avg Daily Usage",
                        value: String(format: "%.1f kWh", calculateDailyAverage()),
                        icon: "calendar"
                    )
                    
                    if let lastUpdate = status?.lastUpdate {
                        StatRow(
                            title: "Last Updated",
                            value: formatRelativeTime(lastUpdate),
                            icon: "arrow.clockwise"
                        )
                    }
                    
                    if let metrics = energyMetrics {
                        StatRow(
                            title: "Peak Power",
                            value: String(format: "%.0f W", metrics.peakPowerW),
                            icon: "bolt.circle"
                        )
                        
                        StatRow(
                            title: "Uptime",
                            value: String(format: "%.1f hours", metrics.uptimeHours),
                            icon: "checkmark.circle"
                        )
                    }
                }
            }
        }
    }
    
    private var costEstimationView: some View {
        LiquidGlassCard(hoveredCard: $hoveredCard, cardId: "cost-estimation") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Cost Estimation")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Spacer()
                    
                    Text("$0.12/kWh")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .opacity(0.5)
                        )
                }
                
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Period")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Text("$\(String(format: "%.2f", calculateCost(for: selectedTimeRange)))")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Monthly Est.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Text("$\(String(format: "%.2f", calculateMonthlyCost()))")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadEnergyData() {
        isLoading = true
        
        Task {
            // Load real data from persistence
            let dataPoints = dataService.getEnergyDataPoints(for: device.id, timeRange: selectedTimeRange)
            let metrics = dataService.calculateEnergyMetrics(for: device.id, timeRange: selectedTimeRange)
            
            await MainActor.run {
                self.energyData = dataPoints
                self.energyMetrics = metrics
                self.isLoading = false
            }
        }
    }
    
    private func calculateAverageEfficiency() -> String {
        return energyMetrics?.averageEfficiency.formatted(.number.precision(.fractionLength(1))) ?? "--"
    }
    
    private func calculateEnergyConsumed() -> Double {
        return energyMetrics?.totalEnergyWh ?? 0
    }
    
    private func calculatePeakLoad() -> Double {
        return energyMetrics?.peakLoad ?? 0
    }
    
    private func calculateAverageLoad() -> Double {
        return energyMetrics?.averageLoad ?? 0
    }
    
    private func getTotalRuntime() -> TimeInterval {
        return Double(energyMetrics?.uptimeMinutes ?? 0) * 60 // Convert minutes to seconds
    }
    
    private func calculateDailyAverage() -> Double {
        return energyMetrics?.dailyAverageKWh ?? 0
    }
    
    private func calculateCost(for range: TimeRange) -> Double {
        let energyUsedKWh = calculateEnergyConsumed() / 1000.0
        return energyUsedKWh * 0.12 // $0.12 per kWh
    }
    
    private func calculateMonthlyCost() -> Double {
        let dailyAverage = calculateDailyAverage()
        return dailyAverage * 30 * 0.12
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        return "\(days)d \(hours)h"
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func exportData() {
        Task {
            if let fileURL = dataService.exportEnergyData(for: device.id, timeRange: selectedTimeRange) {
                await MainActor.run {
                    // Show share sheet (you might want to implement this with a proper share sheet)
                    NSWorkspace.shared.open(fileURL)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct MetricTile: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 16)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                
                Text(unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .opacity(0.3)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Data Model

struct EnergyDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let power: Double // Watts
    let loadPercentage: Double // 0-100
}

#Preview {
    EnergyStatsView(
        device: UPSDevice(
            name: "Main UPS",
            host: "192.168.1.100",
            port: 3493,
            connectionType: .nut
        ),
        status: UPSStatus(deviceId: UUID()),
        monitoringService: UPSMonitoringService()
    )
}