import Foundation
import XCTest
@testable import Lingo_lens

final class LexiconCacheTests: XCTestCase {
    func testDiskCacheStoresAndReadsEntryUsingNormalizedKey() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = DiskWordEntryCache(directory: directory)
        let entry = WordEntry(
            word: "lamp",
            ja: "ランプ",
            ipa: "/læmp/",
            partOfSpeech: "名詞",
            collocations: [WordPhrase(en: "desk lamp", ja: "デスクライト"), WordPhrase(en: "lamp shade", ja: "ランプシェード"), WordPhrase(en: "turn on a lamp", ja: "ランプをつける")],
            examples: [WordPhrase(en: "The lamp is bright.", ja: "ランプが明るいです。")]
        )

        try await cache.store(entry, for: "Lamp")
        let loaded = await cache.entry(for: "lamp")
        XCTAssertEqual(loaded, entry)
    }
}
