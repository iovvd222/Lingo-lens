import CoreData
import XCTest
@testable import Lingo_lens

@MainActor
final class SavedWordRepositoryTests: XCTestCase {
    func testSavingSameWordUpdatesExistingRecord() throws {
        let model = try XCTUnwrap(NSManagedObjectModel.mergedModel(from: [Bundle(for: SavedTranslation.self)]))
        let container = NSPersistentContainer(name: "lingo-lens-model", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        let loaded = expectation(description: "in-memory store loads")
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 5)
        if let loadError { throw loadError }

        let repository = SavedWordRepository(context: container.viewContext)
        try repository.save(makeEntry(word: "lamp", translation: "ランプ"))
        try repository.save(makeEntry(word: "Lamp", translation: "照明器具"))

        XCTAssertEqual(try container.viewContext.count(for: SavedTranslation.fetchRequest()), 1)
        let saved = try XCTUnwrap(container.viewContext.fetch(SavedTranslation.fetchRequest()).first)
        XCTAssertEqual(saved.originalText, "lamp")
        XCTAssertEqual(saved.translatedText, "照明器具")
    }

    private func makeEntry(word: String, translation: String) -> WordEntry {
        WordEntry(
            word: word,
            ja: translation,
            ipa: "/læmp/",
            partOfSpeech: "名詞",
            collocations: [WordPhrase(en: "desk lamp", ja: "デスクライト"), WordPhrase(en: "lamp shade", ja: "ランプシェード"), WordPhrase(en: "turn on a lamp", ja: "ランプをつける")],
            examples: [WordPhrase(en: "The lamp is bright.", ja: "ランプが明るいです。")]
        )
    }
}
