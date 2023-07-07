//
//  GridTileDetailsView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI


struct GridTileDetailsView<Content: View>: View {
    var title: String
    var content: Content
    var icon: String
    var font: Font
    
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = ""
        self.content = content()
        self.font = .title

    }
    
    init(title: String, icon:String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
        self.font = .title
        
    }
    init(title: String, icon:String,font:Font, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
        self.font = font
    }
    var body: some View {
        
        ZStack{
            Color.primaryTile2.opacity(0.5)
            VStack(alignment: .center){
                HStack{
                    Text(title).font(font).padding([.top], -30).padding(.leading, 90).frame(height: 100)
                    Spacer()
                }
                content
            }
            
            
        }.clipShape(RoundedRectangle(cornerRadius: 10))
         .shadow(radius: 3)
         .frame(width: 350)
         .overlay{
             ZStack{
                
                 Image(systemName: icon).resizable(capInsets: EdgeInsets(), resizingMode: .stretch).aspectRatio(contentMode: .fit)
                     .padding(10)
                     .foregroundColor(Color.primary)
                 
             }
            .frame(width: 70, height: 70)
            .background{
                Circle().fill(Color.primaryTile2.opacity(0.7)).stroke(Color.white, style: StrokeStyle(lineWidth: 4))
               
                    
            }
            .padding(.top, -190)
            .padding(.leading, -170)
         }
         .frame(width: 350)
         .padding(.bottom, 50)
        
        
    }
}
