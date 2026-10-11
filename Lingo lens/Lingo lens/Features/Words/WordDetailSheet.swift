import SwiftUI

struct WordDetailSheet: View {
    let word: String
    let provider: any LexiconProvider
    let repository: SavedWordRepository
    let speech: SpeechPlayer
    let initialEntry: WordEntry?

    @Environment(\.dismiss) private var dismiss
    @State private var entry: WordEntry?
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var isSaved = false
    @State private var showSaveError = false

    init(word: String, provider: any LexiconProvider, repository: SavedWordRepository, speech: SpeechPlayer, initialEntry: WordEntry?) {
        self.word = word
        self.provider = provider
        self.repository = repository
        self.speech = speech
        self.initialEntry = initialEntry
        _entry = State(initialValue: initialEntry?.word.lowercased() == word.lowercased() ? initialEntry : nil)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && entry == nil {
                    ProgressView("単語の情報を準備しています…")
                } else if let entry {
                    details(entry)
                } else if loadFailed {
                    ContentUnavailableView("詳細を取得できませんでした", systemImage: "exclamationmark.triangle", description: Text("Apple Intelligence の状態を確認して、もう一度お試しください。"))
                        .overlay(alignment: .bottom) {
                            Button("再試行") { Task { await loadEntry() } }
                                .padding(.bottom, 45)
                        }
                }
            }
            .navigationTitle(word.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .task {
            isSaved = repository.contains(word)
            if entry == nil { await loadEntry() }
        }
        .alert("保存できませんでした", isPresented: $showSaveError) {
            Button("閉じる", role: .cancel) { }
        } message: {
            Text("もう一度お試しください。")
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func details(_ entry: WordEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.ja).font(.title2.weight(.semibold))
                        Text("\(entry.ipa)　\(entry.partOfSpeech)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { speech.speak(entry.word) } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title2)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("\(entry.word) を発音")
                }

                phraseSection(title: "コロケーション", phrases: entry.collocations)
                phraseSection(title: "例文", phrases: entry.examples)

                Button {
                    do {
                        try repository.save(entry)
                        isSaved = true
                    } catch {
                        showSaveError = true
                    }
                } label: {
                    Label(isSaved ? "単語帳に保存済み" : "単語帳に保存", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaved)
            }
            .padding(20)
        }
    }

    private func phraseSection(title: String, phrases: [WordPhrase]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            ForEach(Array(phrases.enumerated()), id: \.offset) { _, phrase in
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(phrase.en).font(.body)
                        Text(phrase.ja).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Button { speech.speak(phrase.en) } label: {
                        Image(systemName: "speaker.wave.2")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(phrase.en) を発音")
                }
                .padding(.vertical, 2)
            }
        }
    }

    @MainActor
    private func loadEntry() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            entry = try await provider.entry(for: word)
        } catch {
            loadFailed = true
        }
    }
}
