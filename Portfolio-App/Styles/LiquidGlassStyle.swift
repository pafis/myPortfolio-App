//
//  LiquidGlassStyle.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 1/9/26.
//

import SwiftUI

struct GlassyCard: ViewModifier {
    var cornerRadius: CGFloat = 30
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func glassyCard(cornerRadius: CGFloat = 30, padding: CGFloat = 20) -> some View {
        modifier(GlassyCard(cornerRadius: cornerRadius, padding: padding))
    }
}

#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()
        VStack {
            Text("Liquid Glass Design")
                .font(.system(.largeTitle, design: .rounded).bold())
                .foregroundStyle(.primary)

            Text("This is a glassy card.")
                .glassyCard()
        }
    }
}
