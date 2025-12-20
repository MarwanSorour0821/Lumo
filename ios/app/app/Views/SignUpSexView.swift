//
//  SignUpSexView.swift
//  app
//
//  Created on iOS
//

import SwiftUI

struct SignUpSexView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var coordinator: SignUpFlowCoordinator
    @State private var selectedSex: BiologicalSex?
    @State private var navigateToAge = false
    
    @State private var headingOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    var body: some View {
        ZStack {
            Theme.colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Heading
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What's your gender?")
                                .font(.custom("ProductSans-Regular", size: 40))
                                .foregroundColor(.white)
                                .opacity(headingOpacity)
                            
                            Text("This helps us personalize your blood analytics.")
                                .font(.custom("ProductSans-Regular", size: 16))
                                .foregroundColor(.white.opacity(0.7))
                                .opacity(headingOpacity)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                        
                        // Sex Options - Vertical List
                        VStack(spacing: 12) {
                            ForEach(BiologicalSex.allCases, id: \.self) { sex in
                                SexOptionCard(
                                    sex: sex,
                                    isSelected: selectedSex == sex
                                ) {
                                    selectSex(sex)
                                }
                            }
                        }
                        .opacity(contentOpacity)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 48)
                        
                        // Continue Button
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
                                    .fill(selectedSex != nil ? Color(hex: "#B01328") : Color(hex: "#B01328").opacity(0.5))
                            )
                            .shadow(color: Color(hex: "#BB3E4F").opacity(0.6), radius: 16, x: 0, y: 6)
                        }
                        .disabled(selectedSex == nil)
                        .opacity(buttonOpacity)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
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
                    .foregroundColor(.white)
                }
            }
            ToolbarItem(placement: .principal) {
                ProgressBar(currentStep: 1, totalSteps: 7)
            }
        }
        .onAppear {
            startAnimations()
        }
        .navigationDestination(isPresented: $navigateToAge) {
            SignUpAgeView(coordinator: coordinator)
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
    
    private func selectSex(_ sex: BiologicalSex) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            selectedSex = sex
        }
    }
    
    private func handleContinue() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        guard let sex = selectedSex else { return }
        coordinator.updateSex(sex)
        coordinator.nextStep()
        navigateToAge = true
    }
}

struct SexOptionCard: View {
    let sex: BiologicalSex
    let isSelected: Bool
    let action: () -> Void
    
    var icon: String {
        switch sex {
        case .male:
            return "person.fill"
        case .female:
            return "person.fill"
        case .other:
            return "person.2.fill"
        case .preferNotToSay:
            return "questionmark.circle.fill"
        }
    }
    
    var iconColor: Color {
        isSelected ? Color(hex: "#B01328") : .white.opacity(0.7)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Group {
                    if sex == .male {
                        Text("♂")
                            .font(.system(size: 20, weight: .medium))
                    } else if sex == .female {
                        Text("♀")
                            .font(.system(size: 20, weight: .medium))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .medium))
                    }
                }
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                
                // Text
                Text(sex.displayName)
                    .font(.custom(isSelected ? "ProductSans-Bold" : "ProductSans-Regular", size: 17))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Checkmark (only show when selected)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#B01328"))
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(.white)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color(hex: "#B01328") : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
    }
}

