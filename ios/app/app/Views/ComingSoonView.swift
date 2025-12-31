import SwiftUI

/// A view that displays "Coming Soon" message for features under development
struct ComingSoonView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppColors.background(themeManager.colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                Text("Coming Soon...")
                    .font(.custom("InstrumentSerif-Regular", size: 48))
                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
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
