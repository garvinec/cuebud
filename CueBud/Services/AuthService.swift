import Foundation
import CryptoKit
import AppKit

enum AuthError: LocalizedError {
    case cancelled
    case invalidCallback
    case tokenExchangeFailed(String)
    case sessionRestoreFailed

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Sign in was cancelled."
        case .invalidCallback: return "Invalid OAuth callback."
        case .tokenExchangeFailed(let reason): return "Failed to sign in: \(reason)"
        case .sessionRestoreFailed: return "Could not restore your session."
        }
    }
}

@MainActor
final class AuthService: ObservableObject {
    @Published var currentUser: AuthUser?
    @Published var isLoading = false

    private let clientID = "689290117585-5mps9d5la1t4m72pa78b8je7lqqku0rq.apps.googleusercontent.com"
    private let redirectURI = "com.googleusercontent.apps.689290117585-5mps9d5la1t4m72pa78b8je7lqqku0rq:/oauth2callback"
    private let googleTokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    private let supabaseURL = "https://qpggiuuvcxyvzmsbldza.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwZ2dpdXV2Y3h5dnptc2JsZHphIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzOTcwODQsImV4cCI6MjA5Mzk3MzA4NH0.JQd86xxemOp5vuXsd-B8PcY8KXgiz-T1PPypVluwLV8"

    private static let refreshTokenKey = "google.refreshToken"
    private static let currentUserKey = "cuebud.currentUser"
    private var pendingAuthContinuation: CheckedContinuation<URL, Error>?

    init() {
        // Restore cached user instantly so the first render skips LoginView for returning users
        if let data = UserDefaults.standard.data(forKey: Self.currentUserKey),
           let user = try? JSONDecoder().decode(AuthUser.self, from: data),
           KeychainHelper.load(forKey: Self.refreshTokenKey) != nil {
            currentUser = user
        }
    }

    /// Called on app launch to silently verify and refresh the stored token in background.
    func refreshSessionInBackground() {
        Task {
            guard let refreshToken = KeychainHelper.load(forKey: Self.refreshTokenKey) else { return }
            do {
                let idToken = try await refreshAccessToken(refreshToken: refreshToken)
                var user = try parseUser(fromIDToken: idToken)
                // Carry over locally stored joinedAt, or fetch from Supabase if missing
                if let existing = currentUser, let date = existing.joinedAt {
                    user.joinedAt = date
                } else {
                    user.joinedAt = await fetchJoinDate(googleID: user.id)
                }
                currentUser = user
                saveUserLocally(user)
            } catch {
                KeychainHelper.delete(forKey: Self.refreshTokenKey)
                UserDefaults.standard.removeObject(forKey: Self.currentUserKey)
                currentUser = nil
            }
        }
    }

    func signInWithGoogle() async throws {
        isLoading = true
        defer { isLoading = false }

        let verifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(from: verifier)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        let callbackURL = try await openBrowserAndWaitForCallback(url: components.url!)

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value
        else { throw AuthError.invalidCallback }

        let tokens = try await exchangeCodeForTokens(code: code, codeVerifier: verifier)
        let user = try parseUser(fromIDToken: tokens.idToken)

        if let refreshToken = tokens.refreshToken {
            KeychainHelper.save(refreshToken, forKey: Self.refreshTokenKey)
        }

        var userWithDate = user
        userWithDate.joinedAt = await upsertUserInSupabase(user)
        saveUserLocally(userWithDate)
        currentUser = userWithDate
    }

    func signOut() {
        KeychainHelper.delete(forKey: Self.refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: Self.currentUserKey)
        currentUser = nil
    }

    // MARK: - Private

    /// Called by the app when macOS routes the OAuth callback URL back to us.
    func handleCallbackURL(_ url: URL) {
        NSApp.activate(ignoringOtherApps: true)
        pendingAuthContinuation?.resume(returning: url)
        pendingAuthContinuation = nil
    }

    private func openBrowserAndWaitForCallback(url: URL) async throws -> URL {
        // Cancel any stale pending auth
        pendingAuthContinuation?.resume(throwing: AuthError.cancelled)
        pendingAuthContinuation = nil

        return try await withCheckedThrowingContinuation { continuation in
            self.pendingAuthContinuation = continuation
            NSWorkspace.shared.open(url)
        }
    }

    private struct TokenResponse {
        let idToken: String
        let refreshToken: String?
    }

    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> TokenResponse {
        var request = URLRequest(url: googleTokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code"
        ]
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AuthError.tokenExchangeFailed(String(data: data, encoding: .utf8) ?? "unknown error")
        }

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard let idToken = json["id_token"] as? String else {
            throw AuthError.tokenExchangeFailed("Missing id_token in response")
        }
        return TokenResponse(idToken: idToken, refreshToken: json["refresh_token"] as? String)
    }

    private func refreshAccessToken(refreshToken: String) async throws -> String {
        var request = URLRequest(url: googleTokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AuthError.sessionRestoreFailed
        }

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard let idToken = json["id_token"] as? String else {
            throw AuthError.sessionRestoreFailed
        }
        return idToken
    }

    private func parseUser(fromIDToken idToken: String) throws -> AuthUser {
        let parts = idToken.split(separator: ".")
        guard parts.count == 3 else { throw AuthError.tokenExchangeFailed("Invalid JWT structure") }

        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }

        guard let data = Data(base64Encoded: base64),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let sub = json["sub"] as? String,
              let email = json["email"] as? String
        else { throw AuthError.tokenExchangeFailed("Could not parse user claims from ID token") }

        return AuthUser(
            id: sub,
            email: email,
            name: json["name"] as? String ?? email,
            pictureURL: (json["picture"] as? String).flatMap { URL(string: $0) }
        )
    }

    private func saveUserLocally(_ user: AuthUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: Self.currentUserKey)
        }
    }

    @discardableResult
    private func upsertUserInSupabase(_ user: AuthUser) async -> Date? {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/users") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")

        var body: [String: Any] = [
            "google_id": user.id,
            "email": user.email,
            "name": user.name,
            "last_sign_in_at": ISO8601DateFormatter().string(from: Date())
        ]
        if let pictureURL = user.pictureURL?.absoluteString {
            body["picture_url"] = pictureURL
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode >= 300 {
            print("[AuthService] Supabase upsert failed \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            return nil
        }
        let rows = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
        guard let createdAtString = rows?.first?["created_at"] as? String else { return nil }
        return ISO8601DateFormatter().date(from: createdAtString)
    }

    private func fetchJoinDate(googleID: String) async -> Date? {
        guard var components = URLComponents(string: "\(supabaseURL)/rest/v1/users") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "google_id", value: "eq.\(googleID)"),
            URLQueryItem(name: "select", value: "created_at")
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let rows = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]],
              let createdAtString = rows.first?["created_at"] as? String else { return nil }
        return ISO8601DateFormatter().date(from: createdAtString)
    }

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

