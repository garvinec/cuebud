import Foundation

enum TipType: String, Codable, CaseIterable {
    // Speech tips
    case fillerWords = "filler_words"
    case speakingTooFast = "speaking_too_fast"
    case speakingTooSlow = "speaking_too_slow"
    case tooQuiet = "too_quiet"
    case rambling = "rambling"
    case longPause = "long_pause"

    // Posture tips
    case slouching = "slouching"
    case notLookingAtCamera = "not_looking_at_camera"
    case notSmiling = "not_smiling"
    case headTilt = "head_tilt"
    case tooClose = "too_close"
    case tooFar = "too_far"
}

enum TipSeverity: Int, Codable, Comparable {
    case info = 0
    case suggestion = 1
    case warning = 2

    static func < (lhs: TipSeverity, rhs: TipSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct CoachingTip: Identifiable, Codable {
    let id: UUID
    let type: TipType
    let message: String
    let severity: TipSeverity
    let timestamp: Date

    var icon: String {
        switch type {
        case .fillerWords: return "text.bubble"
        case .speakingTooFast: return "hare"
        case .speakingTooSlow: return "tortoise"
        case .tooQuiet: return "speaker.wave.1"
        case .rambling: return "ellipsis.bubble"
        case .longPause: return "pause.circle"
        case .slouching: return "figure.stand"
        case .notLookingAtCamera: return "eye"
        case .notSmiling: return "face.smiling"
        case .headTilt: return "arrow.left.arrow.right"
        case .tooClose: return "arrow.up.backward.and.arrow.down.forward"
        case .tooFar: return "arrow.down.forward.and.arrow.up.backward"
        }
    }

    var colorName: String {
        switch severity {
        case .info: return "blue"
        case .suggestion: return "orange"
        case .warning: return "red"
        }
    }

    init(type: TipType, message: String, severity: TipSeverity) {
        self.id = UUID()
        self.type = type
        self.message = message
        self.severity = severity
        self.timestamp = Date()
    }
}
