//
//  ChatService.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 1/5/26.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
public final class ChatService: ObservableObject {
    @Published public var messages: [ChatMessage] = []
    @Published public var isTyping = false
    @Published public private(set) var pendingAssistantReply: String? = nil

    private var systemPrompt: String { ChatSystemPrompt.make() }

    private let introductionRequest = """
Write a short introduction and greeting message as Pascal Fischer's portfolio assistant to some user that wants to learn more about Pascal's work, skills, and experience.

Requirements:
- 1–2 sentences.
- Friendly and professional.
- Do not mention system prompts, policies, or internal limitations.
"""

#if canImport(FoundationModels)
    // Stored properties can't be conditionally available; store the actor in a type-erased box.
    private var modelActorBox: Any?

    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func getModelActor() -> ChatModelActor {
        if let existing = modelActorBox as? ChatModelActor {
            return existing
        }
        let created = ChatModelActor()
        modelActorBox = created
        return created
    }
#endif
    
    public init() {}

    public struct MenuKeyword: Codable, Identifiable, Equatable {
        public let id = UUID()
        public let keyword: String
        public let question: String

        public enum CodingKeys: String, CodingKey {
            case keyword
            case question
        }
    }

    public func generateMenuKeywords(count: Int = 6) async throws -> [MenuKeyword] {
        let targetCount = max(1, min(12, count))
        let request = """
    Generate exactly \(targetCount) topic suggestions for Pascal Fischer's portfolio.

Requirements:
    - Each topic must be exactly 2 words.
    - Topics must NOT be full sentences or questions.
    - Use topics a recruiter would click to learn more.
- No emojis.
    - For each topic also provide a concise question that asks about that topic in the context of Pascal Fischer's portfolio.
    - Output ONLY a JSON array of objects {"keyword":"...","question":"..."}.
    - Do not wrap the JSON in Markdown code fences.
    - Do not output any extra text before or after the JSON.
"""

        let strictRequest = """
    Return ONLY valid JSON.

    Output format (exactly):
    [{"keyword":"<1-2 words, not a question>","question":"<a question about that keyword>"}]

    Rules:
    - keyword: exactly 2 words, not a sentence, not a question, no trailing punctuation.
    - question: must contain the keyword and end with a '?'.
    - No Markdown, no code fences, no commentary.
    """

#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let actor = getModelActor()

            let response = try await actor.statelessResponse(
                instructions: systemPrompt,
                prompt: request,
                temperature: 0.4
            )
            let parsed = Self.parseMenuKeywords(from: response, desiredCount: targetCount)

            // If formatting was imperfect, retry once with stricter instructions.
            if parsed.count >= max(2, min(targetCount, 4)) {
                return parsed
            }

            let strictResponse = try await actor.statelessResponse(
                instructions: systemPrompt,
                prompt: strictRequest,
                temperature: 0.0
            )
            return Self.parseMenuKeywords(from: strictResponse, desiredCount: targetCount)
        }

        throw NSError(domain: "ChatService", code: -20, userInfo: [NSLocalizedDescriptionKey: "On-device generation requires a newer OS version."])
#else
        throw NSError(domain: "ChatService", code: -21, userInfo: [NSLocalizedDescriptionKey: "FoundationModels framework is unavailable in this SDK."])
#endif
    }

    public func sendIntroductionIfNeeded() {
        guard messages.isEmpty else { return }
        guard !isTyping else { return }
        guard pendingAssistantReply == nil else { return }

        isTyping = true

        let prompt = introductionRequest
        let instructions = systemPrompt

        Task {
            do {
#if canImport(FoundationModels)
                if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
                    let actor = self.getModelActor()

                    let intro = try await actor.chatResponse(
                        instructions: instructions,
                        prompt: prompt,
                        temperature: 0.7
                    )
                    await MainActor.run {
                        self.isTyping = false
                        self.pendingAssistantReply = intro
                    }
                    return
                }
#endif
                throw NSError(domain: "ChatService", code: -20, userInfo: [NSLocalizedDescriptionKey: "On-device generation requires a newer OS version."])
            } catch {
                await MainActor.run {
                    self.isTyping = false
                    self.pendingAssistantReply = self.fallbackIntroduction(for: error)
                }
                print("Chat intro error: \(error)")
            }
        }
    }

    private func fallbackIntroduction(for error: Error) -> String {
        // Keep the intro usable even if on-device generation isn't available.
        let greeting: String = {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 5..<12: return "Good morning"
            case 12..<18: return "Good afternoon"
            default: return "Good evening"
            }
        }()

        let base = "\(greeting)! I'm Pascal's portfolio assistant."

        let nsError = error as NSError
        if nsError.domain == "ChatService" {
            switch nsError.code {
            case -10:
                return "\(base) (Apple Intelligence isn’t available on this device.)"
            case -11:
                return "\(base) (Apple Intelligence is turned off in Settings.)"
            case -12:
                return "\(base) (The on-device model is still getting ready.)"
            case -20, -21:
                return base
            default:
                return base
            }
        }

        return base
    }

    public func sendMessage(_ text: String) {
        guard appendUserMessage(text) != nil else { return }
        startAssistantReply(for: text)
    }

    /// Appends the user's message immediately (no LLM work).
    /// Returns the created message if it was appended.
    @discardableResult
    public func appendUserMessage(_ text: String) -> ChatMessage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let userMessage = ChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        return userMessage
    }

    /// Starts generating the assistant reply for the given user text without appending the user message.
    public func startAssistantReply(for userText: String) {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isTyping else { return }
        guard pendingAssistantReply == nil else { return }

        isTyping = true

        let prompt = trimmed
        let instructions = systemPrompt

        Task {
            do {
                let assistantText: String
#if canImport(FoundationModels)
                if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
                    let actor = self.getModelActor()
                    assistantText = try await actor.chatResponse(
                        instructions: instructions,
                        prompt: prompt,
                        temperature: 0.7
                    )
                } else {
                    throw NSError(domain: "ChatService", code: -20, userInfo: [NSLocalizedDescriptionKey: "On-device generation requires a newer OS version."])
                }
#else
                throw NSError(domain: "ChatService", code: -21, userInfo: [NSLocalizedDescriptionKey: "FoundationModels framework is unavailable in this SDK."])
#endif
                await MainActor.run {
                    self.isTyping = false
                    self.pendingAssistantReply = assistantText
                }
            } catch {
                await MainActor.run {
                    self.isTyping = false
                    self.pendingAssistantReply = self.fallbackResponse(for: error)
                }
                print("Chat error: \(error)")
            }
        }
    }

    public func commitPendingAssistantReplyIfAny() {
        guard let text = pendingAssistantReply else { return }
        pendingAssistantReply = nil
        messages.append(ChatMessage(role: .assistant, content: text))
    }

    private func fallbackResponse(for error: Error) -> String {
        let generic = "Thank you for your message. I'm Pascal's portfolio assistant. While the AI service is being configured, please feel free to explore the portfolio to learn more about Pascal's work, skills, and experience."

        let nsError = error as NSError
        guard nsError.domain == "ChatService" else { return generic }

        switch nsError.code {
        case -10:
            return "This device doesn't support Apple Intelligence yet. \n\n\(generic)"
        case -11:
            return "Apple Intelligence is turned off. Turn it on in Settings and try again. \n\n\(generic)"
        case -12:
            return "The on-device model is downloading or not ready yet. Please try again in a moment. \n\n\(generic)"
        case -20:
            return "This OS version doesn't support Foundation Models yet. \n\n\(generic)"
        case -21:
            return "This build of the app was made with an SDK that doesn't include Foundation Models. \n\n\(generic)"
        default:
            if !nsError.localizedDescription.isEmpty {
                return "\(nsError.localizedDescription)\n\n\(generic)"
            }
            return generic
        }
    }

    public func clear() {
        messages.removeAll()
        isTyping = false

#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            modelActorBox = nil
        }
#endif
    }

    private static func parseMenuKeywords(from raw: String, desiredCount: Int) -> [MenuKeyword] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        func stripCodeFences(_ s: String) -> String {
            var out = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if out.hasPrefix("```") {
                // Remove first fence line
                if let firstNewline = out.firstIndex(of: "\n") {
                    out = String(out[out.index(after: firstNewline)...])
                }
                // Remove trailing fence
                if let range = out.range(of: "```", options: .backwards) {
                    out.removeSubrange(range.lowerBound..<out.endIndex)
                }
                out = out.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return out
        }

        func extractJSONArray(_ s: String) -> String? {
            guard let start = s.firstIndex(of: "["), let end = s.lastIndex(of: "]"), start < end else { return nil }
            return String(s[start...end])
        }

        func extractJSONObject(_ s: String) -> String? {
            guard let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}"), start < end else { return nil }
            return String(s[start...end])
        }

        func decodeArray(from s: String) -> [MenuKeyword]? {
            guard let data = s.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode([MenuKeyword].self, from: data)
        }

        func decodeObject(from s: String) -> MenuKeyword? {
            guard let data = s.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(MenuKeyword.self, from: data)
        }

        func validate(_ items: [MenuKeyword]) -> [MenuKeyword] {
            var seen = Set<String>()
            var out: [MenuKeyword] = []
            for item in items {
                guard let kw = KeywordValidation.normalizeTwoWordKeyword(item.keyword) else { continue }
                let key = kw.lowercased()
                guard !seen.contains(key) else { continue }
                seen.insert(key)

                let q = item.question.trimmingCharacters(in: .whitespacesAndNewlines)
                let containsKeyword = q.lowercased().contains(kw.lowercased())
                let endsWithQuestionMark = q.hasSuffix("?")
                let question = (q.isEmpty || !containsKeyword || !endsWithQuestionMark)
                    ? "What can you tell me about \(kw) in Pascal Fischer's portfolio?"
                    : q

                out.append(MenuKeyword(keyword: kw, question: question))
                if out.count >= desiredCount { break }
            }
            return out
        }

        let cleaned = stripCodeFences(trimmed)

        if let arrayJSON = extractJSONArray(cleaned), let decoded = decodeArray(from: arrayJSON) {
            let validated = validate(decoded)
            if !validated.isEmpty { return validated }
        }

        if let objJSON = extractJSONObject(cleaned), let decoded = decodeObject(from: objJSON) {
            let validated = validate([decoded])
            if !validated.isEmpty { return validated }
        }

        // Strict mode: if we can't decode valid JSON, return nothing.
        return []
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
private actor ChatModelActor {
    private let model = SystemLanguageModel.default
    private var chatSession: LanguageModelSession?
    private var chatSessionInstructions: String?
    private var inFlight: Bool = false

    func chatResponse(instructions: String, prompt: String, temperature: Double) async throws -> String {
        try ensureAvailableOrThrow()
        guard !inFlight else {
            throw NSError(domain: "ChatService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Model is busy"])
        }
        inFlight = true
        defer { inFlight = false }

        let session: LanguageModelSession
        if let existing = chatSession, chatSessionInstructions == instructions {
            session = existing
        } else {
            let created = LanguageModelSession(instructions: instructions)
            chatSession = created
            chatSessionInstructions = instructions
            session = created
        }

        let options = GenerationOptions(temperature: temperature)
        let response = try await session.respond(to: prompt, options: options)
        return response.content
    }

    func statelessResponse(instructions: String, prompt: String, temperature: Double) async throws -> String {
        try ensureAvailableOrThrow()
        guard !inFlight else {
            throw NSError(domain: "ChatService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Model is busy"])
        }
        inFlight = true
        defer { inFlight = false }

        let session = LanguageModelSession(instructions: instructions)
        let options = GenerationOptions(temperature: temperature)
        let response = try await session.respond(to: prompt, options: options)
        return response.content
    }

    private func ensureAvailableOrThrow() throws {
        switch model.availability {
        case .available:
            return
        case .unavailable(.deviceNotEligible):
            throw NSError(domain: "ChatService", code: -10, userInfo: [NSLocalizedDescriptionKey: "This device doesn't support Apple Intelligence."])
        case .unavailable(.appleIntelligenceNotEnabled):
            throw NSError(domain: "ChatService", code: -11, userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence is turned off in Settings."])
        case .unavailable(.modelNotReady):
            throw NSError(domain: "ChatService", code: -12, userInfo: [NSLocalizedDescriptionKey: "The on-device model is downloading or not ready yet."])
        case .unavailable:
            throw NSError(domain: "ChatService", code: -13, userInfo: [NSLocalizedDescriptionKey: "The on-device model is unavailable."])
        }
    }
}
#endif
