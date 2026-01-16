//
//  BiomarkersCard.swift
//  app
//
//  Biomarkers summary card showing total, optimal, normal range, and out of range counts
//

import SwiftUI

struct BiomarkersCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let totalBiomarkers: Int
    let optimalCount: Int
    let normalRangeCount: Int
    let outOfRangeCount: Int
    
    var body: some View {
        NavigationLink(destination: TrendsView().environmentObject(themeManager)) {
            ZStack(alignment: .topTrailing) {
                // Background - mesh gradient for dark mode, white for light mode
                Group {
                    let scheme = themeManager.colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
                    if scheme == .dark {
                        MeshGradient(
                            width: 3,
                            height: 3,
                            points: [
                                .init(0, 0),      .init(0.5, 0),      .init(1, 0),
                                .init(0, 0.5),    .init(0.5, 0.5),    .init(1, 0.5),
                                .init(0, 1),      .init(0.5, 1),      .init(1, 1)
                            ],
                            colors: [
                                Color(hex: "#212121"), Color(hex: "#1A1A1A"), Color(hex: "#212121"),
                                Color(hex: "#1A1A1A"), Color(hex: "#0B0B0B"), Color(hex: "#1A1A1A"),
                                Color(hex: "#212121"), Color(hex: "#1A1A1A"), Color(hex: "#212121")
                            ]
                        )
                    } else {
                        Color.white
                    }
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    // Top section with number and label
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(totalBiomarkers)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                        
                        Text("Biomarkers")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                    }
                    .padding(.top, 20)
                    .padding(.leading, 20)
            
            Spacer()
                .frame(height: 20)
            
            // Progress bar (shows normal range vs out of range)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Normal range portion (green) - includes optimal
                    let normalAndOptimal = normalRangeCount + optimalCount
                    if normalAndOptimal > 0 {
                        Rectangle()
                            .fill(Color(hex: "#22C55E")) // Green
                            .frame(width: geometry.size.width * CGFloat(normalAndOptimal) / CGFloat(totalBiomarkers))
                    }
                    
                    // Out of range portion (purple)
                    if outOfRangeCount > 0 {
                        Rectangle()
                            .fill(Color(hex: "#9333EA")) // Purple
                            .frame(width: geometry.size.width * CGFloat(outOfRangeCount) / CGFloat(totalBiomarkers))
                    }
                }
            }
            .frame(height: 8)
            .cornerRadius(4)
            .padding(.horizontal, 20)
            
            Spacer()
                .frame(height: 16)
            
            // Tags at bottom
            HStack(spacing: 8) {
                // Optimal tag
                if optimalCount > 0 {
                    TagView(text: "\(optimalCount) optimal")
                }
                
                // Normal range tag
                if normalRangeCount > 0 {
                    TagView(text: "\(normalRangeCount) normal range")
                }
                
                // Out of range tag
                if outOfRangeCount > 0 {
                    TagView(text: "\(outOfRangeCount) out of range")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
                }
                
                // Icon at top right
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    .padding(.top, 20)
                    .padding(.trailing, 20)
            }
        }
        .cornerRadius(16)
        .padding(.horizontal, 24)
        .simultaneousGesture(TapGesture().onEnded {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        })
    }
}

// MARK: - Tag View
struct TagView: View {
    let text: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(AppColors.text(themeManager.colorScheme))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tagBackgroundColor)
            .cornerRadius(8)
    }
    
    private var tagBackgroundColor: Color {
        let scheme = themeManager.colorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
        return scheme == .dark ? AppColors.background(themeManager.colorScheme) : Color(hex: "#F5F5F5")
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 24) {
        BiomarkersCard(
            totalBiomarkers: 81,
            optimalCount: 3,
            normalRangeCount: 74,
            outOfRangeCount: 4
        )
        .environmentObject(ThemeManager.shared)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
