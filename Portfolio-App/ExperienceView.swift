//
//  ExperienceView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 27.06.23.
//

import SwiftUI

struct ExperienceView: View {
    let cvEvents: [CVEvent] = [
        CVEvent(beginningYear: 2009, endingYear: 2010, title: "Book Chapter Contributions", description: "C# Codebook 2010 by Jürgen Bayer", details: "Contributed to 'Detecting Hardware IDs', 'Generating and Validating License Keys' at the age of 14"),
        CVEvent(beginningYear: 2013, endingYear: 2015, title: "myElly/Educolix-App", description: "iOS, Android, Web-Technologies", details: "Development, Operation and Maintanance of a school information app for teachers and students to access, news of the school, messages from the school administrators, as well as view their class schedules with real-time updates on substitutions and cancellations."),
        CVEvent(beginningYear: 2015, endingYear: 2020, title: "myElly/Educolix-App", description: "iOS, Android, Web-Technologies", details: "Development, Operation & Maintanance for multiple schools"),
        CVEvent(beginningYear: 2017, endingYear: nil, title: "ITQ GmbH", description: "Employed as Junior Software Engineer/Consultant in the field of Mechanical Engineering", details: "Front- & Backend, as well as Embedded Linux Software development with multiple Technologies"),
        CVEvent(beginningYear: 2019, endingYear: nil, title: "Freelancing Software-Developer\n&\nConsultant", description: "Mobil-, Desktop-, Web-Technologies", details: "")
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Experience")
                        .font(.system(.largeTitle, design: .rounded).bold())
                    Text("Highlights across roles and projects")
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
    ExperienceView()
}
