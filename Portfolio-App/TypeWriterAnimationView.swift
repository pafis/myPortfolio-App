//
//  TypeWriterAnimationView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 29.06.23.
//

import SwiftUI

///This is a helper class that contains and animates a Text control with a Typwriter animation.
struct TypewriterTextAnimation: View {
    let text: String
    @State private var animatedText = ""

    var body: some View {
        Text(animatedText)
            .font(.largeTitle)
            .onAppear {
                animateText()
            }
    }

    func animateText() {
        for (index, character) in text.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                animatedText.append(character)
            }
        }
    }
}
