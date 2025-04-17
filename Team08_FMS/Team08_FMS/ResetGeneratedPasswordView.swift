//
//  ResetPasswordView.swift
//  Team08_FMS
//
//  Created by Snehil on 18/03/25.
//

import SwiftUI

struct ResetGeneratedPasswordView: View {
    let userID: UUID  // User ID passed from login
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isNewPasswordVisible: Bool = false
    @State private var isLoading: Bool = false
    @State private var message: String?
    @State private var showAlert: Bool = false
    
    // Computed property that returns true if all password criteria are met.
    private var isPasswordValid: Bool {
        let hasMinLength = newPassword.count >= 6
        let hasUppercase = newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasSpecialChar = newPassword.rangeOfCharacter(from: CharacterSet(charactersIn: "#$@!%&*?")) != nil
        let hasNumber = newPassword.rangeOfCharacter(from: .decimalDigits) != nil
        let passwordsMatch = newPassword == confirmPassword && !newPassword.isEmpty
        return hasMinLength && hasUppercase && hasSpecialChar && hasNumber && passwordsMatch
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Set a New Password")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            Text("Your password was auto-generated. Please set a new password.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // New Password Field with view password toggle
            ZStack(alignment: .trailing) {
                Group {
                    if isNewPasswordVisible {
                        TextField("New Password", text: $newPassword)
                            .autocapitalization(.none)
                    } else {
                        SecureField("New Password", text: $newPassword)
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 20)
                
                Button(action: {
                    isNewPasswordVisible.toggle()
                }) {
                    Image(systemName: isNewPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.gray)
                        .padding(.trailing, 30)
                }
            }
            
            SecureField("Confirm Password", text: $confirmPassword)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 20)
            
            // Always display the password criteria view
            ResetPasswordCriteriaView(newPassword: newPassword, confirmPassword: confirmPassword)
            
            Button(action: {
                resetPassword()
            }) {
                Text("Update Password")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isPasswordValid ? Color.blue : Color.blue.opacity(0.6))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
            }
            .disabled(isLoading || !isPasswordValid)
            
            Spacer()
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Password Update"),
                message: Text(message ?? "An error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Validates the password using regex (this remains for backend consistency).
    private func isValidPassword(_ password: String) -> Bool {
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[#$@!%&*?])[A-Za-z\\d#$@!%&*?]{6,}$"
        return NSPredicate(format: "SELF MATCHES %@", passwordRegex).evaluate(with: password)
    }
    
    // Function to update password in Supabase.
    private func resetPassword() {
        // Using the isPasswordValid computed property ensures all criteria are met.
        guard isPasswordValid else {
            message = "Please ensure your password meets all the requirements."
            showAlert = true
            return
        }
        
        Task {
            isLoading = true
            let success = await SupabaseDataController.shared.updatePassword(newPassword: newPassword)
            await MainActor.run {
                isLoading = false
                message = success ? "Your password has been updated successfully." : "Failed to update password."
                showAlert = true
            }
        }
    }
}

struct ForgotPasswordView: View {
    enum Step {
        case enterEmail
        case enterOTP
        case resetPassword
    }
    
    @State private var email: String = ""
    @State private var otp: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    
    @State private var step: Step = .enterEmail
    @State private var isNewPasswordVisible = false
    @State private var isLoading: Bool = false
    @State private var alertMessage: String = ""
    @State private var showingAlert: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if step == .enterEmail {
                    Text("Enter your email")
                        .font(.largeTitle)
                        .padding()
                    
                    TextField("Enter your email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                    
                    Button("Send OTP") {
                        isLoading = true
                        SupabaseDataController.shared.sendOTPForForgotPassword(email: email) { result in
                            isLoading = false
                            switch result {
                            case .success:
                                alertMessage = "OTP sent to your email."
                                showingAlert = true
                                step = .enterOTP
                            case .failure(let error):
                                alertMessage = error.localizedDescription
                                showingAlert = true
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(email.isEmpty)
                }
                else if step == .enterOTP {
                    Text("Enter OTP")
                        .font(.title2)
                        .padding()
                    
                    TextField("Enter OTP", text: $otp)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                    
                    Button("Verify OTP") {
                        isLoading = true
                        SupabaseDataController.shared.verifyOTPForForgotPassword(email: email, otp: otp) { result in
                            isLoading = false
                            switch result {
                            case .success:
                                alertMessage = "OTP verified successfully."
                                showingAlert = true
                                step = .resetPassword
                            case .failure(let error):
                                alertMessage = error.localizedDescription
                                showingAlert = true
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(otp.isEmpty)
                }
                else if step == .resetPassword {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("New Password")
                            .font(.headline)
                        
                        // New Password Field with toggle to view/hide text
                        ZStack(alignment: .trailing) {
                            Group {
                                if isNewPasswordVisible {
                                    TextField("Enter new password", text: $newPassword)
                                        .autocapitalization(.none)
                                        .padding(10)
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(8)
                                } else {
                                    SecureField("Enter new password", text: $newPassword)
                                        .autocapitalization(.none)
                                        .padding(10)
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(8)
                                }
                            }
                            Button(action: {
                                isNewPasswordVisible.toggle()
                            }) {
                                Image(systemName: isNewPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 30)
                            }
                        }
                        .padding(.horizontal)
                        
                        SecureField("Confirm new password", text: $confirmPassword)
                            .padding(10)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        
                        ResetPasswordCriteriaView(newPassword: newPassword, confirmPassword: confirmPassword)
                            .padding(.horizontal)
                        
                        Button("Reset Password") {
                            Task {
                                let updated = await SupabaseDataController.shared.resetPassword(newPassword: newPassword)
                                if updated {
                                    SupabaseDataController.shared.signOut()
                                    dismiss()
                                    alertMessage = "Password successfully reset."
                                } else {
                                    alertMessage = "Error updating password."
                                }
                                showingAlert = true
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!isPasswordValid)
                        .padding(.horizontal)
                    }
                    .padding()
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Alert"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
        }
    }
    
    // Password validation logic
    private var isPasswordValid: Bool {
        let hasMinLength = newPassword.count >= 6
        let hasUppercase = newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasSpecialChar = newPassword.rangeOfCharacter(from: CharacterSet(charactersIn: "#$@!%&*?")) != nil
        let hasNumber = newPassword.rangeOfCharacter(from: .decimalDigits) != nil
        let passwordsMatch = newPassword == confirmPassword && !newPassword.isEmpty
        return hasMinLength && hasUppercase && hasSpecialChar && hasNumber && passwordsMatch
    }
}

struct ResetPasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // User credentials and state
    @State private var email = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    @State private var isNewPasswordVisible = false
    @State private var isCurrentPasswordVerified = false
    @State private var isGenPass = true  // Assume true initially; will be updated after password reset
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // Computed property for new password validity
    private var isPasswordValid: Bool {
        let hasMinLength = newPassword.count >= 6
        let hasUppercase = newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasSpecialChar = newPassword.rangeOfCharacter(from: CharacterSet(charactersIn: "#$@!%&*?")) != nil
        let hasNumber = newPassword.rangeOfCharacter(from: .decimalDigits) != nil
        let passwordsMatch = newPassword == confirmPassword && !newPassword.isEmpty
        return hasMinLength && hasUppercase && hasSpecialChar && hasNumber && passwordsMatch
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if !isCurrentPasswordVerified {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Verify Current Password")
                            .font(.headline)
                        
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(10)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                        
                        SecureField("Enter current password", text: $currentPassword)
                            .padding(10)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                        
                        Button(action: {
                            SupabaseDataController.shared.verifyCurrentPassword(email: email, currentPassword: currentPassword) { success in
                                if success {
                                    isCurrentPasswordVerified = true
                                    alertMessage = "Current password verified."
                                } else {
                                    alertMessage = "Incorrect current password."
                                }
                                showingAlert = true
                            }
                        }) {
                            Text("Verify")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding()
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("New Password")
                            .font(.headline)
                        
                        // New Password Field with toggle to view/hide text
                        ZStack(alignment: .trailing) {
                            Group {
                                if isNewPasswordVisible {
                                    TextField("Enter new password", text: $newPassword)
                                        .autocapitalization(.none)
                                        .padding(10)
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(8)
                                } else {
                                    SecureField("Enter new password", text: $newPassword)
                                        .autocapitalization(.none)
                                        .padding(10)
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(8)
                                }
                            }
                            Button(action: {
                                isNewPasswordVisible.toggle()
                            }) {
                                Image(systemName: isNewPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 30)
                            }
                        }
                        .padding(.horizontal)
                        
                        SecureField("Confirm new password", text: $confirmPassword)
                            .padding(10)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        
                        ResetPasswordCriteriaView(newPassword: newPassword, confirmPassword: confirmPassword)
                            .padding(.horizontal)
                        
                        Button("Reset Password") {
                            Task {
                                let updated = await SupabaseDataController.shared.resetPassword(newPassword: newPassword)
                                if updated {
                                    alertMessage = "Password successfully reset."
                                } else {
                                    alertMessage = "Error updating password."
                                }
                                showingAlert = true
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!isPasswordValid)
                        .padding(.horizontal)
                    }
                    .padding()
                }
                Spacer()
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Reset Password"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if alertMessage == "Password successfully reset." {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                )
            }
        }
    }
}

// Custom button style for primary actions
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding()
            .background(configuration.isPressed ? Color.blue.opacity(0.7) : Color.blue)
            .cornerRadius(8)
    }
}

struct ResetPasswordCriteriaView: View {
    let newPassword: String
    let confirmPassword: String
    
    // Computed properties for individual criteria
    var isMinLength: Bool { newPassword.count >= 6 }
    var hasUppercase: Bool { newPassword.rangeOfCharacter(from: .uppercaseLetters) != nil }
    var hasSpecialChar: Bool {
        let specialCharacters = CharacterSet(charactersIn: "#$@!%&*?")
        return newPassword.rangeOfCharacter(from: specialCharacters) != nil
    }
    var hasNumber: Bool { newPassword.rangeOfCharacter(from: .decimalDigits) != nil }
    var passwordsMatch: Bool { newPassword == confirmPassword && !newPassword.isEmpty }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Password Requirements")
                .font(.system(.subheadline, design: .default))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            criteriaRow(isMet: isMinLength, text: "At least 6 characters")
            criteriaRow(isMet: hasUppercase, text: "Contains an uppercase letter")
            criteriaRow(isMet: hasSpecialChar, text: "Contains a special character")
            criteriaRow(isMet: hasNumber, text: "Contains a number")
            criteriaRow(isMet: passwordsMatch, text: "Passwords match")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.tertiarySystemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func criteriaRow(isMet: Bool, text: String) -> some View {
        HStack {
            Image(systemName: isMet ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isMet ? .green : .red)
                .font(.title3)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

#Preview {
    ResetGeneratedPasswordView(userID: UUID())
}
