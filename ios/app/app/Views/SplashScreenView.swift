//
//  SplashScreenView.swift
//  app
//
//  Created on iOS
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Logo and Text
            HStack(spacing: 12) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .opacity(opacity)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                
                Text("Lumo")
                    .font(.custom("ProductSans-Bold", size: 42))
                    .foregroundColor(.white)
                    .opacity(opacity)
                    .offset(x: isAnimating ? 0 : -20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                opacity = 1.0
                isAnimating = true
            }
        }
    }
}

