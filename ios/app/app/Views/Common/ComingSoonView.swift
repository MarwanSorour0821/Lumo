import SwiftUI

/// A view that now redirects to TrendsView for displaying biomarker trends
struct ComingSoonView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        TrendsView()
            .environmentObject(themeManager)
    }
}

#Preview {
    NavigationView {
        ComingSoonView()
            .environmentObject(ThemeManager.shared)
    }
}
