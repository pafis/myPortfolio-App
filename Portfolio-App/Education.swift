//
//  CVView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 26.06.23.
//
import SwiftUI

struct Education: View {
    let cvEvents: [CVEvent] = [
        CVEvent(beginningYear: 2006, endingYear: 2015, title: "Higher Education Entrance Qualification", description: "Elly-Heuss-Knapp-Gymnasium", details: "Duisburg, Germany"),
        CVEvent(beginningYear: 2015, endingYear: nil, title: "Bachelor's Degree Program", description: "Heinrich-Heine-Universität Düsseldorf", details: "in Computer Science (Major) /\nPsychology (Minor)")
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Education")
                        .font(.system(.largeTitle, design: .rounded).bold())
                    Text("Formal milestones and focus areas")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .glassyCard(cornerRadius: 32, padding: 20)
                .padding(.top, 24)

                CVTimeLineView(events: cvEvents)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }
}

// The preview
#Preview {
    Education()
}
