//
//  CircleData.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

/// This is the struct storing all the data for the main circle view
struct CircleData: Identifiable {
    let id = UUID() // A unique identifier for the circle
    let size: CGFloat // The size of the circle
    let color: Color // The color of the circle
    let opacity: Double // The opacity of the circle
    var position: CGPoint // The position of the circle
    var velocity: CGPoint // The velocity of the circle
    var isDone: Bool = false // A boolean to indicate if the circle is done animating

    /// Initializes a new instance of `CircleData` with random values for its properties.
    init() {
        size = CGFloat.random(in: 20 ... 300) // Randomly generate the size of the circle
        color = Color(
            red: Double.random(in: 0 ... 1), // Randomly generate the red component of the circle's color
            green: Double.random(in: 0 ... 1), // Randomly generate the green component of the circle's color
            blue: Double.random(in: 0 ... 1) // Randomly generate the blue component of the circle's color
        )
        opacity = Double.random(in: 0.5 ... 1.0) // Randomly generate the opacity of the circle
        position = CGPoint(
            x: CGFloat.random(in: 0 ... UIScreen.main.bounds.width), // Randomly generate the x position of the circle
            y: CGFloat.random(in: 0 ... UIScreen.main.bounds.height) // Randomly generate the y position of the circle
        )
        velocity = CGPoint(
            x: CGFloat.random(in: 0 ... 1), // Randomly generate the x velocity of the circle
            y: CGFloat.random(in: 0 ... 1) // Randomly generate the y velocity of the circle
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.5 ... 3.0)) {} // A placeholder closure for future use
    }
}
