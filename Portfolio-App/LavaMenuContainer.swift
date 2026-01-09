//
//  LavaMenuContainer.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 1/3/26.
//
import SwiftUI

struct LavaMenuContainer: View {
    let menuItems: [PortfolioMenuItem]
    var keywordItems: [ChatService.MenuKeyword] = []
    var onSelectMenuItem: ((PortfolioMenuItem) -> Void)? = nil
    var onSelectKeyword: ((ChatService.MenuKeyword) -> Void)? = nil
    @State private var blobs: [MenuBlobState] = []
    var isChatFocused: Bool = false
    @Binding var debrisInView: Bool
    @Binding var typingOutInView: Bool
    var isDetailOpen: Bool = false
    var detailDragOffsetY: CGFloat = 0
    
    // Chat integration
    @ObservedObject var chatService: ChatService
    var showChatOverlay: Bool = false
    var showTypingIndicator: Bool = false

    @State private var wasFocused: Bool = false

    // Shared wobble time base so blob rendering and label rendering stay in sync.
    @State private var wobbleStart: Date = .now
    @State private var wobbleTime: Float = 0

    @State private var timer = Timer.publish(every: Constants.timerHz, on: .main, in: .common).autoconnect()
    
    @State private var lastSpawn: Date = .now
    @State private var nextSpawnDelay: TimeInterval = 1.0
    @State private var menuQueueIndex = 0
    @State private var keywordQueueIndex = 0
    @State private var lastSpawnWasMenuItem: Bool = false

    @State private var lastDummySpawn: Date = .now
    @State private var nextDummySpawnDelay: TimeInterval = 1.0

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

        // Keep only a tiny amount of background dummy blobs.
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

        // Fluid dynamics (menu/keyword/dummy blobs only)
        // - `fluidFollow` controls how quickly blobs respond to target speed (lower = more resistance).
        // - `fluidDrag` damps velocity each frame (closer to 1 = less damping).
        static let fluidFollow: CGFloat = 0.10
        static let fluidDrag: CGFloat = 0.985
        static let lateralCurrentPxPerSec: CGFloat = 14

        // "Lava lamp" heat model (y increases downward)
        static let heaterBandStart: CGFloat = 0.70 // bottom portion that's "hot"
        static let heatUpRate: CGFloat = 1.6       // per second
        static let coolDownRate: CGFloat = 0.35    // per second

        // Buoyancy model
        static let buoyancyMin: CGFloat = 0.15     // baseline lift even when cooler
        static let buoyancyMax: CGFloat = 1.0      // max lift when fully hot

        // Overall rise rate multiplier.
        static let riseBoost: CGFloat = 1.55

        // Recycling thresholds
        static let topExitPadding: CGFloat = 180
        static let bottomRecyclePadding: CGFloat = 140

        // Typing indicator message ID (stable)
        static let typingMessageID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        static let typingExitPadding: CGFloat = 160
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Drive a rectangular "detail blob" in the Metal background that matches the modal.
                // Keep the reservoir visible even while detail is open.
                let modalWidth = max(0, geo.size.width - 20)
                let modalHeight = max(0, geo.size.height * 0.92)
                let modalDownShift = geo.size.height * 0.10
                let modalCenter = CGPoint(
                    x: geo.size.width * 0.5,
                    y: (geo.size.height * 0.5) + modalDownShift + detailDragOffsetY
                )
                let detailRect = CGRect(
                    x: modalCenter.x - (modalWidth * 0.5),
                    y: modalCenter.y - (modalHeight * 0.5),
                    width: modalWidth,
                    height: modalHeight
                )

                MetalLavaView(
                    blobs: blobs,
                    containerSize: geo.size,
                    time: wobbleTime,
                    showReservoir: true,
                    detailRect: isDetailOpen ? detailRect : nil
                )
                    .ignoresSafeArea(.all)
              
                ForEach(blobs.indices, id: \.self) { i in
                    let b = blobs[i]
                    if (b.status == .rising || b.status == .fleeing || b.status == .returning) && !b.isDummy {
                        let wobble = wobbleOffset(seed: b.wobbleSeed, time: wobbleTime, containerHeight: geo.size.height)
                        Text(b.text)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .position(x: b.position.x + wobble.width, y: b.position.y + wobble.height)
                    }
                }
                
                // Chat overlay with shared blobs
                if showChatOverlay {
                    ChatScrollOverlay(
                        chatService: chatService,
                        blobs: $blobs,
                        containerSize: geo.size,
                        showTypingIndicator: showTypingIndicator
                    )
                }

                if !showChatOverlay {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    handleTap(at: value.location)
                                }
                        )
                }
            }
            .coordinateSpace(name: "lava")
            .onAppear {
                wobbleStart = .now
                wobbleTime = 0
                initialize(geo.size)
            }
            .onReceive(timer) { _ in update(geo.size) }
            .onChange(of: keywordItems) { newValue in
                syncKeywordBlobs(with: newValue)
            }
        }
        .ignoresSafeArea(.all)
    }

    private func wobbleOffset(seed: Float, time: Float, containerHeight: CGFloat) -> CGSize {
        // Matches the wobble applied when packing BlobData in MetalLavaView.
        let ampPx = CGFloat(0.008) * containerHeight
        let dx = CGFloat(sin(Double(time * 1.2 + seed))) * ampPx
        let dy = CGFloat(cos(Double(time * 0.9 + seed))) * ampPx
        return CGSize(width: dx, height: dy)
    }

    private func initialize(_ size: CGSize) {
        blobs = menuItems.map {
            var b = MenuBlobState(text: $0.name, isDummy: false)
            b.menuItemID = $0.id
            return b
        }

        let initialKeywords = keywordItems.filter { isValidKeywordText($0.keyword) }
        for k in initialKeywords {
            blobs.append(MenuBlobState(text: k.keyword, isDummy: false))
        }

        for _ in 0..<30 { blobs.append(MenuBlobState(text: "", isDummy: true)) }

        lastDummySpawn = .now
        nextDummySpawnDelay = Constants.dummyInitialDelay
    }

    private func syncKeywordBlobs(with keywords: [ChatService.MenuKeyword]) {
        // Avoid reshaping blob pools while chat is active/focused.
        guard !showChatOverlay else { return }
        guard !isChatFocused else { return }

        let desired = keywords.map { $0.keyword }.filter { isValidKeywordText($0) }
        guard !desired.isEmpty else { return }

        // Remove idle keyword blobs that are no longer desired.
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

        // Add missing keyword blobs by reusing idle dummies first.
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

    private func isValidKeywordText(_ raw: String) -> Bool {
        KeywordValidation.normalizeTwoWordKeyword(raw) != nil
    }

    private func handleTap(at location: CGPoint) {
        guard !showChatOverlay else { return }
        guard !isChatFocused else { return }

        var bestIndex: Int? = nil
        var bestDistance: CGFloat = .greatestFiniteMagnitude

        for i in blobs.indices {
            let b = blobs[i]
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

        if let id = blobs[idx].menuItemID,
           let item = menuItems.first(where: { $0.id == id }) {
            onSelectMenuItem?(item)
        } else {
            if let kw = keywordItems.first(where: { $0.keyword == blobs[idx].text }) {
                onSelectKeyword?(kw)
            } else {
                // Fallback: synthesize a MenuKeyword if none exists in the current list
                let synthesized = ChatService.MenuKeyword(keyword: blobs[idx].text, question: "What can you tell me about \(blobs[idx].text) in Pascal Fischer's portfolio?")
                onSelectKeyword?(synthesized)
            }
        }
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

    private func handleChatOverlayDismissal(_ size: CGSize) {
        guard !showChatOverlay else { return }
        for i in blobs.indices {
            if blobs[i].status == .chatBubble || blobs[i].status == .spawningToChat || blobs[i].status == .dismissing {
                // Chat overlay dismissed: detach chat metadata and let blobs rise out like menu items.
                // This is independent of message clearing timing, so blobs don't disappear via `.dismissing`.
                blobs[i].messageID = nil
                blobs[i].text = ""
                blobs[i].isAnchored = false
                blobs[i].targetPosition = nil

                // Keep the chat bubble's shape/size while it floats up.
                // (`LavaRenderer` draws `.dismissing` as a chat-rect using `bubbleWidth/Height`.)
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

    private func update(_ size: CGSize) {
        let now = Date()
        wobbleTime = Float(now.timeIntervalSince(wobbleStart))

        let dt = Constants.timerHz

        // Capture previous positions for velocity computation.
        for i in blobs.indices {
            blobs[i].previousPosition = blobs[i].position
        }

        handleChatOverlayDismissal(size)
        stepChatBlobs()

        // Expose whether the typing indicator blob is currently animating out.
        let typingOut = blobs.contains(where: { $0.messageID == Constants.typingMessageID && $0.status == .dismissing })
        if typingOut != typingOutInView {
            typingOutInView = typingOut
        }
        
        // If focus just started or detail view opened, tell all active blobs to flee sideways
        let shouldFlee = isChatFocused || isDetailOpen
        if shouldFlee {
            if !wasFocused {
                wasFocused = true
                for idx in blobs.indices {
                    guard blobs[idx].status != .idle && blobs[idx].status != .fled && blobs[idx].status != .debris else { continue }
                    // Don't flee chat blobs
                    guard blobs[idx].status != .chatBubble && blobs[idx].status != .spawningToChat else { continue }
                    
                    let oldPos = blobs[idx].position
                    let oldRadius = blobs[idx].baseRadius
                    
                    blobs[idx].originalPositionBeforeFlee = oldPos
                    blobs[idx].status = .fleeing
                    // flee left if on left half, otherwise flee right
                    blobs[idx].fleeDirection = blobs[idx].position.x < (size.width * 0.5) ? -1 : 1
                    blobs[idx].currentSpeed = 35.0 // Fast but visible
                    
                    // Spawn debris to look like the blob was torn apart
                    var debrisCount = 0
                    for dIdx in blobs.indices where blobs[dIdx].isDummy && blobs[dIdx].status == .idle && debrisCount < 3 {
                        blobs[dIdx].position = oldPos
                        blobs[dIdx].baseRadius = oldRadius * .random(in: 0.3...0.6)
                        blobs[dIdx].status = .debris
                        // Drift slightly in the opposite direction of the flee
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
            
            // When field is not focused, allow spawning new blobs
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
                        // Mix sources deterministically.
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
                // --- Revised "lava lamp" physics ---
                // 1) Thermal expansion: heat rises from the bottom heater band.
                // 2) Buoyancy (Archimedes): hotter => less dense => more upward lift.
                // 3) Cooling near top reduces buoyancy, transitioning to waiting/sinking.

                // Update temperature for non-chat blobs only.
                if blobs[i].status != .chatBubble && blobs[i].status != .spawningToChat && blobs[i].status != .dismissing {
                    let yN = (size.height > 0) ? (blobs[i].position.y / size.height) : 0
                    if yN >= Constants.heaterBandStart {
                        // Heat up near the bottom.
                        blobs[i].temperature += (1.0 - blobs[i].temperature) * Constants.heatUpRate * dt
                    } else if yN <= 0.25 {
                        // Only start cooling when the blob is near the top.
                        // This keeps blobs buoyant through most of the ascent.
                        blobs[i].temperature += (0.0 - blobs[i].temperature) * Constants.coolDownRate * dt
                    } else {
                        // Mid-column: keep heat almost constant (very slow cooling).
                        blobs[i].temperature += (0.0 - blobs[i].temperature) * (Constants.coolDownRate * 0.08) * dt
                    }
                    blobs[i].temperature = min(1, max(0, blobs[i].temperature))
                }

                // Convert currentSpeed (points/tick) to a baseline target points/second.
                let invDt = CGFloat(1.0 / max(dt, 1.0 / 240.0))
                let baseVy = -blobs[i].currentSpeed * invDt
                let buoyancy = Constants.buoyancyMin + (Constants.buoyancyMax - Constants.buoyancyMin) * blobs[i].temperature
                let targetVy = baseVy * buoyancy * Constants.riseBoost

                // Gentle horizontal current (adds organic drift).
                let currentVx = CGFloat(sin(Double(wobbleTime * 0.35 + blobs[i].wobbleSeed))) * Constants.lateralCurrentPxPerSec

                let follow = Constants.fluidFollow
                blobs[i].simVelocity.dx += (currentVx - blobs[i].simVelocity.dx) * follow
                blobs[i].simVelocity.dy += (targetVy - blobs[i].simVelocity.dy) * follow

                // Viscous drag.
                blobs[i].simVelocity.dx *= Constants.fluidDrag
                blobs[i].simVelocity.dy *= Constants.fluidDrag

                blobs[i].position.x += blobs[i].simVelocity.dx * CGFloat(dt)
                blobs[i].position.y += blobs[i].simVelocity.dy * CGFloat(dt)

                // Let blobs fully exit beyond the top before recycling.
                // This avoids the "teleport to bottom" effect from setting `.idle` at y<0.
                if blobs[i].position.y < -Constants.topExitPadding {
                    if blobs[i].isDummy {
                        // True dummies just disappear.
                        blobs[i].status = .idle
                    } else {
                        // Menu/keyword blobs become a cooled blob and sink back down offscreen.
                        blobs[i].status = .sinking
                        blobs[i].temperature = 0
                        blobs[i].simVelocity = .zero
                        blobs[i].position.y = -Constants.topExitPadding
                    }
                }
            case .fleeing:
                // Move horizontally off-screen with acceleration
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
                
                // Slowly transition back to rising behavior
                blobs[i].debrisVelocity.x *= 0.96
                blobs[i].debrisVelocity.y -= 0.02 
                
                if blobs[i].position.y < -100 {
                    blobs[i].status = .idle
                }
            case .waiting:
                if now.timeIntervalSince(blobs[i].waitStart) > blobs[i].waitTime { blobs[i].status = .sinking }
            case .sinking:
                // Cooled wax is denser -> sinks with resistance.
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

        // Derive per-blob velocity (points/second) for rendering deformation.
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

        // Signal whether any debris blobs are still visible within (or near) the viewport.
        // Update only when it changes to avoid extra view invalidations.
        let padding: CGFloat = 80
        let anyDebris = blobs.contains(where: { b in
            guard b.status == .debris else { return false }
            return b.position.y > -padding && b.position.y < size.height + padding
        })
        if anyDebris != debrisInView {
            debrisInView = anyDebris
        }
    }
}

struct LavaMenuContainer_Previews: PreviewProvider {
    static var previews: some View {
        PreviewHost()
    }

    private struct PreviewHost: View {
        @State private var debrisInView: Bool = false
        @State private var typingOutInView: Bool = false

        var body: some View {
            LavaMenuContainer(
                menuItems: [],
                debrisInView: $debrisInView,
                typingOutInView: $typingOutInView,
                chatService: ChatService()
            )
                .previewLayout(.sizeThatFits)
                .padding()
        }
    }
}
