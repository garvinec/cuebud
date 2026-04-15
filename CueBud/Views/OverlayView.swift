import SwiftUI

/// Main floating overlay window content
struct OverlayView: View {
    @ObservedObject var overlayVM: OverlayViewModel
    @ObservedObject var sessionVM: SessionViewModel

    var body: some View {
        VStack(spacing: 8) {
            // Header with controls
            headerBar

            if !overlayVM.isCompact || sessionVM.isSessionActive {
                // Metrics strip: fixed layout so value changes never shift geometry
                HStack(spacing: 0) {
                    MetricsBadgeView(
                        wpm: overlayVM.currentWPM,
                        fillerCount: overlayVM.fillerCount,
                        volumeLevel: overlayVM.volumeLevel,
                        isActive: sessionVM.isSessionActive
                    )

                    Divider()
                        .frame(height: 24)
                        .opacity(0.3)
                        .padding(.horizontal, 8)

                    PostureBadge(postureCoach: sessionVM.postureCoach, isActive: sessionVM.isSessionActive)
                }
                .frame(width: 336, alignment: .center)
                .padding(.vertical, 8)

                // Active tip bubble — stable identity, no re-animation while showing
                tipSection
            }
        }
        .padding(12)
        .frame(width: 360)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.windowBackgroundColor).opacity(0.85))
                .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 6)
        }
        .animation(.spring(response: 0.3), value: overlayVM.isCompact)
    }

    @ViewBuilder
    private var tipSection: some View {
        if let tip = overlayVM.activeTip {
            TipBubbleView(tip: tip) {
                overlayVM.dismissTip()
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }

    private var headerBar: some View {
        HStack {
            // App icon / status indicator
            Circle()
                .fill(sessionVM.isSessionActive ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            Text("CueBud")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            if sessionVM.isSessionActive {
                Text(sessionVM.formattedDuration)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Minimize chevron — only enabled when not coaching
            if !sessionVM.isSessionActive {
                Button(action: { overlayVM.toggleCompact() }) {
                    Image(systemName: overlayVM.isCompact ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Start/Stop button
            Button(action: { sessionVM.toggleSession() }) {
                Image(systemName: sessionVM.isSessionActive ? "stop.fill" : "play.fill")
                    .font(.system(size: 12))
                    .foregroundColor(sessionVM.isSessionActive ? .red : .green)
            }
            .buttonStyle(.plain)
        }
    }
}
