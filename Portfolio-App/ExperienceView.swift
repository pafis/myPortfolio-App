//
//  ExperienceView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 27.06.23.
//

import SwiftUI

struct ExperienceView: View {
    let cvEvents: [CVEvent] = [
        CVEvent(beginningYear: 2009, endingYear: 2010, title: "Book Chapter Contributions", description: "C# Codebook 2010 by Jürgen Bayer", details: "Contributed to 'Detecting Hardware IDs', 'Generating and Validating License Keys' at the age of 14."),

        CVEvent(beginningYear: 2012, endingYear: 2020, title: "myElly / Educolix", description: "Founder & Developer", details: "Architected a cross-platform school information system (iOS/Android/Web) with 500+ active users. Managed full product lifecycle from concept to operations."),

        CVEvent(beginningYear: 2017, endingYear: nil, title: "ITQ GmbH", description: "Software Engineer / Consultant (Working Student)", details: "• Laboratory Tech: Custom Yocto/KAS layers & HMI interfaces.\n• Industrial IoT: KPI framework using Python & AWS Greengrass.\n• Rail Industry: Research on cross-manufacturer train control interconnects (C/C++).\n• Packaging Industry: KPI dashboard for production lines."),

        CVEvent(beginningYear: 2019, endingYear: nil, title: "Freelance", description: "Software Engineer / Consultant", details: "• Telecom: Mobile apps for network construction (Swift/Kotlin/Obj-C).\n• Retail: Automated sales reporting & Shopify (Power Apps, JS, WPF).\n• AdTech: Mobile app for campaign management (.NET MAUI).")
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
