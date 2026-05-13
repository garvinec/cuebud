import SwiftUI

/// Post-call summary showing session statistics
struct SessionSummaryView: View {
    let metrics: SessionMetrics
    let sessionsRemaining: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Session Summary")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Duration
            SummaryRow(icon: "clock", label: "Duration", value: formattedDuration)

            // Speech section
            Text("Speech")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.secondary)

            SummaryRow(icon: "waveform", label: "Avg WPM", value: "\(Int(metrics.averageWPM))")
            SummaryRow(icon: "waveform", label: "Peak WPM", value: "\(Int(metrics.peakWPM))")
            SummaryRow(icon: "text.bubble", label: "Filler Words", value: "\(metrics.fillerWordCount)")
            SummaryRow(
                icon: "text.bubble",
                label: "Filler Rate",
                value: String(format: "%.1f/min", metrics.fillerWordRate)
            )
            SummaryRow(icon: "character.cursor.ibeam", label: "Words Spoken", value: "\(metrics.totalWordsSpoken)")

            // Posture section
            Text("Posture & Presence")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.secondary)

            SummaryRow(
                icon: "eye",
                label: "Eye Contact",
                value: String(format: "%.0f%%", metrics.eyeContactPercentage)
            )
            SummaryRow(
                icon: "figure.stand",
                label: "Good Posture",
                value: String(format: "%.0f%%", metrics.postureScore)
            )

            // Tips section
            SummaryRow(icon: "lightbulb", label: "Tips Shown", value: "\(metrics.tipsShown)")

            if sessionsRemaining == 0 {
                Text("You've used all your free sessions. Upgrade to keep coaching.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            } else {
                Text("\(sessionsRemaining) free session\(sessionsRemaining == 1 ? "" : "s") remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 320, height: 480)
        .background(.ultraThinMaterial)
    }

    private var formattedDuration: String {
        let total = Int(metrics.sessionDuration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct SummaryRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}
