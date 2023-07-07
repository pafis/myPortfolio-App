//
//  LicensesView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 06.07.23.
//

import SwiftUI

/// This is the LicensesView
struct LicensesView: View {
    @Binding var currentView: Info.InfoNavigationEnum
   
    
    var body: some View {
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
            TileDetailsView(title:"Licenses")
            {
                let licenseText = try? NSAttributedString(url: Bundle.main.url(forResource: "Licenses", withExtension: "rtf")!, options: [:], documentAttributes: nil)
                        
                let a = try? AttributedString(licenseText ?? NSAttributedString(string: ""), including: \.uiKit)
                //AttributedTextView(attributedString: licenseText ?? NSAttributedString(string: "")).frame(minHeight: 300)
          
                Text(a ?? "").padding(10)
               
               
                   
            }
        }
    }
}
#Preview {
    LicensesView(currentView: Info().$currentView)
}
