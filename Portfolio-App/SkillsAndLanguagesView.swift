//
//  SkillsAndLanguagesView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 27.06.23.
//

import SwiftUI

struct SkillsAndLanguagesView: View {
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// The progress skill categories to display.
    let data: [ProgressSkillCategory] = [ProgressSkillCategory(name: "Programming Languages\n& Technologies", skills: [ProgressSkill(name: "Java", progress: 1), ProgressSkill(name: "JavaScript", progress: 1), ProgressSkill(name: "SQL/Datenbanken", progress: 1), ProgressSkill(name: "ASP.NET", progress: 1), ProgressSkill(name: "C", progress: 1), ProgressSkill(name: "C++", progress: 1), ProgressSkill(name: "C#", progress: 1), ProgressSkill(name: "Objective-C", progress: 1), ProgressSkill(name: "Kotlin", progress: 1), ProgressSkill(name: "Swift", progress: 1), ProgressSkill(name: "Clojure", progress: 3 / 5), ProgressSkill(name: "Python", progress: 3 / 5), ProgressSkill(name: "Latex", progress: 3 / 5)], icon: "chevron.left.forwardslash.chevron.right", font: .title2),
                                         ProgressSkillCategory(name: "Spoken Languages", skills: [ProgressSkill(name: "German", progress: 1), ProgressSkill(name: "English", progress: 1)], icon: "person.wave.2", font: .title),
                                         ProgressSkillCategory(name: "Software Tools", skills: [ProgressSkill(name: "Xcode", progress: 1), ProgressSkill(name: "Visual Studio", progress: 1), ProgressSkill(name: "Android Studio", progress: 1), ProgressSkill(name: "Eclipse", progress: 1), ProgressSkill(name: "Microsoft Office", progress: 1), ProgressSkill(name: "3Ds Max", progress: 3 / 5), ProgressSkill(name: "Adobe CC Master Suite", progress: 1), ProgressSkill(name: "Unity", progress: 2 / 5), ProgressSkill(name: "Unreal Engine", progress: 3 / 5)], icon: "pencil.slash", font: .title)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Skills & Languages")
                        .font(.system(.largeTitle, design: .rounded).bold())
                    Text("A quick snapshot of what I use daily")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .glassyCard(cornerRadius: 32, padding: 20)
                .padding(.top, 24)

                ForEach(data, id: \.id) { category in
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: category.icon)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(
                                    LinearGradient(colors: [.purple, .purple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Text(category.name.replacingOccurrences(of: "\n", with: " "))
                                .font(.system(.headline, design: .rounded).bold())

                            Spacer()
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(category.skills, id: \.id) { skill in
                                    VStack(spacing: 12) {
                                        CircularProgressView(progress: skill.progress, text: "", strokeLineWidth: 7)
                                            .frame(width: 76, height: 76)

                                        Text(skill.name)
                                            .font(.system(.caption, design: .rounded).weight(.medium))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: 110, height: 140)
                                    .background(.ultraThinMaterial.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                    .glassyCard(cornerRadius: 32, padding: 20)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }
}

#Preview {
    SkillsAndLanguagesView()
}
