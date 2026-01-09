//
//  AboutMe.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 20.06.23.
//

import SwiftUI

struct AboutMeView: View {
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profileCard
                contactRow
                aboutCard

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }

    private var profileCard: some View {
        HStack(alignment: .center, spacing: 18) {
            Image("MeImage")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Pascal Fischer")
                    .font(.system(.title, design: .rounded).bold())
                Text("Developer • Consultant")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .glassyCard(cornerRadius: 32, padding: 20)
    }

    private var contactRow: some View {
        HStack(spacing: 12) {
            contactButton(title: "Call", systemImage: "phone.fill") {
                openURL(URL(string: "tel://+4917641888552")!)
            }
            contactButton(title: "Email", systemImage: "envelope.fill") {
                openURL(URL(string: "mailto:fischer@p-f.consulting")!)
            }
            contactButton(title: "Web", systemImage: "safari.fill") {
                openURL(URL(string: "https://p-f.consulting")!)
            }
            contactButton(title: "GitHub", systemImage: "terminal.fill") {
                openURL(URL(string: "https://github.com/pafis")!)
            }
        }
        .frame(maxWidth: .infinity)
        .glassyCard(cornerRadius: 32, padding: 16)
    }

    private func contactButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "person.text.rectangle.fill")
                    .foregroundStyle(.blue)
                Text("About")
                    .font(.system(.headline, design: .rounded).bold())
            }

            Text("Hi there! I'm Pascal Fischer, a software developer and consultant. I've been programming since the age of 11 and have delivered projects for a wide range of clients. I care about building reliable systems with a strong UX focus — clean architecture, scalable code, and beautiful interfaces. When I'm not shipping software, I'm usually out photographing the world.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .glassyCard(cornerRadius: 32, padding: 20)
    }
}

// A preview of the AboutMeView
#Preview {
    AboutMeView()
}
