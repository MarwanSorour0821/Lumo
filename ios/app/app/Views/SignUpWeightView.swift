//
//  SignUpWeightView.swift
//  app
//
//  Created on iOS
//

import SwiftUI

struct SignUpWeightView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var coordinator: SignUpFlowCoordinator
    @State private var weight: Double = 154 // lbs
    @State private var weightUnit: String = "lbs"
    @State private var isCreatingAccount = false
    @State private var showError: String?
    @State private var navigateToPersonal = false
    
    @State private var headingOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var showWeightPicker = false
    
    var weightInKg: Double {
        if weightUnit == "kg" {
            return weight
        } else {
            return weight * 0.453592
        }
    }
    
    var weightRange: ClosedRange<Double> {
        weightUnit == "kg" ? 30...300 : 66...660
    }
    
    var body: some View {
        ZStack {
            Theme.colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Heading
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What is Your Weight?")
                                .font(.custom("ProductSans-Bold", size: 40))
                                .foregroundColor(.white)
                                .opacity(headingOpacity)
                                .multilineTextAlignment(.center)
                            
                            Text("Vestibulum sed sagittis nisi, a euismod mauris.")
                                .font(.custom("ProductSans-Regular", size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .opacity(headingOpacity)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 48)
                        
                        // Weight Card
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            showWeightPicker = true
                        }) {
                            VStack(spacing: 12) {
                                Text("\(Int(weight))")
                                    .font(.custom("ProductSans-Bold", size: 64))
                                    .foregroundColor(.white)
                                
                                Text(weightUnit)
                                    .font(.custom("ProductSans-Regular", size: 18))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                HStack(spacing: 6) {
                                    Text("Tap to change")
                                        .font(.custom("ProductSans-Regular", size: 14))
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    Image(systemName: "pencil")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.1))
                                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                            )
                        }
                        .opacity(contentOpacity)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100) // Extra padding for bottom buttons
                    }
                }
            }
            
            // Bottom Navigation Buttons
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 16) {
                        // Back Button
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            dismiss()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.glass)
                        .clipShape(Circle())
                        
                        // Next Button
                        Button(action: handleContinue) {
                            HStack(spacing: 8) {
                                Text("Next")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(.white)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 24)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(Color(hex: "#B01328"))
                            )
                            .shadow(color: Color(hex: "#BB3E4F").opacity(0.6), radius: 16, x: 0, y: 6)
                        }
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true) // Hide top back button, use bottom button
        .toolbar {
            ToolbarItem(placement: .principal) {
                ProgressBar(currentStep: 4, totalSteps: 7)
            }
        }
        .onAppear {
            startAnimations()
        }
        .navigationDestination(isPresented: $navigateToPersonal) {
            SignUpPersonalView(coordinator: coordinator)
        }
        .alert("Error", isPresented: .constant(showError != nil), presenting: showError) { error in
            Button("OK") {
                showError = nil
            }
        } message: { error in
            Text(error)
        }
        .sheet(isPresented: $showWeightPicker) {
            WeightPickerSheet(
                selectedWeight: $weight,
                weightUnit: $weightUnit,
                isPresented: $showWeightPicker
            )
            .presentationDetents([.fraction(0.4), .medium])
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
    
    private func switchUnit(to unit: String) {
        if unit == "kg" && weightUnit == "lbs" {
            weight = weight * 0.453592
        } else if unit == "lbs" && weightUnit == "kg" {
            weight = weight / 0.453592
        }
        weightUnit = unit
    }
    
    private func handleContinue() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        coordinator.updateWeight("\(Int(weight))", unit: weightUnit)
        coordinator.nextStep()
        navigateToPersonal = true
    }
}

struct UnitToggleButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#B01328"))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(.white))
                } else {
                    Circle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                
                Text(title)
                    .font(.custom(isSelected ? "ProductSans-Bold" : "ProductSans-Regular", size: 16))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(isSelected ? Color(hex: "#B01328") : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(isSelected ? Color(hex: "#B01328") : Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Weight Picker Sheet
struct WeightPickerSheet: View {
    @Binding var selectedWeight: Double
    @Binding var weightUnit: String
    @Binding var isPresented: Bool
    @State private var pickerUnit: String = "kg"
    
    var weightRange: ClosedRange<Double> {
        pickerUnit == "kg" ? 30...300 : 66...660
    }
    
    var body: some View {
        ZStack {
            Theme.colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Your weight")
                        .font(.custom("ProductSans-Bold", size: 17))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Unit Toggle
                    HStack(spacing: 0) {
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            if pickerUnit != "kg" {
                                // Convert from lbs to kg
                                selectedWeight = selectedWeight * 0.453592
                            }
                            pickerUnit = "kg"
                        }) {
                            Text("kgs")
                                .font(.custom(pickerUnit == "kg" ? "ProductSans-Bold" : "ProductSans-Regular", size: 15))
                                .foregroundColor(pickerUnit == "kg" ? Color.black : Color.white.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(minWidth: 60)
                        }
                        
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            if pickerUnit != "lbs" {
                                // Convert from kg to lbs
                                selectedWeight = selectedWeight / 0.453592
                            }
                            pickerUnit = "lbs"
                        }) {
                            Text("lbs")
                                .font(.custom(pickerUnit == "lbs" ? "ProductSans-Bold" : "ProductSans-Regular", size: 15))
                                .foregroundColor(pickerUnit == "lbs" ? Color.black : Color.white.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(minWidth: 60)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        // White indicator for selected option
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .frame(width: geometry.size.width / 2)
                                .offset(x: pickerUnit == "kg" ? 0 : geometry.size.width / 2)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pickerUnit)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                // Picker
                Picker("Weight", selection: $selectedWeight) {
                    ForEach(Array(stride(from: weightRange.lowerBound, through: weightRange.upperBound, by: 1)), id: \.self) { value in
                        Text("\(Int(value)) \(pickerUnit)")
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .colorScheme(.dark)
                .accentColor(Theme.colors.button)
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Done Button
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    // Update the weightUnit binding to match pickerUnit
                    weightUnit = pickerUnit
                    isPresented = false
                }) {
                    HStack {
                        Spacer()
                        Text("Done")
                            .font(.custom("ProductSans-Bold", size: 17))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Theme.colors.button)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Initialize pickerUnit from weightUnit
            pickerUnit = weightUnit
        }
    }
}

