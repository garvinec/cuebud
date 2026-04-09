import SwiftUI

/// Tip bubble with color-coded severity — stays stable once shown
struct TipBubbleView: View {
    let tip: CoachingTip
    let onDismiss: () -> Void

    var backgroundColor: Color {
        switch tip.severity {
        case .info: return Color.blue.opacity(0.9)
        case .suggestion: return Color.orange.opacity(0.9)
        case .warning: return Color.red.opacity(0.9)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tip.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text(tip.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
    }
}
