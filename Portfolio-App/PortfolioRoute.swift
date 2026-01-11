//
//  PortfolioRoute.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 09.01.26.
//

import Foundation

enum PortfolioRoute: String, Identifiable {
    case info
    case services
    case skillsAndLanguages
    case experience
    case education
    case aboutMe

    var id: String { rawValue }
}
