//
//  AnimatedScoreView.swift
//  app
//
//  Animated health score display with counting animation and haptic feedback
//

import SwiftUI

struct AnimatedScoreView: View {
    let targetScore: Double
    let textColor: Color
    
    @State private var displayedScore: Double = 0.0
    @State private var hasAnimated: Bool = false
    @State private var previousScore: Double = 0.0
    
    // Animation configuration
    private let animationDuration: Double = 1.8
    private let hapticInterval: Double = 0.15 // Haptic every 150ms during animation
    
    var body: some View {
        if #available(iOS 17.0, *) {
            Text(String(format: "%.1f", displayedScore))
                .font(.system(size: 72, weight: .bold))
                .foregroundColor(textColor)
                .contentTransition(.numericText(value: displayedScore))
                .onChange(of: targetScore) { oldValue, newValue in
                    // Only animate if value actually changed and is valid
                    if newValue != previousScore && newValue > 0 {
                        previousScore = newValue
                        animateToScore(newValue)
                    }
                }
                .onAppear {
                    // Animate on first appear if we have a valid score
                    if !hasAnimated && targetScore > 0 {
                        // Small delay for smoother entrance
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            animateToScore(targetScore)
                            hasAnimated = true
                            previousScore = targetScore
                        }
                    }
                }
        } else {
            // Fallback on earlier versions
        }
    }
    
    private func animateToScore(_ score: Double) {
        // Reset to 0 for fresh animation
        displayedScore = 0.0
        
        // Calculate animation parameters
        let startTime = Date()
        let startValue: Double = 0.0
        let endValue = score
        
        // Start haptic feedback timer
        var hapticCount = 0
        let maxHaptics = Int(animationDuration / hapticInterval)
        
        // Use a display link style timer for smooth animation
        let timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in // ~60fps
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / animationDuration, 1.0)
            
            // Easing function: ease-out cubic for natural deceleration
            let easedProgress = 1 - pow(1 - progress, 3)
            
            // Update displayed score
            let newScore = startValue + (endValue - startValue) * easedProgress
            
            DispatchQueue.main.async {
                withAnimation(.linear(duration: 0.016)) {
                    displayedScore = newScore
                }
            }
            
            // Trigger haptic feedback at intervals
            let expectedHapticCount = Int(elapsed / hapticInterval)
            if expectedHapticCount > hapticCount && hapticCount < maxHaptics {
                hapticCount = expectedHapticCount
                
                // Use lighter haptics as we progress
                let impactStyle: UIImpactFeedbackGenerator.FeedbackStyle
                if progress < 0.3 {
                    impactStyle = .light
                } else if progress < 0.7 {
                    impactStyle = .light
                } else {
                    impactStyle = .soft
                }
                
                let haptic = UIImpactFeedbackGenerator(style: impactStyle)
                haptic.impactOccurred(intensity: max(0.3, 1.0 - progress * 0.5))
            }
            
            // Stop when animation is complete
            if progress >= 1.0 {
                timer.invalidate()
                
                // Final haptic with slight delay for "landing" effect
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    let finalHaptic = UIImpactFeedbackGenerator(style: .medium)
                    finalHaptic.impactOccurred(intensity: 0.8)
                    
                    // Ensure final value is exact
                    displayedScore = endValue
                }
            }
        }
        
        RunLoop.main.add(timer, forMode: .common)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 40) {
        AnimatedScoreView(targetScore: 8.5, textColor: .black)
        AnimatedScoreView(targetScore: 6.2, textColor: .gray)
    }
    .padding()
}
