import SwiftUI

struct UpgradeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text("You've used all 3 free sessions")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Upgrade to CueBud Pro for unlimited coaching sessions.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Upgrade to Pro") {}
                .buttonStyle(.borderedProminent)
                .disabled(true)
        }
        .padding(20)
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(12)
    }
}
