import SwiftUI

struct RoleSelectionView: View {
    @State private var selectedRole: String? = nil
    @State private var navigateToLogin = false
    let roles = ["Fleet Manager", "Driver", "Maintenance Personnel"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("TrackNGo")
                    .font(.system(.title, design: .default))
                    .fontWeight(.bold)
                    .foregroundColor(Color.blue.opacity(0.5))
                    .padding(.top, 20)
                
                Image("image")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .padding(.bottom, 20)
                
                Text("Select Your Role")
                    .font(.system(.headline, design: .default))
                
                VStack(spacing: 10) {
                    ForEach(roles, id: \.self) { role in
                        Button(action: {
                            selectedRole = role
                            UserDefaults.standard.set(role, forKey: "selectedRole")
                            navigateToLogin = true
                        }) {
                            HStack {
                                Image(systemName: "person.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)
                                
                                Text(role)
                                    .font(.headline)
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.white)
                                    .shadow(color: Color.gray.opacity(0.3), radius: 5, x: 0, y: 2)
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding()
            .navigationDestination(isPresented: $navigateToLogin) {
                NavigationStack {
                    LoginView(selectedRole: selectedRole ?? "")
                }
            }
        }
    }
}

struct LoginView: View {
    var selectedRole: String
    @State private var email: String = ""
    @State private var password: String = ""
    @FocusState private var isPasswordFocused: Bool
    @State private var passwordFieldHasBeenFocused: Bool = false
    @StateObject private var dataController = SupabaseDataController.shared
    @State private var isLoading: Bool = false
    @State private var navigateToVerify = false
    @State private var isPasswordVisible: Bool = false
    @State private var navigateToForgotPassword = false
    
    var body: some View {
        VStack {
            Spacer()  // Pushes the content to the vertical center
            
            VStack(spacing: 20) {
                Text("Login as \(selectedRole)")
                    .multilineTextAlignment(.center)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Color.blue.opacity(0.5))
                    .padding(.top, 20)
                    
                TextField("Email", text: $email)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .cornerRadius(25)
                    .shadow(radius: 1)
                    .padding(.horizontal, 20)
                
                ZStack(alignment: .trailing) {
                    Group {
                        if isPasswordVisible {
                            TextField("Password", text: $password)
                                .autocapitalization(.none)
                                .focused($isPasswordFocused)
                        } else {
                            SecureField("Password", text: $password)
                                .focused($isPasswordFocused)
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .cornerRadius(25)
                    .shadow(radius: 1)
                    .padding(.horizontal, 20)
                    
                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 30)
                    }
                }
                
                // Show criteria view if the field has been focused at least once.
                if passwordFieldHasBeenFocused {
                    PasswordCriteriaView(password: password)
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.7, dampingFraction: 0.8, blendDuration: 0.5), value: password)
                }
                
                Button(action: {
                    dataController.signInWithPassword(email: email, password: password, roleName: selectedRole) { success, error in
                        if success {
                            print("success")
                            if !dataController.isGenPass, dataController.is2faEnabled {
                                if dataController.roleMatched {
                                    dataController.sendOTP(email: email) { success, error in
                                        if success {
                                            print("OTP sent")
                                        } else {
                                            print("Failed to send OTP: \(error ?? "Unknown error")")
                                        }
                                    }
                                }
                                navigateToVerify = dataController.roleMatched
                            }
                        } else {
                            print("Cannot sign in")
                        }
                    }
                }) {
                    Text("Login")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .cornerRadius(25)
                        .padding(.horizontal, 20)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLoading || !isValidEmail(email) || !isValidPassword(password))
                
                // Forgot Password Button
                Button(action: {
                    navigateToForgotPassword = true
                }) {
                    Text("Forgot Password?")
                        .foregroundColor(.blue)
                        .font(.footnote)
                }
                .padding(.top, 5)
            }
            .padding(.trailing, 16)
            .padding(.leading, 16)
            
            Spacer()  // Pushes the content to the vertical center
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(isPresented: $dataController.showAlert) {
            Alert(title: Text("Alert"), message: Text(dataController.alertMessage), dismissButton: .default(Text("OK")))
        }
        .navigationDestination(isPresented: $navigateToVerify) {
            VerifyOTPView(email: email)
        }
        .navigationDestination(isPresented: $navigateToForgotPassword) {
            ForgotPasswordView()
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[#$@!%&*?])[A-Za-z\\d#$@!%&*?]{6,}$"
        return NSPredicate(format: "SELF MATCHES %@", passwordRegex).evaluate(with: password)
    }
}


struct PasswordCriteriaView: View {
    let password: String
    
    // Individual criteria computed properties
    var isMinLength: Bool { password.count >= 6 }
    var hasUppercase: Bool { password.rangeOfCharacter(from: .uppercaseLetters) != nil }
    var hasSpecialChar: Bool {
        let specialCharacters = CharacterSet(charactersIn: "#$@!%&*?")
        return password.rangeOfCharacter(from: specialCharacters) != nil
    }
    var hasNumber: Bool { password.rangeOfCharacter(from: .decimalDigits) != nil }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Password Requirements")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            criteriaRow(isMet: isMinLength, text: "At least 6 characters")
            criteriaRow(isMet: hasUppercase, text: "Contains an uppercase letter")
            criteriaRow(isMet: hasSpecialChar, text: "Contains a special character")
            criteriaRow(isMet: hasNumber, text: "Contains a number")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemGray6))
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

struct VerifyOTPView: View {
    var email: String
    @State private var otpCode: String = ""
    @State private var isLoading = false
    @State private var resendCooldown: Int = 0
    @State private var timer: Timer? = nil
    @StateObject private var dataController = SupabaseDataController.shared

    var body: some View {
        VStack(spacing: 30) {
            Text("Enter OTP Sent to")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(email)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Color.pink.opacity(0.8))
            
            TextField("Enter OTP", text: $otpCode)
                .keyboardType(.numberPad)
                .padding()
                .background(Color(.systemGray6))
                .foregroundColor(.primary)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))
                .padding(.horizontal, 20)
            
            Button(action: verifyOTP) {
                HStack {
                    if isLoading {
                        ProgressView()
                    }
                    Text("Verify OTP")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(10)
                .padding(.horizontal, 20)
            }
            .disabled(isLoading || otpCode.isEmpty)
            
            Button(action: resendOTP) {
                if resendCooldown > 0 {
                    Text("Resend OTP (\(resendCooldown)s)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                } else {
                    Text("Resend OTP")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .underline()
                }
            }
            .disabled(resendCooldown > 0)
            
            Spacer()
        }
        .padding()
        .alert(isPresented: $dataController.showAlert) {
            Alert(title: Text("Alert"), message: Text(dataController.alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func verifyOTP() {
        isLoading = true
        dataController.verifyOTP(email: email, token: otpCode) { success, error in
            isLoading = false
            if success {
                print("OTP verified")
            } else {
                print("OTP verification failed: \(error ?? "Unknown error")")
            }
        }
    }
    
    private func resendOTP() {
        // Start cooldown only if not in cooldown period.
        guard resendCooldown == 0 else { return }
        
        dataController.sendOTP(email: email) { success, error in
            if success {
                print("OTP sent again")
                startCooldown()
            } else {
                print("Failed to send OTP: \(error ?? "Unknown error")")
            }
        }
    }
    
    private func startCooldown() {
        resendCooldown = 60
        timer?.invalidate()  // invalidate any existing timer
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if resendCooldown > 0 {
                resendCooldown -= 1
            } else {
                timer?.invalidate()
                timer = nil
            }
        }
    }
}

//struct ForgotPasswordView: View {
//    @State private var email: String = ""
//    @State private var newPassword: String = ""
//    @State private var confirmPassword: String = ""
//    @State private var isLoading: Bool = false
//    @State private var showAlert: Bool = false
//    @State private var alertMessage: String = ""
//
//    var body: some View {
//        VStack(spacing: 20) {
//            Text("Forgot Password")
//                .font(.title)
//                .fontWeight(.bold)
//                .foregroundColor(Color.pink.opacity(0.5))
//                .padding(.top, 20)
//            
//            TextField("Enter your email", text: $email)
//                .keyboardType(.emailAddress)
//                .autocapitalization(.none)
//                .padding()
//                .background(Color(.systemGray6))
//                .foregroundColor(.primary)
//                .cornerRadius(8)
//            
//            TextField("Enter new password", text: $newPassword)
//                .autocapitalization(.none)
//                .padding(10)
//                .background(Color(.systemGray6))
//                .foregroundColor(.primary)
//                .cornerRadius(8)
//            
//            SecureField("Enter new password", text: $newPassword)
//                .autocapitalization(.none)
//                .padding(10)
//                .background(Color(.systemGray6))
//                .foregroundColor(.primary)
//                .cornerRadius(8)
//            
//            SecureField("Confirm new password", text: $confirmPassword)
//                .padding(10)
//                .background(Color(.systemGray6))
//                .foregroundColor(.primary)
//                .cornerRadius(8)
//            
//            Button(action: {
//                // Implement password reset logic here
//            }) {
//                Text("Reset Password")
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .padding()
//                    .frame(maxWidth: .infinity)
//                    .background(Color.accentColor)
//                    .cornerRadius(25)
//                    .padding(.horizontal, 20)
//            }
//            .buttonStyle(PlainButtonStyle())
//            .disabled(isLoading || !isValidEmail(email) || !isValidPassword(newPassword) || newPassword != confirmPassword)
//            
//            Spacer()
//        }
//        .padding()
//        .alert(isPresented: $showAlert) {
//            Alert(title: Text("Alert"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
//        }
//    }
//    
//    private func isValidEmail(_ email: String) -> Bool {
//        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
//        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
//    }
//    
//    private func isValidPassword(_ password: String) -> Bool {
//        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[#$@!%&*?])[A-Za-z\\d#$@!%&*?]{6,}$"
//        return NSPredicate(format: "SELF MATCHES %@", passwordRegex).evaluate(with: password)
//    }
//}

#Preview {
    RoleSelectionView()
}
