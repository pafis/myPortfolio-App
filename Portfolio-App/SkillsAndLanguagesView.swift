//
//  SkillsAndLanguagesView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 27.06.23.
//

import SwiftUI

/// A view that displays a list of progress skill categories.
struct SkillsAndLanguagesView: View {
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// The progress skill categories to display.
    let data: [ProgressSkillCategory] = [ProgressSkillCategory(name: "Programming Languages\n& Technologies", skills: [ProgressSkill(name: "Java", progress: 1), ProgressSkill(name: "JavaScript", progress: 1), ProgressSkill(name: "SQL/Datenbanken", progress: 1), ProgressSkill(name: "ASP.NET", progress: 1), ProgressSkill(name: "C", progress: 1), ProgressSkill(name: "C++", progress: 1), ProgressSkill(name: "C#", progress: 1), ProgressSkill(name: "Objective-C", progress: 1), ProgressSkill(name: "Kotlin", progress: 1), ProgressSkill(name: "Swift", progress: 1), ProgressSkill(name: "Clojure", progress: 3 / 5), ProgressSkill(name: "Python", progress: 3 / 5), ProgressSkill(name: "Latex", progress: 3 / 5)], icon: "chevron.left.forwardslash.chevron.right", font: .title2),
                                         ProgressSkillCategory(name: "Spoken Languages", skills: [ProgressSkill(name: "German", progress: 1), ProgressSkill(name: "English", progress: 1)], icon: "person.wave.2", font: .title),
                                         ProgressSkillCategory(name: "Software Tools", skills: [ProgressSkill(name: "Xcode", progress: 1), ProgressSkill(name: "Visual Studio", progress: 1), ProgressSkill(name: "Android Studio", progress: 1), ProgressSkill(name: "Eclipse", progress: 1), ProgressSkill(name: "Microsoft Office", progress: 1), ProgressSkill(name: "3Ds Max", progress: 3 / 5), ProgressSkill(name: "Adobe CC Master Suite", progress: 1), ProgressSkill(name: "Unity", progress: 2 / 5), ProgressSkill(name: "Unreal Engine", progress: 3 / 5)], icon: "pencil.slash", font: .title)]

    var body: some View {
        ScrollView {
            StickyHeader {
                ZStack {
                    Image(.professionalExperienceHeader)
                        .renderingMode(.original)
                        .resizable(resizingMode: .stretch)
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 350)
                    VStack {
                        Text("Skills & Languages")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(Color.white)
                    }.padding(.top, 75)
                }
            }
            ZStack {
                BackgroundView().blur(radius: 40).padding(.top, -10)
                LinearGradient(
                    gradient: Gradient(colors: [Color.primaryTile.opacity(0.9), Color.clear]),
                    startPoint: .top,
                    endPoint: .bottom
                ).padding(.top, -10)
                Grid(alignment: .center) {
                    ForEach(data, id: \.id) { tile in

                        HStack {
                            GridTileDetailsView(title: tile.name, icon: tile.icon, font: tile.font) {
                                ZStack {
                                    VStack(alignment: .center) {
                                        TabView {
                                            ForEach(tile.skills, id: \.id) { skill in
                                                GeometryReader { geometry in

                                                    ProgressView(progress: skill.progress, text: skill.name, strokeLineWidth: 10).frame(width: 150, height: 150)
                                                        .background {
                                                            Color.secondary.opacity(skill.progress)
                                                        }.clipShape(RoundedRectangle(cornerRadius: 30))
                                                        .padding(.leading, 80)

                                                        .animation(.bouncy)
                                                        .rotation3DEffect(Angle(degrees: (Double(geometry.frame(in: .global).minX) - 50) / -8), axis: (x: 0, y: 1.0, z: 0))
                                                }
                                            }
                                        }.tabViewStyle(PageTabViewStyle())
                                            .frame(height: 210)
                                            .padding(.top, 150)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.top, -150)
                                }
                            }
                        }.padding(.horizontal, 10)
                        Spacer()
                    }
                }.padding(.top, 50)
                    .padding(.bottom, 30)

            }.clipShape(UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 35.0, topTrailing: 35.0)))
                .padding(.bottom, -40)

        }.scrollIndicators(.hidden)
    }

/// Creates an array of grid items based on the current size class.
///
/// - Returns: An array of grid items.
private func createGridItems() -> [GridItem] {
    let columns: [GridItem]

    if verticalSizeClass == .regular {
        columns = [GridItem(.flexible(minimum: 300))]
    } else {
        columns = [
            GridItem(.flexible(minimum: 120)),
            GridItem(.flexible(minimum: 120)),
            GridItem(.flexible(minimum: 120)),
        ]
    }
    return columns
}
}

#Preview {
    SkillsAndLanguagesView()
}
