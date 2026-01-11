//  BlobModalView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 01/09/26.
//

import SwiftUI

struct BlobModalWrapper<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content

    @State private var offsetY: CGFloat = 0
    @State private var isDragging: Bool = false

    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Modal panel
                ZStack {

                    // Top invisible grabber area — captures dismissal drags
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: 44)
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 2)
                                    .onChanged { value in
                                        if value.translation.height > 0 {
                                            isDragging = true
                                            offsetY = value.translation.height / 1.1
                                        }
                                    }
                                    .onEnded { value in
                                        isDragging = false
                                        let translation = max(0, value.translation.height)
                                        let predicted = max(0, value.predictedEndTranslation.height)

                                        if translation > 100 || predicted > 200 {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                offsetY = geometry.size.height
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                                                isPresented = false
                                                offsetY = 0
                                            }
                                        } else {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                                offsetY = 0
                                            }
                                        }
                                    }
                            )

                        // Content area (scrollable) — does not intercept dismissal drag
                        content
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                            .mask(
                                RoundedRectangle(cornerRadius: 35, style: .continuous)
                            )
                    }
                }
                .frame(width: geometry.size.width - 20, height: geometry.size.height * 0.92)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2 + (geometry.size.height * 0.04))
                .offset(y: offsetY)
                .scaleEffect(isDragging ? 0.98 : 1.0)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
