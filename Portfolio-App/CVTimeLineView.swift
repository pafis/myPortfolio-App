//
//  CVTimeLineView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

struct CVTimeLineView: View {
    let events: [CVEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(events) { event in
                TimelineRow(event: event)
            }
        }
    }
}

private struct TimelineRow: View {
    let event: CVEvent

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 8) {
                Circle()
                    .fill(
                        LinearGradient(colors: [.white, .white.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 14, height: 14)
                    .shadow(color: .white.opacity(0.5), radius: 4)

                Rectangle()
                    .fill(
                        LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 18)

            VStack(alignment: .leading, spacing: 10) {
                Text(event.dateRange)
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(.blue)

                Text(event.title)
                    .font(.system(.headline, design: .rounded).bold())

                if !event.description.isEmpty {
                    Text(event.description)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.primary)
                }

                if !event.details.isEmpty {
                    Text(event.details)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassyCard(cornerRadius: 32, padding: 20)
        }
    }
}