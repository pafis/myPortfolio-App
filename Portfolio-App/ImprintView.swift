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
                if let imprintText {
                    Text(imprintText)
                        .padding(10)
                } else {
                    Text("Imprint content not available.")
                        .padding(10)
                }
            }
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
