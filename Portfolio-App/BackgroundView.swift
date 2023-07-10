//
//  BackgroundView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 29.06.23.
//
import CoreMotion
import SwiftUI

/// This is the background view used as a background for all views
struct BackgroundView: View {
    // State variables to hold the circles and the motion manager
    @State private var circles: [CircleData] = []
    @StateObject private var motionManager = MotionManager()

    // The body of the view
    var body: some View {
        ZStack {
            // A linear gradient that fades from blue to white
            LinearGradient(
                gradient: Gradient(colors: [Color.blue, Color.white]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // A loop that creates a circle for each circle data object
            ForEach(circles) { circle in
                Circle()
                    .foregroundColor(circle.color.opacity(circle.opacity))
                    .frame(width: circle.size, height: circle.size)
                    .position(circle.position)
            }
        }
        // Start animating and start the gyroscope updates when the view appears
        .onAppear {
            startAnimating()
            motionManager.startGyroscopeUpdates()
        }
        // Stop the gyroscope updates when the view disappears
        .onDisappear {
            motionManager.stopGyroscopeUpdates()
        }
    }

    // A private function that starts the animation timer
    private func startAnimating() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation {
                updateCircles()
            }
        }
    }

    // A private function that updates the circle data objects
    private func updateCircles() {
        // Remove any circles that are done animating
        circles = circles.filter { !$0.isDone }

        // Add a new circle if there are less than 10 circles
        if circles.count < 10 {
            circles.append(CircleData())
        }

        // Get the rotation rate from the motion manager
        let rotationRate = motionManager.rotationRate

        // Loop through each circle data object and update its position and velocity
        for i in 0 ..< circles.count {
            let circle = circles[i]

            // Calculate the new position of the circle
            var newPosition = circle.position.applying(
                CGAffineTransform(translationX: circle.velocity.x, y: circle.velocity.y)
            )

            // Calculate the new velocity of the circle
            let newVelocity: CGPoint

            if newPosition.x < 0 || newPosition.x > UIScreen.main.bounds.width {
                newVelocity = CGPoint(x: -circle.velocity.x, y: CGFloat.random(in: -5 ... 5))
            } else if newPosition.y < 0 || newPosition.y > UIScreen.main.bounds.height {
                newVelocity = CGPoint(x: CGFloat.random(in: -5 ... 5), y: -circle.velocity.y)
            } else {
                newVelocity = circle.velocity
            }

            // Apply gyroscope data to the movement
            let gyroscopeFactor: CGFloat = 0.5
            newPosition.x += rotationRate.y * gyroscopeFactor
            newPosition.y -= rotationRate.x * gyroscopeFactor

            // Update the circle data object with the new position and velocity
            circles[i].position = newPosition
            circles[i].velocity = newVelocity
        }
    }
}


// A preview of the background view
#Preview {
    BackgroundView()
}
