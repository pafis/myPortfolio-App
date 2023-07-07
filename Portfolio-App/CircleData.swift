//
//  CircleData.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

/// This is the struct storing all the data for the main circle view
struct CircleData: Identifiable {
    let id = UUID()
    let size: CGFloat
    let color: Color
    let opacity: Double
    var position: CGPoint
    var velocity: CGPoint
    var isDone: Bool = false
    
    init() {
        size = CGFloat.random(in: 20...300)
        color = Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
        opacity = Double.random(in: 0.5...1.0)
        position = CGPoint(
            x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
            y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
        )
        velocity = CGPoint(
            x: CGFloat.random(in: 0...1),
            y: CGFloat.random(in: 0...1)
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.5...3.0)) {
            
        }
    }
}
