import CoreMotion

/// Protocol abstraction over motion input used by the app.
/// Implementations should update `rotationRate` and provide start/stop control.
protocol MotionServiceProtocol: AnyObject {
    var rotationRate: CMRotationRate { get }
    func startGyroscopeUpdates()
    func stopGyroscopeUpdates()
}
