import CoreData
import SwiftUI

struct SavedWordsView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SavedTranslation.dateAdded, ascending: false)],
        animation: .default
    ) private var savedWords: FetchedResults<SavedTranslation>

    var body: some View {
        NavigationStack {
            Group {
                if savedWords.isEmpty {
                    ContentUnavailableView("保存した単語はありません", systemImage: "bookmark", description: Text("カメラで見つけた単語を保存できます。"))
                } else {
                    List {
                        ForEach(savedWords) { item in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(item.originalText ?? "")
                                        .font(.headline)
                                    Spacer()
                                    Text(item.ipa ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(item.translatedText ?? "")
                                    .foregroundStyle(.secondary)
                                if let partOfSpeech = item.partOfSpeech, !partOfSpeech.isEmpty {
                                    Text(partOfSpeech)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("単語帳")
            .toolbar { EditButton() }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(savedWords[index]) }
        try? context.save()
    }
}
