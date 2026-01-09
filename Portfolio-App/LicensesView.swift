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
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    withAnimation {
                        currentView = .main
                    }
                }) {
                    Image(systemName: "chevron.left").padding(.trailing, 2)
                    Text("Back")
                }
                .padding()
                .foregroundColor(.primary)

            }.padding(.bottom, 5)
            TileDetailsView(title: "Licenses") {
                if let licenseText {
                    Text(licenseText)
                        .padding(10)
                } else {
                    Text("License content not available.")
                        .padding(10)
                }
            }
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
