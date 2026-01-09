//
//  LicensesView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 06.07.23.
//

import SwiftUI

struct LicensesView: View {
    @Binding var currentView: Info.InfoNavigationEnum

    private var licenseText: AttributedString? {
        RTFResourceLoader.loadAttributedString(named: "Licenses")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    withAnimation { currentView = .main }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.headline)
                }
                .buttonStyle(.plain)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("Licenses")
                    .font(.system(.title2, design: .rounded).bold())

                if let licenseText {
                    Text(licenseText)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                } else {
                    Text("License content not available.")
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
        @State private var currentView: Info.InfoNavigationEnum = .licenses

        var body: some View {
            LicensesView(currentView: $currentView)
        }
    }

    return PreviewHost()
}
