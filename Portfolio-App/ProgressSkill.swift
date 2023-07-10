//
//  ProgressSkill.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import Foundation

/// A struct that represents a progress skill.
struct ProgressSkill {
    /// The unique identifier of the progress skill.
    let id = UUID()

    /// The name of the progress skill.
    var name: String

    /// The progress of the progress skill, represented as a percentage.
    var progress: CGFloat

    /// The width of the stroke line used to draw the progress skill.
    var strokeLineWidth: CGFloat = 10
}
