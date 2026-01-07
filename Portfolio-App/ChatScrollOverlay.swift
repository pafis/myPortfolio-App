import SwiftUI
import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

// PreferenceKey to collect frames for messages
struct MessageFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// PreferenceKey to observe the ScrollView's visible height
private struct ScrollViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// PreferenceKey to observe where the bottom sentinel sits inside the ScrollView
private struct ScrollBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// PreferenceKey to collect intrinsic (single-line) sizes for messages
struct MessageTextSizeKey: PreferenceKey {
    static var defaultValue: [UUID: CGSize] = [:]
    static func reduce(value: inout [UUID: CGSize], nextValue: () -> [UUID: CGSize]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct ChatScrollOverlay: View {
    @ObservedObject var chatService: ChatService
    @Binding var blobs: [MenuBlobState]
    var containerSize: CGSize

    @State private var messageTextSizes: [UUID: CGSize] = [:]
    @State private var keyboardHeight: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var bottomSentinelMaxY: CGFloat = 0
    @State private var isAtBottom: Bool = true

    private let bottomTolerance: CGFloat = 28
    private let bottomAnchorID: String = "chatBottom"

#if canImport(UIKit)
    private var keyboardHeightPublisher: AnyPublisher<CGFloat, Never> {
        let willChange = NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .compactMap { notification -> CGFloat? in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return nil }
                // Translate the keyboard frame into a height relative to the screen bottom.
                let overlap = UIScreen.main.bounds.height - frame.origin.y
                return max(0, overlap)
            }

        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }

        return willChange.merge(with: willHide).eraseToAnyPublisher()
    }
#endif

    private func richText(for content: String) -> AttributedString {
        if #available(iOS 15.0, macOS 12.0, visionOS 1.0, *) {
            do {
                return try AttributedString(
                    markdown: content,
                    options: AttributedString.MarkdownParsingOptions(
                        interpretedSyntax: .full,
                        failurePolicy: .returnPartiallyParsedIfPossible
                    )
                )
            } catch {
                return AttributedString(content)
            }
        }

        return AttributedString(content)
    }

    private func updateBottomState(scrollHeight: CGFloat, bottomMaxY: CGFloat) {
        let atBottom = bottomMaxY <= scrollHeight + bottomTolerance
        if atBottom != isAtBottom {
            withAnimation(.easeOut(duration: 0.2)) {
                isAtBottom = atBottom
            }
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                let bubblePadding: CGFloat = 20
                let messageSpacing: CGFloat = 40
                let bottomInset: CGFloat = max(160, containerSize.height * 0.20)
                let maxBubbleWidth = containerSize.width * 0.78
                let keyboardInset = keyboardHeight
                let topInset: CGFloat = max(40, geo.safeAreaInsets.top + 20)

                // Avoid repeated linear scans in the hot SwiftUI layout path.
                let messageRoleByID: [UUID: ChatRole] = Dictionary(
                    uniqueKeysWithValues: chatService.messages.map { ($0.id, $0.role) }
                )
                let blobIndexByMessageID: [UUID: Int] = Dictionary(
                    uniqueKeysWithValues: blobs.enumerated().compactMap { idx, blob in
                        blob.messageID.map { ($0, idx) }
                    }
                )

                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        // Track the visible ScrollView height
                        GeometryReader { proxyHeight in
                            Color.clear.preference(key: ScrollViewHeightKey.self, value: proxyHeight.size.height)
                        }
                        .frame(height: 0)

                        VStack(spacing: messageSpacing) {
                            ForEach(chatService.messages) { msg in
                                let blob: MenuBlobState? = blobIndexByMessageID[msg.id].map { blobs[$0] }
                                let attributed = richText(for: msg.content)
                                let isReady: Bool = {
                                    guard let blob else { return false }
                                    switch blob.status {
                                    case .spawningToChat, .chatBubble, .dismissing:
                                        return true
                                    default:
                                        return false
                                    }
                                }()

                                let measuredWidth = messageTextSizes[msg.id]?.width ?? maxBubbleWidth
                                let bubbleWidth = min(maxBubbleWidth, max(60, measuredWidth))
                                
                                let yOffset: CGFloat = {
                                    if let b = blob, let target = b.targetPosition {
                                        return b.position.y - target.y
                                    }
                                    return 2000 // Start at reservoir position
                                }()
                                let xOffset: CGFloat = {
                                    if let b = blob, let target = b.targetPosition {
                                        return b.position.x - target.x
                                    }
                                    return 0
                                }()

                                HStack {
                                    if msg.role == .user {
                                        Spacer()
                                    } else {
                                        Spacer().frame(width: 16)
                                    }

                                    ZStack(alignment: .topLeading) {

                                        Color.clear
                                            .frame(width: 0, height: 0)
                                            .overlay(alignment: .topLeading) {
                                                Text(attributed)
                                                    .padding(bubblePadding)
                                                    .fixedSize(horizontal: true, vertical: true)
                                                    .opacity(0)
                                                    .background(
                                                        GeometryReader { proxyMsg in
                                                            Color.clear.preference(
                                                                key: MessageTextSizeKey.self,
                                                                value: [msg.id: proxyMsg.size]
                                                            )
                                                        }
                                                    )
                                            }
                                        Text(attributed)
                                            .padding(bubblePadding)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(width: bubbleWidth,
                                                   alignment: msg.role == .user ? .trailing : .leading)

                                            .opacity(0)
                                            .background(
                                                GeometryReader { proxyMsg in
                                                    Color.clear.preference(key: MessageFrameKey.self, value: [msg.id: proxyMsg.frame(in: .named("lava"))])
                                                }
                                            )

                                        // Visible text that follows the blob
                                        Text(attributed)
                                            .padding(bubblePadding)
                                            .foregroundColor(.white)
                                            .frame(width: bubbleWidth, alignment: msg.role == .user ? .trailing : .leading)
                                            .offset(x: xOffset, y: yOffset)
                                            .opacity(isReady ? 1 : 0)
                                    }
                                    .id(msg.id)

                                    if msg.role == .user {
                                        Spacer().frame(width: 16)
                                    } else {
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal, 12)
                            }
                        }
                        .padding(.top, topInset)
                        .padding(.bottom, bottomInset + keyboardInset)

                        // Sentinel at the bottom to determine if we're scrolled to the end
                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorID)
                            .background(
                                GeometryReader { proxyBottom in
                                    Color.clear.preference(
                                        key: ScrollBottomKey.self,
                                        value: proxyBottom.frame(in: .named("chatScrollView")).maxY
                                    )
                                }
                            )
                    }
                    .coordinateSpace(name: "chatScrollView")
                    .onChange(of: chatService.messages.count) { _ in
                        withAnimation { proxy.scrollTo(bottomAnchorID, anchor: .bottom) }
                    }
#if canImport(UIKit)
                    .onReceive(keyboardHeightPublisher) { height in
                        withAnimation(.easeOut(duration: 0.25)) {
                            keyboardHeight = height
                        }

                        withAnimation { proxy.scrollTo(bottomAnchorID, anchor: .bottom) }
                    }
#endif
                    .onPreferenceChange(MessageFrameKey.self) { frames in
                        // Allocate blobs for each message
                        for (id, frame) in frames {
                            if let idx = blobs.firstIndex(where: { $0.messageID == id }) {

                                blobs[idx].bubbleWidth = frame.width
                                blobs[idx].bubbleHeight = frame.height
                                blobs[idx].targetPosition = CGPoint(x: frame.midX, y: frame.midY)
                                
                                if blobs[idx].isAnchored {
                                    blobs[idx].position = blobs[idx].targetPosition!
                                }
                            } else if let idle = blobs.firstIndex(where: { $0.isDummy && $0.messageID == nil && ($0.status == .idle || $0.status == .debris) }) {
                      
                                guard let role = messageRoleByID[id] else { continue }
                                blobs[idle].status = .idle
                                blobs[idle].assignMessage(id: id, frame: frame, role: role)
                            }
                        }

                        // When the chat is dismissed we clear `chatService.messages`.
                        // Don't reclaim blobs in that moment; `LavaMenuContainer` will detach them and
                        // transition them back to normal rising blobs.
                        guard !chatService.messages.isEmpty else { return }

                        let liveMessageIDs = Set(chatService.messages.map { $0.id })
                        for i in blobs.indices {
                            guard let mid = blobs[i].messageID else { continue }
                            if !liveMessageIDs.contains(mid) {
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
                    .onPreferenceChange(MessageTextSizeKey.self) { sizes in
                        messageTextSizes = sizes
                    }
                    .onPreferenceChange(ScrollViewHeightKey.self) { height in
                        scrollViewHeight = height
                        updateBottomState(scrollHeight: height, bottomMaxY: bottomSentinelMaxY)
                    }
                    .onPreferenceChange(ScrollBottomKey.self) { bottomY in
                        bottomSentinelMaxY = bottomY
                        updateBottomState(scrollHeight: scrollViewHeight, bottomMaxY: bottomY)
                    }

                    if !isAtBottom {
                        Button {
                            withAnimation { proxy.scrollTo(bottomAnchorID, anchor: .bottom) }
                        } label: {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial.opacity(0.8))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, max(12, bottomInset + keyboardInset - 70))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
    }
}
