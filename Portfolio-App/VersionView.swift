//
//  VersionView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 06.07.23.
//

import SwiftUI

struct VersionView: View {
    @Binding var currentView: Info.InfoNavigationEnum

    var body: some View {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    withAnimation { currentView = .main }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.headline)
                }
                .buttonStyle(.plain)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("Version")
                    .font(.system(.title2, design: .rounded).bold())

                HStack {
                    Text("App")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(appVersion)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                }

                Divider()
                    .opacity(0.3)

                HStack {
                    Text("Build")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(buildNumber)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                }
            }
            .glassyCard(cornerRadius: 32, padding: 20)
        }
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var currentView: Info.InfoNavigationEnum = .version

        var body: some View {
            VersionView(currentView: $currentView)
        }
    }

    return PreviewHost()
}
