import SwiftUI

struct LoginView: View {
    @ObservedObject var auth: AuthService
    @State private var error: Error?
    @State private var showError = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("LoginBackground"))
                .shadow(color: .black.opacity(0.15), radius: 24, y: 8)

            VStack(spacing: 0) {
                Spacer()

                Image("HeroLockup")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 280)

                Spacer()

                Button {
                    Task {
                        do {
                            try await auth.signInWithGoogle()
                        } catch AuthError.cancelled {
                            // user dismissed the sheet — no error shown
                        } catch {
                            self.error = error
                            showError = true
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        if auth.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                        }
                        Text("Sign in with Google")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(auth.isLoading)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 40)
        }
        .frame(width: 380, height: 320)
        .alert("Sign In Failed", isPresented: $showError, presenting: error) { _ in
            Button("OK") {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}
