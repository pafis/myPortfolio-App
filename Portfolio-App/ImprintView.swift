//
//  ImprintView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 06.07.23.
//

import SwiftUI

struct ImprintView: View {
    @Binding var currentView: Info.InfoNavigationEnum

    private var imprintText: AttributedString? {
        RTFResourceLoader.loadAttributedString(named: "Imprint")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Back navigation handled by the top header in `Info`.

            VStack(alignment: .leading, spacing: 14) {
                Text("Imprint")
                    .font(.system(.title2, design: .rounded).bold())

                if let imprintText {
                    Text(imprintText)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                } else {
                    Text("Imprint content not available.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .glassyCard(cornerRadius: 32, padding: 20)
        }
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var currentView: Info.InfoNavigationEnum = .imprint

        var body: some View {
            ImprintView(currentView: $currentView)
        }
    }

    return PreviewHost()
}
