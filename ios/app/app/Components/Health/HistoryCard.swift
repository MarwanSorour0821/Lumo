//
//  HistoryCard.swift
//  app
//
//  Compact card that navigates to the history view
//

import SwiftUI

struct HistoryCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationLink(destination: HistoryTabView().environmentObject(themeManager)) {
            HStack {
                Image(systemName: "square.stack.3d.forward.dottedline")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                
                Text("Your Previous Blood Tests")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                
                Spacer()
                
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(AppColors.modalBackground(themeManager.colorScheme))
            .cornerRadius(12)
        }
        .padding(.horizontal, 24)
        .simultaneousGesture(TapGesture().onEnded {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        })
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 24) {
        HistoryCard()
            .environmentObject(ThemeManager.shared)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
