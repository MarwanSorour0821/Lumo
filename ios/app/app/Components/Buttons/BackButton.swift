//
//  BackButton.swift
//  app
//
//  Created on iOS
//

import SwiftUI

struct BackButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(AppColors.text(themeManager.colorScheme))
                .frame(width: 24, height: 24)
        }
    }
}





