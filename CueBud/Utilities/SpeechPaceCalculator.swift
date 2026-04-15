import Foundation

/// Calculates words-per-minute using a sliding window approach
final class SpeechPaceCalculator {
    struct WordEvent {
        let wordCount: Int
        let timestamp: Date
    }

    private var events: [WordEvent] = []
    private let windowDuration: TimeInterval
    private let lock = NSLock()

    /// Current words per minute
    private(set) var currentWPM: Double = 0

    /// Initialize with sliding window duration (default 10 seconds)
    init(windowDuration: TimeInterval = 10) {
        self.windowDuration = windowDuration
    }

    /// Record a batch of words spoken at a given time
    func recordWords(_ count: Int, at timestamp: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }

        events.append(WordEvent(wordCount: count, timestamp: timestamp))
        pruneOldEvents(before: timestamp)
        recalculate(at: timestamp)
    }

    /// Get current WPM (thread-safe)
    func getWPM() -> Double {
        lock.lock()
        defer { lock.unlock() }

        // Also prune stale events on read so WPM decays when user stops talking
        let now = Date()
        pruneOldEvents(before: now)
        recalculate(at: now)

        return currentWPM
    }

    /// Reset calculator
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        events.removeAll()
        currentWPM = 0
    }

    private func pruneOldEvents(before now: Date) {
        let cutoff = now.addingTimeInterval(-windowDuration)
        events.removeAll { $0.timestamp < cutoff }
    }

    private func recalculate(at now: Date) {
        guard !events.isEmpty else {
            currentWPM = 0
            return
        }

        let totalWords = events.reduce(0) { $0 + $1.wordCount }

        // Use the full window duration as denominator so WPM is stable
        // (not just the span between first and last event)
        let elapsed = min(windowDuration, now.timeIntervalSince(events.first!.timestamp))
        guard elapsed > 0.5 else {
            currentWPM = 0
            return
        }

        currentWPM = Double(totalWords) / (elapsed / 60.0)
    }
}
