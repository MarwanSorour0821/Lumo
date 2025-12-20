//
//  InputField.swift
//  app
//
//  Created on iOS
//

import SwiftUI

struct InputField: View {
    let placeholder: String
    @Binding var text: String
    var icon: InputIcon
    var isSecure: Bool = false
    var isEnabled: Bool = true
    var keyboardType: UIKeyboardType = .default
    
    enum InputIcon {
        case email
        case password
        case none
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if icon != .none {
                iconView
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(Color(uiColor: .label))
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .disabled(!isEnabled)
            } else {
                TextField(placeholder, text: $text)
                    .font(.custom("ProductSans-Regular", size: 16))
                    .foregroundColor(Color(uiColor: .label))
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .textContentType(icon == .email ? .emailAddress : .none)
                    .disabled(!isEnabled)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(28)
    }
    
    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .email:
            Image(systemName: "envelope")
                .foregroundColor(Color(uiColor: .secondaryLabel))
                .frame(width: 20, height: 20)
        case .password:
            Image(systemName: "lock")
                .foregroundColor(Color(uiColor: .secondaryLabel))
                .frame(width: 20, height: 20)
        case .none:
            EmptyView()
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        InputField(placeholder: "Email address", text: .constant(""), icon: .email)
        InputField(placeholder: "Password", text: .constant(""), icon: .password, isSecure: true)
    }
    .padding()
    .background(Color(uiColor: .systemBackground))
}

