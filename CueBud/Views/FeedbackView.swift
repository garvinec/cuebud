import SwiftUI

struct FeedbackView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var feedbackText = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var errorMessage: String?

    private let maxChars = 1000

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if didSubmit {
                thankYouContent
            } else {
                feedbackContent
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private var feedbackContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Send Feedback")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                if feedbackText.isEmpty {
                    Text("Tell us what you think, report a bug, or suggest a feature...")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                }
                TextEditor(text: $feedbackText)
                    .frame(height: 140)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                    .onChange(of: feedbackText) { _, new in
                        if new.count > maxChars {
                            feedbackText = String(new.prefix(maxChars))
                        }
                    }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))

            HStack {
                Text("\(feedbackText.count)/\(maxChars)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button(isSubmitting ? "Submitting..." : "Submit") {
                    Task { await submit() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
        }
    }

    private var thankYouContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("Thanks for your feedback!")
                .font(.headline)
            Text("Your input helps make CueBud better.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        do {
            try await auth.submitFeedback(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines))
            didSubmit = true
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
        isSubmitting = false
    }
}
