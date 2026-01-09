//
//  MenuBlobState.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 1/3/26.
//

import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Chat Models
public enum ChatRole {
    case user
    case assistant
}

public struct ChatMessage: Identifiable {
    public let id: UUID
    public let role: ChatRole
    public let content: String
    public let timestamp = Date()

    public init(id: UUID = UUID(), role: ChatRole, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

// MARK: - MenuBlobState
public struct MenuBlobState: Identifiable {
    public let id = UUID()
    public var text: String
    public var isDummy: Bool
    public var menuItemID: UUID? = nil
    public var baseRadius: CGFloat
    private var originalRadius: CGFloat
    public let baseSpeed: CGFloat
    public var currentSpeed: CGFloat   
    public let waitTime: TimeInterval
    public let wobbleSeed: Float

    // 0..1 heat level used for buoyancy/expansion-style motion.
    public var temperature: CGFloat = 0

    public var position = CGPoint(x: 0, y: 2000)
    public var previousPosition = CGPoint(x: 0, y: 2000)
    // Simulation velocity (points/second) used for fluid-like motion with resistance.
    // Note: `velocity` below is derived from frame-to-frame position deltas for rendering.
    public var simVelocity: CGVector = .zero
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

    private static func measuredTextSize(text: String, fontSize: CGFloat) -> CGSize {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .zero }

#if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        return (trimmed as NSString).size(withAttributes: attrs)
#elseif canImport(AppKit)
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        return (trimmed as NSString).size(withAttributes: attrs)
#else
        // Fallback heuristic if we can't measure: ~0.6em per character.
        let w = CGFloat(trimmed.count) * fontSize * 0.6
        return CGSize(width: w, height: fontSize * 1.2)
#endif
    }

    private static func radiusForLabel(text: String, fontSize: CGFloat) -> CGFloat {
        let textSize = measuredTextSize(text: text, fontSize: fontSize)
        guard textSize != .zero else { return 38 }

        // Padding so the label doesn't touch the blob edge.
        let padX: CGFloat = 16
        let padY: CGFloat = 12
        let w = textSize.width + padX
        let h = textSize.height + padY

        // Circle that encloses the text's bounding box.
        let diagonal = sqrt(w * w + h * h)
        return max(38, ceil(diagonal / 2))
    }

    public mutating func setLabelText(_ newText: String, fontSize: CGFloat = 14) {
        text = newText
        let r = Self.radiusForLabel(text: newText, fontSize: fontSize)
        baseRadius = r
        originalRadius = r
    }

    public init(text: String, isDummy: Bool) {
        self.text = text
        self.isDummy = isDummy

        let radius: CGFloat = {
            if isDummy {
                return CGFloat.random(in: 20...35)
            }
            // Matches the label font used in LavaMenuContainer.
            return Self.radiusForLabel(text: text, fontSize: 14)
        }()
        self.baseRadius = radius
        self.originalRadius = radius

        let randomSpeed = CGFloat.random(in: 0.5...0.8)
        self.baseSpeed = randomSpeed
        self.currentSpeed = randomSpeed

        self.waitTime = .random(in: 3.0...7.0)
        self.wobbleSeed = Float.random(in: 0...1000)
        self.temperature = 0
    }

    public mutating func spawn(x: CGFloat, y: CGFloat) {
        position = CGPoint(x: x, y: y)
        previousPosition = position
        simVelocity = .zero
        velocity = .zero
        status = .rising
        baseRadius = originalRadius
        currentSpeed = baseSpeed
        waitStart = Date()

        // Freshly spawned blobs represent freshly heated wax.
        // Keep background dummies cooler so they stay small and don't immediately merge.
        temperature = max(temperature, isDummy ? 0.25 : 0.85)
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
            self.simVelocity = .zero
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
