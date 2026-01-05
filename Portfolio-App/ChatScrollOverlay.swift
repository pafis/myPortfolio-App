import SwiftUI

// PreferenceKey to collect frames for messages
struct MessageFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
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
    
    var body: some View {
        GeometryReader { _ in
            ScrollViewReader { proxy in
                let bubblePadding: CGFloat = 13
                let messageSpacing: CGFloat = 40
                let bottomInset: CGFloat = max(160, containerSize.height * 0.20)
                let maxBubbleWidth = containerSize.width * 0.78

                // Avoid repeated linear scans in the hot SwiftUI layout path.
                let messageRoleByID: [UUID: ChatRole] = Dictionary(
                    uniqueKeysWithValues: chatService.messages.map { ($0.id, $0.role) }
                )
                let blobIndexByMessageID: [UUID: Int] = Dictionary(
                    uniqueKeysWithValues: blobs.enumerated().compactMap { idx, blob in
                        blob.messageID.map { ($0, idx) }
                    }
                )

                ScrollView {

                    VStack(spacing: messageSpacing) {
                        ForEach(chatService.messages) { msg in
                            let blob: MenuBlobState? = blobIndexByMessageID[msg.id].map { blobs[$0] }
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
                                            Text(msg.content)
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
                                    Text(msg.content)
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
                                    Text(msg.content)
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
                    .padding(.top, 40)
                    .padding(.bottom, bottomInset)
                }
                .onChange(of: chatService.messages.count) { _ in
                    if let last = chatService.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
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
                        } else if let idle = blobs.firstIndex(where: { $0.status == .idle && $0.isDummy }) {
                  
                            guard let role = messageRoleByID[id] else { continue }
                            blobs[idle].assignMessage(id: id, frame: frame, role: role)
                        }
                    }

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
            }
        }
    }
}
