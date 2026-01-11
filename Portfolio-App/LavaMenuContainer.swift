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
    var onSelectMenuItem: ((PortfolioMenuItem) -> Void)?
    var onSelectKeyword: ((ChatService.MenuKeyword) -> Void)?
    @StateObject private var engine = LavaPhysicsEngine()
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

    // Shared timer driving physics updates.
    @State private var timer = Timer.publish(every: Constants.timerHz, on: .main, in: .common).autoconnect()

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
                    blobs: engine.blobs,
                    containerSize: geo.size,
                    time: engine.wobbleTime,
                    showReservoir: true,
                    detailRect: isDetailOpen ? detailRect : nil
                )
                    .ignoresSafeArea(.all)

                ForEach(engine.blobs) { b in
                    if (b.status == .rising || b.status == .fleeing || b.status == .returning) && !b.isDummy {
                        let wobble = wobbleOffset(seed: b.wobbleSeed, time: engine.wobbleTime, containerHeight: geo.size.height)
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
                        blobs: Binding(get: { engine.blobs }, set: { engine.blobs = $0 }),
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
                                    engine.handleTap(at: value.location, size: geo.size, onSelectMenuItem: onSelectMenuItem, onSelectKeyword: onSelectKeyword)
                                }
                        )
                }
            }
            .coordinateSpace(name: "lava")
            .onAppear {
                engine.configure(menuItems: menuItems, keywordItems: keywordItems, chatService: chatService)
                engine.initialize(geo.size)
            }
            .onReceive(timer) { _ in
                let res = engine.update(geo.size, isChatFocused: isChatFocused, isDetailOpen: isDetailOpen, showChatOverlay: showChatOverlay)
                typingOutInView = res.typingOut
                debrisInView = res.anyDebris
            }
            // Handle selection events published by the physics engine.
            .onReceive(engine.selectionSubject) { selection in
                switch selection {
                case .menuItem(let item):
                    onSelectMenuItem?(item)
                case .keyword(let kw):
                    onSelectKeyword?(kw)
                }
            }
            .onChange(of: keywordItems) {
                // Use zero-parameter closure to comply with iOS 17 onChange signature.
                syncKeywordBlobs(with: keywordItems)
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
        engine.configure(menuItems: menuItems, keywordItems: keywordItems, chatService: chatService)
        engine.initialize(size)
    }

    private func syncKeywordBlobs(with keywords: [ChatService.MenuKeyword]) {
        engine.syncKeywordBlobs(with: keywords)
    }

    private func isValidKeywordText(_ raw: String) -> Bool {
        KeywordValidation.normalizeTwoWordKeyword(raw) != nil
    }

    private func handleTap(at location: CGPoint) {
        engine.handleTap(at: location, size: .zero, onSelectMenuItem: onSelectMenuItem, onSelectKeyword: onSelectKeyword)
    }

    private func getSafeSpawnX(in width: CGFloat) -> CGFloat {
        return CGFloat.random(in: Constants.safeSpawnMargin...(width - Constants.safeSpawnMargin))
    }

    private func adjustTraffic() {
        // Delegated to `LavaPhysicsEngine`.
    }

    private func handleChatOverlayDismissal(_ size: CGSize) {
        // Delegated to `LavaPhysicsEngine` (handled in its update step).
    }

    private func stepChatBlobs() {
        // Delegated to `LavaPhysicsEngine`.
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
