//
//  Legal.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 05.07.23.
//

import SwiftUI

/// This is the Info View
struct Info: View {
    @State var currentView: InfoNavigationEnum = .main
    enum InfoNavigationEnum {
        case main
        case licenses
        case imprint
        case version
    }
    var body: some View {
        ScrollView {
            StickyHeader ()
            {
                ZStack{
                    Image(.infoHeader)
                        .renderingMode(.original)
                        .resizable(resizingMode: .stretch)
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 400)
                    Text("Info")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color.black)
                        .padding(.top, 40)
                    
                }
            }
            ZStack{
                BackgroundView().blur(radius: 40)
                LinearGradient(
                    gradient: Gradient(colors: [Color.primaryTile.opacity(0.9), Color.clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack{
                    if (currentView == .main)
                    {
                        TileDetailsView(title: "Info"){
                            VStack{
                                HStack{
                                    Text("Licenses")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }.contentShape(Rectangle()).padding(5)
                                    .onTapGesture {
                                        withAnimation {
                                            currentView = .licenses
                                        }
                                    }
                                Divider()
                                HStack{
                                    Text("Imprint")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }.contentShape(Rectangle()).padding(5)
                                    .onTapGesture {
                                        withAnimation {
                                            currentView = .imprint
                                        }
                                    }
                                Divider()
                                HStack{
                                    Text("Version")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }.contentShape(Rectangle()).padding(5)
                                    .onTapGesture {
                                        withAnimation {
                                            currentView = .version
                                        }
                                    }
                            }.padding(10)
                          
                            
                        }.frame(height: 150)
                        .padding(.top,30)
                        
                    }
                    if(currentView == .licenses)
                    {  LicensesView(currentView: $currentView)
                            .padding(.top,30)
                            .transition(.move(edge: .trailing))
                    }
                    if (currentView == .imprint)
                    {  ImprintView(currentView: $currentView)
                            .padding(.top,30)
                            .transition(.move(edge: .trailing))
                    }
                    if(currentView == .version)
                    { VersionView(currentView: $currentView)
                            .padding(.top,30)
                            .transition(.move(edge: .trailing))
                    }
                    Spacer()
                }.frame(minHeight: 750)
                    .padding(.horizontal, 10)
            
                    
            }.clipShape(UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 30.0, topTrailing: 30.0)))
                .padding(.top, -42.0)
                .padding(.bottom, -30)
               
           
            
        }.scrollIndicators(.hidden)
    }
}



#Preview {
    Info()
}
