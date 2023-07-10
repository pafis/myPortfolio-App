//
//  MotionManager.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import CoreMotion


/// A class that manages gyroscope motion updates.
class MotionManager: ObservableObject {
    /// The Core Motion manager used to receive gyroscope updates.
    private let motionManager = CMMotionManager()

    /// The current rotation rate of the device.
    @Published var rotationRate: CMRotationRate = .init()

    /// Starts receiving gyroscope updates.
    func startGyroscopeUpdates() {
        motionManager.gyroUpdateInterval = 0.1

        if motionManager.isGyroAvailable {
            motionManager.startGyroUpdates(to: .main) { data, _ in
                guard let rotationRate = data?.rotationRate else { return }
                self.rotationRate = rotationRate
            }
        }
    }

    /// Stops receiving gyroscope updates.
    func stopGyroscopeUpdates() {
        motionManager.stopGyroUpdates()
    }
}
