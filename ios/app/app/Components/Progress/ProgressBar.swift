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
    @Environment(\.appColorScheme) var appColorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(index < currentStep ? Color(hex: "#B01328") : AppColors.border(appColorScheme))
                    .frame(width: index < currentStep ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentStep)
            }
        }
    }
}

