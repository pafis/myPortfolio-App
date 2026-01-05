//
//  MenuBlobState.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 1/3/26.
//

import SwiftUI
import Combine

// MARK: - Chat Models
public enum ChatRole {
    case user
    case assistant
}

public struct ChatMessage: Identifiable {
    public let id = UUID()
    public let role: ChatRole
    public let content: String
    public let timestamp = Date()

    public init(role: ChatRole, content: String) {
        self.role = role
        self.content = content
    }
}

public class ChatService: ObservableObject {
    @Published public var messages: [ChatMessage] = []
    @Published public var isTyping = false
    
    private let systemPrompt = """
    You are Pascal Fischer's portfolio assistant. You are helpful, friendly, and knowledgeable about Pascal's work.
    Keep your answers concise and relevant to the portfolio context.
    """
    
    public init() {}

    public func sendMessage(_ text: String) {
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        isTyping = true
        
        Task {
            do {
                let conversationHistory = messages.map { msg in
                    "\(msg.role == .user ? "User" : "Assistant"): \(msg.content)"
                }.joined(separator: "\n")
                
                let fullPrompt = """
                \(systemPrompt)
                
                Conversation:
                \(conversationHistory)
                """
                
                guard let url = URL(string: "foundation://chat") else {
                    throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let payload: [String: Any] = [
                    "prompt": fullPrompt,
                    "temperature": 0.7,
                    "max_tokens": 500
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                
                let (data, _) = try await URLSession.shared.data(for: request)
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["response"] as? String {
                    await MainActor.run {
                        self.isTyping = false
                        let assistantMessage = ChatMessage(role: .assistant, content: content)
                        self.messages.append(assistantMessage)
                    }
                } else {
                    throw NSError(domain: "ChatService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
            } catch {
                await MainActor.run {
                    self.isTyping = false
                    let demoResponse = "Thank you for your message. I'm Pascal's portfolio assistant. While the AI service is being configured, please feel free to explore the portfolio to learn more about Pascal's work, skills, and experience."
                    let assistantMessage = ChatMessage(role: .assistant, content: demoResponse)
                    self.messages.append(assistantMessage)
                }
                print("Chat error: \(error)")
            }
        }
    }
    
    public func clear() {
        messages.removeAll()
        isTyping = false
    }
}

// MARK: - MenuBlobState
public struct MenuBlobState: Identifiable {
    public let id = UUID()
    public var text: String
    public var isDummy: Bool
    public var baseRadius: CGFloat
    private let originalRadius: CGFloat
    public let baseSpeed: CGFloat
    public var currentSpeed: CGFloat   
    public let waitTime: TimeInterval
    public let wobbleSeed: Float

    public var position = CGPoint(x: 0, y: 2000)
    // Normalized lane position (0..1) for stable menu blob X placement.
    public var laneT: CGFloat? = nil
    public var targetPosition: CGPoint?
    public var status: BlobStatus = .idle
    public var waitStart = Date()
    public var fleeDirection: CGFloat = 0
    public var originalPositionBeforeFlee: CGPoint = .zero
    public var debrisVelocity: CGPoint = .zero
    public var chatRole: ChatRole?
    public var messageID: UUID?
    public var bubbleWidth: CGFloat = 0
    public var bubbleHeight: CGFloat = 0
    public var isAnchored: Bool = false

    public enum BlobStatus { case idle, rising, waiting, sinking, fleeing, fled, returning, debris, chatBubble, spawningToChat, dismissing }

    public init(text: String, isDummy: Bool) {
        self.text = text
        self.isDummy = isDummy
        let radius = isDummy ? CGFloat.random(in: 20...35) : 38
        self.baseRadius = radius
        self.originalRadius = radius

        let randomSpeed = CGFloat.random(in: 0.5...0.8)
        self.baseSpeed = randomSpeed
        self.currentSpeed = randomSpeed

        self.waitTime = .random(in: 3.0...7.0)
        self.wobbleSeed = Float.random(in: 0...1000)
    }

    public mutating func spawn(x: CGFloat, y: CGFloat) {
        position = CGPoint(x: x, y: y)
        status = .rising
        baseRadius = originalRadius
        currentSpeed = baseSpeed
        waitStart = Date()
    }

    public mutating func spawnInLane(containerWidth: CGFloat, startY: CGFloat) {
        let t = laneT ?? 0.5
        let margin: CGFloat = 80
        let x = min(max(containerWidth * t, margin), max(containerWidth - margin, margin))
        spawn(x: x, y: startY)
    }

    public mutating func assignMessage(id: UUID, frame: CGRect, role: ChatRole) {
        self.messageID = id
        self.chatRole = role
        if self.status == .idle {
            self.status = .spawningToChat
            self.isAnchored = false
            self.position = CGPoint(x: frame.midX, y: 2000)
        }
        self.isDummy = false
        self.bubbleWidth = frame.width
        self.bubbleHeight = frame.height
        self.targetPosition = CGPoint(x: frame.midX, y: frame.midY)
        
        if self.isAnchored {
            self.position = self.targetPosition!
        }
    }
}
