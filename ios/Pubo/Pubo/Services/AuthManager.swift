import Foundation
import UIKit
import FirebaseAuth
import Combine

/// 管理 Firebase Email 登入狀態的單例
@MainActor
class AuthManager: ObservableObject {

    static let shared = AuthManager()

    @Published var currentUser: User?
    @Published var isSignedIn: Bool = false

    /// 目前登入者的 UID（用於 Firestore ownerUID 欄位）
    var currentUID: String {
        currentUser?.uid ?? UIDeviceID.anonymous
    }

    private var handle: AuthStateDidChangeListenerHandle?

    private init() {
        // 監聽 Firebase Auth 狀態變化
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.currentUser = user
                self.isSignedIn = user != nil
            }
        }
    }

    deinit {
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    // MARK: - Sign In / Sign Up

    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        self.currentUser = result.user
        self.isSignedIn = true
    }

    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        self.currentUser = result.user
        self.isSignedIn = true
    }

    func signOut() {
        try? Auth.auth().signOut()
        self.currentUser = nil
        self.isSignedIn = false
    }

    // MARK: - Password Reset

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
}

// MARK: - Anonymous Fallback ID

/// 若用戶尚未登入，用 identifierForVendor 作為備援匿名識別碼
private enum UIDeviceID {
    static var anonymous: String {
        UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
}
