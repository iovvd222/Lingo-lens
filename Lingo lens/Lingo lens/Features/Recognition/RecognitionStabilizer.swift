import Foundation

struct RecognitionStabilizer {
    private(set) var generation: UInt64 = 0
    private(set) var currentWord: String?
    private var pendingWord: String?
    private var pendingCount = 0
    private var missedCount = 0
    private let confirmationsRequired: Int
    private let missesBeforeClear: Int

    init(confirmationsRequired: Int = 2, missesBeforeClear: Int = 3) {
        self.confirmationsRequired = max(1, confirmationsRequired)
        self.missesBeforeClear = max(1, missesBeforeClear)
    }

    @discardableResult
    mutating func beginGeneration(clearCurrent: Bool = true) -> UInt64 {
        generation &+= 1
        pendingWord = nil
        pendingCount = 0
        missedCount = 0
        if clearCurrent { currentWord = nil }
        return generation
    }

    mutating func accept(_ candidate: String?, generation resultGeneration: UInt64) -> String? {
        guard resultGeneration == generation else { return nil }
        guard let candidate = candidate.flatMap(WordValidation.normalize) else {
            pendingWord = nil
            pendingCount = 0
            missedCount += 1
            if missedCount >= missesBeforeClear { currentWord = nil }
            return currentWord
        }

        missedCount = 0
        if candidate == currentWord {
            pendingWord = nil
            pendingCount = 0
            return currentWord
        }

        if candidate == pendingWord {
            pendingCount += 1
        } else {
            pendingWord = candidate
            pendingCount = 1
        }
        if pendingCount >= confirmationsRequired {
            currentWord = candidate
            pendingWord = nil
            pendingCount = 0
        }
        return currentWord
    }
}
