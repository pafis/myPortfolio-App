//
//  TypeWriterAnimationView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 29.06.23.
//

import SwiftUI

/// A helper view that contains and animates a Text control with a Typewriter animation.
struct TypewriterTextAnimation: View {
    /// The text to be animated.
    let text: String

    /// The animated text.
    @State private var animatedText = ""

    var body: some View {
        Text(animatedText)
            .font(.largeTitle)
            .onAppear {
                animateText()
            }
    }

    /// Animates the text by appending each character to the animated text with a delay.
    func animateText() {
        for (index, character) in text.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                animatedText.append(character)
            }
        }
    }
}
