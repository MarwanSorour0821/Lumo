//
//  SignUpFlowCoordinator.swift
//  app
//
//  Created on iOS
//

import SwiftUI
import Combine

class SignUpFlowCoordinator: ObservableObject {
    @Published var signUpData = SignUpData()
    @Published var currentStep: Int = 1
    
    func updateFirstName(_ name: String) {
        signUpData.firstName = name
    }
    
    func updateLastName(_ name: String) {
        signUpData.lastName = name
    }
    
    func updateEmail(_ email: String) {
        signUpData.email = email
    }
    
    func updatePassword(_ password: String) {
        signUpData.password = password
    }
    
    func updateSex(_ sex: BiologicalSex) {
        signUpData.sex = sex
    }
    
    func updateAge(_ age: String) {
        signUpData.age = age
    }
    
    func updateHeight(_ height: String, feet: String? = nil, inches: String? = nil, unit: String? = nil) {
        signUpData.height = height
        signUpData.heightFeet = feet
        signUpData.heightInches = inches
        signUpData.heightUnit = unit
    }
    
    func updateWeight(_ weight: String, unit: String? = nil) {
        signUpData.weight = weight
        signUpData.weightUnit = unit
    }
    
    func nextStep() {
        currentStep += 1
    }
    
    func previousStep() {
        currentStep = max(1, currentStep - 1)
    }
}

