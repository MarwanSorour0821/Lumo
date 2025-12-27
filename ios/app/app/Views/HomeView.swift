//
//  HomeView.swift
//  app
//
//  Created on iOS
//

import SwiftUI

struct HomeView: View {
    @State private var showAnalyseModal = false
    
    var body: some View {
        ZStack {
            TabView {
                HomeTabView()
                    .tabItem {
                        Image("HomeIcon")
                        Text("Home")
                    }
                
                HistoryTabView()
                    .tabItem {
                        Label("History", systemImage: "chart.line.uptrend.xyaxis")
                    }
                
                ChatTabView()
                    .tabItem {
                        Label("Chat", systemImage: "message")
                    }
                
                SettingsTabView()
                    .tabItem {
                        Label("Me", systemImage: "person.circle")
                    }
            }
            .accentColor(Color(hex: "#C7002B"))
            .preferredColorScheme(.dark)
            
            // Floating Analyse Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        showAnalyseModal = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(Color(hex: "#C7002B"))
                                    .shadow(color: Color(hex: "#BB3E4F").opacity(0.6), radius: 16, x: 0, y: 6)
                            )
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 70) // Position above tab bar
                }
            }
        }
        .sheet(isPresented: $showAnalyseModal) {
            AnalyseModalView(isPresented: $showAnalyseModal)
        }
    }
}

// MARK: - Home Tab View
struct HomeTabView: View {
    let score: Double = 8.8
    let categories: [(icon: String, color: Color, progress: Double)] = [
        ("figure.walk", .yellow, 0.8),
        ("leaf.fill", .green, 0.9),
        ("heart.fill", .pink, 0.7),
        ("brain.head.profile", .blue, 0.85),
        ("bed.double.fill", .purple, 0.6),
        ("fork.knife", .orange, 0.75),
        ("figure.run", .mint, 0.88),
        ("drop.fill", .cyan, 0.92)
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Circular health score
                ZStack {
                    // Category segments around the circle
                    ForEach(0..<categories.count, id: \.self) { index in
                        CategorySegment(
                            category: categories[index],
                            index: index,
                            total: categories.count
                        )
                    }
                    
                    // Center score display
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", score))
                            .font(.system(size: 72, weight: .bold))
                        Text("your health score")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 300, height: 300)
                
                // Plan check-up button
                Button(action: {}) {
                    Text("Plan check-up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .cornerRadius(30)
                }
            }
        }
    }
}

struct CategorySegment: View {
    let category: (icon: String, color: Color, progress: Double)
    let index: Int
    let total: Int
    
    var body: some View {
        let angle = (360.0 / Double(total)) * Double(index)
        let radius: CGFloat = 120
        
        // Calculate position around circle
        let x = cos((angle - 90) * .pi / 180) * radius
        let y = sin((angle - 90) * .pi / 180) * radius
        
        // Progress arc background (white, transparent)
        Circle()
            .trim(from: angleStart, to: angleEnd)
            .stroke(Color.white.opacity(0.2), lineWidth: 30)
            .frame(width: 240, height: 240)
            .rotationEffect(.degrees(angle - 22.5))
        
        // Progress arc fill (white)
        Circle()
            .trim(from: 0, to: category.progress * (angleEnd - angleStart))
            .stroke(Color.white, style: StrokeStyle(lineWidth: 30, lineCap: .round))
            .frame(width: 240, height: 240)
            .rotationEffect(.degrees(angle - 22.5))
        
        // Icon
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 50, height: 50)
            
            Image(systemName: category.icon)
                .font(.system(size: 20))
                .foregroundColor(.black)
        }
        .offset(x: x, y: y)
    }
    
    var angleStart: CGFloat {
        0
    }
    
    var angleEnd: CGFloat {
        0.8 / Double(total) // Leaves gaps between segments
    }
}

// MARK: - History Tab View
struct HistoryTabView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("History")
                    .font(.custom("ProductSans-Bold", size: 32))
                    .foregroundColor(.white)
                
                Text("Your test history")
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(Color(hex: "#808080"))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Chat Tab View
struct ChatTabView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Chat")
                    .font(.custom("ProductSans-Bold", size: 32))
                    .foregroundColor(.white)
                
                Text("Get medical advice")
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(Color(hex: "#808080"))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Settings Tab View
struct SettingsTabView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "#B01328"), Color(hex: "#C01328")]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )
                        
                        Text("Me")
                            .font(.custom("ProductSans-Bold", size: 32))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 40)
                    
                    // Settings Options
                    VStack(spacing: 12) {
                        settingsRow(icon: "person.fill", title: "Personal Information")
                        settingsRow(icon: "bell.fill", title: "Notifications")
                        settingsRow(icon: "lock.fill", title: "Privacy & Security")
                        settingsRow(icon: "questionmark.circle.fill", title: "Help & Support")
                        
                        // Sign Out Button
                        Button {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.right.square.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#C7002B"))
                                
                                Text("Sign Out")
                                    .font(.custom("ProductSans-Bold", size: 16))
                                    .foregroundColor(Color(hex: "#C7002B"))
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(Color(hex: "#1A1A1A"))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
                .padding(.bottom, 20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func settingsRow(icon: String, title: String) -> some View {
        Button {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#808080"))
            }
            .padding(16)
            .background(Color(hex: "#1A1A1A"))
            .cornerRadius(12)
        }
    }
}

// MARK: - Analyse Modal View
struct AnalyseModalView: View {
    @Binding var isPresented: Bool
    @State private var selectedFile: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Drag Handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "#333333"))
                    .frame(width: 40, height: 4)
                    .padding(.top, 8)
                
                Spacer()
                
                if selectedFile == nil {
                    // Upload Options
                    VStack(spacing: 16) {
                        Text("Add Post")
                            .font(.custom("ProductSans-Bold", size: 18))
                            .foregroundColor(.white)
                        
                        Text("Export post to upload here")
                            .font(.custom("ProductSans-Regular", size: 14))
                            .foregroundColor(Color(hex: "#808080"))
                        
                        HStack(spacing: 16) {
                            uploadOption(icon: "camera.fill", title: "Camera")
                            uploadOption(icon: "photo.fill", title: "Photo")
                            uploadOption(icon: "doc.fill", title: "File")
                        }
                        .padding(.top, 16)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#333333"), style: StrokeStyle(lineWidth: 2, dash: [5]))
                    )
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // Continue Button
                Button {
                    // Handle continue action
                } label: {
                    HStack {
                        Text("Continue")
                            .font(.custom("ProductSans-Bold", size: 16))
                            .foregroundColor(selectedFile == nil ? Color(hex: "#808080") : .white)
                        
                        Image(systemName: "arrow.right")
                            .foregroundColor(selectedFile == nil ? Color(hex: "#808080") : .white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedFile == nil ? Color(hex: "#333333") : Color(hex: "#C7002B"))
                    .cornerRadius(24)
                }
                .disabled(selectedFile == nil)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Color(hex: "#1A1A1A"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func uploadOption(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color(hex: "#1A1A1A"))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                )
            
            Text(title)
                .font(.custom("ProductSans-Regular", size: 14))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
