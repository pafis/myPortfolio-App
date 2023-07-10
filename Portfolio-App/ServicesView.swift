//
//  ServicesView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 27.06.23.
//

import SwiftUI

/// A view that displays a list of services.
struct ServicesView: View {
    /// The size category of the environment.
    @Environment(\.sizeCategory) private var sizeCategory

    /// The vertical size class of the environment.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// The services displayed in the view.
    let GridItems = [ServicesItem(title: "App Development", icon: "macbook.and.iphone", text: "Building innovative and robust applications that enhance user experiences.\nFrom concept to deployment, I'll work closely with you to create mobile, web and desktop applications that align with your business goals.\n\nLet's bring your ideas to life."),
                     ServicesItem(title: "Web Development", icon: "safari", text: "Transforming your vision into a captivating online presence.\nI specialize in designing and developing responsive, user-friendly websites tailored to your unique requirements.\n\nLet's create a website that leaves a lasting impression."),
                     ServicesItem(title: "Consulting", icon: "person.badge.shield.checkmark", text: "Guiding businesses towards technology-driven success. As an IT consultant, I provide strategic advice and solutions to optimize your IT infrastructure, streamline processes, and enhance overall efficiency.\n\nLet's leverage technology for your advantage."),
                     ServicesItem(title: "Data Science", icon: "chart.dots.scatter", text: "Extracting valuable insights from data to drive informed decision-making. With my knowledge in data analysis, machine learning, and predictive modeling, I'm helping businesses leverage their data assets for improved performance and competitive advantage.\n\nLet's harness the power of data.")]

    var body: some View {
        ScrollView {
            StickyHeader {
                ZStack {
                    Image(.serviceHeader)
                        .renderingMode(.original)
                        .resizable(resizingMode: .stretch)
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 350)
                    Text("Services")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color.white)
                        .padding(.top, 75)
                }
            }
            ZStack {
                BackgroundView().blur(radius: 40)
                LinearGradient(
                    gradient: Gradient(colors: [Color.primaryTile.opacity(0.9), Color.clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                Grid(alignment: .center) {
                    ForEach(GridItems, id: \.self) { item in
                        GridTileDetailsView(title: item.title, icon: item.icon) {
                            ZStack {
                                Text(item.text).padding(5)
                                    .padding(.bottom, 10)
                            }
                        }
                    }
                }.padding(.top, 50)
                    .padding(.bottom, 30)
                    .padding([.horizontal, .bottom], 10)

            }.clipShape(UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 30.0, topTrailing: 30.0)))
                .padding(.bottom, -30)

        }.scrollIndicators(.hidden)
    }

    /// Creates the grid items for the view.
    private func createGridItems() -> [GridItem] {
        let columns: [GridItem]

        if verticalSizeClass == .regular {
            columns = [GridItem(.flexible(minimum: 300))]
        } else {
            columns = [
                GridItem(.flexible(minimum: 400)),
                GridItem(.flexible(minimum: 400)),
            ]
        }

        return columns
    }
}

#Preview {
    ServicesView()
}
