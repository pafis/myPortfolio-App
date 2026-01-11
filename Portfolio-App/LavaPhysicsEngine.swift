//
//  LavaPhysicsEngine.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 01/09/26.
//

import Foundation
import Combine
import CoreGraphics
import SwiftUI

@MainActor
final class LavaPhysicsEngine: ObservableObject {
    @Published var blobs: [MenuBlobState] = []
    @Published var wobbleTime: Float = 0

    private var wobbleStart: Date = .now

    private var timerHz: TimeInterval { Constants.timerHz }

    private var lastSpawn: Date = .now
    private var nextSpawnDelay: TimeInterval = 1.0
    private var menuQueueIndex = 0
    private var keywordQueueIndex = 0
    private var lastSpawnWasMenuItem: Bool = false

    private var lastDummySpawn: Date = .now
    private var nextDummySpawnDelay: TimeInterval = 1.0

    private var wasFocused: Bool = false

    // Selection events produced by user interaction (taps).
    public enum Selection {
        case menuItem(PortfolioMenuItem)
        case keyword(ChatService.MenuKeyword)
    }

    /// Publishes a selection event when the user taps a blob.
    public let selectionSubject = PassthroughSubject<Selection, Never>()

    private var menuItems: [PortfolioMenuItem] = []
    private var keywordItems: [ChatService.MenuKeyword] = []
    private weak var chatService: ChatService?

    private enum Constants {
        static let timerHz: TimeInterval = 1 / 60

        static let safeSpawnMargin: CGFloat = 80
        static let safeSpawnMinDistance: CGFloat = 170
        static let safeSpawnAttempts: Int = 10

        static let trafficLaneWidth: CGFloat = 170.0
        static let trafficSafeDistance: CGFloat = 240.0

        static let dismissSpeed: CGFloat = 2.0
        static let spawnToChatSpeed: CGFloat = 15.0
        static let resetOffscreenY: CGFloat = -100

        static let spawnStartYOffset: CGFloat = 360
        static let menuSpawnDelay: ClosedRange<TimeInterval> = 9.0...15.0

        static let maxActiveDummies: Int = 2
        static let dummyInitialDelay: TimeInterval = 0.2
        static let dummySpawnDelay: ClosedRange<TimeInterval> = 1.0...2.0
        static let dummySpawnBackoffDelay: ClosedRange<TimeInterval> = 1.5...3.0
        static let dummySpawnXPadding: CGFloat = 40

        static let fleeSpeed: CGFloat = 35.0
        static let fleeAccel: CGFloat = 1.15
        static let fleeOffscreenPadding: CGFloat = 250
        static let returnSpeedBoost: CGFloat = 4.0

        static let maxDebrisPerFlee: Int = 3
        static let debrisRadiusScale: ClosedRange<CGFloat> = 0.3...0.6
        static let debrisOpposeX: ClosedRange<CGFloat> = 1...3
        static let debrisY: ClosedRange<CGFloat> = -1...1
        static let debrisDamp: CGFloat = 0.96
        static let debrisUpwardBias: CGFloat = 0.02

        static let tapMaxDistanceScale: CGFloat = 1.35

        static let fluidFollow: CGFloat = 0.10
        static let fluidDrag: CGFloat = 0.985
        static let lateralCurrentPxPerSec: CGFloat = 14

        static let heaterBandStart: CGFloat = 0.70
        static let heatUpRate: CGFloat = 1.6
        static let coolDownRate: CGFloat = 0.35

        static let buoyancyMin: CGFloat = 0.15
        static let buoyancyMax: CGFloat = 1.0

        static let riseBoost: CGFloat = 1.55

        static let topExitPadding: CGFloat = 180
        static let bottomRecyclePadding: CGFloat = 140

        static let typingMessageID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        static let typingExitPadding: CGFloat = 160
    }

    init() {}

    func configure(menuItems: [PortfolioMenuItem], keywordItems: [ChatService.MenuKeyword], chatService: ChatService) {
        self.menuItems = menuItems
        self.keywordItems = keywordItems
        self.chatService = chatService
    }

    func initialize(_ size: CGSize) {
        blobs = menuItems.map {
            var b = MenuBlobState(text: $0.name, isDummy: false)
            b.menuItemID = $0.id
            return b
        }

        let initialKeywords = keywordItems.filter { KeywordValidation.normalizeTwoWordKeyword($0.keyword) != nil }
        for k in initialKeywords {
            blobs.append(MenuBlobState(text: k.keyword, isDummy: false))
        }

        for _ in 0..<30 { blobs.append(MenuBlobState(text: "", isDummy: true)) }

        lastDummySpawn = .now
        nextDummySpawnDelay = Constants.dummyInitialDelay
        wobbleStart = .now
        wobbleTime = 0
    }

    func syncKeywordBlobs(with keywords: [ChatService.MenuKeyword]) {
        keywordItems = keywords
        let desired = keywords.map { $0.keyword }.filter { KeywordValidation.normalizeTwoWordKeyword($0) != nil }
        guard !desired.isEmpty else { return }

        let desiredSet = Set(desired)
        for i in blobs.indices {
            guard !blobs[i].isDummy else { continue }
            guard blobs[i].menuItemID == nil else { continue }
            guard blobs[i].messageID == nil else { continue }
            guard blobs[i].status == .idle else { continue }
            if !desiredSet.contains(blobs[i].text) {
                blobs[i].isDummy = true
                blobs[i].text = ""
                blobs[i].menuItemID = nil
            }
        }

        let existingKeywords = Set(blobs.filter { !$0.isDummy && $0.menuItemID == nil && $0.messageID == nil }.map { $0.text })
        let missing = desired.filter { !existingKeywords.contains($0) }
        for k in missing {
            if let idle = blobs.firstIndex(where: { $0.isDummy && $0.messageID == nil && ($0.status == .idle || $0.status == .debris) }) {
                blobs[idle].isDummy = false
                blobs[idle].setLabelText(k, fontSize: 14)
                blobs[idle].menuItemID = nil
                blobs[idle].status = .idle
                blobs[idle].targetPosition = nil
                blobs[idle].isAnchored = false
            } else {
                blobs.append(MenuBlobState(text: k, isDummy: false))
            }
        }

        keywordQueueIndex = 0
    }

    func handleTap(at location: CGPoint, size: CGSize, onSelectMenuItem: ((PortfolioMenuItem) -> Void)?, onSelectKeyword: ((ChatService.MenuKeyword) -> Void)?) {
        // Work from a snapshot of the blobs array to avoid index invalidation
        // if the underlying array changes concurrently during rendering.
        let snapshot = blobs
        var bestIndex: Int?
        var bestDistance: CGFloat = .greatestFiniteMagnitude

        for (i, b) in snapshot.enumerated() {
            guard !b.isDummy else { continue }
            guard b.messageID == nil else { continue }
            guard b.status == .rising || b.status == .returning else { continue }
            guard !b.text.isEmpty else { continue }

            let dx = b.position.x - location.x
            let dy = b.position.y - location.y
            let dist = sqrt(dx * dx + dy * dy)
            let maxDist = max(44, b.baseRadius * Constants.tapMaxDistanceScale)
            guard dist <= maxDist else { continue }
            if dist < bestDistance {
                bestDistance = dist
                bestIndex = i
            }
        }

        guard let idx = bestIndex else { return }

        // Capture local copies to avoid races with concurrent updates.
        let menuItemsCopy = menuItems
        let keywordItemsCopy = keywordItems
        let blobText = snapshot[idx].text
        let menuItemID = snapshot[idx].menuItemID

        // Publish selection via Combine subject; caller (LavaMenuContainer) will
        // subscribe and handle the selection on the main thread. This avoids
        // directly invoking view callbacks from the engine.
        if let id = menuItemID,
           let item = menuItemsCopy.first(where: { $0.id == id }) {
            selectionSubject.send(.menuItem(item))
            return
        }

        if let kw = keywordItemsCopy.first(where: { $0.keyword == blobText }) {
            selectionSubject.send(.keyword(kw))
            return
        }

        let synthesized = ChatService.MenuKeyword(keyword: blobText, question: "What can you tell me about \(blobText) in Pascal Fischer's portfolio?")
        selectionSubject.send(.keyword(synthesized))
    }

    private func getSafeSpawnX(in width: CGFloat) -> CGFloat {
        let range = Constants.safeSpawnMargin...(width - Constants.safeSpawnMargin)

        for _ in 0..<Constants.safeSpawnAttempts {
            let candidate = CGFloat.random(in: range)
            let hasCollision = blobs.contains { b in
                !b.isDummy && b.status != .idle && abs(b.position.x - candidate) < Constants.safeSpawnMinDistance
            }
            if !hasCollision { return candidate }
        }
        return CGFloat.random(in: range)
    }

    private func adjustTraffic() {
        for i in blobs.indices where blobs[i].status == .rising {
            blobs[i].currentSpeed = blobs[i].baseSpeed
        }

        for i in 0..<blobs.count {
            guard !blobs[i].isDummy, blobs[i].status == .rising else { continue }
            for j in 0..<blobs.count {
                if i == j { continue }
                guard !blobs[j].isDummy, blobs[j].status == .rising else { continue }
                if abs(blobs[i].position.x - blobs[j].position.x) < Constants.trafficLaneWidth {
                    let distY = blobs[i].position.y - blobs[j].position.y
                    if distY > 0 && distY < Constants.trafficSafeDistance {
                        blobs[i].currentSpeed = min(blobs[i].currentSpeed, blobs[j].currentSpeed)
                    }
                }
            }
        }
    }

    func update(_ size: CGSize, isChatFocused: Bool, isDetailOpen: Bool, showChatOverlay: Bool) -> (typingOut: Bool, anyDebris: Bool) {
        let now = Date()
        wobbleTime = Float(now.timeIntervalSince(wobbleStart))

        let dt = Constants.timerHz

        for i in blobs.indices { blobs[i].previousPosition = blobs[i].position }

        if !showChatOverlay { handleChatOverlayDismissal() }
        stepChatBlobs()

        let typingOut = blobs.contains(where: { $0.messageID == Constants.typingMessageID && $0.status == .dismissing })

        let shouldFlee = isChatFocused || isDetailOpen
        if shouldFlee {
            if !wasFocused {
                wasFocused = true
                for idx in blobs.indices {
                    guard blobs[idx].status != .idle && blobs[idx].status != .fled && blobs[idx].status != .debris else { continue }
                    guard blobs[idx].status != .chatBubble && blobs[idx].status != .spawningToChat else { continue }

                    let oldPos = blobs[idx].position
                    let oldRadius = blobs[idx].baseRadius

                    blobs[idx].originalPositionBeforeFlee = oldPos
                    blobs[idx].status = .fleeing
                    blobs[idx].fleeDirection = blobs[idx].position.x < (size.width * 0.5) ? -1 : 1
                    blobs[idx].currentSpeed = 35.0

                    var debrisCount = 0
                    for dIdx in blobs.indices where blobs[dIdx].isDummy && blobs[dIdx].status == .idle && debrisCount < 3 {
                        blobs[dIdx].position = oldPos
                        blobs[dIdx].baseRadius = oldRadius * .random(in: 0.3...0.6)
                        blobs[dIdx].status = .debris
                        blobs[dIdx].debrisVelocity = CGPoint(
                            x: -blobs[idx].fleeDirection * .random(in: 1...3),
                            y: .random(in: -1...1)
                        )
                        debrisCount += 1
                    }
                }
            }
        } else {
            if wasFocused {
                wasFocused = false
                for idx in blobs.indices {
                    if blobs[idx].status == .fled || blobs[idx].status == .fleeing {
                        blobs[idx].status = .returning
                        blobs[idx].currentSpeed *= 4.0
                    }
                }
            }

            if now.timeIntervalSince(lastSpawn) > nextSpawnDelay {
                let menuCount = menuItems.count
                let keywordCount = keywordItems.count

                func nextMenuIndex() -> Int? {
                    guard menuCount > 0 else { return nil }
                    let id = menuItems[menuQueueIndex % menuCount].id
                    return blobs.firstIndex(where: { !$0.isDummy && $0.status == .idle && $0.menuItemID == id })
                }

                func nextKeywordIndex() -> Int? {
                    guard keywordCount > 0 else { return nil }
                    let key = keywordItems[keywordQueueIndex % keywordCount].keyword
                    return blobs.firstIndex(where: { !$0.isDummy && $0.status == .idle && $0.menuItemID == nil && $0.messageID == nil && $0.text == key })
                }

                let menuIdx = nextMenuIndex()
                let keywordIdx = nextKeywordIndex()

                let spawnMenu: Bool = {
                    switch (menuIdx, keywordIdx) {
                    case (.some, .some):
                        return !lastSpawnWasMenuItem
                    case (.some, .none):
                        return true
                    case (.none, .some):
                        return false
                    case (.none, .none):
                        return false
                    }
                }()

                if spawnMenu, let i = menuIdx {
                    let safeX = getSafeSpawnX(in: size.width)
                    blobs[i].spawn(x: safeX, y: size.height + Constants.spawnStartYOffset)
                    menuQueueIndex = (menuQueueIndex + 1) % max(1, menuCount)
                    lastSpawnWasMenuItem = true
                    lastSpawn = now
                    nextSpawnDelay = .random(in: Constants.menuSpawnDelay)
                } else if let i = keywordIdx {
                    let safeX = getSafeSpawnX(in: size.width)
                    blobs[i].spawn(x: safeX, y: size.height + Constants.spawnStartYOffset)
                    keywordQueueIndex = (keywordQueueIndex + 1) % max(1, keywordCount)
                    lastSpawnWasMenuItem = false
                    lastSpawn = now
                    nextSpawnDelay = .random(in: Constants.menuSpawnDelay)
                }
            }

            if Constants.maxActiveDummies > 0, now.timeIntervalSince(lastDummySpawn) > nextDummySpawnDelay {
                let activeDummyCount = blobs.filter { $0.isDummy && $0.status != .idle }.count
                if activeDummyCount < Constants.maxActiveDummies,
                   let i = blobs.firstIndex(where: { $0.isDummy && $0.status == .idle }) {
                    blobs[i].spawn(x: .random(in: 40...size.width-40), y: size.height + 360)
                    lastDummySpawn = now
                    nextDummySpawnDelay = .random(in: Constants.dummySpawnDelay)
                } else {
                    lastDummySpawn = now
                    nextDummySpawnDelay = .random(in: Constants.dummySpawnBackoffDelay)
                }
            }
        }

        adjustTraffic()

        for i in blobs.indices where blobs[i].status != .idle {
            switch blobs[i].status {
            case .rising:
                if blobs[i].status != .chatBubble && blobs[i].status != .spawningToChat && blobs[i].status != .dismissing {
                    let yN = (size.height > 0) ? (blobs[i].position.y / size.height) : 0
                    if yN >= Constants.heaterBandStart {
                        blobs[i].temperature += (1.0 - blobs[i].temperature) * Constants.heatUpRate * dt
                    } else if yN <= 0.25 {
                        blobs[i].temperature += (0.0 - blobs[i].temperature) * Constants.coolDownRate * dt
                    } else {
                        blobs[i].temperature += (0.0 - blobs[i].temperature) * (Constants.coolDownRate * 0.08) * dt
                    }
                    blobs[i].temperature = min(1, max(0, blobs[i].temperature))
                }

                let invDt = CGFloat(1.0 / max(dt, 1.0 / 240.0))
                let baseVy = -blobs[i].currentSpeed * invDt
                let buoyancy = Constants.buoyancyMin + (Constants.buoyancyMax - Constants.buoyancyMin) * blobs[i].temperature
                let targetVy = baseVy * buoyancy * Constants.riseBoost

                let currentVx = CGFloat(sin(Double(wobbleTime * 0.35 + blobs[i].wobbleSeed))) * Constants.lateralCurrentPxPerSec

                let follow = Constants.fluidFollow
                blobs[i].simVelocity.dx += (currentVx - blobs[i].simVelocity.dx) * follow
                blobs[i].simVelocity.dy += (targetVy - blobs[i].simVelocity.dy) * follow

                blobs[i].simVelocity.dx *= Constants.fluidDrag
                blobs[i].simVelocity.dy *= Constants.fluidDrag

                blobs[i].position.x += blobs[i].simVelocity.dx * CGFloat(dt)
                blobs[i].position.y += blobs[i].simVelocity.dy * CGFloat(dt)

                if blobs[i].position.y < -Constants.topExitPadding {
                    if blobs[i].isDummy {
                        blobs[i].status = .idle
                    } else {
                        blobs[i].status = .sinking
                        blobs[i].temperature = 0
                        blobs[i].simVelocity = .zero
                        blobs[i].position.y = -Constants.topExitPadding
                    }
                }
            case .fleeing:
                blobs[i].position.x += blobs[i].fleeDirection * blobs[i].currentSpeed
                blobs[i].currentSpeed *= 1.15
                if blobs[i].position.x < -250 || blobs[i].position.x > size.width + 250 {
                    blobs[i].status = .fled
                }
            case .returning:
                let target = blobs[i].originalPositionBeforeFlee
                let dx = target.x - blobs[i].position.x
                let dy = target.y - blobs[i].position.y
                let dist = sqrt(dx*dx + dy*dy)

                if dist < blobs[i].currentSpeed {
                    blobs[i].position = target
                    blobs[i].status = .rising
                    blobs[i].currentSpeed = blobs[i].baseSpeed
                } else {
                    blobs[i].position.x += (dx / dist) * blobs[i].currentSpeed
                    blobs[i].position.y += (dy / dist) * blobs[i].currentSpeed
                }
            case .fled:
                break
            case .debris:
                blobs[i].position.x += blobs[i].debrisVelocity.x
                blobs[i].position.y += blobs[i].debrisVelocity.y

                blobs[i].debrisVelocity.x *= 0.96
                blobs[i].debrisVelocity.y -= 0.02

                if blobs[i].position.y < -100 {
                    blobs[i].status = .idle
                }
            case .waiting:
                if now.timeIntervalSince(blobs[i].waitStart) > blobs[i].waitTime { blobs[i].status = .sinking }
            case .sinking:
                let targetVy = CGFloat(90)
                let currentVx = CGFloat(sin(Double(wobbleTime * 0.25 + blobs[i].wobbleSeed))) * (Constants.lateralCurrentPxPerSec * 0.6)
                let follow = Constants.fluidFollow
                blobs[i].simVelocity.dx += (currentVx - blobs[i].simVelocity.dx) * follow
                blobs[i].simVelocity.dy += (targetVy - blobs[i].simVelocity.dy) * (follow * 0.8)
                blobs[i].simVelocity.dx *= Constants.fluidDrag
                blobs[i].simVelocity.dy *= Constants.fluidDrag
                blobs[i].position.x += blobs[i].simVelocity.dx * CGFloat(dt)
                blobs[i].position.y += blobs[i].simVelocity.dy * CGFloat(dt)

                if blobs[i].position.y > size.height + Constants.bottomRecyclePadding {
                    blobs[i].status = .idle
                }
            default: break
            }
        }

        let dtV = max(Constants.timerHz, 1.0 / 120.0)
        let invDt = CGFloat(1.0 / dtV)
        for i in blobs.indices {
            if blobs[i].status == .chatBubble && blobs[i].isAnchored {
                blobs[i].velocity = .zero
                continue
            }

            let dx = blobs[i].position.x - blobs[i].previousPosition.x
            let dy = blobs[i].position.y - blobs[i].previousPosition.y
            blobs[i].velocity = CGVector(dx: dx * invDt, dy: dy * invDt)
        }

        let padding: CGFloat = 80
        let anyDebris = blobs.contains(where: { b in
            guard b.status == .debris else { return false }
            return b.position.y > -padding && b.position.y < size.height + padding
        })

        return (typingOut: typingOut, anyDebris: anyDebris)
    }

    private func handleChatOverlayDismissal() {
        for i in blobs.indices {
            if blobs[i].status == .chatBubble || blobs[i].status == .spawningToChat || blobs[i].status == .dismissing {
                blobs[i].messageID = nil
                blobs[i].text = ""
                blobs[i].isAnchored = false
                blobs[i].targetPosition = nil

                blobs[i].isDummy = false
                blobs[i].status = .dismissing
                blobs[i].currentSpeed = max(blobs[i].baseSpeed, Constants.dismissSpeed)
            }
        }
    }

    private func stepChatBlobs() {
        for i in blobs.indices {
            if blobs[i].status == .spawningToChat {
                if let target = blobs[i].targetPosition {
                    let dx = target.x - blobs[i].position.x
                    let dy = target.y - blobs[i].position.y
                    let dist = sqrt(dx * dx + dy * dy)

                    let speed = Constants.spawnToChatSpeed
                    if dist < speed {
                        blobs[i].position = target
                        blobs[i].status = .chatBubble
                        blobs[i].isAnchored = true
                    } else {
                        blobs[i].position.x += (dx / dist) * speed
                        blobs[i].position.y += (dy / dist) * speed
                    }
                }
            } else if blobs[i].status == .chatBubble && blobs[i].isAnchored {
                if let target = blobs[i].targetPosition {
                    blobs[i].position = target
                }
            } else if blobs[i].status == .dismissing {
                if blobs[i].messageID == Constants.typingMessageID {
                    blobs[i].position.x -= max(blobs[i].currentSpeed, 16)
                    if blobs[i].position.x < -Constants.typingExitPadding {
                        blobs[i].status = .idle
                        blobs[i].messageID = nil
                        blobs[i].chatRole = nil
                        blobs[i].isDummy = true
                        blobs[i].text = ""
                        blobs[i].isAnchored = false
                        blobs[i].targetPosition = nil
                        blobs[i].bubbleWidth = 0
                        blobs[i].bubbleHeight = 0
                    }
                } else {
                    blobs[i].position.y -= blobs[i].currentSpeed
                    if blobs[i].position.y < Constants.resetOffscreenY {
                        blobs[i].status = .idle
                        blobs[i].messageID = nil
                        blobs[i].chatRole = nil
                        blobs[i].isDummy = true
                        blobs[i].text = ""
                        blobs[i].isAnchored = false
                        blobs[i].targetPosition = nil
                        blobs[i].bubbleWidth = 0
                        blobs[i].bubbleHeight = 0
                    }
                }
                if blobs[i].status == .idle {
                    blobs[i].status = .idle
                    blobs[i].messageID = nil
                    blobs[i].chatRole = nil
                    blobs[i].isDummy = true
                    blobs[i].text = ""
                    blobs[i].isAnchored = false
                    blobs[i].targetPosition = nil
                    blobs[i].bubbleWidth = 0
                    blobs[i].bubbleHeight = 0
                }
            }
        }
    }

}
