import Foundation
import Combine

/// Drives the overlay UI, managing active tips and display state
@MainActor
final class OverlayViewModel: ObservableObject {
    @Published var isCompact = false
    @Published var activeTip: CoachingTip?
    @Published var currentWPM: Double = 0
    @Published var fillerCount: Int = 0
    @Published var volumeLevel: Float = -160
    @Published var isSessionActive = false

    private var cancellables = Set<AnyCancellable>()
    private let session: SessionViewModel

    init(session: SessionViewModel) {
        self.session = session
        setupBindings()
    }

    private func setupBindings() {
        // Bind active tip — only update when the tip ID actually changes
        session.tipEngine.$activeTip
            .receive(on: DispatchQueue.main)
            .removeDuplicates { $0?.id == $1?.id }
            .assign(to: &$activeTip)

        // Bind speech metrics — throttle to avoid rapid redraws
        session.speechCoach.$currentWPM
            .receive(on: DispatchQueue.main)
            .throttle(for: .seconds(2), scheduler: DispatchQueue.main, latest: true)
            .assign(to: &$currentWPM)

        session.speechCoach.$recentFillerCount
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .assign(to: &$fillerCount)

        // Volume updates throttled heavily — only for visual bar
        session.audioService.$currentVolume
            .receive(on: DispatchQueue.main)
            .throttle(for: .seconds(0.5), scheduler: DispatchQueue.main, latest: true)
            .assign(to: &$volumeLevel)

        // Bind session state
        session.$isSessionActive
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .assign(to: &$isSessionActive)
    }

    func dismissTip() {
        session.tipEngine.userDismiss()
    }

    func toggleCompact() {
        withAnimation(.spring(response: 0.3)) {
            isCompact.toggle()
        }
    }
}

// Helper for withAnimation in non-View context
import SwiftUI

private func withAnimation<Result>(_ animation: Animation, _ body: () -> Result) -> Result {
    SwiftUI.withAnimation(animation, body)
}
