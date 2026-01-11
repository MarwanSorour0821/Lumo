//
//  MainTabView.swift
//  app
//
//  Reusable tab bar component with iOS 18 Liquid Glass style
//  Tabs grouped on the left, action button on the right
//

import SwiftUI

// MARK: - Tab Item Enum
enum MainTab: Int, CaseIterable {
    case today = 0
    case medication = 1
    case health = 2
    case me = 3

    var title: String {
        switch self {
        case .today: return "Today"
        case .medication: return "Medication"
        case .health: return "Health"
        case .me: return "Me"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .medication: return "pills.fill"
        case .health: return "heart.fill"
        case .me: return "person.fill"
        }
    }
}

// MARK: - Simple Tab View Component
struct SimpleMainTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedTab: MainTab
    var onPlusButtonTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Tabs container (left side) - pill shaped
            HStack(spacing: 0) {
                ForEach(MainTab.allCases, id: \.rawValue) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(6)
            .background(
                Capsule()
                    .fill(glassBackground)
                    .overlay(
                        Capsule()
                            .stroke(glassBorder, lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 4)
            )
            
            Spacer()
            
            // Plus button (right side) - circular, like search button in reference
            Button {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                onPlusButtonTapped()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(glassBackground)
                            .overlay(
                                Circle()
                                    .stroke(glassBorder, lineWidth: 0.5)
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 4)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    
    // MARK: - Tab Button
    private func tabButton(for tab: MainTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTab = tab
            }
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .medium))
                
                if selectedTab == tab {
                    Text(tab.title)
                        .font(.system(size: 14, weight: .medium))
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.8)),
                            removal: .opacity.combined(with: .scale(scale: 0.8))
                        ))
                }
            }
            .foregroundColor(selectedTab == tab ? AppColors.primary : iconColor)
            .padding(.horizontal, selectedTab == tab ? 14 : 12)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(selectedTab == tab ? selectedTabBackground : Color.clear)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTab)
    }
    
    // MARK: - Glass Effect Colors
    private var glassBackground: Color {
        themeManager.colorScheme == .dark
            ? Color(white: 0.18).opacity(0.92)
            : Color(white: 0.94).opacity(0.92)
    }
    
    private var glassBorder: Color {
        themeManager.colorScheme == .dark
            ? Color.white.opacity(0.15)
            : Color.black.opacity(0.08)
    }
    
    private var selectedTabBackground: Color {
        themeManager.colorScheme == .dark
            ? Color(white: 0.28).opacity(0.9)
            : Color.white.opacity(0.95)
    }
    
    private var iconColor: Color {
        themeManager.colorScheme == .dark
            ? Color.white.opacity(0.7)
            : Color.black.opacity(0.6)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        // Dark background to see the effect
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            SimpleMainTabView(
                selectedTab: .constant(.today),
                onPlusButtonTapped: {}
            )
            .environmentObject(ThemeManager.shared)
        }
    }
}
