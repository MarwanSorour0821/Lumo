//
//  ProgressBar.swift
//  app
//
//  Created on iOS
//

import SwiftUI

struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(index < currentStep ? Color(hex: "#B01328") : Color.white.opacity(0.3))
                    .frame(width: index < currentStep ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentStep)
            }
        }
    }
}

