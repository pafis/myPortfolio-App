//
//  TileDetailsView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

/// A view that formats content in the details views.
struct TileDetailsView<Content: View>: View {
    /// The title of the details view.
    var title: String

    /// The content of the details view.
    var content: Content

    /// Initializes a new instance of the `TileDetailsView` struct.
    ///
    /// - Parameters:
    ///   - title: The title of the details view.
    ///   - content: The content of the details view.
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack {
            HStack {
                Text(title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 10.0)
                Spacer()
            }

            ZStack {
                Color.primaryTile2.opacity(0.5)

                content

            }.clipShape(RoundedRectangle(cornerRadius: 10))

                .padding([.leading, .bottom, .trailing], 10.0)
                .shadow(radius: 3)

        }.padding(.top, 30.0)
    }
}