//
//  SignUpHeightView.swift
//  app
//
//  Created on iOS
//

import SwiftUI

struct SignUpHeightView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var coordinator: SignUpFlowCoordinator
    @State private var height: Double = 170 // cm
    @State private var navigateToWeight = false
    
    @State private var headingOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var showHeightPicker = false
    
    var heightInFeetInches: (feet: Int, inches: Int) {
        let totalInches = height / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return (feet, inches)
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
                            Text("Your Height")
                                .font(.custom("ProductSans-Regular", size: 40))
                                .foregroundColor(.white)
                                .opacity(headingOpacity)
                            
                            Text("What is your height?")
                                .font(.custom("ProductSans-Regular", size: 16))
                                .foregroundColor(.white.opacity(0.7))
                                .opacity(headingOpacity)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 48)
                        
                        // Height Card
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            showHeightPicker = true
                        }) {
                            VStack(spacing: 12) {
                                Text("\(Int(height))")
                                    .font(.custom("ProductSans-Bold", size: 64))
                                    .foregroundColor(.white)
                                
                                Text("cm")
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
                                .foregroundColor(.black)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(.white)
                                )
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
                ProgressBar(currentStep: 3, totalSteps: 7)
            }
        }
        .onAppear {
            startAnimations()
        }
        .navigationDestination(isPresented: $navigateToWeight) {
            SignUpWeightView(coordinator: coordinator)
        }
        .sheet(isPresented: $showHeightPicker) {
            HeightPickerSheet(
                selectedHeight: $height,
                isPresented: $showHeightPicker
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
    
    private func handleContinue() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        coordinator.updateHeight("\(Int(height))", unit: "cm")
        coordinator.nextStep()
        navigateToWeight = true
    }
}

// MARK: - Height Picker Sheet
struct HeightPickerSheet: View {
    @Binding var selectedHeight: Double
    @Binding var isPresented: Bool
    @State private var heightUnit: String = "cm"
    @State private var selectedFeet: Int = 5
    @State private var selectedInches: Int = 9
    
    var heightInFeetInches: (feet: Int, inches: Int) {
        let totalInches = selectedHeight / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return (feet, inches)
    }
    
    var body: some View {
        ZStack {
            Theme.colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Your height")
                        .font(.custom("ProductSans-Bold", size: 17))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Unit Toggle
                    HStack(spacing: 0) {
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            if heightUnit != "cm" {
                                // Convert from ft/in to cm
                                let totalInches = Double(selectedFeet * 12 + selectedInches)
                                selectedHeight = totalInches * 2.54
                            }
                            heightUnit = "cm"
                        }) {
                            Text("cm")
                                .font(.custom(heightUnit == "cm" ? "ProductSans-Bold" : "ProductSans-Regular", size: 15))
                                .foregroundColor(heightUnit == "cm" ? Color.black : Color.white.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(minWidth: 60)
                        }
                        
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            if heightUnit != "ft/in" {
                                // Convert from cm to ft/in
                                let (feet, inches) = heightInFeetInches
                                selectedFeet = feet
                                selectedInches = inches
                            }
                            heightUnit = "ft/in"
                        }) {
                            Text("ft/in")
                                .font(.custom(heightUnit == "ft/in" ? "ProductSans-Bold" : "ProductSans-Regular", size: 15))
                                .foregroundColor(heightUnit == "ft/in" ? Color.black : Color.white.opacity(0.7))
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
                                .offset(x: heightUnit == "cm" ? 0 : geometry.size.width / 2)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: heightUnit)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                // Picker
                if heightUnit == "cm" {
                    Picker("Height", selection: $selectedHeight) {
                        ForEach(Array(stride(from: 100, through: 250, by: 1)), id: \.self) { value in
                            Text("\(Int(value)) cm")
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .colorScheme(.dark)
                    .accentColor(Theme.colors.button)
                    .padding(.horizontal, 24)
                } else {
                    // Feet and Inches pickers
                    HStack(spacing: 0) {
                        Picker("Feet", selection: $selectedFeet) {
                            ForEach(3..<8, id: \.self) { feet in
                                Text("\(feet) ft")
                                    .tag(feet)
                            }
                        }
                        .pickerStyle(.wheel)
                        .colorScheme(.dark)
                        .accentColor(Theme.colors.button)
                        .frame(maxWidth: .infinity)
                        .onChange(of: selectedFeet) { oldValue, newValue in
                            updateHeightFromFeetInches()
                        }
                        
                        Picker("Inches", selection: $selectedInches) {
                            ForEach(0..<12, id: \.self) { inches in
                                Text("\(inches) in")
                                    .tag(inches)
                            }
                        }
                        .pickerStyle(.wheel)
                        .colorScheme(.dark)
                        .accentColor(Theme.colors.button)
                        .frame(maxWidth: .infinity)
                        .onChange(of: selectedInches) { oldValue, newValue in
                            updateHeightFromFeetInches()
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // Done Button
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
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
            // Initialize feet/inches from current height
            let (feet, inches) = heightInFeetInches
            selectedFeet = feet
            selectedInches = inches
        }
    }
    
    private func updateHeightFromFeetInches() {
        let totalInches = Double(selectedFeet * 12 + selectedInches)
        selectedHeight = totalInches * 2.54
    }
}

