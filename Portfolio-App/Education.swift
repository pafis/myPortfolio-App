//
//  CVView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 26.06.23.
//
import SwiftUI

/// This is the Education View
struct Education: View {
    let cvEvents: [CVEvent] = [
        CVEvent(beginningYear: 2006, endingYear: 2015, title: "Higher Education Entrance Qualification", description: "Elly-Heuss-Knapp-Gymnasium", details: "Duisburg, Germany"),
        CVEvent(beginningYear: 2015, endingYear: nil, title: "Bachelor's Degree Program", description: "Heinrich-Heine-Universität Düsseldorf", details: "in Computer Science (Major) /\nPsychology (Minor)"),
    ]
    var body: some View {
        ScrollView {
            // The sticky header
            StickyHeader {
                ZStack {
                    Image(.educationHeader)
                        .renderingMode(.original)
                        .resizable(resizingMode: .stretch)
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 400)
                    Text("Education")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color.white)
                        .padding(.top, 40)
                }
            }

            // The timeline view
            ZStack {
                BackgroundView().blur(radius: 40)
                LinearGradient(
                    gradient: Gradient(colors: [Color.primaryTile.opacity(0.9), Color.clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                CVTimeLineView(events: cvEvents)

            }.clipShape(UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 30.0, topTrailing: 30.0)))
                .padding(.top, -42.0)
                .padding(.bottom, -32.0)

        }.scrollIndicators(.hidden)
    }
}

// The preview
#Preview {
    Education()
}