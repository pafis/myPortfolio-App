//
//  StickyHeader.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

/// A view that creates a sticky header.
struct StickyHeader<Content: View>: View {
    /// The minimum height of the header.
    var minHeight: CGFloat

    /// The content of the header.
    var content: Content

    /// Initializes a new instance of the `StickyHeader` struct.
    ///
    /// - Parameters:
    ///   - minHeight: The minimum height of the header.
    ///   - content: The content of the header.
    init(minHeight: CGFloat = 200, @ViewBuilder content: () -> Content) {
        self.minHeight = minHeight
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            if geo.frame(in: .global).minY <= 0 {
                content
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            } else {
                content
                    .offset(y: -geo.frame(in: .global).minY)
                    .frame(width: geo.size.width, height: geo.size.height + geo.frame(in: .global).minY)
            }
        }.frame(minHeight: minHeight)
    }
}
