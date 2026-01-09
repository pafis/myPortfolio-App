//
//  Legal.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 05.07.23.
//

import SwiftUI

struct Info: View {
    @State private var currentView: InfoNavigationEnum = .main

    /// The possible views for the Info View
    enum InfoNavigationEnum {
        case main
        case licenses
        case imprint
        case version
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                Group {
                    switch currentView {
                    case .main:
                        mainMenu
                            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    case .licenses:
                        LicensesView(currentView: $currentView)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                    case .imprint:
                        ImprintView(currentView: $currentView)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                    case .version:
                        VersionView(currentView: $currentView)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: currentView)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Info")
                    .font(.system(.largeTitle, design: .rounded).bold())
                Text("Legal, versioning, and app details")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if currentView != .main {
                Button {
                    withAnimation { currentView = .main }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .glassyCard(cornerRadius: 32, padding: 20)
    }

    private var mainMenu: some View {
        VStack(spacing: 8) {
            InfoRow(title: "Licenses", subtitle: "Third‑party notices", systemImage: "doc.text.fill", color: .blue) {
                withAnimation { currentView = .licenses }
            }
            
            Divider()
                .padding(.leading, 56)
                .opacity(0.3)
            
            InfoRow(title: "Imprint", subtitle: "Publisher details", systemImage: "building.2.fill", color: .purple) {
                withAnimation { currentView = .imprint }
            }
            
            Divider()
                .padding(.leading, 56)
                .opacity(0.3)
            
            InfoRow(title: "Version", subtitle: "Build and app version", systemImage: "number.square.fill", color: .green) {
                withAnimation { currentView = .version }
            }
        }
        .glassyCard(cornerRadius: 32, padding: 20)
    }
}

private struct InfoRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).bold())
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    Info()
}
