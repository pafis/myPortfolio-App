//
//  BackgroundView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 29.06.23.
//
import SwiftUI
import CoreMotion

/// This is the background view used as a background for all views
struct BackgroundView: View {
    @State private var circles: [CircleData] = []
    @StateObject private var motionManager = MotionManager()
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue, Color.white]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ForEach(circles) { circle in
                Circle()
                    .foregroundColor(circle.color.opacity(circle.opacity))
                    .frame(width: circle.size, height: circle.size)
                    .position(circle.position)
            }
        }
        .onAppear {
            startAnimating()
            motionManager.startGyroscopeUpdates()
        }
        .onDisappear {
            motionManager.stopGyroscopeUpdates()
        }
    }
    
    private func startAnimating() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation {
                updateCircles()
            }
        }
    }
    
    private func updateCircles() {
        circles = circles.filter { !$0.isDone }
        
        if circles.count < 10 {
            circles.append(CircleData())
        }
        
        let rotationRate = motionManager.rotationRate
        
        for i in 0..<circles.count {
            let circle = circles[i]
            
            var newPosition = circle.position.applying(
                CGAffineTransform(translationX: circle.velocity.x, y: circle.velocity.y)
            )
            
            let newVelocity: CGPoint
            
            if newPosition.x < 0 || newPosition.x > UIScreen.main.bounds.width {
                newVelocity = CGPoint(x: -circle.velocity.x, y: CGFloat.random(in: -5...5))
            } else if newPosition.y < 0 || newPosition.y > UIScreen.main.bounds.height {
                newVelocity = CGPoint(x: CGFloat.random(in: -5...5), y: -circle.velocity.y)
            } else {
                newVelocity = circle.velocity
            }
            
            // Apply gyroscope data to the movement
            let gyroscopeFactor: CGFloat = 0.5
            newPosition.x += rotationRate.y * gyroscopeFactor
            newPosition.y -= rotationRate.x * gyroscopeFactor
            
            circles[i].position = newPosition
            circles[i].velocity = newVelocity
        }
    }
}

#Preview {
    BackgroundView()
}
