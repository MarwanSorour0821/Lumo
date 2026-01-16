//
//  HealthScoreCard.swift
//  app
//
//  Health score card with mesh gradient background matching the design
//

import SwiftUI

struct HealthScoreCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let healthScore: Double
    let isLoading: Bool
    let onInfoTapped: () -> Void
    
    @State private var animatedScore: Double = 0.0
    
    // Calculate score difference from average (7.0 is considered average)
    private var scoreDifference: Double {
        let average: Double = 7.0
        return healthScore - average
    }
    
    // Text color based on color scheme
    private var textColor: Color {
        let scheme = themeManager.colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .dark ? .white : .black
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Mesh gradient background with smooth transition
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    .init(0, 0),      .init(0.5, 0),      .init(1, 0),
                    .init(0, 0.5),    .init(0.5, 0.5),    .init(1, 0.5),
                    .init(0, 1),      .init(0.5, 1),      .init(1, 1)
                ],
                colors: meshGradientColors
            )
            .cornerRadius(20)
            .overlay(
                // Subtle texture overlay for depth
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            
            // Content
            VStack(alignment: .leading, spacing: 0) {
                // Top section with score and label
                VStack(alignment: .leading, spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                            .scaleEffect(1.2)
                            .frame(height: 60)
                    } else {
                        Text(String(format: "%.1f", animatedScore))
                            .font(.system(size: 64, weight: .bold))
                            .foregroundColor(textColor)
                    }
                    
                    // Health score label with info button
                    HStack(spacing: 6) {
                        Text("Health score")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(textColor.opacity(0.9))
                        
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            onInfoTapped()
                        }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(textColor.opacity(0.9))
                        }
                    }
                }
                .padding(.top, 24)
                .padding(.leading, 24)
                
                Spacer()
                    .frame(height: 24)
                
                    // Slider section
                    VStack(spacing: 12) {
                        HealthScoreSlider(
                            value: min(max(healthScore / 10.0, 0.0), 1.0),
                            scoreDifference: scoreDifference,
                            isLoading: isLoading,
                            textColor: textColor
                        )
                        
                        // Explanatory text
                        if !isLoading {
                            let differenceText = scoreDifference > 0 
                                ? "\(String(format: "%.1f", scoreDifference)) points above average"
                                : scoreDifference < 0 
                                ? "\(String(format: "%.1f", abs(scoreDifference))) points below average"
                                : "at average"
                            Text("Your health score is \(differenceText).")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(textColor.opacity(0.85))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                        }
                    }
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 200)
        .padding(.horizontal, 24)
        .onAppear {
            print("🔵 HealthScoreCard appeared with score: \(healthScore), isLoading: \(isLoading)")
            if !isLoading {
                animateScore()
            }
        }
        .onChange(of: healthScore) { oldValue, newValue in
            print("🔵 HealthScoreCard healthScore changed from \(oldValue) to \(newValue)")
            if !isLoading {
                animateScore()
            }
        }
        .onChange(of: isLoading) { oldValue, newValue in
            print("🔵 HealthScoreCard isLoading changed from \(oldValue) to \(newValue), score: \(healthScore)")
            if !newValue && healthScore > 0 {
                animateScore()
            }
        }
    }
    
    // Mesh gradient colors based on color scheme
    private var meshGradientColors: [Color] {
        let scheme = themeManager.colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        
        if scheme == .dark {
            // Dark mode: darker, more muted colors with blue to beige transition
            return [
                Color(hex: "#1A2B3D"), // Dark blue-gray (top-left)
                Color(hex: "#2A3B4D"), // Medium blue-gray (top-center)
                Color(hex: "#1A2B3D"), // Dark blue-gray (top-right)
                Color(hex: "#2A3B4D"), // Medium blue-gray (middle-left)
                Color(hex: "#3A4B5D"), // Lighter blue-gray center
                Color(hex: "#2A3B4D"), // Medium blue-gray (middle-right)
                Color(hex: "#2A2B2D"), // Dark beige-gray (bottom-left)
                Color(hex: "#3A3B3D"), // Medium beige-gray (bottom-center)
                Color(hex: "#2A2B2D")  // Dark beige-gray (bottom-right)
            ]
        } else {
            // Light mode: darker blue to beige gradient
            // Creating a horizontal gradient from darker blue (left) to beige (right)
            return [
                Color(hex: "#B3D9F0"), // Darker blue (top-left)
                Color(hex: "#C4E0F5"), // Medium blue (top-center)
                Color(hex: "#D4E8E0"), // Blue-beige transition (top-right)
                Color(hex: "#C4E0F5"), // Medium blue (middle-left)
                Color(hex: "#D9E8DC"), // Off-white with beige tint (center)
                Color(hex: "#E0D8C8"), // Light beige (middle-right)
                Color(hex: "#D4E8E0"), // Blue-beige transition (bottom-left)
                Color(hex: "#E0D8C8"), // Light beige (bottom-center)
                Color(hex: "#D8D0C0")  // Medium beige (bottom-right)
            ]
        }
    }
    
    private func animateScore() {
        withAnimation(.easeOut(duration: 1.8)) {
            animatedScore = healthScore
        }
    }
}

// MARK: - Health Score Slider
struct HealthScoreSlider: View {
    let value: Double // 0.0 to 1.0
    let scoreDifference: Double
    let isLoading: Bool
    let textColor: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 4)
                    .fill(textColor.opacity(0.25))
                    .frame(height: 8)
                
                // Filled portion
                let thumbPosition = geometry.size.width * CGFloat(value)
                RoundedRectangle(cornerRadius: 4)
                    .fill(textColor.opacity(0.4))
                    .frame(width: thumbPosition, height: 8)
            }
        }
        .frame(height: 8)
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 24) {
        HealthScoreCard(
            healthScore: 8.2,
            isLoading: false,
            onInfoTapped: {}
        )
        .environmentObject(ThemeManager.shared)
        
        HealthScoreCard(
            healthScore: 7.5,
            isLoading: false,
            onInfoTapped: {}
        )
        .environmentObject(ThemeManager.shared)
    }
    .padding()
    .background(Color.black)
}
