//
//  ProgressSkillCategory.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

struct ProgressSkillCategory {
    let id = UUID()
    var name:String
    var skills:[ProgressSkill]
    var icon:String
    var font:Font
}
