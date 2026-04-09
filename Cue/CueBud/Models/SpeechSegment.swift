import Foundation

struct SpeechSegment: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let duration: TimeInterval
    let averageVolume: Float
    let wordCount: Int

    init(text: String, timestamp: Date, duration: TimeInterval, averageVolume: Float) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
        self.averageVolume = averageVolume
        self.wordCount = text.split(separator: " ").count
    }

    var wordsPerMinute: Double {
        guard duration > 0 else { return 0 }
        return Double(wordCount) / (duration / 60.0)
    }
}
