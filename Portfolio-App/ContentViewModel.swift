//
//  ContentViewModel.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 01/09/26.
//

import Foundation

@MainActor
final class ContentViewModel: ObservableObject {
    @Published private(set) var keywordTopics: [ChatService.MenuKeyword] = []

    private var isLoadingKeywordTopics = false
    private var keywordRefreshTask: Task<Void, Never>?
    private let keywordRefreshInterval: UInt64 = 60 * 1_000_000_000 // 60s

    func startKeywordRefreshLoopIfNeeded(chatService: ChatService) {
        guard keywordRefreshTask == nil else { return }

        keywordRefreshTask = Task {
            while !Task.isCancelled {
                await refreshKeywordTopicsOnce(chatService: chatService)
                do {
                    try await Task.sleep(nanoseconds: keywordRefreshInterval)
                } catch {
                    break
                }
            }
        }
    }

    func stopKeywordRefreshLoop() {
        keywordRefreshTask?.cancel()
        keywordRefreshTask = nil
    }

    private func refreshKeywordTopicsOnce(chatService: ChatService) async {
        guard !isLoadingKeywordTopics else { return }
        isLoadingKeywordTopics = true
        defer { isLoadingKeywordTopics = false }

        do {
            let topics = try await chatService.generateMenuKeywords(count: 6)
            if !topics.isEmpty {
                keywordTopics = topics
            }
        } catch {
            let nsError = error as NSError
            // If keyword generation is permanently unavailable, stop the loop.
            if nsError.domain == "ChatService", [-10, -11, -20, -21].contains(nsError.code) {
                if keywordTopics.isEmpty {
                    keywordTopics = defaultKeywordTopics()
                }
            }
            // -3 (busy) / -12 (not ready) and other transient errors: keep current topics.
            print("Keyword generation error: \(error)")
        }
    }

    private func defaultKeywordTopics() -> [ChatService.MenuKeyword] {
        let topics = [
            "Tech Stack",
            "Work Experience",
            "Featured Projects",
            "Key Skills",
            "Leadership Style",
            "Education Background"
        ]
        return topics.map { t in
            ChatService.MenuKeyword(keyword: t, question: "What can you tell me about \(t) in Pascal Fischer's portfolio?")
        }
    }
}
