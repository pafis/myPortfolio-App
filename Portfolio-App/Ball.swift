//
//  Ball.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

// Define a struct called Ball
struct Ball {
    // The level of the ball
    let level: Int
    // The name of the ball
    let name: String
    // The view of the ball
    let view: AnyView
    // The image of the ball
    let image: UIImage
    // The size of the text on the ball
    let textSize: CGFloat
    // The color of the ball, which can be nil if it hasn't been assigned yet
    var color: UIColor?
}