//
//  TileDetailsView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

/// This is the TileDetailsView that is used to fromat content in the details views
struct TileDetailsView<Content: View>: View {
    var title: String
    var content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack {
            HStack{
                Text(title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 10.0)
                Spacer()
            }
            
            
            ZStack{
                Color.primaryTile2.opacity(0.5)
                    
                    content

                }.clipShape(RoundedRectangle(cornerRadius: 10))
            
                .padding([.leading, .bottom, .trailing], 10.0)
                .shadow(radius: 3)

        } .padding(.top, 30.0)
    }
}
