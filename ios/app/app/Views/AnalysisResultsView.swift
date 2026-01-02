import SwiftUI
import Foundation
import Combine

// MARK: - Stored Chat Message Model
struct StoredChatMessage: Codable, Identifiable {
    let id: String
    let role: String
    let content: String
    let createdAt: Date
    
    init(id: String = UUID().uuidString, role: String, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

// MARK: - Analysis Chat Storage
class AnalysisChatStorage {
    static let shared = AnalysisChatStorage()
    
    private let userDefaults = UserDefaults.standard
    private let storageKeyPrefix = "analysis_chat_"
    
    private init() {}
    
    private func storageKey(for analysisId: String) -> String {
        return "\(storageKeyPrefix)\(analysisId)"
    }
    
    func loadMessages(for analysisId: String) -> [StoredChatMessage] {
        let key = storageKey(for: analysisId)
        
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }
        
        do {
            let messages = try JSONDecoder().decode([StoredChatMessage].self, from: data)
            return messages.sorted { $0.createdAt < $1.createdAt }
        } catch {
            print("Error loading chat messages: \(error)")
            return []
        }
    }
    
    func saveMessages(_ messages: [StoredChatMessage], for analysisId: String) {
        let key = storageKey(for: analysisId)
        
        do {
            let data = try JSONEncoder().encode(messages)
            userDefaults.set(data, forKey: key)
        } catch {
            print("Error saving chat messages: \(error)")
        }
    }
    
    func addMessage(_ message: StoredChatMessage, for analysisId: String) {
        var messages = loadMessages(for: analysisId)
        messages.append(message)
        saveMessages(messages, for: analysisId)
    }
    
    func clearMessages(for analysisId: String) {
        let key = storageKey(for: analysisId)
        userDefaults.removeObject(forKey: key)
    }
}

// MARK: - Markdown Text View
struct MarkdownTextView: View {
    let text: String
    let textColor: Color
    let fontSize: CGFloat
    
    init(_ text: String, textColor: Color = .primary, fontSize: CGFloat = 15) {
        self.text = text
        self.textColor = textColor
        self.fontSize = fontSize
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseMarkdown().enumerated()), id: \.offset) { _, element in
                element
            }
        }
    }
    
    private func parseMarkdown() -> [AnyView] {
        var views: [AnyView] = []
        let lines = text.components(separatedBy: "\n")
        var currentParagraph = ""
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Check for numbered list
            if let match = trimmedLine.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                if !currentParagraph.isEmpty {
                    views.append(AnyView(createFormattedText(currentParagraph)))
                    currentParagraph = ""
                }
                
                let content = String(trimmedLine[match.upperBound...])
                views.append(AnyView(
                    HStack(alignment: .top, spacing: 8) {
                        Text(String(trimmedLine[..<match.upperBound]))
                            .font(.custom("ProductSans-Bold", size: fontSize))
                            .foregroundColor(textColor)
                            .frame(width: 24, alignment: .trailing)
                        createFormattedText(content)
                    }
                ))
            }
            // Check for bullet point
            else if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("• ") || trimmedLine.hasPrefix("* ") {
                if !currentParagraph.isEmpty {
                    views.append(AnyView(createFormattedText(currentParagraph)))
                    currentParagraph = ""
                }
                
                let content = String(trimmedLine.dropFirst(2))
                views.append(AnyView(
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.custom("ProductSans-Bold", size: fontSize))
                            .foregroundColor(textColor)
                            .frame(width: 16, alignment: .center)
                        createFormattedText(content)
                    }
                ))
            }
            // Check for headers
            else if trimmedLine.hasPrefix("### ") {
                if !currentParagraph.isEmpty {
                    views.append(AnyView(createFormattedText(currentParagraph)))
                    currentParagraph = ""
                }
                let content = String(trimmedLine.dropFirst(4))
                views.append(AnyView(
                    Text(content)
                        .font(.custom("ProductSans-Bold", size: fontSize + 2))
                        .foregroundColor(textColor)
                        .padding(.top, 4)
                ))
            }
            else if trimmedLine.hasPrefix("## ") {
                if !currentParagraph.isEmpty {
                    views.append(AnyView(createFormattedText(currentParagraph)))
                    currentParagraph = ""
                }
                let content = String(trimmedLine.dropFirst(3))
                views.append(AnyView(
                    Text(content)
                        .font(.custom("ProductSans-Bold", size: fontSize + 4))
                        .foregroundColor(textColor)
                        .padding(.top, 6)
                ))
            }
            else if trimmedLine.hasPrefix("# ") {
                if !currentParagraph.isEmpty {
                    views.append(AnyView(createFormattedText(currentParagraph)))
                    currentParagraph = ""
                }
                let content = String(trimmedLine.dropFirst(2))
                views.append(AnyView(
                    Text(content)
                        .font(.custom("ProductSans-Bold", size: fontSize + 6))
                        .foregroundColor(textColor)
                        .padding(.top, 8)
                ))
            }
            // Empty line
            else if trimmedLine.isEmpty {
                if !currentParagraph.isEmpty {
                    views.append(AnyView(createFormattedText(currentParagraph)))
                    currentParagraph = ""
                }
            }
            // Regular text
            else {
                if !currentParagraph.isEmpty {
                    currentParagraph += " "
                }
                currentParagraph += trimmedLine
            }
        }
        
        if !currentParagraph.isEmpty {
            views.append(AnyView(createFormattedText(currentParagraph)))
        }
        
        return views
    }
    
    private func createFormattedText(_ text: String) -> some View {
        var attributedString = AttributedString(text)
        attributedString = processBold(attributedString)
        attributedString = processItalic(attributedString)
        attributedString = processInlineCode(attributedString)
        
        return Text(attributedString)
            .font(.custom("ProductSans-Regular", size: fontSize))
            .foregroundColor(textColor)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private func processBold(_ input: AttributedString) -> AttributedString {
        var result = input
        let string = String(result.characters)
        let pattern = #"\*\*(.+?)\*\*"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: string, options: [], range: NSRange(string.startIndex..., in: string))
            
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: string),
                      let contentRange = Range(match.range(at: 1), in: string) else { continue }
                
                let content = String(string[contentRange])
                var replacement = AttributedString(content)
                replacement.font = .custom("ProductSans-Bold", size: fontSize)
                
                if let attrRange = result.range(of: String(string[fullRange])) {
                    result.replaceSubrange(attrRange, with: replacement)
                }
            }
        }
        
        return result
    }
    
    private func processItalic(_ input: AttributedString) -> AttributedString {
        var result = input
        let string = String(result.characters)
        let pattern = #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: string, options: [], range: NSRange(string.startIndex..., in: string))
            
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: string),
                      let contentRange = Range(match.range(at: 1), in: string) else { continue }
                
                let content = String(string[contentRange])
                var replacement = AttributedString(content)
                replacement.font = .custom("ProductSans-Regular", size: fontSize).italic()
                
                if let attrRange = result.range(of: String(string[fullRange])) {
                    result.replaceSubrange(attrRange, with: replacement)
                }
            }
        }
        
        return result
    }
    
    private func processInlineCode(_ input: AttributedString) -> AttributedString {
        var result = input
        let string = String(result.characters)
        let pattern = #"`(.+?)`"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: string, options: [], range: NSRange(string.startIndex..., in: string))
            
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: string),
                      let contentRange = Range(match.range(at: 1), in: string) else { continue }
                
                let content = String(string[contentRange])
                var replacement = AttributedString(content)
                replacement.font = .system(size: fontSize - 1, design: .monospaced)
                replacement.backgroundColor = Color.gray.opacity(0.2)
                
                if let attrRange = result.range(of: String(string[fullRange])) {
                    result.replaceSubrange(attrRange, with: replacement)
                }
            }
        }
        
        return result
    }
}

// MARK: - Circular Progress Component
struct CircularProgressView: View {
    let percentage: Int
    var size: CGFloat = 80
    var customColor: Color? = nil
    
    private var strokeWidth: CGFloat { 8 }
    private var radius: CGFloat { (size - strokeWidth) / 2 }
    
    private var progressColor: Color {
        if let color = customColor {
            return color
        }
        if percentage >= 80 {
            return Color(hex: "#10b981") // green
        } else if percentage >= 60 {
            return Color(hex: "#f59e0b") // yellow
        }
        return Color(hex: "#ef4444") // red
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: strokeWidth)
                .frame(width: size, height: size)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: CGFloat(percentage) / 100)
                .stroke(progressColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
            
            // Percentage text
            Text("\(percentage)%")
                .font(.custom("ProductSans-Bold", size: size * 0.2))
                .foregroundColor(progressColor)
        }
    }
}

// MARK: - Range Bar Component
struct RangeBarView: View {
    let value: Double
    let min: Double
    let max: Double
    let unit: String
    let status: String
    
    private var percentage: Double {
        let pct = ((value - min) / (max - min)) * 100
        return Swift.max(0, Swift.min(100, pct))
    }
    
    private var statusColor: Color {
        switch status {
        case "normal":
            return Color(hex: "#10b981")
        case "low":
            return Color(hex: "#f59e0b")
        default:
            return Color(hex: "#ef4444")
        }
    }
    
    // Use the actual status to determine which zone to light up
    private var activeZone: String {
        switch status.lowercased() {
        case "normal":
            return "normal"
        case "low":
            return "low"
        case "high":
            return "high"
        default:
            return "normal"
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Range bar track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track with zones - light up based on actual status
                    HStack(spacing: 0) {
                        // Low zone (left 20%)
                        Rectangle()
                            .fill(Color(hex: "#f59e0b").opacity(activeZone == "low" ? 1.0 : 0.3))
                            .frame(width: geometry.size.width * 0.2)
                        
                        // Normal zone (middle 60%)
                        Rectangle()
                            .fill(Color(hex: "#10b981").opacity(activeZone == "normal" ? 1.0 : 0.3))
                            .frame(width: geometry.size.width * 0.6)
                        
                        // High zone (right 20%)
                        Rectangle()
                            .fill(Color(hex: "#ef4444").opacity(activeZone == "high" ? 1.0 : 0.3))
                            .frame(width: geometry.size.width * 0.2)
                    }
                    .frame(height: 8)
                    .cornerRadius(4)
                    
                    // Marker
                    Circle()
                        .fill(statusColor)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                        )
                        .offset(x: (geometry.size.width * CGFloat(percentage) / 100) - 10)
                }
            }
            .frame(height: 20)
            
            // Labels
            HStack {
                Text(String(format: "%.0f", min))
                    .font(.custom("ProductSans-Regular", size: 12))
                    .foregroundColor(Color.gray)
                
                Spacer()
                
                Text("\(String(format: "%.1f", value)) \(unit)")
                    .font(.custom("ProductSans-Bold", size: 14))
                    .foregroundColor(statusColor)
                
                Spacer()
                
                Text(String(format: "%.0f", max))
                    .font(.custom("ProductSans-Regular", size: 12))
                    .foregroundColor(Color.gray)
            }
        }
    }
}

// MARK: - Status Badge Component
struct StatusBadge: View {
    let status: String
    
    private var backgroundColor: Color {
        switch status.lowercased() {
        case "normal":
            return Color(hex: "#10b981")
        case "low":
            return Color(hex: "#f59e0b")
        default:
            return Color(hex: "#ef4444")
        }
    }
    
    var body: some View {
        Text(status.uppercased())
            .font(.custom("ProductSans-Bold", size: 10))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(4)
    }
}

// MARK: - Biomarker Info Modal (Bottom Sheet Style)
struct BiomarkerInfoModal: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    let biomarkerName: String
    let insight: BiomarkerInsight?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background overlay
            Color.black.opacity(0.5)
                .ignoresSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isPresented = false
                    }
                }
            
            // Bottom sheet content
            VStack(spacing: 0) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                
                // Header
                HStack {
                    Text(biomarkerName)
                        .font(.custom("ProductSans-Bold", size: 22))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color.gray.opacity(0.5))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                
                // Scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // General section
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppColors.primary)
                                
                                Text("General Information")
                                    .font(.custom("ProductSans-Bold", size: 17))
                                    .foregroundColor(AppColors.primary)
                            }
                            
                            Text(insight?.general ?? "No general information available for this biomarker.")
                                .font(.custom("ProductSans-Regular", size: 15))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Divider()
                            .background(AppColors.border(themeManager.colorScheme))
                            .padding(.vertical, 4)
                        
                        // Specific section
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "#10b981"))
                                
                                Text("Your Result")
                                    .font(.custom("ProductSans-Bold", size: 17))
                                    .foregroundColor(Color(hex: "#10b981"))
                            }
                            
                            Text(insight?.specific ?? "No specific insights available for your result.")
                                .font(.custom("ProductSans-Regular", size: 15))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // Recommendations section (only show if available)
                        if let recommendations = insight?.recommendations, !recommendations.isEmpty {
                            Divider()
                                .background(AppColors.border(themeManager.colorScheme))
                                .padding(.vertical, 4)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(hex: "#f59e0b"))
                                    
                                    Text("Our Recommendations")
                                        .font(.custom("ProductSans-Bold", size: 17))
                                        .foregroundColor(Color(hex: "#f59e0b"))
                                }
                                
                                Text(recommendations)
                                    .font(.custom("ProductSans-Regular", size: 15))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    .lineSpacing(5)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                // Source links
                                if let sources = insight?.recommendationSources, !sources.isEmpty {
                                    HStack(spacing: 12) {
                                        ForEach(sources.prefix(4), id: \.url) { source in
                                            Button(action: {
                                                if let url = URL(string: source.url) {
                                                    UIApplication.shared.open(url)
                                                }
                                            }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "link")
                                                        .font(.system(size: 12))
                                                    Text(source.domain)
                                                        .font(.custom("ProductSans-Regular", size: 11))
                                                        .lineLimit(1)
                                                }
                                                .foregroundColor(AppColors.primary)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(AppColors.primary.opacity(0.1))
                                                .cornerRadius(12)
                                            }
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 60)
                }
            }
            .frame(height: UIScreen.main.bounds.height * 0.75)
            .frame(maxWidth: .infinity)
            .background(AppColors.modalBackground(themeManager.colorScheme))
            .cornerRadius(24, corners: [.topLeft, .topRight])
        }
        .ignoresSafeArea(.all)
    }
}

// MARK: - Corner Radius Extension for Specific Corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Result Card Component
struct ResultCardView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let result: BloodTestResult
    let insight: BiomarkerInsight?
    var onInfoPressed: (() -> Void)?
    
    // Convenience initializer for backward compatibility
    init(result: BloodTestResult) {
        self.result = result
        self.insight = nil
        self.onInfoPressed = nil
    }
    
    init(result: BloodTestResult, insight: BiomarkerInsight?, onInfoPressed: (() -> Void)?) {
        self.result = result
        self.insight = insight
        self.onInfoPressed = onInfoPressed
    }
    
    private var parsedRange: ReferenceRange? {
        ReferenceRange.parse(result.referenceRange)
    }
    
    private var numericValue: Double? {
        Double(result.value)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text(result.marker)
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                    
                    // Info button
                    if onInfoPressed != nil {
                        Button(action: { onInfoPressed?() }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 16))
                                .foregroundColor(Color.gray.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                if let status = result.status {
                    StatusBadge(status: status)
                }
            }
            
            // Range bar or simple value
            if let range = parsedRange, let value = numericValue {
                RangeBarView(
                    value: value,
                    min: range.min,
                    max: range.max,
                    unit: result.unit ?? "",
                    status: result.status ?? "normal"
                )
                
                if let refRange = result.referenceRange {
                    Text("Reference: \(refRange)")
                        .font(.custom("ProductSans-Regular", size: 12))
                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(result.value) \(result.unit ?? "")")
                        .font(.custom("ProductSans-Bold", size: 18))
                        .foregroundColor(AppColors.primary)
                    
                    if let refRange = result.referenceRange {
                        Text("Reference: \(refRange)")
                            .font(.custom("ProductSans-Regular", size: 12))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
        )
    }
}

// MARK: - Info Card Component
struct InfoCardView<Content: View>: View {
    @EnvironmentObject var themeManager: ThemeManager
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
        )
    }
}

// MARK: - Category Section Component
struct CategorySectionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let section: AnalysisSection
    let testResults: [BloodTestResult]
    let index: Int
    let biomarkerInsights: [String: BiomarkerInsight]?
    var onBiomarkerInfoPressed: ((BloodTestResult) -> Void)?
    
    @State private var isExpanded: Bool = false
    
    // Get the biomarkers for this category
    private var categoryResults: [BloodTestResult] {
        guard let biomarkers = section.biomarkers else { return [] }
        return testResults.filter { biomarkers.contains($0.marker) }
    }
    
    // Icon mapping - matches React Native Ionicons to SF Symbols
    private var iconName: String {
        switch section.icon {
        case "medical-outline":
            return "cross.case"
        case "body-outline":
            return "figure.stand"
        case "water-outline":
            return "drop"
        case "heart-outline":
            return "heart"
        case "pulse-outline":
            return "waveform.path.ecg"
        case "flask-outline":
            return "flask"
        case "speedometer-outline":
            return "speedometer"
        case "information-circle-outline":
            return "info.circle"
        default:
            return "cross.case"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category Header
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.primary)
                }
                
                Text(section.category ?? "Analysis")
                    .font(.custom("ProductSans-Bold", size: 18))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                    .lineLimit(2)
                
                Spacer()
            }
            
            // Summary
            if let summary = section.summary, !summary.isEmpty {
                Text(summary)
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                    .lineSpacing(4)
                    .padding(.bottom, 8)
            }
            
            // Details Toggle
            if let details = section.details, !details.isEmpty {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text(isExpanded ? "Hide Details" : "Show Details")
                            .font(.custom("ProductSans-Bold", size: 14))
                            .foregroundColor(AppColors.primary)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.primary)
                    }
                    .padding(.vertical, 8)
                }
                
                // Expanded Details
                if isExpanded {
                    Text(details)
                        .font(.custom("ProductSans-Regular", size: 14))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                        .lineSpacing(4)
                        .padding(.bottom, 12)
                }
            }
            
            // Biomarker Cards for this Category
            if !categoryResults.isEmpty {
                Divider()
                    .background(AppColors.border(themeManager.colorScheme))
                
                ForEach(categoryResults) { result in
                    ResultCardView(
                        result: result,
                        insight: biomarkerInsights?[result.marker],
                        onInfoPressed: { onBiomarkerInfoPressed?(result) }
                    )
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
        )
    }
}

// MARK: - Main Analysis Results View
struct AnalysisResultsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    let analysisData: AnalysisData
    
    @State private var showBiomarkerInfo: Bool = false
    @State private var selectedBiomarker: BloodTestResult? = nil
    @State private var showChatModal: Bool = false
    
    private var selectedBiomarkerInsight: BiomarkerInsight? {
        guard let biomarker = selectedBiomarker else { return nil }
        return analysisData.biomarkerInsights?[biomarker.marker]
    }
    
    /// Generate analysis context string for the chat
    private var analysisContextString: String {
        var context = "Patient Blood Test Results:\n"
        
        if let patientInfo = analysisData.patientInfo {
            if let name = patientInfo.name {
                context += "Patient: \(name)\n"
            }
            if let age = patientInfo.age {
                context += "Age: \(age)\n"
            }
            if let sex = patientInfo.sex {
                context += "Sex: \(sex)\n"
            }
        }
        
        context += "\nTest Date: \(analysisData.formattedCreatedAt)\n"
        context += "Total Biomarkers: \(analysisData.testResults.count)\n"
        context += "Normal: \(analysisData.normalCount), Abnormal: \(analysisData.abnormalCount)\n\n"
        
        context += "Biomarker Results:\n"
        for result in analysisData.testResults {
            context += "- \(result.marker): \(result.value) \(result.unit ?? "") (Status: \(result.status ?? "unknown"))"
            if let refRange = result.referenceRange {
                context += " [Reference: \(refRange)]"
            }
            context += "\n"
        }
        
        if let overview = analysisData.testOverview {
            context += "\nTest Overview: \(overview)\n"
        }
        
        return context
    }
    
    var body: some View {
        let _ = print("🔍 AnalysisResultsView - sections count: \(analysisData.sections.count)")
        let _ = print("🔍 AnalysisResultsView - testResults count: \(analysisData.testResults.count)")
        let _ = print("🔍 AnalysisResultsView - testOverview: \(analysisData.testOverview ?? "nil")")
        
        ZStack {
            // Background
            AppColors.background(themeManager.colorScheme)
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Blood Test Analysis")
                            .font(.custom("ProductSans-Bold", size: 28))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        
                        Text(analysisData.formattedCreatedAt)
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    }
                    .padding(.top, 8)
                    
                    // Info Cards
                    VStack(spacing: 16) {
                        // Patient Info Card
                        InfoCardView {
                            Text(analysisData.patientInfo?.name ?? "You")
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                            
                            if let birthDate = analysisData.patientInfo?.birthDate {
                                InfoRowView(label: "Birth date", value: analysisData.formatDate(birthDate))
                            }
                            
                            if let age = analysisData.patientInfo?.age {
                                InfoRowView(label: "Age", value: age)
                            }
                            
                            if let sex = analysisData.patientInfo?.sex {
                                InfoRowView(label: "Gender", value: sex)
                            }
                            
                            if let testDate = analysisData.patientInfo?.testDate {
                                InfoRowView(label: "Test Date", value: analysisData.formatDate(testDate))
                            }
                        }
                        
                        // Scan Info Card
                        InfoCardView {
                            Text("Scan")
                                .font(.custom("ProductSans-Bold", size: 18))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                            
                            if let testDate = analysisData.patientInfo?.testDate {
                                InfoRowView(label: "Test Date", value: analysisData.formatDate(testDate))
                            }
                            
                            InfoRowView(label: "Date Analyzed", value: analysisData.formatDate(analysisData.createdAt))
                            
                            InfoRowView(label: "Test Type", value: "blood test")
                            
                            Divider()
                                .background(AppColors.border(themeManager.colorScheme))
                            
                            // Biomarker Summary
                            HStack(spacing: 40) {
                                VStack {
                                    Text("\(analysisData.testResults.count)")
                                        .font(.custom("ProductSans-Bold", size: 24))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    
                                    Text("biomarkers")
                                        .font(.custom("ProductSans-Regular", size: 12))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                }
                                
                                VStack {
                                    Text("\(analysisData.abnormalCount)")
                                        .font(.custom("ProductSans-Bold", size: 24))
                                        .foregroundColor(analysisData.abnormalCount > 0 ? Color(hex: "#ef4444") : AppColors.text(themeManager.colorScheme))
                                    
                                    Text("abnormal")
                                        .font(.custom("ProductSans-Regular", size: 12))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                        }
                        
                        // Normal Range Card
                        InfoCardView {
                            Text("In normal range")
                                .font(.custom("ProductSans-Regular", size: 16))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                            
                            HStack {
                                Spacer()
                                CircularProgressView(
                                    percentage: analysisData.normalRangePercentage,
                                    size: 120,
                                    customColor: Color(hex: "#10b981")
                                )
                                Spacer()
                            }
                            .padding(.vertical, 16)
                            
                            Text("of total biomarkers")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    
                    // Test Overview Section
                    if let testOverview = analysisData.testOverview, !testOverview.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Test Overview")
                                .font(.custom("ProductSans-Bold", size: 20))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                            
                            Text(testOverview)
                                .font(.custom("ProductSans-Regular", size: 16))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .lineSpacing(4)
                        }
                    }
                    
                    // Analysis by Category Section
                    if !analysisData.sections.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Analysis by Category")
                                .font(.custom("ProductSans-Bold", size: 20))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                            
                            ForEach(Array(analysisData.sections.enumerated()), id: \.element.id) { index, section in
                                CategorySectionView(
                                    section: section,
                                    testResults: analysisData.testResults,
                                    index: index,
                                    biomarkerInsights: analysisData.biomarkerInsights,
                                    onBiomarkerInfoPressed: { result in
                                        selectedBiomarker = result
                                        showBiomarkerInfo = true
                                    }
                                )
                            }
                        }
                    } else {
                        // Fallback: Show all test results if no sections
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Test Results")
                                .font(.custom("ProductSans-Bold", size: 20))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                            
                            if !analysisData.testResults.isEmpty {
                                ForEach(analysisData.testResults) { result in
                                    ResultCardView(
                                        result: result,
                                        insight: analysisData.biomarkerInsights?[result.marker],
                                        onInfoPressed: {
                                            selectedBiomarker = result
                                            showBiomarkerInfo = true
                                        }
                                    )
                                }
                            } else {
                                // No results available
                                VStack(spacing: 8) {
                                    Text(analysisData.testOverview ?? "No detailed analysis available.")
                                        .font(.custom("ProductSans-Regular", size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.border(themeManager.colorScheme), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showChatModal = true
                }) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .sheet(isPresented: $showBiomarkerInfo) {
            // Native iOS Biomarker Info Modal
            if let biomarker = selectedBiomarker {
                BiomarkerInfoSheet(
                    biomarkerName: biomarker.marker,
                    insight: selectedBiomarkerInsight
                )
                .environmentObject(themeManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showChatModal) {
            AnalysisChatModal(
                analysisId: analysisData.id ?? "unknown",
                analysisContext: analysisContextString
            )
                .environmentObject(themeManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Native Biomarker Info Sheet
struct BiomarkerInfoSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    let biomarkerName: String
    let insight: BiomarkerInsight?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // General section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.primary)
                            
                            Text("General Information")
                                .font(.custom("ProductSans-Bold", size: 17))
                                .foregroundColor(AppColors.primary)
                        }
                        
                        Text(insight?.general ?? "No general information available for this biomarker.")
                            .font(.custom("ProductSans-Regular", size: 15))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Divider()
                        .background(AppColors.border(themeManager.colorScheme))
                        .padding(.vertical, 4)
                    
                    // Specific section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Color(hex: "#10b981"))
                            
                            Text("Your Result")
                                .font(.custom("ProductSans-Bold", size: 17))
                                .foregroundColor(Color(hex: "#10b981"))
                        }
                        
                        Text(insight?.specific ?? "No specific insights available for your result.")
                            .font(.custom("ProductSans-Regular", size: 15))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Recommendations section (only show if available)
                    if let recommendations = insight?.recommendations, !recommendations.isEmpty {
                        Divider()
                            .background(AppColors.border(themeManager.colorScheme))
                            .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "#f59e0b"))
                                
                                Text("Our Recommendations")
                                    .font(.custom("ProductSans-Bold", size: 17))
                                    .foregroundColor(Color(hex: "#f59e0b"))
                            }
                            
                            Text(recommendations)
                                .font(.custom("ProductSans-Regular", size: 15))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Source links
                            if let sources = insight?.recommendationSources, !sources.isEmpty {
                                HStack(spacing: 12) {
                                    ForEach(sources.prefix(4), id: \.url) { source in
                                        Button(action: {
                                            if let url = URL(string: source.url) {
                                                UIApplication.shared.open(url)
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "link")
                                                    .font(.system(size: 12))
                                                Text(source.domain)
                                                    .font(.custom("ProductSans-Regular", size: 11))
                                                    .lineLimit(1)
                                            }
                                            .foregroundColor(AppColors.primary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(AppColors.primary.opacity(0.1))
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .background(AppColors.background(themeManager.colorScheme))
            .navigationTitle(biomarkerName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.custom("ProductSans-Bold", size: 16))
                    .foregroundColor(AppColors.primary)
                }
            }
        }
    }
}

// MARK: - Info Row View
struct InfoRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.custom("ProductSans-Regular", size: 14))
                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            
            Spacer()
            
            Text(value)
                .font(.custom("ProductSans-Bold", size: 14))
                .foregroundColor(AppColors.text(themeManager.colorScheme))
        }
    }
}

// MARK: - Analysis Chat Modal
struct AnalysisChatModal: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let analysisId: String
    let analysisContext: String
    
    @State private var messageText: String = ""
    @State private var messages: [StoredChatMessage] = []
    @State private var isTyping: Bool = false
    @State private var userId: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 48))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                    
                                    Text("Ask about your results")
                                        .font(.custom("ProductSans-Bold", size: 18))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    
                                    Text("Ask any questions about your blood test results and get personalized insights.")
                                        .font(.custom("ProductSans-Regular", size: 14))
                                        .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                }
                                .padding(.top, 60)
                            } else {
                                ForEach(messages) { message in
                                    FormattedMessageBubble(message: message)
                                        .environmentObject(themeManager)
                                        .id(message.id)
                                }
                                
                                if isTyping {
                                    HStack {
                                        TypingIndicatorView()
                                            .padding(12)
                                            .background(AppColors.surface(themeManager.colorScheme))
                                            .cornerRadius(16)
                                        Spacer()
                                    }
                                    .padding(.leading, 8)
                                    .id("typing")
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                        .onChange(of: messages.count) { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation {
                                    if let lastMessage = messages.last {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .onChange(of: isTyping) { typing in
                            if typing {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        proxy.scrollTo("typing", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                
                // Input bar
                HStack(spacing: 12) {
                    TextField("Ask about your results...", text: $messageText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(AppColors.surface(themeManager.colorScheme))
                        .clipShape(Capsule())
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                    
                    Button(action: sendMessage) {
                        if isTyping {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 48, height: 48)
                                .background(AppColors.primary)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : AppColors.primary)
                                .clipShape(Circle())
                        }
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTyping)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.background(themeManager.colorScheme))
            }
            .background(AppColors.background(themeManager.colorScheme))
            .navigationTitle("Ask About Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.custom("ProductSans-Bold", size: 16))
                    .foregroundColor(AppColors.primary)
                }
            }
        }
        .onAppear {
            Task {
                await initializeChat()
            }
        }
    }
    
    private func initializeChat() async {
        do {
            let uid = try await AuthService.shared.getCurrentUserId()
            await MainActor.run {
                userId = uid
                // Load saved messages for this analysis
                messages = AnalysisChatStorage.shared.loadMessages(for: analysisId)
            }
        } catch {
            print("Error getting user ID: \(error)")
        }
    }
    
    private func sendMessage() {
        guard let uid = userId else { return }
        let userMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty else { return }
        
        // Create and save user message
        let userChatMessage = StoredChatMessage(role: "user", content: userMessage)
        messages.append(userChatMessage)
        AnalysisChatStorage.shared.addMessage(userChatMessage, for: analysisId)
        
        messageText = ""
        isTyping = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        Task {
            do {
                let response = try await ChatService.shared.sendChatMessageWithContext(
                    userId: uid,
                    message: userMessage,
                    analysisContext: analysisContext
                )
                
                await MainActor.run {
                    // Create and save assistant message
                    let assistantMessage = StoredChatMessage(role: "assistant", content: response)
                    messages.append(assistantMessage)
                    AnalysisChatStorage.shared.addMessage(assistantMessage, for: analysisId)
                    isTyping = false
                }
            } catch {
                print("Error sending message: \(error)")
                await MainActor.run {
                    let errorMessage = StoredChatMessage(role: "assistant", content: "Sorry, I couldn't process your question. Please try again.")
                    messages.append(errorMessage)
                    AnalysisChatStorage.shared.addMessage(errorMessage, for: analysisId)
                    isTyping = false
                }
            }
        }
    }
}

// MARK: - Formatted Message Bubble
struct FormattedMessageBubble: View {
    @EnvironmentObject var themeManager: ThemeManager
    let message: StoredChatMessage
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer(minLength: 60)
                
                Text(message.content)
                    .font(.custom("ProductSans-Regular", size: 15))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(AppColors.primary)
                    .cornerRadius(16)
                    .padding(.trailing, 8)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    MarkdownTextView(
                        message.content,
                        textColor: AppColors.text(themeManager.colorScheme),
                        fontSize: 15
                    )
                }
                .padding(12)
                .background(AppColors.surface(themeManager.colorScheme))
                .cornerRadius(16)
                .padding(.leading, 8)
                
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Typing Indicator View
struct TypingIndicatorView: View {
    @State private var animationPhase: Int = 0
    
    let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .frame(width: 8, height: 8)
                .foregroundColor(Color.gray)
                .opacity(animationPhase == 0 ? 1.0 : 0.4)
            
            Circle()
                .frame(width: 8, height: 8)
                .foregroundColor(Color.gray)
                .opacity(animationPhase == 1 ? 1.0 : 0.4)
            
            Circle()
                .frame(width: 8, height: 8)
                .foregroundColor(Color.gray)
                .opacity(animationPhase == 2 ? 1.0 : 0.4)
        }
        .animation(.easeInOut(duration: 0.3), value: animationPhase)
        .onReceive(timer) { _ in
            animationPhase = (animationPhase + 1) % 3
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        AnalysisResultsView(
            analysisData: AnalysisData(
                id: "preview-1",
                parsedData: ParsedBloodTestData(
                    patientInfo: PatientInfo(
                        name: "John Doe",
                        age: "35",
                        testDate: "2025-01-15",
                        birthDate: "1990-05-20",
                        sex: "Male"
                    ),
                    testResults: [
                        BloodTestResult(marker: "Hemoglobin", value: "14.5", unit: "g/dL", referenceRange: "13.0-17.0", status: "normal"),
                        BloodTestResult(marker: "RBC Count", value: "4.2", unit: "M/uL", referenceRange: "4.5-5.5", status: "low"),
                        BloodTestResult(marker: "WBC Count", value: "12500", unit: "/uL", referenceRange: "4000-11000", status: "high")
                    ]
                ),
                analysis: nil,
                createdAt: "2025-01-15T10:30:00Z"
            )
        )
        .environmentObject(ThemeManager.shared)
    }
}
