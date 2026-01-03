//
//  TrendsView.swift
//  app
//
//  View for displaying biomarker trends with elegant charts
//

import SwiftUI
import Charts
import Combine

// MARK: - Trends View
struct TrendsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = TrendsViewModel()
    @State private var selectedCategory: TrendCategory = .all
    
    enum TrendCategory: String, CaseIterable {
        case all = "All"
        case abnormal = "Needs Attention"
        case normal = "Normal"
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    AppColors.gradientStart(themeManager.colorScheme),
                    AppColors.gradientEnd(themeManager.colorScheme)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if viewModel.isLoading && !viewModel.hasLoaded {
                loadingView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if viewModel.trends.isEmpty && viewModel.hasLoaded {
                emptyStateView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                trendsContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.4), value: viewModel.hasLoaded)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Your Trends")
                    .font(.custom("ProductSans-Bold", size: 18))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
            }
        }
        .task {
            await viewModel.loadTrends()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            CustomSpinner(size: 32, lineWidth: 3)
            
            Text("Loading your trends...")
                .font(.custom("ProductSans-Regular", size: 16))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 64))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            
            Text("No Trends Yet")
                .font(.custom("InstrumentSerif-Regular", size: 36))
                .foregroundColor(AppColors.text(themeManager.colorScheme))
            
            Text("Upload at least one blood test\nto see your biomarker trends")
                .font(.custom("ProductSans-Regular", size: 16))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Trends Content
    private var trendsContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary Header
                summaryHeader
                
                // Category Filter
                categoryFilter
                
                // Trends List
                LazyVStack(spacing: 16) {
                    ForEach(filteredTrends) { trend in
                        BiomarkerTrendCard(trend: trend)
                            .environmentObject(themeManager)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
        }
        .refreshable {
            await viewModel.loadTrends()
        }
    }
    
    // MARK: - Summary Header
    private var summaryHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                Text("Tracking ")
                    .font(.custom("ProductSans-Bold", size: 28))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                
                Text("\(viewModel.trends.count)")
                    .font(.custom("InstrumentSerif-Italic", size: 28))
                    .foregroundColor(AppColors.primary)
                
                Text(" Biomarkers")
                    .font(.custom("ProductSans-Bold", size: 28))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
            }
            
            HStack(spacing: 24) {
                StatBadge(
                    icon: "checkmark.circle.fill",
                    value: "\(viewModel.normalCount)",
                    label: "Normal",
                    color: .green
                )
                
                StatBadge(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(viewModel.abnormalCount)",
                    label: "Attention",
                    color: .orange
                )
                
                StatBadge(
                    icon: "apple.books.pages.fill",
                    value: "\(viewModel.testCount)",
                    label: "Tests",
                    color: AppColors.text(themeManager.colorScheme)
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TrendCategory.allCases, id: \.self) { category in
                    CategoryPill(
                        title: category.rawValue,
                        isSelected: selectedCategory == category,
                        count: countForCategory(category)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                    .environmentObject(themeManager)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Filtered Trends
    private var filteredTrends: [BiomarkerTrend] {
        switch selectedCategory {
        case .all:
            return viewModel.trends
        case .abnormal:
            return viewModel.trends.filter { $0.latestStatus != "normal" }
        case .normal:
            return viewModel.trends.filter { $0.latestStatus == "normal" }
        }
    }
    
    private func countForCategory(_ category: TrendCategory) -> Int {
        switch category {
        case .all:
            return viewModel.trends.count
        case .abnormal:
            return viewModel.abnormalCount
        case .normal:
            return viewModel.normalCount
        }
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.custom("ProductSans-Bold", size: 18))
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.custom("ProductSans-Regular", size: 11))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.custom("ProductSans-Medium", size: 14))
                
                Text("\(count)")
                    .font(.custom("ProductSans-Bold", size: 12))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.3) : AppColors.surface(themeManager.colorScheme))
                    )
            }
            .foregroundColor(isSelected ? .white : AppColors.text(themeManager.colorScheme))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? AppColors.primary : AppColors.surface(themeManager.colorScheme))
            )
        }
    }
}

// MARK: - Biomarker Trend Card
struct BiomarkerTrendCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let trend: BiomarkerTrend
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }) {
                cardHeader
            }
            
            // Expanded Content
            if isExpanded {
                VStack(spacing: 16) {
                    Divider()
                        .background(AppColors.border(themeManager.colorScheme))
                    
                    // Chart
                    if trend.dataPoints.count > 1 {
                        trendChart
                    } else {
                        singleDataPointView
                    }
                    
                    // Data Points List
                    dataPointsList
                }
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(AppColors.surface(themeManager.colorScheme))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Card Header
    private var cardHeader: some View {
        HStack(spacing: 12) {
            // Status Indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            // Marker Name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(trend.marker)
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .lineLimit(1)
                    
                    // Info tooltip for aliases
                    if trend.aliasTooltip != nil {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            .help(trend.aliasTooltip ?? "")
                    }
                }
                
                Text(trend.unit)
                    .font(.custom("ProductSans-Regular", size: 12))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
            
            Spacer()
            
            // Latest Value
            HStack(spacing: 8) {
                if let latestValue = trend.latestValue {
                    Text(formatValue(latestValue))
                        .font(.custom("ProductSans-Bold", size: 18))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
                
                // Expand Icon
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
        }
    }
    
    // MARK: - Trend Chart (iOS 16+)
    @ViewBuilder
    private var trendChart: some View {
        if #available(iOS 16.0, *) {
            Chart {
                // Reference range area
                if let min = trend.referenceMin, let max = trend.referenceMax {
                    RectangleMark(
                        xStart: nil,
                        xEnd: nil,
                        yStart: .value("Min", min),
                        yEnd: .value("Max", max)
                    )
                    .foregroundStyle(Color.green.opacity(0.1))
                }
                
                // Line
                ForEach(trend.dataPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(AppColors.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }
                
                // Points
                ForEach(trend.dataPoints) { point in
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(point.status == "normal" ? Color.green : AppColors.primary)
                    .symbolSize(50)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(trend.dataPoints.count, 5))) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(formatAxisDate(date))
                                .font(.custom("ProductSans-Regular", size: 10))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatValue(doubleValue))
                                .font(.custom("ProductSans-Regular", size: 10))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(AppColors.border(themeManager.colorScheme))
                }
            }
            .chartYScale(domain: chartYDomain)
            .frame(height: 180)
            .padding(.horizontal, 4)
        } else {
            // Fallback for iOS 15
            legacyChart
        }
    }
    
    // MARK: - Legacy Chart (iOS 15)
    private var legacyChart: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let points = trend.dataPoints
            
            ZStack {
                // Reference range
                if let min = trend.referenceMin, let max = trend.referenceMax {
                    let yRange = chartYDomain.upperBound - chartYDomain.lowerBound
                    let minY = height - ((min - chartYDomain.lowerBound) / yRange * height)
                    let maxY = height - ((max - chartYDomain.lowerBound) / yRange * height)
                    
                    Rectangle()
                        .fill(Color.green.opacity(0.1))
                        .frame(height: abs(maxY - minY))
                        .position(x: width / 2, y: (minY + maxY) / 2)
                }
                
                // Line Path
                Path { path in
                    guard points.count > 1 else { return }
                    
                    let yRange = chartYDomain.upperBound - chartYDomain.lowerBound
                    
                    for (index, point) in points.enumerated() {
                        let x = CGFloat(index) / CGFloat(points.count - 1) * width
                        let y = height - ((point.value - chartYDomain.lowerBound) / yRange * height)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(AppColors.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                
                // Points
                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    let yRange = chartYDomain.upperBound - chartYDomain.lowerBound
                    let x = CGFloat(index) / CGFloat(max(points.count - 1, 1)) * width
                    let y = height - ((point.value - chartYDomain.lowerBound) / yRange * height)
                    
                    Circle()
                        .fill(point.status == "normal" ? Color.green : AppColors.primary)
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)
                }
            }
        }
        .frame(height: 150)
        .padding(.horizontal, 8)
    }
    
    // MARK: - Single Data Point View
    private var singleDataPointView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            
            Text("Only one measurement")
                .font(.custom("ProductSans-Regular", size: 14))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            
            Text("Upload more blood tests to see trends")
                .font(.custom("ProductSans-Regular", size: 12))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme).opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Data Points List
    private var dataPointsList: some View {
        VStack(spacing: 8) {
            ForEach(trend.dataPoints.reversed()) { point in
                HStack {
                    Text(point.fullFormattedDate)
                        .font(.custom("ProductSans-Regular", size: 13))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    
                    Spacer()
                    
                    Text(formatValue(point.value))
                        .font(.custom("ProductSans-Medium", size: 13))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                    
                    Circle()
                        .fill(point.status == "normal" ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                }
                .padding(.vertical, 4)
            }
            
            // Reference Range
            if let min = trend.referenceMin, let max = trend.referenceMax {
                HStack {
                    Text("Reference Range")
                        .font(.custom("ProductSans-Regular", size: 12))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    
                    Spacer()
                    
                    Text("\(formatValue(min)) - \(formatValue(max))")
                        .font(.custom("ProductSans-Medium", size: 12))
                        .foregroundColor(Color.green)
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Helper Properties
    private var statusColor: Color {
        switch trend.latestStatus {
        case "normal": return .green
        case "high": return .orange
        case "low": return .orange
        default: return .gray
        }
    }
    
    private var trendColor: Color {
        switch trend.trend {
        case .increasing:
            return trend.latestStatus == "high" ? .red : .green
        case .decreasing:
            return trend.latestStatus == "low" ? .red : .green
        case .stable:
            return .gray
        }
    }
    
    private var chartYDomain: ClosedRange<Double> {
        let values = trend.dataPoints.map { $0.value }
        var minValue = values.min() ?? 0
        var maxValue = values.max() ?? 100
        
        // Include reference range in domain
        if let refMin = trend.referenceMin {
            minValue = min(minValue, refMin)
        }
        if let refMax = trend.referenceMax {
            maxValue = max(maxValue, refMax)
        }
        
        // Add padding
        let padding = (maxValue - minValue) * 0.15
        return (minValue - padding)...(maxValue + padding)
    }
    
    private func formatValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
    
    private func formatAxisDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Trends View Model
@MainActor
class TrendsViewModel: ObservableObject {
    @Published var trends: [BiomarkerTrend] = []
    @Published var isLoading: Bool = false
    @Published var testCount: Int = 0
    @Published var hasLoaded: Bool = false
    
    var normalCount: Int {
        trends.filter { $0.latestStatus == "normal" }.count
    }
    
    var abnormalCount: Int {
        trends.filter { $0.latestStatus != "normal" }.count
    }
    
    func loadTrends() async {
        isLoading = true
        defer { 
            isLoading = false
            hasLoaded = true
        }
        
        // Get analyses from the shared UserDataViewModel
        let analyses = UserDataViewModel.shared.analyses
        testCount = analyses.count
        
        // If no analyses loaded yet, fetch them
        if analyses.isEmpty {
            await UserDataViewModel.shared.refreshAnalyses()
            let refreshedAnalyses = UserDataViewModel.shared.analyses
            testCount = refreshedAnalyses.count
            trends = TrendsService.shared.processTrends(from: refreshedAnalyses)
        } else {
            trends = TrendsService.shared.processTrends(from: analyses)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        TrendsView()
            .environmentObject(ThemeManager.shared)
    }
}
