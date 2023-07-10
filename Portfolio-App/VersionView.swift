//
//  VersionView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 06.07.23.
//

import SwiftUI

/// A view that displays the version and build number of the app.
struct VersionView: View {
    /// The current view state.
    @Binding var currentView: Info.InfoNavigationEnum

    var body: some View {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

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
            TileDetailsView(title: "Version") {
                VStack {
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

            }.frame(height: 100)
        }
    }
}

#Preview {
    VersionView(currentView: Info().$currentView)
}
