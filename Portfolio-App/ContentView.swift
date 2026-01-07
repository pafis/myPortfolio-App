//
//  ContentView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 16.06.23.
//

import SwiftUI

/// This is the main "Content" View
struct ContentView: View {
    let balls: [Ball] = [
        Ball(level: 1, name: "Info", view: AnyView(Info()), image: UIImage(), textSize: 12),
        Ball(level: 1, name: "Services", view: AnyView(ServicesView()), image: UIImage(), textSize: 12),
        Ball(level: 2, name: "Skills & Languages", view: AnyView(SkillsAndLanguagesView()), image: UIImage(), textSize: 14),
        Ball(level: 2, name: "Professional Experience", view: AnyView(ExperienceView()), image: UIImage(), textSize: 12),
        Ball(level: 2, name: "Education", view: AnyView(Education()), image: UIImage(), textSize: 15),
        Ball(level: 3, name: "About me", view: AnyView(AboutMeView()), image: UIImage(resource: .meImage1X1), textSize: 25),
    ]

    @State private var showChat: Bool = false
    @State private var showChatOverlay: Bool = false
    @State private var chatText: String = ""
    @StateObject private var chatService = ChatService()
    @Namespace private var animationNamespace
    @FocusState private var isChatFieldFocused: Bool

    @State private var chatDismissToken = UUID()

    var body: some View {
        ZStack {
            // Background with integrated chat overlay
            LavaMenuContainer(isChatFocused: showChat || isChatFieldFocused, chatService: chatService, showChatOverlay: showChatOverlay)
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
                                    chatService.sendMessage(chatText)
                                    chatText = ""
                                },
                                closeAction: {
                                    isChatFieldFocused = false
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

                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    showChat = true
                                }
                                showChatOverlay = true
                                isChatFieldFocused = true

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    guard showChat else { return }
                                    chatService.sendIntroductionIfNeeded()
                                }
                            }
                        }
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
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
