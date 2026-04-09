import AVFoundation
import Combine

/// Calculates RMS volume level from audio buffers
final class AudioLevelMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var _currentLevel: Float = -160
    private var _peakLevel: Float = -160

    /// Current RMS level in decibels (-160 silence to 0 max)
    var currentLevel: Float {
        lock.withLock { _currentLevel }
    }

    /// Peak level since last reset
    var peakLevel: Float {
        lock.withLock { _peakLevel }
    }

    /// Process an audio buffer and update levels
    func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        var rms: Float = 0

        for channel in 0..<channelCount {
            let data = channelData[channel]
            var channelRMS: Float = 0
            for frame in 0..<frameLength {
                let sample = data[frame]
                channelRMS += sample * sample
            }
            rms += channelRMS / Float(frameLength)
        }

        rms = sqrt(rms / Float(channelCount))

        // Convert to decibels
        let db: Float
        if rms > 0 {
            db = 20 * log10(rms)
        } else {
            db = -160
        }

        lock.withLock {
            _currentLevel = db
            if db > _peakLevel {
                _peakLevel = db
            }
        }
    }

    /// Reset peak level tracking
    func resetPeak() {
        lock.withLock {
            _peakLevel = -160
        }
    }

    /// Whether current level indicates silence (below threshold)
    func isSilent(threshold: Float = -40) -> Bool {
        currentLevel < threshold
    }
}
