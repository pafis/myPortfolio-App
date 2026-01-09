//
//  ContentView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 16.06.23.
//

import SwiftUI

/// This is the main "Content" View
struct ContentView: View {
    let menuItems: [PortfolioMenuItem] = [
        PortfolioMenuItem(name: "Info", view: AnyView(Info())),
        PortfolioMenuItem(name: "Services", view: AnyView(ServicesView())),
        PortfolioMenuItem(name: "Skills & Languages", view: AnyView(SkillsAndLanguagesView())),
        PortfolioMenuItem(name: "Professional Experience", view: AnyView(ExperienceView())),
        PortfolioMenuItem(name: "Education", view: AnyView(Education())),
        PortfolioMenuItem(name: "About me", view: AnyView(AboutMeView())),
    ]

    @State private var showChat: Bool = false
    @State private var showChatOverlay: Bool = false
    @State private var chatText: String = ""
    @StateObject private var chatService = ChatService()
    @Namespace private var animationNamespace
    @FocusState private var isChatFieldFocused: Bool

    @State private var chatDismissToken = UUID()
    @State private var pendingLLMSendToken = UUID()
    @State private var debrisInView: Bool = false
    @State private var isLLMQueued: Bool = false
    @State private var typingOutInView: Bool = false
    @State private var pendingAssistantCommitToken = UUID()

    @State private var keywordTopics: [ChatService.MenuKeyword] = []
    @State private var isLoadingKeywordTopics: Bool = false
    @State private var selectedMenuItem: PortfolioMenuItem? = nil
    @State private var keywordRefreshTask: Task<Void, Never>? = nil

    private let keywordRefreshInterval: UInt64 = 60 * 1_000_000_000 // 60s

    var body: some View {
        ZStack {
            // Background with integrated chat overlay
            LavaMenuContainer(
                menuItems: menuItems,
                keywordItems: keywordTopics,
                onSelectMenuItem: { item in
                    selectedMenuItem = item
                },
                onSelectKeyword: { keyword in
                    openChatAndAsk(topic: keyword)
                },
                isChatFocused: showChat || isChatFieldFocused,
                debrisInView: $debrisInView,
                typingOutInView: $typingOutInView,
                chatService: chatService,
                showChatOverlay: showChatOverlay,
                showTypingIndicator: (chatService.isTyping || isLLMQueued)
            )
                .ignoresSafeArea()

            // Foreground: Floating Chat Controls
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    // Alignment Container
                    ZStack(alignment: .bottomTrailing) {
                        if showChat {
                            ChatBox(
                                text: $chatText,
                                namespace: animationNamespace,
                                isFocused: $isChatFieldFocused,
                                onSend: {
                                    let text = chatText
                                    chatText = ""
                                    enqueueLLMSend(text)
                                },
                                closeAction: {
                                    isChatFieldFocused = false
                                    // Cancel any pending LLM send triggered by taps.
                                    pendingLLMSendToken = UUID()
                                    isLLMQueued = false
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                        showChat = false
                                    }

                                    // Drop the overlay immediately so its blobs can be detached and start rising.
                                    showChatOverlay = false

                                    // Delay history clear until after the close animation.
                                    let token = UUID()
                                    chatDismissToken = token
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        guard chatDismissToken == token else { return }
                                        guard !showChat else { return }
                                        chatText = ""
                                        chatService.clear()
                                    }
                                }
                            )
                        } else {
                            ChatButton(namespace: animationNamespace) {
                                // Cancel any pending dismissal.
                                chatDismissToken = UUID()
                                // Cancel any pending LLM send triggered by taps.
                                pendingLLMSendToken = UUID()

                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    showChat = true
                                }
                                showChatOverlay = true
                                isChatFieldFocused = true

                                // Wait for the open animation to settle before kicking off LLM work.
                                let token = UUID()
                                pendingLLMSendToken = token
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 600_000_000)
                                    guard pendingLLMSendToken == token else { return }
                                    guard showChat else { return }
                                    enqueueLLMSend(introductionIfNeeded: true)
                                }
                            }
                        }
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
        .sheet(item: $selectedMenuItem) { item in
            item.view
        }
        .onAppear {
            startKeywordRefreshLoopIfNeeded()
        }
        .onChange(of: chatService.pendingAssistantReply) { newValue in
            guard newValue != nil else { return }

            // Cancel any pending commit and schedule a new one.
            let token = UUID()
            pendingAssistantCommitToken = token

            Task { @MainActor in
                // Wait until the typing blob has fully floated out.
                while typingOutInView {
                    guard pendingAssistantCommitToken == token else { return }
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                guard pendingAssistantCommitToken == token else { return }
                chatService.commitPendingAssistantReplyIfAny()
            }
        }
        .onDisappear {
            keywordRefreshTask?.cancel()
            keywordRefreshTask = nil
        }
    }

    private func openChatAndAsk(topic: ChatService.MenuKeyword) {
        let trimmed = topic.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Cancel any pending dismissal.
        chatDismissToken = UUID()

        // Cancel any pending LLM send triggered by previous taps.
        pendingLLMSendToken = UUID()

        let willAnimateOpen = !showChat

        if !showChat {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                showChat = true
            }
            showChatOverlay = true
            isChatFieldFocused = true
        }

        chatText = ""

        // Wait until the open animation has rendered before starting generation.
        let token = UUID()
        pendingLLMSendToken = token
        Task { @MainActor in
            if willAnimateOpen {
                try? await Task.sleep(nanoseconds: 600_000_000)
            } else {
                // Chat already open: just yield a frame.
                await Task.yield()
            }
            guard pendingLLMSendToken == token else { return }
            enqueueLLMSend(topic.question, token: token)
        }
    }

    @MainActor
    private func enqueueLLMSend(_ text: String, token: UUID? = nil) {
        let current = token ?? pendingLLMSendToken
        // Append the user message immediately so it can render while we delay LLM compute.
        guard chatService.appendUserMessage(text) != nil else { return }
        isLLMQueued = true

        Task { @MainActor in
            // Wait until debris has fully left the viewport.
            // This prevents LLM compute contention during the heavy "move out of the way" animation.
            while debrisInView {
                guard pendingLLMSendToken == current else { isLLMQueued = false; return }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            guard pendingLLMSendToken == current else { isLLMQueued = false; return }
            isLLMQueued = false
            chatService.startAssistantReply(for: text)
        }
    }

    @MainActor
    private func enqueueLLMSend(introductionIfNeeded: Bool) {
        let token = pendingLLMSendToken
        isLLMQueued = true
        Task { @MainActor in
            while debrisInView {
                guard pendingLLMSendToken == token else { isLLMQueued = false; return }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            guard pendingLLMSendToken == token else { isLLMQueued = false; return }
            isLLMQueued = false
            chatService.sendIntroductionIfNeeded()
        }
    }

    private func startKeywordRefreshLoopIfNeeded() {
        guard keywordRefreshTask == nil else { return }

        keywordRefreshTask = Task {
            while !Task.isCancelled {
                await refreshKeywordTopicsOnce()
                do {
                    try await Task.sleep(nanoseconds: keywordRefreshInterval)
                } catch {
                    break
                }
            }
        }
    }

    private func refreshKeywordTopicsOnce() async {
        if isLoadingKeywordTopics { return }
        isLoadingKeywordTopics = true
        defer { isLoadingKeywordTopics = false }

        do {
            let topics = try await chatService.generateMenuKeywords(count: 6)
            await MainActor.run {
                if !topics.isEmpty {
                    keywordTopics = topics
                }
            }
        } catch {
            let nsError = error as NSError
            // If keyword generation is permanently unavailable, stop the loop.
            if nsError.domain == "ChatService", [-10, -11, -20, -21].contains(nsError.code) {
                await MainActor.run {
                    if keywordTopics.isEmpty {
                        keywordTopics = defaultKeywordTopics()
                    }
                    keywordRefreshTask?.cancel()
                    keywordRefreshTask = nil
                }
            }
            // -3 (busy) / -12 (not ready) and other transient errors: just keep current topics.
            print("Keyword generation error: \(error)")
        }
    }

    private func defaultKeywordTopics() -> [ChatService.MenuKeyword] {
        let topics = [
            "Tech Stack",
            "Work Experience",
            "Featured Projects",
            "Key Skills",
            "Leadership Style",
            "Education Background",
        ]
        return topics.map { t in
            ChatService.MenuKeyword(keyword: t, question: "What can you tell me about \(t) in Pascal Fischer's portfolio?")
        }
    }
}

// MARK: - ChatButton (Collapsed State)
fileprivate struct ChatButton: View {
    var namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "message.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                )
                .matchedGeometryEffect(id: "action_button_bg", in: namespace)
                .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
        }
        .transition(.scale(scale: 0.1).combined(with: .opacity))
    }
}

// MARK: - ChatBox (Expanded State)
fileprivate struct ChatBox: View {
    @Binding var text: String
    var namespace: Namespace.ID
    var isFocused: FocusState<Bool>.Binding
    var onSend: () -> Void
    var closeAction: () -> Void

    @State private var isSendVisible: Bool = false

    var body: some View {
        // 1. ALIGNMENT CHANGE: Align to .bottom so buttons stay down when text grows up
        HStack(alignment: .bottom, spacing: 12) {

            // --- CLOSE BUTTON (Left) ---
            Button(action: closeAction) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    // Kept at 44 to match Send button height for symmetry in the row
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.8))
                    )
                    .matchedGeometryEffect(id: "action_button_bg", in: namespace)
                    .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
            }
            .padding(.bottom, 2) // Align with the bottom of the text field

            // --- TEXT FIELD CONTAINER (Middle) ---
            HStack {
                // 2. MULTILINE SETUP
                TextField("Ask me...", text: $text, axis: .vertical)
                    .lineLimit(1...5) // Expands from 1 to 5 lines, then scrolls
                    .textFieldStyle(.plain)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.8))
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
                    .focused(isFocused)
            }
            .frame(minWidth: 200, maxWidth: .infinity)
            .layoutPriority(1)
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.0, anchor: .trailing).combined(with: .opacity),
                    removal: .scale(scale: 0.0, anchor: .trailing).combined(with: .opacity)
                )
            )

            // --- SEND BUTTON (Right) ---
            if isSendVisible {
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            ZStack {
                                Circle().fill(.ultraThinMaterial.opacity(0.6))
                                Circle().fill(Color.blue.gradient.opacity(0.6))
                            }
                            .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                }
                .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                .transition(.move(edge: .trailing).combined(with: .scale).combined(with: .opacity))
                .zIndex(1)
                // Add padding to align visually with the text input if it's single line
                .padding(.bottom, 2)
            }
        }
        .padding(.leading, 16)
        .transition(.scale(scale: 0.98, anchor: .bottomTrailing).combined(with: .opacity))
        .onChange(of: text) { newValue in
            let shouldShow = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if shouldShow != isSendVisible {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    isSendVisible = shouldShow
                }
            }
        }
        .onAppear {
            isSendVisible = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

#Preview {
    ContentView()
}
