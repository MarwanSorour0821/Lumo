//
//  CustomSpinner.swift
//  app
//
//  Custom spinner component with theme support
//

import SwiftUI

struct CustomSpinner: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isAnimating = false
    
    var size: CGFloat = 24
    var lineWidth: CGFloat = 2.5
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                spinnerColor,
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round
                )
            )
            .frame(width: size, height: size)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .animation(
                Animation.linear(duration: 0.8)
                    .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
    
    private var spinnerColor: Color {
        themeManager.colorScheme == .dark ? .white : .black
    }
}

// Preview
struct CustomSpinner_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CustomSpinner()
                .environmentObject(ThemeManager.shared)
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            CustomSpinner()
                .environmentObject(ThemeManager.shared)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
        .padding()
    }
}
