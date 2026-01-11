import Foundation
import simd

/// Shared data models used by the Lava renderer and CPU conversion logic.
public struct BlobData {
    public var position: SIMD2<Float>
    public var size: SIMD2<Float>
    /// params: x: type (0=circle, 1=rect), y: role (rect only), z: seed, w: upwardSpeed (normalized/sec)
    public var params: SIMD4<Float>

    public init(position: SIMD2<Float>, size: SIMD2<Float>, params: SIMD4<Float>) {
        self.position = position
        self.size = size
        self.params = params
    }
}

public struct Uniforms {
    public var resolution: SIMD2<Float>
    public var blobCount: Int32
    public var threshold: Float
    public var time: Float

    public init(resolution: SIMD2<Float>, blobCount: Int32, threshold: Float, time: Float) {
        self.resolution = resolution
        self.blobCount = blobCount
        self.threshold = threshold
        self.time = time
    }
}
