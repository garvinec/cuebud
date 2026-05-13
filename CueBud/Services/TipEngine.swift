import Foundation
import Combine

/// Manages tip cooldowns, priority, deduplication, and display queue.
/// Up to 3 tips can be shown simultaneously. Each tip auto-dismisses
/// after the condition clears (no re-emission within the grace period).
@MainActor
final class TipEngine: ObservableObject {
    @Published var activeTips: [CoachingTip] = []
    @Published var tipHistory: [CoachingTip] = []

    let displayTipSubject = PassthroughSubject<CoachingTip, Never>()

    private var cancellables = Set<AnyCancellable>()
    private var pendingQueue: [CoachingTip] = []
    private var lastDismissedTime: [TipType: Date] = [:]
    private var graceTimers: [UUID: Timer] = [:]

    var cooldownInterval: TimeInterval = 90
    var gracePeriod: TimeInterval = 3
    var warmupDuration: TimeInterval = 15
    private let maxActiveTips = 3

    private var sessionStartTime: Date?

    // Backwards-compat for tests and any callers that expect a single tip
    var activeTip: CoachingTip? { activeTips.first }

    init() {
        loadSettings()
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.loadSettings() }
            .store(in: &cancellables)
    }

    private func loadSettings() {
        let v = UserDefaults.standard.double(forKey: "tipCooldown")
        if v > 0 { cooldownInterval = v }
    }

    func startSession() {
        sessionStartTime = Date()
        activeTips.removeAll()
        pendingQueue.removeAll()
        lastDismissedTime.removeAll()
        tipHistory.removeAll()
        graceTimers.values.forEach { $0.invalidate() }
        graceTimers.removeAll()
    }

    func endSession() {
        sessionStartTime = nil
        activeTips.removeAll()
        pendingQueue.removeAll()
        graceTimers.values.forEach { $0.invalidate() }
        graceTimers.removeAll()
    }

    func subscribe(to publisher: AnyPublisher<CoachingTip, Never>) {
        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tip in self?.enqueue(tip) }
            .store(in: &cancellables)
    }

    private func isTipTypeEnabled(_ type: TipType) -> Bool {
        let categoryKey = type.isSpeechTip ? "showSpeechTips" : "showPostureTips"
        let defaults = UserDefaults.standard
        if defaults.object(forKey: categoryKey) != nil && !defaults.bool(forKey: categoryKey) { return false }
        let perTypeKey = "tipEnabled_\(type.rawValue)"
        if defaults.object(forKey: perTypeKey) != nil && !defaults.bool(forKey: perTypeKey) { return false }
        return true
    }

    func enqueue(_ tip: CoachingTip) {
        guard let start = sessionStartTime,
              Date().timeIntervalSince(start) >= warmupDuration else { return }
        guard isTipTypeEnabled(tip.type) else { return }

        // If same type is already active, reset its grace timer (condition still active)
        if let existing = activeTips.first(where: { $0.type == tip.type }) {
            resetGraceTimer(for: existing)
            return
        }

        if let lastDismissed = lastDismissedTime[tip.type],
           Date().timeIntervalSince(lastDismissed) < cooldownInterval { return }

        if pendingQueue.contains(where: { $0.type == tip.type }) { return }

        pendingQueue.append(tip)
        pendingQueue.sort { $0.severity > $1.severity }
        showNextTips()
    }

    // Backwards-compat: dismisses the first active tip
    func userDismiss() {
        if let first = activeTips.first {
            dismiss(id: first.id)
        }
    }

    func userDismiss(id: UUID) {
        dismiss(id: id)
    }

    private func showNextTips() {
        while !pendingQueue.isEmpty && activeTips.count < maxActiveTips {
            let tip = pendingQueue.removeFirst()
            if let lastDismissed = lastDismissedTime[tip.type],
               Date().timeIntervalSince(lastDismissed) < cooldownInterval { continue }
            activeTips.append(tip)
            tipHistory.append(tip)
            displayTipSubject.send(tip)
            resetGraceTimer(for: tip)
        }
    }

    private func resetGraceTimer(for tip: CoachingTip) {
        graceTimers[tip.id]?.invalidate()
        graceTimers[tip.id] = Timer.scheduledTimer(withTimeInterval: gracePeriod, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss(id: tip.id)
            }
        }
    }

    private func dismiss(id: UUID) {
        guard let idx = activeTips.firstIndex(where: { $0.id == id }) else { return }
        let tip = activeTips[idx]
        graceTimers[id]?.invalidate()
        graceTimers.removeValue(forKey: id)
        lastDismissedTime[tip.type] = Date()
        activeTips.remove(at: idx)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showNextTips()
        }
    }
}
