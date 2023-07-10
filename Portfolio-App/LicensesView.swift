//
//  LicensesView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 06.07.23.
//

import SwiftUI

import SwiftUI

/// This is the LicensesView
struct LicensesView: View {
    /// The current view binding
    @Binding var currentView: Info.InfoNavigationEnum

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
                let licenseText = try? NSAttributedString(url: Bundle.main.url(forResource: "Licenses", withExtension: "rtf")!, options: [:], documentAttributes: nil)

                let a = try? AttributedString(licenseText ?? NSAttributedString(string: ""), including: \.uiKit)

                Text(a ?? "").padding(10)
            }
        }
    }
}

#Preview {
    LicensesView(currentView: Info().$currentView)
}
