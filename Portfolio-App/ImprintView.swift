//
//  ImprintView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 06.07.23.
//

import SwiftUI

/// This is the Imprint View
import SwiftUI

/// This is the Imprint View
struct ImprintView: View {
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
            TileDetailsView(title: "Imprint") {
                let licenseText = try? NSAttributedString(url: Bundle.main.url(forResource: "Imprint", withExtension: "rtf")!, options: [:], documentAttributes: nil)

                let convertedAttrString = try? AttributedString(licenseText ?? NSAttributedString(string: ""), including: \.uiKit)
            }
        }
    }
}

#Preview {
    ImprintView(currentView: Info().$currentView)
}
