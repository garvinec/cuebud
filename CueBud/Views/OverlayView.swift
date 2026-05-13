import SwiftUI

struct OverlayView: View {
    @ObservedObject var overlayVM: OverlayViewModel
    @ObservedObject var sessionVM: SessionViewModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
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
                isActive: sessionVM.isSessionActive,
                duration: sessionVM.isSessionActive ? sessionVM.formattedDuration : nil,
                onToggle: { sessionVM.toggleSession() }
            )
        }
        .frame(width: 280, alignment: .trailing)
        .padding(12)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: overlayVM.activeTips.map(\.id))
    }
}
