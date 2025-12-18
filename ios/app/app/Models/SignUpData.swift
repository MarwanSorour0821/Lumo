//
//  SignUpData.swift
//  app
//
//  Created on iOS
//

import Foundation

enum BiologicalSex: String, Codable, CaseIterable {
    case male = "male"
    case female = "female"
    case other = "other"
    case preferNotToSay = "prefer_not_to_say"
    
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

struct SignUpData {
    var firstName: String?
    var lastName: String?
    var email: String?
    var password: String?
    var sex: BiologicalSex?
    var age: String?
    var height: String?
    var heightFeet: String?
    var heightInches: String?
    var heightUnit: String?
    var weight: String?
    var weightUnit: String?
    
    // For OAuth sign-ins
    var userId: String?
    var isOAuthSignIn: Bool = false
}

