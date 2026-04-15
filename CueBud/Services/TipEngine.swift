import Foundation
import Combine

/// Manages tip cooldowns, priority, deduplication, and display queue.
/// Tips persist while their condition is active and auto-dismiss only
/// after the condition clears (no re-emission within the grace period).
@MainActor
final class TipEngine: ObservableObject {
    @Published var activeTip: CoachingTip?
    @Published var tipHistory: [CoachingTip] = []

    /// Publisher for tips that should be displayed
    let displayTipSubject = PassthroughSubject<CoachingTip, Never>()

    private var cancellables = Set<AnyCancellable>()
    private var pendingQueue: [CoachingTip] = []

    // Cooldown tracking: last dismissed time per tip type
    private var lastDismissedTime: [TipType: Date] = [:]

    // Tracks last time the active tip's condition was re-confirmed
    private var lastReEmitTime: Date?

    // Configuration
    var cooldownInterval: TimeInterval = 90
    /// How long after the last re-emission before auto-dismissing (condition cleared)
    var gracePeriod: TimeInterval = 2
    var warmupDuration: TimeInterval = 15

    private var sessionStartTime: Date?
    private var graceTimer: Timer?

    func startSession() {
        sessionStartTime = Date()
        activeTip = nil
        pendingQueue.removeAll()
        lastDismissedTime.removeAll()
        tipHistory.removeAll()
        lastReEmitTime = nil
    }

    func endSession() {
        sessionStartTime = nil
        graceTimer?.invalidate()
        graceTimer = nil
        activeTip = nil
        pendingQueue.removeAll()
    }

    /// Connect to tip sources (speech coach, posture coach)
    func subscribe(to publisher: AnyPublisher<CoachingTip, Never>) {
        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tip in
                self?.enqueue(tip)
            }
            .store(in: &cancellables)
    }

    /// Enqueue a tip for display (applies filtering)
    func enqueue(_ tip: CoachingTip) {
        // Warmup check
        if let start = sessionStartTime,
           Date().timeIntervalSince(start) < warmupDuration {
            return
        }

        // If this is the same type as the active tip, the condition is still active —
        // refresh the grace timer so the tip stays visible.
        if activeTip?.type == tip.type {
            lastReEmitTime = Date()
            resetGraceTimer()
            return
        }

        // Cooldown check (based on when the tip was last *dismissed*, not shown)
        if let lastDismissed = lastDismissedTime[tip.type],
           Date().timeIntervalSince(lastDismissed) < cooldownInterval {
            return
        }

        // Deduplication: don't re-queue if same type already pending
        if pendingQueue.contains(where: { $0.type == tip.type }) {
            return
        }

        pendingQueue.append(tip)
        pendingQueue.sort { $0.severity > $1.severity }

        if activeTip == nil {
            showNextTip()
        }
    }

    /// Manually dismiss via user tap
    func userDismiss() {
        guard let tip = activeTip else { return }
        graceTimer?.invalidate()
        graceTimer = nil
        lastDismissedTime[tip.type] = Date()
        activeTip = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showNextTip()
        }
    }

    private func showNextTip() {
        guard !pendingQueue.isEmpty else { return }

        let tip = pendingQueue.removeFirst()

        // Final cooldown check
        if let lastDismissed = lastDismissedTime[tip.type],
           Date().timeIntervalSince(lastDismissed) < cooldownInterval {
            showNextTip()
            return
        }

        activeTip = tip
        lastReEmitTime = Date()
        tipHistory.append(tip)
        displayTipSubject.send(tip)

        resetGraceTimer()
    }

    /// Start/restart the grace timer. If the condition is still active, coaches will
    /// re-emit and call `enqueue` which resets this timer. If they stop re-emitting,
    /// the timer fires and the tip auto-dismisses.
    private func resetGraceTimer() {
        graceTimer?.invalidate()
        graceTimer = Timer.scheduledTimer(withTimeInterval: gracePeriod, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.gracePeriodExpired()
            }
        }
    }

    private func gracePeriodExpired() {
        guard let tip = activeTip else { return }
        graceTimer = nil
        lastDismissedTime[tip.type] = Date()
        activeTip = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showNextTip()
        }
    }
}
