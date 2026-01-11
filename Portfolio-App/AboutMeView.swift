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
                .scaledToFill()
                .frame(width: 80, height: 80, alignment: .top)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Pascal Fischer")
                    .font(.system(.title, design: .rounded).bold())
                Text("Software Engineer • Consultant")
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

            Text("""
I am a Software Engineer with a deep passion for software systems that range from low-level embedded architecture to user-centric mobile applications. My career began early with contributions to the C# Codebook 2010 at the age of 14, establishing a foundation of self-driven learning and technical curiosity.\nOver the last decade, I have balanced my academic studies in Computer Science and Psychology with professional roles that demand high technical versatility.\n\nMy expertise spans the full stack, including Embedded Linux, IoT integration with AWS Greengrass, and cross-platform mobile development.\nWhether conducting architectural reviews for industrial clients or managing the full product lifecycle of my own educational apps, I focus on delivering scalable, maintainable, and efficient code.
""")
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
