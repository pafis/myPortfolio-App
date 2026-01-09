//
//  ServicesView.swift
//  Portfolio-App
//  Created by Pascal Fischer on 27.06.23.

import SwiftUI

struct ServicesView: View {
    let items = [
        ServicesItem(title: "App Development", icon: "macbook.and.iphone", text: "Building innovative and robust applications that enhance user experiences.\nFrom concept to deployment, I'll work closely with you to create mobile, web and desktop applications that align with your business goals.\n\nLet's bring your ideas to life."),
        ServicesItem(title: "Web Development", icon: "safari", text: "Transforming your vision into a captivating online presence.\nI specialize in designing and developing responsive, user-friendly websites tailored to your unique requirements.\n\nLet's create a website that leaves a lasting impression."),
        ServicesItem(title: "Consulting", icon: "person.badge.shield.checkmark", text: "Guiding businesses towards technology-driven success. As an IT consultant, I provide strategic advice and solutions to optimize your IT infrastructure, streamline processes, and enhance overall efficiency.\n\nLet's leverage technology for your advantage."),
        ServicesItem(title: "Data Science", icon: "chart.dots.scatter", text: "Extracting valuable insights from data to drive informed decision-making. With my knowledge in data analysis, machine learning, and predictive modeling, I'm helping businesses leverage their data assets for improved performance and competitive advantage.\n\nLet's harness the power of data."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Services")
                            .font(.system(.largeTitle, design: .rounded).bold())
                        Text("What I can help you ship")
                            .font(.system(.callout, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .glassyCard(cornerRadius: 32, padding: 20)
                .padding(.top, 24)

                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(items, id: \.self) { item in
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .center, spacing: 14) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        LinearGradient(colors: [.blue, .blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                Text(item.title)
                                    .font(.system(.headline, design: .rounded).bold())

                                Spacer()
                            }

                            Text(item.text)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassyCard(cornerRadius: 32, padding: 20)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }

    private var gridColumns: [GridItem] {
        [GridItem(.flexible(minimum: 320))]
    }
}

#Preview {
    ServicesView()
}
