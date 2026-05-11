import Foundation
import CryptoKit
import AppKit
import Supabase

enum AuthError: LocalizedError {
    case cancelled
    case invalidCallback
    case tokenExchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Sign in was cancelled."
        case .invalidCallback: return "Invalid OAuth callback."
        case .tokenExchangeFailed(let reason): return "Failed to sign in: \(reason)"
        }
    }
}

@MainActor
final class AuthService: ObservableObject {
    @Published var currentUser: AuthUser?
    @Published var isLoading = false

    let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://qpggiuuvcxyvzmsbldza.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFwZ2dpdXV2Y3h5dnptc2JsZHphIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzOTcwODQsImV4cCI6MjA5Mzk3MzA4NH0.JQd86xxemOp5vuXsd-B8PcY8KXgiz-T1PPypVluwLV8",
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(storage: UserDefaultsAuthStorage())
        )
    )

    private let clientID = "689290117585-5mps9d5la1t4m72pa78b8je7lqqku0rq.apps.googleusercontent.com"
    private let redirectURI = "com.googleusercontent.apps.689290117585-5mps9d5la1t4m72pa78b8je7lqqku0rq:/oauth2callback"
    private let googleTokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    private static let currentUserKey = "cuebud.currentUser"
    private var pendingAuthContinuation: CheckedContinuation<URL, Error>?

    init() {
        // Restore cached user instantly — refreshSessionInBackground() verifies the session
        if let data = UserDefaults.standard.data(forKey: Self.currentUserKey),
           let user = try? JSONDecoder().decode(AuthUser.self, from: data) {
            currentUser = user
        }
    }

    /// Silently verifies and refreshes the Supabase session on app launch.
    func refreshSessionInBackground() {
        Task {
            do {
                let session = try await supabase.auth.session
                let user = authUser(from: session)
                currentUser = user
                saveUserLocally(user)
            } catch {
                // Session expired or missing — require sign in
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

        let idToken = try await exchangeCodeForIDToken(code: code, codeVerifier: verifier)

        // Supabase validates the Google ID token and creates/restores the session
        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .google, idToken: idToken)
        )

        let user = try await upsertProfile(session: session)
        saveUserLocally(user)
        currentUser = user
    }

    func signOut() {
        Task {
            try? await supabase.auth.signOut()
            UserDefaults.standard.removeObject(forKey: Self.currentUserKey)
            currentUser = nil
        }
    }

    func handleCallbackURL(_ url: URL) {
        NSApp.activate(ignoringOtherApps: true)
        pendingAuthContinuation?.resume(returning: url)
        pendingAuthContinuation = nil
    }

    // MARK: - Private

    private func openBrowserAndWaitForCallback(url: URL) async throws -> URL {
        pendingAuthContinuation?.resume(throwing: AuthError.cancelled)
        pendingAuthContinuation = nil
        return try await withCheckedThrowingContinuation { continuation in
            self.pendingAuthContinuation = continuation
            NSWorkspace.shared.open(url)
        }
    }

    private func exchangeCodeForIDToken(code: String, codeVerifier: String) async throws -> String {
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
        return idToken
    }

    private struct UserProfile: Encodable {
        let id: UUID
        let google_id: String
        let email: String
        let name: String
        let picture_url: String?
        let last_sign_in_at: Date
    }

    @discardableResult
    private func upsertProfile(session: Session) async throws -> AuthUser {
        let meta = session.user.userMetadata
        let name = meta["name"]?.value as? String ?? session.user.email ?? ""
        let pictureURL = (meta["picture"]?.value as? String).flatMap { URL(string: $0) }
        let googleID = meta["sub"]?.value as? String ?? session.user.id.uuidString

        let profile = UserProfile(
            id: session.user.id,
            google_id: googleID,
            email: session.user.email ?? "",
            name: name,
            picture_url: pictureURL?.absoluteString,
            last_sign_in_at: Date()
        )
        try await supabase.from("users").upsert(profile, onConflict: "id").execute()

        return AuthUser(
            id: session.user.id.uuidString,
            email: session.user.email ?? "",
            name: name,
            pictureURL: pictureURL,
            joinedAt: session.user.createdAt
        )
    }

    private func authUser(from session: Session) -> AuthUser {
        let meta = session.user.userMetadata
        let name = meta["name"]?.value as? String ?? session.user.email ?? ""
        let pictureURL = (meta["picture"]?.value as? String).flatMap { URL(string: $0) }
        return AuthUser(
            id: session.user.id.uuidString,
            email: session.user.email ?? "",
            name: name,
            pictureURL: pictureURL,
            joinedAt: session.user.createdAt
        )
    }

    private func saveUserLocally(_ user: AuthUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: Self.currentUserKey)
        }
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

/// Stores Supabase session data in UserDefaults to avoid macOS keychain permission popups.
struct UserDefaultsAuthStorage: AuthLocalStorage {
    func store(key: String, value: Data) throws {
        UserDefaults.standard.set(value, forKey: key)
    }

    func retrieve(key: String) throws -> Data? {
        UserDefaults.standard.data(forKey: key)
    }

    func remove(key: String) throws {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
