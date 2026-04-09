import Foundation

struct PostureSnapshot: Codable {
    let timestamp: Date

    // Shoulder-to-nose ratio (lower = more slouched)
    let shoulderNoseRatio: Double?

    // Gaze direction: 0 = center, positive = right, negative = left
    let gazeHorizontalOffset: Double?
    let gazeVerticalOffset: Double?

    // Smile confidence (0-1)
    let smileConfidence: Double?

    // Head tilt in degrees (0 = level)
    let headTiltDegrees: Double?

    // Face bounding box as fraction of frame (0-1)
    let faceSizeFraction: Double?

    // Face vertical center position in frame (0 = bottom, 1 = top in Vision coords)
    let faceVerticalCenter: Double?

    // Whether a person was detected at all
    let personDetected: Bool

    var isSlouching: Bool {
        // Primary: shoulder-to-nose ratio from body pose
        if let ratio = shoulderNoseRatio {
            return ratio < 0.15
        }
        // Fallback: if face drops to the lower portion of frame, user is likely slouching.
        // In Vision coordinates, Y=0 is bottom, Y=1 is top.
        // A well-positioned face center is around 0.6-0.75. Below 0.45 indicates slouching.
        if let vc = faceVerticalCenter {
            return vc < 0.45
        }
        return false
    }

    var isLookingAway: Bool {
        guard let h = gazeHorizontalOffset, let v = gazeVerticalOffset else { return false }
        // Face bounding box center offset from frame center.
        // 0.2 = face center is 20% off from frame center — user turned away significantly
        return abs(h) > 0.2 || abs(v) > 0.25
    }

    var isSmiling: Bool {
        guard let confidence = smileConfidence else { return true } // Don't penalize if no data
        return confidence > 0.15 // Very lenient — only flag truly flat expressions
    }

    var hasHeadTilt: Bool {
        guard let tilt = headTiltDegrees else { return false }
        return abs(tilt) > 15  // face roll in degrees
    }

    // Ideal framing: head + shoulders + upper chest visible.
    // Face should occupy roughly 15-25% of frame area.
    var isTooClose: Bool {
        guard let size = faceSizeFraction else { return false }
        return size > 0.25
    }

    var isTooFar: Bool {
        guard let size = faceSizeFraction else { return false }
        return size < 0.08
    }
}
