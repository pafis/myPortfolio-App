import SwiftUI
import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

private final class AttributedStringCache: ObservableObject {
    // Intentionally not @Published: caching should not trigger view updates.
    private var storage: [UUID: (source: String, value: AttributedString)] = [:]

    func value(for id: UUID, source: String, compute: () -> AttributedString) -> AttributedString {
        if let cached = storage[id], cached.source == source {
            return cached.value
        }
        let computed = compute()
        storage[id] = (source: source, value: computed)
        return computed
    }

    func prune(keeping ids: Set<UUID>) {
        storage = storage.filter { ids.contains($0.key) }
    }
}

// PreferenceKey to collect frames for messages
struct MessageFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// PreferenceKey to observe the ScrollView's visible height (viewport)
private struct ScrollViewGlobalMaxYKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct BottomSentinelGlobalMaxYKey: PreferenceKey {
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
    var showTypingIndicator: Bool = false

    @State private var messageTextSizes: [UUID: CGSize] = [:]
    @StateObject private var attributedCache = AttributedStringCache()
    @State private var keyboardHeight: CGFloat = 0
    @State private var scrollViewGlobalMaxY: CGFloat = 0
    @State private var bottomSentinelGlobalMaxY: CGFloat = 0
    @State private var isAtBottom: Bool = true

#if canImport(UIKit)
    @State private var underlyingScrollView: UIScrollView?
#endif

    private let bottomTolerance: CGFloat = 28
    private let bottomAnchorID: String = "chatBottom"

    private static let typingMessageID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var typingMessage: ChatMessage {
        ChatMessage(id: Self.typingMessageID, role: .assistant, content: "...")
    }

    private struct TypingDotsView: View {
        var dotSize: CGFloat = 12
        var spacing: CGFloat = 7
        var jumpHeight: CGFloat = 8
        var jumpsPerSecond: Double = 1.1

        var body: some View {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let omega = 2.0 * Double.pi * jumpsPerSecond
                HStack(spacing: spacing) {
                    ForEach(0..<3, id: \.self) { i in
                        let phase = (2.0 * Double.pi / 3.0) * Double(i)
                        let s = sin(omega * t + phase)
                        // Single hump per cycle: only the positive half-wave “jumps”.
                        let hump = max(0.0, s)
                        let y = -jumpHeight * CGFloat(hump * hump)

                        Circle()
                            .fill(Color.white)
                            .frame(width: dotSize, height: dotSize)
                            .offset(y: y)
                    }
                }
                // Ensure a stable layout box even while dots offset.
                .frame(height: dotSize + jumpHeight)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.async {
#if canImport(UIKit)
            if let scrollView = underlyingScrollView {
                if scrollView.isDecelerating || scrollView.isDragging {
                    // Stop existing momentum so the new animated scroll reliably takes over.
                    scrollView.setContentOffset(scrollView.contentOffset, animated: false)
                }

                let bottomY = scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
                let minY = -scrollView.adjustedContentInset.top
                let targetY = max(minY, bottomY)
                scrollView.setContentOffset(CGPoint(x: 0, y: targetY), animated: animated)
                return
            }
#endif

            if animated {
                withAnimation(.easeOut(duration: 0.35)) {
                    proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        }
    }

    private func dismissKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#elseif canImport(AppKit)
        NSApp.keyWindow?.makeFirstResponder(nil)
#endif
    }

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
        // Fast path: if there's no obvious markdown syntax, avoid markdown parsing entirely.
        // This helps a lot during chat overlay transitions where SwiftUI may recompute body often.
        func looksLikeMarkdown(_ s: String) -> Bool {
            // Heuristic: common markdown characters.
            return s.contains("*") || s.contains("_") || s.contains("`") || s.contains("[") || s.contains("]") || s.contains("#") || s.contains(">") || s.contains("-")
        }

        func normalizedModelText(_ s: String) -> String {
            // Some model outputs contain literal escape sequences like "\\n".
            // Normalize them, then normalize actual CRLF/CR, and also map Unicode separators.
            let unescaped = s
                .replacingOccurrences(of: "\\r\\n", with: "\n")
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\r", with: "\n")

            return unescaped
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .replacingOccurrences(of: "\u{2028}", with: "\n")
                .replacingOccurrences(of: "\u{2029}", with: "\n\n")
        }

        let normalized = normalizedModelText(content)

        if !looksLikeMarkdown(normalized) {
            return AttributedString(normalized)
        }

        if #available(iOS 15.0, macOS 12.0, visionOS 1.0, *) {
            do {
                // `AttributedString(markdown:)` can collapse single newlines.
                // Work around by parsing per line (so inline formatting still works) and
                // stitching with explicit "\n" that SwiftUI will render.
                let options = AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .full,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )

                let paragraphStrings = normalized
                    .replacingOccurrences(of: "\r", with: "\n")
                    .components(separatedBy: "\n\n")

                var out = AttributedString()
                for pIndex in paragraphStrings.indices {
                    let paragraph = paragraphStrings[pIndex]
                    let lines = paragraph.components(separatedBy: "\n")
                    for lIndex in lines.indices {
                        let line = lines[lIndex]
                        if line.isEmpty {
                            // Preserve empty lines within a paragraph.
                            out += AttributedString("\n")
                        } else {
                            out += try AttributedString(markdown: line, options: options)
                        }
                        if lIndex != lines.count - 1 {
                            out += AttributedString("\n")
                        }
                    }
                    if pIndex != paragraphStrings.count - 1 {
                        out += AttributedString("\n\n")
                    }
                }
                return out
            } catch {
                return AttributedString(normalized)
            }
        }

        return AttributedString(normalized)
    }

    private func attributed(for message: ChatMessage) -> AttributedString {
        attributedCache.value(for: message.id, source: message.content) {
            richText(for: message.content)
        }
    }

    private func updateBottomState(scrollMaxY: CGFloat, bottomMaxY: CGFloat) {
        guard scrollMaxY > 0 else { return }
        let atBottom = bottomMaxY <= scrollMaxY + bottomTolerance
        if atBottom != isAtBottom {
            withAnimation(.easeOut(duration: 0.2)) {
                isAtBottom = atBottom
            }
        }
    }

    private func makeBlobIndexByMessageID() -> [UUID: Int] {
        Dictionary(
            uniqueKeysWithValues: blobs.enumerated().compactMap { idx, blob in
                blob.messageID.map { ($0, idx) }
            }
        )
    }

    private func isTypingRowVisible(blobIndexByMessageID: [UUID: Int], typingBlobIsDismissing: Bool) -> Bool {
        guard showTypingIndicator || typingBlobIsDismissing else { return false }
        // Never show the typing indicator in an empty chat.
        guard !chatService.messages.isEmpty else { return false }

        // Only show the typing indicator once all existing messages are rendered/assigned.
        // This prevents the typing blob from appearing while previous chat blobs are still flying in.
        let hasPendingChatBlobs: Bool = chatService.messages.contains { msg in
            guard let idx = blobIndexByMessageID[msg.id] else { return true }
            if blobs[idx].status == .spawningToChat { return true }
            if blobs[idx].status == .chatBubble && blobs[idx].isAnchored == false { return true }
            return false
        }
        return !hasPendingChatBlobs
    }

    private func makeDisplayMessages(typingRowVisible: Bool) -> [ChatMessage] {
        typingRowVisible ? (chatService.messages + [typingMessage]) : chatService.messages
    }

    private func makeMessageRoleByID(displayMessages: [ChatMessage]) -> [UUID: ChatRole] {
        Dictionary(uniqueKeysWithValues: displayMessages.map { ($0.id, $0.role) })
    }

    private func pruneAttributedCache(typingRowVisible: Bool) {
        var liveIDs = Set(chatService.messages.map { $0.id })
        if typingRowVisible {
            liveIDs.insert(Self.typingMessageID)
        }
        attributedCache.prune(keeping: liveIDs)
    }

    private func handleMessageFrames(
        _ frames: [UUID: CGRect],
        messageRoleByID: [UUID: ChatRole],
        typingRowVisible: Bool
    ) {
        // Local caches for this callback to avoid repeated linear scans.
        var blobIndexByMessageID: [UUID: Int] = [:]
        blobIndexByMessageID.reserveCapacity(blobs.count)
        var idleDummyIndices: [Int] = []
        idleDummyIndices.reserveCapacity(blobs.count)

        for i in blobs.indices {
            if let mid = blobs[i].messageID {
                blobIndexByMessageID[mid] = i
            }
            if blobs[i].isDummy && blobs[i].messageID == nil && (blobs[i].status == .idle || blobs[i].status == .debris) {
                idleDummyIndices.append(i)
            }
        }

        // Allocate blobs for each message
        for (id, frame) in frames {
            if let idx = blobIndexByMessageID[id] {
                blobs[idx].bubbleWidth = frame.width
                blobs[idx].bubbleHeight = frame.height
                blobs[idx].targetPosition = CGPoint(x: frame.midX, y: frame.midY)

                if blobs[idx].isAnchored {
                    blobs[idx].position = blobs[idx].targetPosition!
                }
            } else if let idle = idleDummyIndices.popLast() {
                guard let role = messageRoleByID[id] else { continue }
                blobs[idle].status = .idle
                blobs[idle].assignMessage(id: id, frame: frame, role: role)

                // Typing indicator should float in from the left side.
                if id == Self.typingMessageID {
                    blobs[idle].status = .spawningToChat
                    blobs[idle].isAnchored = false
                    let entryPad: CGFloat = max(140, frame.width)
                    blobs[idle].position = CGPoint(x: -entryPad, y: frame.midY)
                    blobs[idle].previousPosition = blobs[idle].position
                    blobs[idle].targetPosition = CGPoint(x: frame.midX, y: frame.midY)
                }
                blobIndexByMessageID[id] = idle
            }
        }

        // When the chat is dismissed we clear `chatService.messages`.
        // Don't reclaim blobs in that moment; `LavaMenuContainer` will detach them and
        // transition them back to normal rising blobs.
        guard !chatService.messages.isEmpty else { return }

        var liveMessageIDs = Set(chatService.messages.map { $0.id })
        // Keep typing indicator alive while shown, and also while it's dismissing.
        if typingRowVisible {
            liveMessageIDs.insert(Self.typingMessageID)
        } else if blobs.contains(where: { $0.messageID == Self.typingMessageID && $0.status == .dismissing }) {
            liveMessageIDs.insert(Self.typingMessageID)
        }

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
    
    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                let bubblePadding: CGFloat = 20
                let messageSpacing: CGFloat = 40
                let bottomInset: CGFloat = max(160, containerSize.height * 0.20)
                let maxBubbleWidth = containerSize.width * 0.78
                let keyboardInset = keyboardHeight
                let topInset: CGFloat = max(40, geo.safeAreaInsets.top + 20)

                let blobIndexByMessageID = makeBlobIndexByMessageID()
                let typingBlobIsDismissing = blobs.contains(where: { $0.messageID == Self.typingMessageID && $0.status == .dismissing })
                let typingRowVisible = isTypingRowVisible(blobIndexByMessageID: blobIndexByMessageID, typingBlobIsDismissing: typingBlobIsDismissing)
                let displayMessages = makeDisplayMessages(typingRowVisible: typingRowVisible)
                let messageRoleByID = makeMessageRoleByID(displayMessages: displayMessages)

                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        VStack(spacing: messageSpacing) {
                            ForEach(displayMessages) { msg in
                                let isTyping = msg.id == Self.typingMessageID
                                let blob: MenuBlobState? = blobIndexByMessageID[msg.id].map { blobs[$0] }
                                let attributed = isTyping ? AttributedString("...") : attributed(for: msg)
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
                                                Group {
                                                    if isTyping {
                                                        TypingDotsView()
                                                            .padding(bubblePadding)
                                                    } else {
                                                        Text(attributed)
                                                            .padding(bubblePadding)
                                                            .fixedSize(horizontal: true, vertical: true)
                                                    }
                                                }
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
                                        Group {
                                            if isTyping {
                                                TypingDotsView()
                                                    .padding(bubblePadding)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                    .frame(width: bubbleWidth, alignment: .leading)
                                            } else {
                                                Text(attributed)
                                                    .padding(bubblePadding)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                    .frame(width: bubbleWidth,
                                                          alignment: .leading)
                                                    .multilineTextAlignment(.leading)
                                            }
                                        }
                                        .opacity(0)
                                        .background(
                                            GeometryReader { proxyMsg in
                                                Color.clear.preference(key: MessageFrameKey.self, value: [msg.id: proxyMsg.frame(in: .named("lava"))])
                                            }
                                        )

                                        // Visible content that follows the blob
                                        Group {
                                            if isTyping {
                                                TypingDotsView()
                                                    .padding(bubblePadding)
                                            } else {
                                                Text(attributed)
                                                    .padding(bubblePadding)
                                                    .foregroundColor(.white)
                                                    .multilineTextAlignment(.leading)
                                            }
                                        }
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(width: bubbleWidth, alignment: .leading)
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
                                        key: BottomSentinelGlobalMaxYKey.self,
                                        value: proxyBottom.frame(in: .global).maxY
                                    )
                                }
                            )
                    }
                    // Track the ScrollView's bottom edge in global coordinates.
                    .overlay(
                        GeometryReader { proxyScroll in
                            Color.clear.preference(key: ScrollViewGlobalMaxYKey.self, value: proxyScroll.frame(in: .global).maxY)
                        }
                    )
#if canImport(UIKit)
                    .background(
                        ScrollViewIntrospector { sv in
                            if underlyingScrollView !== sv {
                                underlyingScrollView = sv
                            }
                        }
                    )
#endif
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            dismissKeyboard()
                        }
                    )
                    .onChange(of: chatService.messages.count) { _ in
                        scrollToBottom(proxy, animated: true)
                        // Ensure the "scroll to bottom" button hides immediately when we auto-scroll.
                        isAtBottom = true

                        // Drop cache entries for messages that no longer exist.
                        pruneAttributedCache(typingRowVisible: typingRowVisible)
                    }
                    .onChange(of: showTypingIndicator) { isShown in
                        // When the typing indicator appears, keep the view pinned to bottom.
                        if isShown {
                            scrollToBottom(proxy, animated: true)
                            isAtBottom = true
                            return
                        }

                        // When generation finishes, float the typing blob out to the left.
                        if let idx = blobs.firstIndex(where: { $0.messageID == Self.typingMessageID }) {
                            guard blobs[idx].status != .dismissing else { return }
                            blobs[idx].status = .dismissing
                            blobs[idx].isAnchored = false
                            blobs[idx].targetPosition = nil
                            blobs[idx].currentSpeed = max(blobs[idx].baseSpeed, 18)
                        }
                    }
#if canImport(UIKit)
                    .onReceive(keyboardHeightPublisher) { height in
                        withAnimation(.easeOut(duration: 0.25)) {
                            keyboardHeight = height
                        }

                        scrollToBottom(proxy, animated: true)
                        // Keyboard changes often trigger a programmatic scroll-to-bottom.
                        isAtBottom = true
                    }
#endif
                    .onPreferenceChange(MessageFrameKey.self) { frames in
                        handleMessageFrames(frames, messageRoleByID: messageRoleByID, typingRowVisible: typingRowVisible)
                    }
                    .onPreferenceChange(MessageTextSizeKey.self) { sizes in
                        messageTextSizes = sizes
                    }
                    .onPreferenceChange(ScrollViewGlobalMaxYKey.self) { maxY in
                        scrollViewGlobalMaxY = maxY
                        updateBottomState(scrollMaxY: maxY, bottomMaxY: bottomSentinelGlobalMaxY)
                    }
                    .onPreferenceChange(BottomSentinelGlobalMaxYKey.self) { bottomY in
                        bottomSentinelGlobalMaxY = bottomY
                        updateBottomState(scrollMaxY: scrollViewGlobalMaxY, bottomMaxY: bottomY)
                    }

                    if !isAtBottom {
                        Button {
                            dismissKeyboard()
                            scrollToBottom(proxy, animated: true)
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
                        .transition(.opacity)
                    }
                }
            }
        }
    }
}

#if canImport(UIKit)
private struct ScrollViewIntrospector: UIViewRepresentable {
    let onResolve: (UIScrollView) -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let scrollView = uiView.findSuperview(of: UIScrollView.self) else { return }
            onResolve(scrollView)
        }
    }
}

private extension UIView {
    func findSuperview<T: UIView>(of type: T.Type) -> T? {
        var node: UIView? = self
        while let current = node {
            if let match = current as? T {
                return match
            }
            node = current.superview
        }
        return nil
    }
}
#endif
