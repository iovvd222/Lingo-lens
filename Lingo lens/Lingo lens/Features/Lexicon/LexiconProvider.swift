import Foundation
import FoundationModels

@Generable
struct WordPhrase: Codable, Hashable, Sendable {
    var en: String
    var ja: String
}

@Generable
struct WordEntry: Codable, Hashable, Sendable {
    var word: String
    var ja: String
    var ipa: String
    var partOfSpeech: String
    @Guide(description: "Three natural English collocations for this word, each with a Japanese translation.", .count(3))
    var collocations: [WordPhrase]
    @Guide(description: "Two short example sentences that use this word, each with a Japanese translation.", .count(2))
    var examples: [WordPhrase]
}

protocol LexiconProvider: Sendable {
    func entry(for word: String) async throws -> WordEntry
}

enum LexiconError: Error {
    case modelUnavailable
    case invalidEntry
}

actor DiskWordEntryCache {
    private let directory: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directory = directory ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WordEntryCache", isDirectory: true)
    }

    func entry(for word: String) -> WordEntry? {
        let url = fileURL(for: word)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(WordEntry.self, from: data)
    }

    func store(_ entry: WordEntry, for word: String) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(entry)
        try data.write(to: fileURL(for: word), options: .atomic)
    }

    private func fileURL(for word: String) -> URL {
        let key = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return directory.appendingPathComponent("\(key).json")
    }
}

actor FoundationModelsLexiconProvider: LexiconProvider {
    private let cache: DiskWordEntryCache
    private var inFlight: [String: Task<WordEntry, Error>] = [:]

    init(cache: DiskWordEntryCache = DiskWordEntryCache()) {
        self.cache = cache
    }

    func entry(for word: String) async throws -> WordEntry {
        let key = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let cached = await cache.entry(for: key) { return cached }
        if let task = inFlight[key] {
            return try await task.value
        }

        let task = Task { try await Self.generateEntry(for: key) }
        inFlight[key] = task
        do {
            let generated = try await task.value
            try await cache.store(generated, for: key)
            inFlight[key] = nil
            return generated
        } catch {
            inFlight[key] = nil
            throw error
        }
    }

    private nonisolated static func generateEntry(for key: String) async throws -> WordEntry {
        guard SystemLanguageModel.default.availability == .available else {
            throw LexiconError.modelUnavailable
        }
        let session = LanguageModelSession(instructions: "Create accurate English learning information for the given common noun. Write the Japanese translation and part of speech in Japanese. Use General American IPA. Keep the requested array lengths exact.")
        let response = try await session.respond(generating: WordEntry.self, options: GenerationOptions(samplingMode: .greedy)) {
            "Create a learner's entry for the English word: \(key). Include three collocations and two short example sentences."
        }
        var generated = response.content
        guard WordValidation.normalize(generated.word) == WordValidation.normalize(key),
              !generated.ja.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !generated.ipa.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !generated.partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              generated.collocations.count == 3,
              generated.examples.count == 2 else { throw LexiconError.invalidEntry }
        generated.word = key
        return generated
    }
}

struct MockLexiconProvider: LexiconProvider {
    let value: WordEntry

    func entry(for word: String) async throws -> WordEntry { value }
}
