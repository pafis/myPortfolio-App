//
//  LavaMenuContainer.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 1/3/26.
//
import SwiftUI

struct LavaMenuContainer: View {
    let menuItems = ["Home", "About", "Work", "Labs", "Store", "Contact"]
    @State private var blobs: [MenuBlobState] = []
    var isChatFocused: Bool = false
    
    // Chat integration
    @ObservedObject var chatService: ChatService
    var showChatOverlay: Bool = false

    @State private var wasFocused: Bool = false

    @State private var timer = Timer.publish(every: Constants.timerHz, on: .main, in: .common).autoconnect()
    
    @State private var lastSpawn: Date = .now
    @State private var nextSpawnDelay: TimeInterval = 1.0
    @State private var queueIndex = 0

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
        static let menuSpawnDelay: ClosedRange<TimeInterval> = 4.0...7.0

        static let maxActiveDummies: Int = 4
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
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                MetalLavaView(blobs: blobs, containerSize: geo.size)
                    .ignoresSafeArea(.all)
              
                ForEach(blobs.indices, id: \.self) { i in
                    let b = blobs[i]
                    if (b.status == .rising || b.status == .fleeing || b.status == .returning) && !b.isDummy {
                        Text(b.text)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .position(b.position)
                    }
                }
                
                // Chat overlay with shared blobs
                if showChatOverlay {
                    ChatScrollOverlay(
                        chatService: chatService,
                        blobs: $blobs,
                        containerSize: geo.size
                    )
                }
            }
            .coordinateSpace(name: "lava")
            .onAppear { initialize(geo.size) }
            .onReceive(timer) { _ in update(geo.size) }
        }
        .ignoresSafeArea(.all)
    }

    private func initialize(_ size: CGSize) {
        blobs = menuItems.map { MenuBlobState(text: $0, isDummy: false) }
        for _ in 0..<30 { blobs.append(MenuBlobState(text: "", isDummy: true)) }

        lastDummySpawn = .now
        nextDummySpawnDelay = Constants.dummyInitialDelay
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

    private func handleChatOverlayDismissal() {
        guard !showChatOverlay else { return }
        for i in blobs.indices {
            if blobs[i].status == .chatBubble || blobs[i].status == .spawningToChat {
                blobs[i].status = .dismissing
                blobs[i].isAnchored = false
                blobs[i].currentSpeed = Constants.dismissSpeed
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
                blobs[i].position.y -= blobs[i].currentSpeed
                if blobs[i].position.y < Constants.resetOffscreenY {
                    blobs[i].status = .idle
                    blobs[i].messageID = nil
                    blobs[i].chatRole = nil
                    blobs[i].isDummy = true
                    blobs[i].text = ""
                    blobs[i].isAnchored = false
                    blobs[i].targetPosition = nil
                }
            }
        }
    }

    private func update(_ size: CGSize) {
        let now = Date()

        handleChatOverlayDismissal()
        stepChatBlobs()
        
        // If focus just started, tell all active blobs to flee sideways
        if isChatFocused {
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
                if let i = blobs.firstIndex(where: { !$0.isDummy && $0.status == .idle && $0.text == menuItems[queueIndex] }) {
                    let safeX = getSafeSpawnX(in: size.width)

                    blobs[i].spawn(x: safeX, y: size.height + 360)
                    queueIndex = (queueIndex + 1) % menuItems.count
                    lastSpawn = now
                    nextSpawnDelay = .random(in: 4.0...7.0)
                }
            }

            if now.timeIntervalSince(lastDummySpawn) > nextDummySpawnDelay {
                let activeDummyCount = blobs.filter { $0.isDummy && $0.status != .idle }.count
                if activeDummyCount < 4, let i = blobs.firstIndex(where: { $0.isDummy && $0.status == .idle }) {
                    blobs[i].spawn(x: .random(in: 40...size.width-40), y: size.height + 360)
                    lastDummySpawn = now
                    nextDummySpawnDelay = .random(in: 1.0...2.0)
                } else {
                    lastDummySpawn = now
                    nextDummySpawnDelay = .random(in: 1.5...3.0)
                }
            }
        }
        
        adjustTraffic()

        for i in blobs.indices where blobs[i].status != .idle {
            switch blobs[i].status {
            case .rising:
                blobs[i].position.y -= blobs[i].currentSpeed
                if blobs[i].position.y < 0 { if blobs[i].isDummy { blobs[i].status = .waiting} else { blobs[i].status = .idle}  }
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
                blobs[i].position.y += (blobs[i].baseSpeed * 0.7)
                if blobs[i].position.y > size.height + 100 { blobs[i].status = .idle }
            default: break
            }
        }
    }
}

struct LavaMenuContainer_Previews: PreviewProvider {
    static var previews: some View {
        LavaMenuContainer(chatService: ChatService())
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
