import Foundation

struct SessionMetrics: Codable {
    var sessionStart: Date
    var sessionEnd: Date?

    // Speech metrics
    var totalWordsSpoken: Int = 0
    var fillerWordCount: Int = 0
    var averageWPM: Double = 0
    var peakWPM: Double = 0
    var averageVolume: Float = 0
    var totalSpeakingDuration: TimeInterval = 0
    var totalSilenceDuration: TimeInterval = 0
    var longestRamblingStreak: TimeInterval = 0

    // Posture metrics
    var slouchingDuration: TimeInterval = 0
    var notLookingAtCameraDuration: TimeInterval = 0
    var smilingDuration: TimeInterval = 0

    // Tips
    var tipsShown: Int = 0
    var tipsByType: [String: Int] = [:]

    var sessionDuration: TimeInterval {
        (sessionEnd ?? Date()).timeIntervalSince(sessionStart)
    }

    var fillerWordRate: Double {
        guard totalSpeakingDuration > 0 else { return 0 }
        return Double(fillerWordCount) / (totalSpeakingDuration / 60.0)
    }

    var eyeContactPercentage: Double {
        guard sessionDuration > 0 else { return 0 }
        return max(0, 1.0 - (notLookingAtCameraDuration / sessionDuration)) * 100
    }

    var postureScore: Double {
        guard sessionDuration > 0 else { return 0 }
        return max(0, 1.0 - (slouchingDuration / sessionDuration)) * 100
    }

    init() {
        self.sessionStart = Date()
    }

    mutating func recordTip(_ tip: CoachingTip) {
        tipsShown += 1
        let key = tip.type.rawValue
        tipsByType[key, default: 0] += 1
    }
}
