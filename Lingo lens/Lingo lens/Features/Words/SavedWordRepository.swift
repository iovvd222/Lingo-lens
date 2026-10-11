import CoreData
import Foundation

@MainActor
final class SavedWordRepository {
    private let context: NSManagedObjectContext
    private let encoder = JSONEncoder()

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func contains(_ word: String) -> Bool {
        let request = SavedTranslation.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "originalText ==[c] %@", word)
        return ((try? context.count(for: request)) ?? 0) > 0
    }

    @discardableResult
    func save(_ entry: WordEntry) throws -> SavedTranslation {
        let request = SavedTranslation.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "originalText ==[c] %@", entry.word)

        let existing = try context.fetch(request).first
        let saved = existing ?? SavedTranslation(context: context)
        saved.id = saved.id ?? UUID()
        saved.originalText = entry.word.lowercased()
        saved.translatedText = entry.ja
        saved.languageCode = "en-US"
        saved.languageName = "英語"
        saved.ipa = entry.ipa
        saved.partOfSpeech = entry.partOfSpeech
        saved.collocationsJSON = String(data: try encoder.encode(entry.collocations), encoding: .utf8)
        saved.examplesJSON = String(data: try encoder.encode(entry.examples), encoding: .utf8)
        saved.dateAdded = Date()
        try context.save()
        return saved
    }
}
