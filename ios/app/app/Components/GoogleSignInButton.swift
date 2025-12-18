//
//  GoogleSignInButton.swift
//  app
//
//  Created on iOS
//

import SwiftUI

struct GoogleSignInButton: View {
    let onPress: () -> Void
    var loading: Bool = false
    var disabled: Bool = false
    var text: String = "Continue with Google"
    
    var body: some View {
        Button(action: onPress) {
            if loading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    .frame(height: 20)
            } else {
                HStack(spacing: 12) {
                    GoogleIcon()
                    Text(text)
                        .font(.custom("ProductSans-Bold", size: 16))
                        .foregroundColor(.black)
                }
            }
        }
        .disabled(disabled || loading)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(Color.white)
        .cornerRadius(28)
        .opacity((disabled || loading) ? 0.6 : 1.0)
    }
}

// MARK: - Google Icon
struct GoogleIcon: View {
    var body: some View {
        // Try to use image asset first (simplest approach)
        // If you add "GoogleIcon" to Assets.xcassets, it will use that
        // Otherwise, fallback to Canvas implementation
        Group {
            if UIImage(named: "GoogleIcon") != nil {
                Image("GoogleIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            } else {
                // Canvas fallback - matches React Native SVG
                googleIconCanvas
            }
        }
    }
    
    private var googleIconCanvas: some View {
        Canvas { context, size in
            let scale = min(size.width / 16, size.height / 16)
            
            // Red path
            var redPath = Path()
            redPath.move(to: CGPoint(x: 7.209, y: 1.061))
            redPath.addCurve(to: CGPoint(x: 9.142, y: 1.061), 
                           control1: CGPoint(x: 7.934, y: 0.98), 
                           control2: CGPoint(x: 8.363, y: 0.98))
            redPath.addCurve(to: CGPoint(x: 12.792, y: 2.881), 
                           control1: CGPoint(x: 10.466, y: 1.289), 
                           control2: CGPoint(x: 11.619, y: 1.863))
            redPath.addCurve(to: CGPoint(x: 10.806, y: 4.811), 
                           control1: CGPoint(x: 12.13, y: 3.524), 
                           control2: CGPoint(x: 11.468, y: 4.168))
            redPath.addCurve(to: CGPoint(x: 6.618, y: 4.077), 
                           control1: CGPoint(x: 9.555, y: 3.461), 
                           control2: CGPoint(x: 8.181, y: 3.221))
            redPath.addCurve(to: CGPoint(x: 4.256, y: 6.605), 
                           control1: CGPoint(x: 5.488, y: 4.597), 
                           control2: CGPoint(x: 4.922, y: 5.377))
            redPath.addCurve(to: CGPoint(x: 2.108, y: 4.947), 
                           control1: CGPoint(x: 3.539, y: 6.052), 
                           control2: CGPoint(x: 2.824, y: 5.499))
            redPath.addCurve(to: CGPoint(x: 1.948, y: 4.92), 
                           control1: CGPoint(x: 2.055, y: 4.937), 
                           control2: CGPoint(x: 2.001, y: 4.929))
            redPath.addCurve(to: CGPoint(x: 7.209, y: 1.061), 
                           control1: CGPoint(x: 3.631, y: 1.675), 
                           control2: CGPoint(x: 5.314, y: 0.43))
            context.fill(redPath, with: .color(Color(red: 0.956, green: 0.263, blue: 0.212).opacity(0.987)))
            
            // Yellow path
            var yellowPath = Path()
            yellowPath.move(to: CGPoint(x: 1.946, y: 4.92))
            yellowPath.addCurve(to: CGPoint(x: 2.107, y: 4.947), 
                              control1: CGPoint(x: 2.031, y: 4.907), 
                              control2: CGPoint(x: 2.046, y: 4.934))
            yellowPath.addCurve(to: CGPoint(x: 4.255, y: 6.605), 
                              control1: CGPoint(x: 2.824, y: 5.499), 
                              control2: CGPoint(x: 3.539, y: 6.052))
            yellowPath.addCurve(to: CGPoint(x: 4.04, y: 7.99), 
                              control1: CGPoint(x: 4.178, y: 7.013), 
                              control2: CGPoint(x: 4.103, y: 7.502))
            yellowPath.addCurve(to: CGPoint(x: 4.255, y: 9.321), 
                              control1: CGPoint(x: 4.077, y: 8.668), 
                              control2: CGPoint(x: 4.152, y: 9.01))
            yellowPath.addLine(to: CGPoint(x: 2, y: 11.116))
            yellowPath.addCurve(to: CGPoint(x: 1.946, y: 4.92), 
                              control1: CGPoint(x: 0.527, y: 8.038), 
                              control2: CGPoint(x: 0.857, y: 6.288))
            context.fill(yellowPath, with: .color(Color(red: 1, green: 0.757, blue: 0.027).opacity(0.997)))
            
            // Blue path
            var bluePath = Path()
            bluePath.move(to: CGPoint(x: 12.685, y: 13.29))
            bluePath.addCurve(to: CGPoint(x: 10.483, y: 11.55), 
                            control1: CGPoint(x: 11.951, y: 12.71), 
                            control2: CGPoint(x: 11.217, y: 12.13))
            bluePath.addCurve(to: CGPoint(x: 11.879, y: 9.322), 
                            control1: CGPoint(x: 10.867, y: 10.738), 
                            control2: CGPoint(x: 11.333, y: 10.134))
            bluePath.addLine(to: CGPoint(x: 8.122, y: 9.322))
            bluePath.addLine(to: CGPoint(x: 8.122, y: 6.713))
            bluePath.addCurve(to: CGPoint(x: 14.619, y: 6.768), 
                            control1: CGPoint(x: 10.205, y: 6.704), 
                            control2: CGPoint(x: 12.372, y: 6.695))
            bluePath.addCurve(to: CGPoint(x: 13.196, y: 12.8), 
                            control1: CGPoint(x: 15.235, y: 10.113), 
                            control2: CGPoint(x: 14.773, y: 11.872))
            bluePath.addCurve(to: CGPoint(x: 12.685, y: 13.29), 
                            control1: CGPoint(x: 13.026, y: 12.963), 
                            control2: CGPoint(x: 12.856, y: 13.127))
            context.fill(bluePath, with: .color(Color(red: 0.267, green: 0.541, blue: 1).opacity(0.999)))
            
            // Green path
            var greenPath = Path()
            greenPath.move(to: CGPoint(x: 4.255, y: 9.322))
            greenPath.addCurve(to: CGPoint(x: 8.765, y: 12.176), 
                             control1: CGPoint(x: 5.485, y: 12.379), 
                             control2: CGPoint(x: 7.652, y: 13.03))
            greenPath.addCurve(to: CGPoint(x: 10.483, y: 11.55), 
                             control1: CGPoint(x: 9.338, y: 11.916), 
                             control2: CGPoint(x: 9.911, y: 11.75))
            greenPath.addCurve(to: CGPoint(x: 12.685, y: 13.29), 
                             control1: CGPoint(x: 11.217, y: 12.13), 
                             control2: CGPoint(x: 11.951, y: 12.71))
            greenPath.addCurve(to: CGPoint(x: 8.658, y: 14.974), 
                             control1: CGPoint(x: 11.351, y: 14.006), 
                             control2: CGPoint(x: 10.027, y: 14.658))
            greenPath.addCurve(to: CGPoint(x: 7.638, y: 14.974), 
                             control1: CGPoint(x: 8.318, y: 14.974), 
                             control2: CGPoint(x: 7.978, y: 14.974))
            greenPath.addCurve(to: CGPoint(x: 2, y: 11.116), 
                             control1: CGPoint(x: 3.82, y: 14.524), 
                             control2: CGPoint(x: 2.91, y: 12.82))
            greenPath.addLine(to: CGPoint(x: 4.255, y: 9.322))
            context.fill(greenPath, with: .color(Color(red: 0.263, green: 0.627, blue: 0.278).opacity(0.993)))
            
            context.scaleBy(x: scale, y: scale)
        }
        .frame(width: 20, height: 20)
    }
}

#Preview {
    GoogleSignInButton(onPress: {})
        .padding()
        .background(Color.black)
}

