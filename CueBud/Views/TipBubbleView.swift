import SwiftUI

private let brandRed = Color(red: 0.92, green: 0.26, blue: 0.21)

/// Dark notification card matching the in-product overlay design
struct NotificationCard: View {
    let tip: CoachingTip
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(brandRed)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(tip.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(tip.type.category)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.1).opacity(0.92))
        )
        .onTapGesture { onDismiss() }
    }
}

/// Persistent status badge shown in the corner
struct CueBudBadge: View {
    let isActive: Bool
    let duration: String?
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(brandRed)
                .frame(width: 14, height: 14)

            HStack(spacing: 4) {
                Text("cuebud")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Text("·")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.35))

                Text(isActive ? "listening" : "ready")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))

                if let dur = duration {
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.35))

                    Text(dur)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Button(action: onToggle) {
                Image(systemName: isActive ? "stop.fill" : "play.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(isActive ? brandRed : .white.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(white: 0.1).opacity(0.92))
        )
    }
}
