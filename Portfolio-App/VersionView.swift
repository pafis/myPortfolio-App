//
//  VersionView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 06.07.23.
//

import SwiftUI


/// This is the VersionView
struct VersionView: View {
    @Binding var currentView: Info.InfoNavigationEnum
    
    var body: some View {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
            
        VStack (alignment: .leading) {
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
            TileDetailsView(title:"Version")
            {
                VStack
                {
                    HStack {
                        Text("Version \(appVersion)")
                        Spacer()
                    }.padding(5)
                   Divider()
                    HStack {
                        Text("Build \(buildNumber)")
                        Spacer()
                    }.padding(5)
                }.padding(10)
      
            }.frame(height: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/)
        }
    }
}
#Preview{
    VersionView(currentView: Info().$currentView)
}
