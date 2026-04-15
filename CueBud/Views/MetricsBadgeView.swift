import SwiftUI

/// Live metrics strip showing WPM, filler count, and volume (no posture — that's separate)
struct MetricsBadgeView: View {
    let wpm: Double
    let fillerCount: Int
    let volumeLevel: Float
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            // WPM
            MetricItem(
                icon: "waveform",
                value: isActive ? "\(Int(wpm))" : "—",
                label: "WPM",
                color: wpmColor
            )

            Divider()
                .frame(height: 24)
                .opacity(0.3)

            // Filler words
            MetricItem(
                icon: "text.bubble",
                value: isActive ? "\(fillerCount)" : "—",
                label: "Fillers",
                color: fillerCount > 3 ? .orange : .secondary
            )

            Divider()
                .frame(height: 24)
                .opacity(0.3)

            // Volume bar
            VolumeBar(level: isActive ? volumeLevel : -160)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var wpmColor: Color {
        guard isActive, wpm > 0 else { return .secondary }
        // Ideal range: 140–160 WPM
        if wpm >= 140 && wpm <= 160 { return .green }
        return .yellow
    }
}

struct MetricItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var width: CGFloat = 55

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(width: width)
    }
}

struct VolumeBar: View {
    let level: Float

    private let barWidth: CGFloat = 40
    private let barHeight: CGFloat = 6

    /// Map dB level (-160 to 0) to 0-1 range
    private var normalizedLevel: CGFloat {
        let clamped = max(-60, min(0, level))
        return CGFloat((clamped + 60) / 60)
    }

    private var fillWidth: CGFloat {
        max(0, barWidth * normalizedLevel)
    }

    var body: some View {
        VStack(spacing: 2) {
            Capsule()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: barWidth, height: barHeight)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(volumeColor)
                        .frame(width: fillWidth, height: barHeight)
                }
                .clipShape(Capsule())

            Text("Vol")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(width: 55)
    }

    private var volumeColor: Color {
        // Ideal mic input: -12 to -6 dB (maps to 0.8–0.9 in our 0–1 range from -60..0)
        // level is in dB: -60 (silence) to 0 (max)
        let db = max(-60, min(0, level))
        if db >= -12 && db <= -6 { return .green }
        if db > -6 { return .red }  // clipping/too loud
        if db > -20 { return .yellow }  // speaking but below ideal
        return .yellow  // very quiet
    }
}

/// Isolated posture display — observes PostureCoach directly so changes
/// never invalidate the parent OverlayView or MetricsBadgeView.
struct PostureBadge: View {
    @ObservedObject var postureCoach: PostureCoach
    let isActive: Bool

    private var posture: String {
        isActive ? postureCoach.currentPosture : "—"
    }

    private var color: Color {
        posture == "Good" ? .green : .orange
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(posture)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            Text("Posture")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(width: 100, alignment: .center)
    }
}
