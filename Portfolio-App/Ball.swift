//
//  Ball.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

struct PortfolioMenuItem: Identifiable {
    let id: UUID = UUID()
    let name: String
    let route: PortfolioRoute
}