import SwiftUI

struct OverlayView: View {
    @ObservedObject var overlayVM: OverlayViewModel
    @ObservedObject var sessionVM: SessionViewModel

    @AppStorage("showScreenShareReminder") private var showScreenShareReminder = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if showScreenShareReminder {
                ScreenShareReminderCard()
            }

            ForEach(overlayVM.activeTips) { tip in
                NotificationCard(tip: tip) {
                    overlayVM.dismissTip(id: tip.id)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }

            CueBudBadge(
                isActive: sessionVM.isSessionActive || sessionVM.isRequestingPermissions,
                duration: sessionVM.isSessionActive ? sessionVM.formattedDuration : nil,
                onToggle: { sessionVM.toggleSession() }
            )
        }
        .frame(width: 280, alignment: .trailing)
        .padding(12)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: overlayVM.activeTips.map(\.id))
    }
}

private struct ScreenShareReminderCard: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))

            VStack(alignment: .leading, spacing: 3) {
                Text("Set up screen sharing")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text("Hide CueBud from other meeting participants.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                Button("Learn how →") {
                    if let url = URL(string: "https://trycuebud.com/#screen-share-setup") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.blue)

                Text("You can turn this notification off in Settings.")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.1).opacity(0.92))
        )
    }
}
