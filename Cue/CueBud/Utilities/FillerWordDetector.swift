import Foundation

/// Detects filler words in transcribed speech
struct FillerWordDetector {
    /// Set of known filler words/phrases
    static let fillerPatterns: Set<String> = [
        "um", "uh", "uh huh", "umm", "uhh",
        "er", "err", "ah", "ahh",
        "like", "literally",
        "you know", "you know what i mean",
        "i mean", "right",
        "basically", "actually", "honestly",
        "sort of", "kind of",
        "so yeah", "yeah so",
    ]

    /// Single-word fillers for fast lookup
    static let singleWordFillers: Set<String> = [
        "um", "uh", "umm", "uhh", "er", "err", "ah", "ahh",
        "like", "literally", "basically", "actually", "honestly", "right",
    ]

    /// Multi-word filler phrases
    static let multiWordFillers: [String] = [
        "you know what i mean",
        "you know",
        "i mean",
        "sort of",
        "kind of",
        "so yeah",
        "yeah so",
        "uh huh",
    ]

    /// Detect filler words in a text segment.
    /// Returns array of (filler, range) tuples.
    static func detect(in text: String) -> [FillerMatch] {
        let lowered = text.lowercased()
        var matches: [FillerMatch] = []
        var coveredRanges: [Range<String.Index>] = []

        // Check multi-word phrases first (greedy)
        for phrase in multiWordFillers {
            var searchStart = lowered.startIndex
            while let range = lowered.range(of: phrase, range: searchStart..<lowered.endIndex) {
                // Check word boundaries
                let isStartBound = range.lowerBound == lowered.startIndex ||
                    lowered[lowered.index(before: range.lowerBound)].isWhitespace ||
                    lowered[lowered.index(before: range.lowerBound)].isPunctuation
                let isEndBound = range.upperBound == lowered.endIndex ||
                    lowered[range.upperBound].isWhitespace ||
                    lowered[range.upperBound].isPunctuation

                if isStartBound && isEndBound {
                    let alreadyCovered = coveredRanges.contains { existing in
                        existing.overlaps(range)
                    }
                    if !alreadyCovered {
                        matches.append(FillerMatch(filler: phrase, range: range))
                        coveredRanges.append(range)
                    }
                }
                searchStart = range.upperBound
            }
        }

        // Check single-word fillers
        let words = lowered.split(separator: " ")
        for word in words {
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            if singleWordFillers.contains(cleaned) {
                // Contextual filtering: "like" at start of sentence or after pause is filler
                // "like" used as "I like pizza" is not - simple heuristic: skip if followed by a/an/the/to
                if cleaned == "like" || cleaned == "right" {
                    // These are context-dependent; for now count them as fillers
                    // A more sophisticated approach would use n-gram context
                }

                let range = lowered.range(of: String(word))!
                let alreadyCovered = coveredRanges.contains { $0.overlaps(range) }
                if !alreadyCovered {
                    matches.append(FillerMatch(filler: cleaned, range: range))
                }
            }
        }

        return matches
    }

    /// Count filler words in text
    static func count(in text: String) -> Int {
        detect(in: text).count
    }
}

struct FillerMatch {
    let filler: String
    let range: Range<String.Index>
}
