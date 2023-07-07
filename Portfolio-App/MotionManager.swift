//
//  MotionManager.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import CoreMotion

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    @Published var rotationRate: CMRotationRate = CMRotationRate()
    
    func startGyroscopeUpdates() {
        motionManager.gyroUpdateInterval = 0.1
        
        if motionManager.isGyroAvailable {
            motionManager.startGyroUpdates(to: .main) { data, error in
                guard let rotationRate = data?.rotationRate else { return }
                self.rotationRate = rotationRate
            }
        }
    }
    
    func stopGyroscopeUpdates() {
        motionManager.stopGyroUpdates()
    }
}
