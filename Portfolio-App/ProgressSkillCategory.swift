//
//  ProgressSkillCategory.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

/// A struct that represents a category of progress skills.
struct ProgressSkillCategory {
    /// The unique identifier of the progress skill category.
    let id = UUID()

    /// The name of the progress skill category.
    var name: String

    /// The progress skills in the progress skill category.
    var skills: [ProgressSkill]

    /// The name of the icon used to represent the progress skill category.
    var icon: String

    /// The font used to display the progress skill category name.
    var font: Font
}
