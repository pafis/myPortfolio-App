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
    public var previousPosition = CGPoint(x: 0, y: 2000)
    public var velocity: CGVector = .zero // points/second
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
        previousPosition = position
        velocity = .zero
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
            self.previousPosition = self.position
            self.velocity = .zero
        }
        self.isDummy = false
        self.bubbleWidth = frame.width
        self.bubbleHeight = frame.height
        self.targetPosition = CGPoint(x: frame.midX, y: frame.midY)
        
        if self.isAnchored {
            self.position = self.targetPosition!
            self.previousPosition = self.position
            self.velocity = .zero
        }
    }
}
