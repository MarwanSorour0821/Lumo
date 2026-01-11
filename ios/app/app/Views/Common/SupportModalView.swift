//
//  SupportModalView.swift
//  app
//
//  Support modal for submitting help requests
//

import SwiftUI
import MessageUI
import Supabase
import Auth

struct SupportModalView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    
    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var userEmail: String = ""
    @State private var userName: String = ""
    @State private var isLoading: Bool = true
    @State private var showMailComposer: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    private let supportEmail = "lumobloodapp@gmail.com"
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background(themeManager.colorScheme)
                    .ignoresSafeArea()
                    .onTapGesture {
                        hideKeyboard()
                    }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "envelope.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(AppColors.primary)
                            
                            Text("Contact Support")
                                .font(.custom("ProductSans-Bold", size: 28))
                                .foregroundColor(AppColors.text(themeManager.colorScheme))
                            
                            Text("We're here to help! Send us a message and we'll get back to you as soon as possible.")
                                .font(.custom("ProductSans-Regular", size: 14))
                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(.top, 20)
                        
                        // Form
                        VStack(spacing: 16) {
                            // Subject Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Subject")
                                    .font(.custom("ProductSans-Bold", size: 14))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                
                                TextField("Brief description of your issue", text: $subject)
                                    .font(.custom("ProductSans-Regular", size: 16))
                                    .padding(16)
                                    .background(AppColors.inputBackground(themeManager.colorScheme))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    .cornerRadius(12)
                            }
                            
                            // Message Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Message")
                                    .font(.custom("ProductSans-Bold", size: 14))
                                    .foregroundColor(AppColors.text(themeManager.colorScheme))
                                
                                ZStack(alignment: .topLeading) {
                                    if message.isEmpty {
                                        Text("Please describe your issue in detail...")
                                            .font(.custom("ProductSans-Regular", size: 16))
                                            .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 20)
                                    }
                                    
                                    TextEditor(text: $message)
                                        .font(.custom("ProductSans-Regular", size: 16))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                        .padding(12)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                }
                                .frame(height: 200)
                                .background(AppColors.inputBackground(themeManager.colorScheme))
                                .cornerRadius(12)
                            }
                            
                            // User Info (Read-only)
                            if !userEmail.isEmpty || !userName.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Your Information")
                                        .font(.custom("ProductSans-Bold", size: 14))
                                        .foregroundColor(AppColors.text(themeManager.colorScheme))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        if !userName.isEmpty {
                                            Text("Name: \(userName)")
                                                .font(.custom("ProductSans-Regular", size: 14))
                                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                        }
                                        if !userEmail.isEmpty {
                                            Text("Email: \(userEmail)")
                                                .font(.custom("ProductSans-Regular", size: 14))
                                                .foregroundColor(AppColors.textSecondary(themeManager.colorScheme))
                                        }
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppColors.inputBackground(themeManager.colorScheme))
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Send Button
                            Button(action: {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                handleSendSupport()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 16))
                                    Text("Send Message")
                                        .font(.custom("ProductSans-Bold", size: 16))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 28)
                                        .fill(canSend ? AppColors.primary : Color.gray.opacity(0.5))
                                )
                            }
                            .disabled(!canSend)
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer()
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
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
            }
        }
        .onAppear {
            loadUserInfo()
        }
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(
                recipients: [supportEmail],
                subject: subject,
                messageBody: generateEmailBody(),
                isPresented: $showMailComposer
            )
        }
        .alert("Unable to Send Email", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var canSend: Bool {
        !subject.trimmingCharacters(in: .whitespaces).isEmpty &&
        !message.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func loadUserInfo() {
        Task {
            do {
                // Get user email from Supabase auth
                guard let client = SupabaseManager.shared.getClient() else { return }
                let session = try await client.auth.session
                
                await MainActor.run {
                    userEmail = session.user.email ?? ""
                    isLoading = false
                }
                
                // Try to get user's name
                let userId = try await AuthService.shared.getCurrentUserId()
                guard let supabaseURL = SupabaseManager.shared.getURL(),
                      let supabaseKey = SupabaseManager.shared.getAnonKey(),
                      let url = URL(string: "\(supabaseURL)/rest/v1/users?id=eq.\(userId)&select=first_name,last_name") else {
                    return
                }
                
                let accessToken = try await AuthService.shared.getAccessToken()
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
                
                struct UserProfile: Codable {
                    let first_name: String?
                    let last_name: String?
                }
                
                let (data, _) = try await URLSession.shared.data(for: request)
                let decoder = JSONDecoder()
                
                if let profiles = try? decoder.decode([UserProfile].self, from: data),
                   let profile = profiles.first {
                    await MainActor.run {
                        if let firstName = profile.first_name, !firstName.isEmpty {
                            userName = firstName
                            if let lastName = profile.last_name, !lastName.isEmpty {
                                userName += " \(lastName)"
                            }
                        }
                    }
                }
            } catch {
                print("Error loading user info: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func generateEmailBody() -> String {
        var body = message + "\n\n"
        body += "---\n"
        body += "User Information:\n"
        if !userName.isEmpty {
            body += "Name: \(userName)\n"
        }
        if !userEmail.isEmpty {
            body += "Email: \(userEmail)\n"
        }
        body += "App: Lumo iOS\n"
        body += "Date: \(Date().formatted(date: .long, time: .shortened))\n"
        return body
    }
    
    private func handleSendSupport() {
        // Check if Mail is available
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            // Fallback: Open mailto link in default browser/app
            let urlString = generateMailtoURL()
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url) { success in
                    if success {
                        isPresented = false
                    } else {
                        alertMessage = "Unable to open email. Please email us directly at \(supportEmail)"
                        showAlert = true
                    }
                }
            } else {
                alertMessage = "Unable to open email. Please email us directly at \(supportEmail)"
                showAlert = true
            }
        }
    }
    
    private func generateMailtoURL() -> String {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = generateEmailBody().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)"
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Mail Compose View Wrapper
struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let messageBody: String
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(messageBody, isHTML: false)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.isPresented = false
        }
    }
}

// MARK: - Preview
#Preview {
    SupportModalView(isPresented: .constant(true))
        .environmentObject(ThemeManager.shared)
}
