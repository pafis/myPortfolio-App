//
//  MenuBlobState.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 1/3/26.
//

import SwiftUI

// MARK: - MenuBlobState
public struct MenuBlobState: Identifiable {
    public let id = UUID()
    public let text: String
    public let isDummy: Bool
    public let baseRadius: CGFloat
    public let baseSpeed: CGFloat
    public var currentSpeed: CGFloat   
    public let waitTime: TimeInterval
    public let wobbleSeed: Float

    public var position = CGPoint(x: 0, y: 2000)
    public var status: BlobStatus = .idle
    public var waitStart = Date()

    public enum BlobStatus { case idle, rising, waiting, sinking }

    public init(text: String, isDummy: Bool) {
        self.text = text
        self.isDummy = isDummy
        self.baseRadius = isDummy ? .random(in: 20...35) : 38

        let randomSpeed = CGFloat.random(in: 0.5...0.8)
        self.baseSpeed = randomSpeed
        self.currentSpeed = randomSpeed // Start at base speed

        self.waitTime = .random(in: 3.0...7.0)
        self.wobbleSeed = Float.random(in: 0...1000)
    }

    public mutating func spawn(x: CGFloat, y: CGFloat) {
        position = CGPoint(x: x, y: y)
        status = .rising
        currentSpeed = baseSpeed // Reset speed on spawn
        waitStart = Date()
    }
}
