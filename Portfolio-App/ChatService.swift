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

public class ChatService: ObservableObject {
    @Published public var messages: [ChatMessage] = []
    @Published public var isTyping = false

    private var systemPrompt: String { ChatSystemPrompt.make() }

    private let introductionRequest = """
Write a short introduction and greeting message as Pascal Fischer's portfolio assistant to some user that wants to learn more about Pascal's work, skills, and experience.

Requirements:
- 1–2 sentences.
- Friendly and professional.
- Do not mention system prompts, policies, or internal limitations.
"""

    private var onDeviceStateBox: Any?
    
    public init() {}

    public func generateMenuKeywords(count: Int = 6) async throws -> [String] {
        let targetCount = max(1, min(12, count))
        let request = """
Generate exactly \(targetCount) single-keyword topic suggestions for Pascal Fischer's portfolio.

Requirements:
- Each suggestion must be a single keyword (no spaces).
- Use keywords a recruiter would click to learn more.
- No emojis.
- Output ONLY a JSON array of strings.
"""

#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let state = getOnDeviceStateBox()

            // Avoid concurrent use with the active chat session.
            if state.session?.isResponding == true {
                throw NSError(domain: "ChatService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Model is busy"])
            }

            switch state.model.availability {
            case .available:
                // Use a dedicated session for keyword generation so we don't pollute chat context.
                let session = LanguageModelSession(instructions: systemPrompt)
                let options = GenerationOptions(temperature: 0.4)
                let response = try await session.respond(to: request, options: options)
                return Self.parseMenuKeywords(from: response.content, desiredCount: targetCount)

            case .unavailable(.deviceNotEligible):
                throw NSError(domain: "ChatService", code: -10, userInfo: [NSLocalizedDescriptionKey: "This device doesn't support Apple Intelligence."])
            case .unavailable(.appleIntelligenceNotEnabled):
                throw NSError(domain: "ChatService", code: -11, userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence is turned off in Settings."])
            case .unavailable(.modelNotReady):
                throw NSError(domain: "ChatService", code: -12, userInfo: [NSLocalizedDescriptionKey: "The on-device model is downloading or not ready yet."])
            case .unavailable:
                throw NSError(domain: "ChatService", code: -13, userInfo: [NSLocalizedDescriptionKey: "The on-device model is unavailable."])
            }
        } else {
            throw NSError(domain: "ChatService", code: -20, userInfo: [NSLocalizedDescriptionKey: "On-device generation requires a newer OS version."])
        }
#else
        throw NSError(domain: "ChatService", code: -21, userInfo: [NSLocalizedDescriptionKey: "FoundationModels framework is unavailable in this SDK."])
#endif
    }

    public func sendIntroductionIfNeeded() {
        guard messages.isEmpty else { return }
        guard !isTyping else { return }

        isTyping = true

        Task {
            do {
                let intro = try await self.generateAssistantReply(to: self.introductionRequest)
                await MainActor.run {
                    self.isTyping = false
                    self.messages.append(ChatMessage(role: .assistant, content: intro))
                }
            } catch {
                await MainActor.run {
                    self.isTyping = false
                    self.messages.append(ChatMessage(role: .assistant, content: self.fallbackIntroduction(for: error)))
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
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isTyping else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        isTyping = true
        
        Task {
            do {
                let assistantText = try await self.generateAssistantReply(to: text)
                await MainActor.run {
                    self.isTyping = false
                    self.messages.append(ChatMessage(role: .assistant, content: assistantText))
                }
            } catch {
                await MainActor.run {
                    self.isTyping = false
                    let assistantMessage = ChatMessage(
                        role: .assistant,
                        content: self.fallbackResponse(for: error)
                    )
                    self.messages.append(assistantMessage)
                }
                print("Chat error: \(error)")
            }
        }
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

    private func generateAssistantReply(to userText: String) async throws -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let state = getOnDeviceStateBox()
            switch state.model.availability {
            case .available:
                let session = state.session ?? LanguageModelSession(instructions: systemPrompt)
                state.session = session

                if session.isResponding {
                    throw NSError(
                        domain: "ChatService",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "Model is busy"]
                    )
                }

                let options = GenerationOptions(temperature: 0.7)
                let response = try await session.respond(to: userText, options: options)
                return response.content

            case .unavailable(.deviceNotEligible):
                throw NSError(
                    domain: "ChatService",
                    code: -10,
                    userInfo: [NSLocalizedDescriptionKey: "This device doesn't support Apple Intelligence."]
                )
            case .unavailable(.appleIntelligenceNotEnabled):
                throw NSError(
                    domain: "ChatService",
                    code: -11,
                    userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence is turned off in Settings."]
                )
            case .unavailable(.modelNotReady):
                throw NSError(
                    domain: "ChatService",
                    code: -12,
                    userInfo: [NSLocalizedDescriptionKey: "The on-device model is downloading or not ready yet."]
                )
            case .unavailable:
                throw NSError(
                    domain: "ChatService",
                    code: -13,
                    userInfo: [NSLocalizedDescriptionKey: "The on-device model is unavailable."]
                )
            }
        } else {
            throw NSError(
                domain: "ChatService",
                code: -20,
                userInfo: [NSLocalizedDescriptionKey: "On-device generation requires a newer OS version."]
            )
        }
#else
        throw NSError(
            domain: "ChatService",
            code: -21,
            userInfo: [NSLocalizedDescriptionKey: "FoundationModels framework is unavailable in this SDK."]
        )
#endif
    }
    
    public func clear() {
        messages.removeAll()
        isTyping = false

        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            onDeviceStateBox = nil
        }
    }

    private static func parseMenuKeywords(from raw: String, desiredCount: Int) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var candidates: [String] = []

        if let data = trimmed.data(using: .utf8) {
            if let json = try? JSONSerialization.jsonObject(with: data),
               let arr = json as? [Any] {
                candidates = arr.compactMap { $0 as? String }
            }
        }

        if candidates.isEmpty {
            candidates = trimmed
                .replacingOccurrences(of: "\r", with: "\n")
                .split(whereSeparator: { $0 == "\n" || $0 == "," })
                .map { String($0) }
        }

        func normalize(_ s: String) -> String? {
            var v = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if v.hasPrefix("-") { v.removeFirst() }
            if v.hasPrefix("•") { v.removeFirst() }
            v = v.trimmingCharacters(in: .whitespacesAndNewlines)
            v = v.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`[](){}<>.:;!?") )
            guard !v.isEmpty else { return nil }
            guard v.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
            guard v.count <= 24 else { return nil }
            return v
        }

        var seen = Set<String>()
        var out: [String] = []
        for c in candidates {
            guard let n = normalize(c) else { continue }
            let key = n.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(n)
            if out.count >= desiredCount { break }
        }
        return out
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
private final class OnDeviceStateBox {
    let model = SystemLanguageModel.default
    var session: LanguageModelSession?
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
private extension ChatService {
    func getOnDeviceStateBox() -> OnDeviceStateBox {
        if let existing = onDeviceStateBox as? OnDeviceStateBox {
            return existing
        }

        let created = OnDeviceStateBox()
        onDeviceStateBox = created
        return created
    }
}
#endif
