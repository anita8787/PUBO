import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    @State private var showEmailForm = false
    
    // Pubo Colors
    let navy = Color(hex: "021F3A") // Very dark blue/navy
    let red = Color(hex: "EE4A4A")
    let yellow = Color(hex: "FFCC00")
    
    var body: some View {
        ZStack {
            // Background Image (Fully visible, no dark overlay)
            Image("LoginBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Bottom Button Area
                VStack(spacing: 16) {
                    
                    // Email Login Button
                    Button(action: {
                        isSignUp = false
                        showEmailForm = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 20))
                            Text("start with email")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color(hex: "233783")) // Matches the blue in the reference image
                        .clipShape(Capsule())
                        .retroShadow(color: .black, offset: 3)
                    }
                    .padding(.bottom, 8)
                    
                    // Links row
                    Button(action: {
                        isSignUp = true
                        showEmailForm = true
                    }) {
                        Text("還沒有帳號？建立新帳號")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                    }
                    
                    Spacer().frame(height: 12)
                    
                    // Guest Login Button
                    Button(action: handleGuestLogin) {
                        ZStack {
                            if isLoading && !showEmailForm {
                                ProgressView().tint(.white)
                            } else {
                                Text("以訪客身分繼續")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                    .underline()
                            }
                        }
                    }
                    .disabled(isLoading)
                    
                    if let err = errorMessage, !showEmailForm {
                        Text(err)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showEmailForm) {
            EmailAuthSheet(
                email: $email,
                password: $password,
                isSignUp: $isSignUp,
                isLoading: $isLoading,
                errorMessage: $errorMessage,
                onAuthAction: handleAuthAction,
                onResetPassword: resetPassword
            )
            .presentationDetents([.fraction(0.55)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
        }
    }
    
    private func handleAuthAction() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if isSignUp {
                    try await authManager.signUp(email: email, password: password)
                } else {
                    try await authManager.signIn(email: email, password: password)
                }
                await MainActor.run {
                    self.showEmailForm = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func handleGuestLogin() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.signInAnonymously()
            } catch {
                await MainActor.run {
                    self.errorMessage = "訪客登入失敗：\(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func resetPassword() {
        guard !email.isEmpty else {
            errorMessage = "請先輸入您的 Email 才能發送重設密碼信。"
            return
        }
        
        isLoading = true
        Task {
            do {
                try await authManager.sendPasswordReset(email: email)
                await MainActor.run {
                    self.errorMessage = "重設密碼信件已發送，請檢查您的信箱！"
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct EmailAuthSheet: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var isSignUp: Bool
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    
    var onAuthAction: () -> Void
    var onResetPassword: () -> Void
    
    let navy = Color(hex: "021F3A")
    let red = Color(hex: "EE4A4A")
    
    var body: some View {
        VStack(spacing: 24) {
            Text(isSignUp ? "建立新帳號" : "歡迎回來")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(navy)
                .padding(.top, 32)
            
            // Input Fields
            VStack(spacing: 16) {
                TextField("電子郵件 Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(16)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                
                SecureField("密碼 Password", text: $password)
                    .padding(16)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }
            .padding(.horizontal, 24)
            
            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(action: onAuthAction) {
                    ZStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isSignUp ? "註冊" : "登入")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(navy)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
                }
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                .opacity((isLoading || email.isEmpty || password.isEmpty) ? 0.5 : 1.0)
                
                // Switch Mode
                Button(action: {
                    withAnimation {
                        isSignUp.toggle()
                        errorMessage = nil
                    }
                }) {
                    Text(isSignUp ? "已有帳號？點此登入" : "還沒有帳號？建立新帳號")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(navy.opacity(0.7))
                }
                .padding(.top, 4)
                
                // Forgot Password
                if !isSignUp {
                    Button(action: onResetPassword) {
                        Text("忘記密碼？")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
}
