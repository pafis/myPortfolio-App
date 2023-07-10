//
//  GridTileDetailsView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

import SwiftUI

/// A view that displays a grid tile with a title, content, and icon.
struct GridTileDetailsView<Content: View>: View {
    /// The title of the grid tile details view.
    var title: String
    /// The content of the grid tile details view.
    var content: Content
    /// The icon of the grid tile details view.
    var icon: String
    /// The font of the grid tile details view.
    var font: Font

    /// Creates a grid tile details view with a title and content.
    /// - Parameters:
    ///   - title: The title of the grid tile details view.
    ///   - content: The content of the grid tile details view.
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        icon = ""
        self.content = content()
        font = .title
    }

    /// Creates a grid tile details view with a title, icon, and content.
    /// - Parameters:
    ///   - title: The title of the grid tile details view.
    ///   - icon: The icon of the grid tile details view.
    ///   - content: The content of the grid tile details view.
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
        font = .title
    }

    /// Creates a grid tile details view with a title, icon, font, and content.
    /// - Parameters:
    ///   - title: The title of the grid tile details view.
    ///   - icon: The icon of the grid tile details view.
    ///   - font: The font of the grid tile details view.
    ///   - content: The content of the grid tile details view.
    init(title: String, icon: String, font: Font, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
        self.font = font
    }

    var body: some View {
        ZStack {
            Color.primaryTile2.opacity(0.5)
            VStack(alignment: .center) {
                HStack {
                    Text(title).font(font).padding([.top], -30).padding(.leading, 90).frame(height: 100)
                    Spacer()
                }
                content
            }

        }.clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 3)
            .frame(width: 350)
            .overlay {
                ZStack {
                    Image(systemName: icon).resizable(capInsets: EdgeInsets(), resizingMode: .stretch).aspectRatio(contentMode: .fit)
                        .padding(10)
                        .foregroundColor(Color.primary)
                }
                .frame(width: 70, height: 70)
                .background {
                    Circle().fill(Color.primaryTile2.opacity(0.7)).stroke(Color.white, style: StrokeStyle(lineWidth: 4))
                }
                .padding(.top, -190)
                .padding(.leading, -170)
            }
            .frame(width: 350)
            .padding(.bottom, 50)
    }
}