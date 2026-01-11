//
//  TellHealthView.swift
//  app
//
//  Created on iOS
//

import SwiftUI

struct TellHealthView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var coordinator: SignUpFlowCoordinator
    @State private var selectedConditions: Set<HeartCondition> = []
    @State private var navigateToNext = false
    
    @State private var headingOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    var body: some View {
        ZStack {
            AppColors.background(themeManager.colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Heading
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Anything we should know?")
                                .font(.custom("ProductSans-Regular", size: 40))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                                .opacity(headingOpacity)
                            
                            Text("This helps interpret your blood results more accurately.")
                                .font(.custom("ProductSans-Regular", size: 12))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                .tracking(0.5)
                                .opacity(headingOpacity)
                                .padding(.top, 16)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                        
                        // Health Condition Chips
                        FlowLayout(spacing: 10) {
                            ForEach(HeartCondition.allCases, id: \.self) { condition in
                                ConditionChip(
                                    condition: condition,
                                    isSelected: selectedConditions.contains(condition)
                                ) {
                                    toggleCondition(condition)
                                }
                            }
                        }
                        .opacity(contentOpacity)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 48)
                    }
                }
                
                // Continue Button - Fixed at bottom
                Button(action: handleContinue) {
                    HStack {
                        Spacer()
                        Text("Continue")
                            .font(.custom("ProductSans-Bold", size: 16))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(AppColors.primary)
                    )
                    .shadow(color: Color(hex: "#BB3E4F").opacity(0.6), radius: 16, x: 0, y: 6)
                }
                .opacity(buttonOpacity)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Back")
                            .font(.custom("ProductSans-Regular", size: 17))
                    }
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
            }
        }
        .onAppear {
            startAnimations()
        }
        .navigationDestination(isPresented: $navigateToNext) {
            // Navigate to Sign Up Sex view to continue the signup flow
            SignUpSexView(coordinator: coordinator)
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.4)) {
            headingOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            contentOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
            buttonOpacity = 1
        }
    }
    
    private func toggleCondition(_ condition: HeartCondition) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if selectedConditions.contains(condition) {
                selectedConditions.remove(condition)
            } else {
                selectedConditions.insert(condition)
            }
        }
    }
    
    private func handleContinue() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Store selected conditions (convert Set to Array of raw values)
        let conditionStrings = Array(selectedConditions).map { $0.rawValue }
        coordinator.updateHealthConditions(conditionStrings)
        
        // Navigate to next step
        coordinator.nextStep()
        navigateToNext = true
    }
}

// MARK: - Heart Condition Enum
enum HeartCondition: String, CaseIterable {
    case highBloodPressure = "High blood pressure"
    case highCholesterol = "High cholesterol"
    case prediabetes = "Prediabetes"
    case type2Diabetes = "Type 2 diabetes"
    case familyHistory = "Family history of heart disease"
    case thyroidCondition = "Thyroid condition"
    case autoimmuneCondition = "Autoimmune condition"
    case chronicInflammation = "Chronic inflammation"
    case ironDeficiency = "Iron deficiency / anemia"
    case hormonalImbalance = "Hormonal imbalance (e.g. PCOS, low testosterone)"
    case sleepApnea = "Sleep apnea"
    case digestiveIssues = "Digestive issues"
    case other = "Other"
    
    var displayName: String {
        return rawValue
    }
}

// MARK: - Condition Chip Component
struct ConditionChip: View {
    let condition: HeartCondition
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            Text(condition.displayName)
                .font(.custom(isSelected ? "ProductSans-Bold" : "ProductSans-Regular", size: 14))
                .foregroundColor(isSelected ? Color(hex: "#B01328") : AppColors.text(themeManager.colorScheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color(hex: "#B01328").opacity(0.1) : AppColors.inputBackground(themeManager.colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color(hex: "#B01328") : AppColors.border(themeManager.colorScheme), lineWidth: isSelected ? 1.5 : 1)
                )
        }
    }
}

// MARK: - Flow Layout for Chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 10
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxWidth: CGFloat = maxWidth
            
            for subview in subviews {
                let viewSize = subview.sizeThatFits(.unspecified)
                
                if currentX + viewSize.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, viewSize.height)
                currentX += viewSize.width + spacing
                
                size.width = max(size.width, currentX - spacing)
            }
            
            size.height = currentY + lineHeight
        }
    }
}

#Preview {
    NavigationStack {
        TellHealthView(coordinator: SignUpFlowCoordinator())
            .environmentObject(ThemeManager.shared)
    }
}

