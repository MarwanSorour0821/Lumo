//
//  SignUpAgeView.swift
//  app
//
//  Created on iOS
//

import SwiftUI

struct SignUpAgeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var coordinator: SignUpFlowCoordinator
    @State private var selectedBirthday: Date = Calendar.current.date(byAdding: .year, value: -24, to: Date()) ?? Date()
    @State private var navigateToHeight = false
    
    @State private var headingOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var showDatePicker = false
    
    private var calculatedAge: Int {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: selectedBirthday, to: now)
        return ageComponents.year ?? 24
    }
    
    private var birthdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
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
                            Text("When's your birthday?")
                                .font(.custom("ProductSans-Regular", size: 30))
                                .foregroundColor(.white)
                                .opacity(headingOpacity)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("We only use this to calculate your age for health metrics and goals. Your birthday data is kept private and secure.")
                                .font(.custom("ProductSans-Regular", size: 16))
                                .foregroundColor(.white.opacity(0.7))
                                .opacity(headingOpacity)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                        
                        // Birthday Input Field
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Birthday")
                                .font(.custom("ProductSans-Bold", size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Button(action: {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                showDatePicker = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(birthdayFormatter.string(from: selectedBirthday))
                                            .font(.custom("ProductSans-Bold", size: 19))
                                            .foregroundColor(Theme.colors.buttonText)
                                        
                                        Text("\(calculatedAge) years old")
                                            .font(.custom("ProductSans-Regular", size: 15))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "calendar")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                            }
                            
                            // Privacy Statement - Centered
                            HStack {
                                Spacer()
                                HStack(spacing: 6) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Theme.colors.button)
                                    
                                    Text("Your data is private and secure")
                                        .font(.custom("ProductSans-Regular", size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                Spacer()
                            }
                            .padding(.top, 8)
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
                ProgressBar(currentStep: 2, totalSteps: 7)
            }
        }
        .onAppear {
            startAnimations()
        }
        .navigationDestination(isPresented: $navigateToHeight) {
            SignUpHeightView(coordinator: coordinator)
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(
                selectedDate: $selectedBirthday,
                isPresented: $showDatePicker
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
        
        // Store the calculated age (not the birthday) - backend logic unchanged
        coordinator.updateAge("\(calculatedAge)")
        coordinator.nextStep()
        navigateToHeight = true
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Theme.colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(.custom("ProductSans-Regular", size: 17))
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Select Birthday")
                        .font(.custom("ProductSans-Bold", size: 17))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Done") {
                        isPresented = false
                    }
                    .font(.custom("ProductSans-Bold", size: 17))
                    .foregroundColor(Theme.colors.button)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                // Date Picker
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .accentColor(Theme.colors.button)
                .padding(.horizontal, 24)
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
}

