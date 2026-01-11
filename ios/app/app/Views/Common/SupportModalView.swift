//
//  SupportModalView.swift
//  app
//
//  Support modal for submitting help requests
//

import SwiftUI
import WebKit

struct SupportModalView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    
    private let feedbackURL = "https://lumoapp.userjot.com/?cursor=1&order=top&limit=10&status=%5B%22PENDING%22%2C%22REVIEW%22%2C%22PLANNED%22%2C%22PROGRESS%22%5D"
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()
                
                WebView(urlString: feedbackURL)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.text(themeManager.colorScheme))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Support and Feedback")
                        .font(.custom("ProductSans-Bold", size: 17))
                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                }
            }
        }
    }
}

// MARK: - WebView
struct WebView: UIViewRepresentable {
    let urlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // Optional: Show loading indicator
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Optional: Hide loading indicator
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview
#Preview {
    SupportModalView(isPresented: .constant(true))
        .environmentObject(ThemeManager.shared)
}
