//
//  Ball.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

struct PortfolioMenuItem: Identifiable {
    let id: UUID = UUID()
    // The name of the ball
    let name: String
    // The view of the ball
    let view: AnyView
}