import SwiftUI

/// A view that displays "Coming Soon" message for features under development
struct ComingSoonView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Adaptive gradient background
            LinearGradient(
                colors: [
                    AppColors.gradientStart(themeManager.colorScheme),
                    AppColors.gradientEnd(themeManager.colorScheme)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                Text("Coming Soon...")
                    .font(.custom("InstrumentSerif-Regular", size: 48))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                    .multilineTextAlignment(.center)
                
                Text("You'll be able to see individual trends \nfor each biomarker here soon!")
                    .font(.custom("ProductSans-Regular", size: 20))
                    .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Your Trends")
                    .font(.custom("ProductSans-Bold", size: 18))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
            }
        }
    }
}

#Preview {
    NavigationView {
        ComingSoonView()
            .environmentObject(ThemeManager.shared)
    }
}
