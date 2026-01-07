//
//  LavaRenderer.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 1/3/26.
//

import SwiftUI
import MetalKit

public struct BlobData {
    var position: SIMD2<Float>
    var size: SIMD2<Float>
    var params: SIMD4<Float> // x: type (0=circle, 1=rect), y: role (rect only), z: seed, w: upwardSpeed (normalized/sec)
}

// MARK: - LavaRenderer
final public class LavaRenderer: NSObject, MTKViewDelegate {
    public struct Uniforms {
        var resolution: SIMD2<Float>
        var blobCount: Int32
        var threshold: Float
        var time: Float
    }

    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLRenderPipelineState
    private var blobs: [BlobData] = []
    private let blobsLock = NSLock()

    private static let maxInflightFrames = 3
    private let inflightSemaphore = DispatchSemaphore(value: maxInflightFrames)
    private var inflightIndex: Int = 0
    private var blobBuffers: [MTLBuffer?] = Array(repeating: nil, count: maxInflightFrames)
    private var blobBufferCapacities: [Int] = Array(repeating: 0, count: maxInflightFrames)

    private var emptyBlobBuffer: MTLBuffer?
    let startTime = Date()

    public func updateBlobs(_ newBlobs: [BlobData]) {
        blobsLock.lock()
        blobs = newBlobs
        blobsLock.unlock()
    }

    public init?(device: MTLDevice) {
        self.device = device
        guard let q = device.makeCommandQueue() else { return nil }
        self.commandQueue = q
        do {
            guard let library = device.makeDefaultLibrary() else {
                print("Metal: makeDefaultLibrary() returned nil")
                return nil
            }

            let vertexName = "vertex_lava_main"
            let fragmentName = "fragment_lava_main"

            guard let vertexFunction = library.makeFunction(name: vertexName) else {
                let names = (library.functionNames).sorted().joined(separator: ", ")
                print("Metal: Missing vertex function '\(vertexName)'. Available: [\(names)]")
                return nil
            }

            guard let fragmentFunction = library.makeFunction(name: fragmentName) else {
                let names = (library.functionNames).sorted().joined(separator: ", ")
                print("Metal: Missing fragment function '\(fragmentName)'. Available: [\(names)]")
                return nil
            }

            let pipeline = MTLRenderPipelineDescriptor()
            pipeline.vertexFunction = vertexFunction
            pipeline.fragmentFunction = fragmentFunction
            pipeline.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipeline.colorAttachments[0].isBlendingEnabled = true
            pipeline.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipeline.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

            let state = try device.makeRenderPipelineState(descriptor: pipeline)
            self.pipelineState = state
        } catch {
            print("Shader compilation failed: \(error)")
            return nil
        }
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        _ = inflightSemaphore.wait(timeout: .distantFuture)

        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else { return }
        
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.inflightSemaphore.signal()
        }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        encoder.setRenderPipelineState(pipelineState)
        
        let vertices: [SIMD2<Float>] = [[-1, -1], [1, -1], [-1, 1], [1, -1], [1, 1], [-1, 1]]
        encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<SIMD2<Float>>.stride, index: 0)
        
        let time = Float(Date().timeIntervalSince(startTime))

        blobsLock.lock()
        let blobSnapshot = blobs
        blobsLock.unlock()
        
        var uniforms = Uniforms(
            resolution: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            blobCount: Int32(blobSnapshot.count),
            threshold: 0.7, // Lower => larger/more visible blobs (incl. dummies)
            time: time
        )
        
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        let bufferIndex = inflightIndex
        inflightIndex = (inflightIndex + 1) % Self.maxInflightFrames

        if blobSnapshot.isEmpty {
            if emptyBlobBuffer == nil {
                emptyBlobBuffer = device.makeBuffer(length: MemoryLayout<BlobData>.stride, options: .storageModeShared)
                emptyBlobBuffer?.label = "LavaRenderer.emptyBlobBuffer"
            }
            if let buf = emptyBlobBuffer {
                encoder.setFragmentBuffer(buf, offset: 0, index: 1)
            }
        } else {
            let needed = blobSnapshot.count
            if blobBuffers[bufferIndex] == nil || blobBufferCapacities[bufferIndex] < needed {
                let newCapacity = max(needed, blobBufferCapacities[bufferIndex] * 2, 64)
                let length = newCapacity * MemoryLayout<BlobData>.stride
                blobBuffers[bufferIndex] = device.makeBuffer(length: length, options: .storageModeShared)
                blobBuffers[bufferIndex]?.label = "LavaRenderer.blobBuffer[\(bufferIndex)]"
                blobBufferCapacities[bufferIndex] = newCapacity
            }

            if let buffer = blobBuffers[bufferIndex] {
                let capacity = blobBufferCapacities[bufferIndex]
                let ptr = buffer.contents().bindMemory(to: BlobData.self, capacity: capacity)
                for i in 0..<needed {
                    ptr.advanced(by: i).pointee = blobSnapshot[i]
                }
                encoder.setFragmentBuffer(buffer, offset: 0, index: 1)
            }
        }
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - MetalLavaView (SwiftUI wrapper)
public struct MetalLavaView: UIViewRepresentable {
    var blobs: [MenuBlobState]
    var containerSize: CGSize

    public func makeCoordinator() -> Coordinator { Coordinator() }
    
    public func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm
        view.isOpaque = true
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false

        if let device = view.device, let renderer = LavaRenderer(device: device) {
            context.coordinator.renderer = renderer
            view.delegate = renderer
        }

        return view
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {
        let scale = uiView.contentScaleFactor
        let drawableSize = CGSize(width: uiView.bounds.width * scale, height: uiView.bounds.height * scale)
        if uiView.drawableSize != drawableSize {
            uiView.drawableSize = drawableSize
        }

        let width = Float(containerSize.width)
        let height = Float(containerSize.height)
        guard width > 0, height > 0 else {
            context.coordinator.renderer?.updateBlobs([])
            return
        }

        var data: [BlobData] = blobs.compactMap { blob in
            guard blob.status != .idle else { return nil }
            let px = Float(blob.position.x)
            let py = Float(blob.position.y)
            let pos = SIMD2(px / width, py / height)

            // Upward speed in normalized-units per second (0 when not rising).
            // Coordinate system: y increases downward; upward motion => negative dy.
            let vdy = Float(blob.velocity.dy)
            var upwardSpeedPointsPerSec = max(0.0, -vdy)

            // Fallback: for tick-driven rise/dismiss states, currentSpeed is points-per-tick.
            // This keeps buoyancy deformation visible even if velocity isn't updated (e.g. during view/layout transitions).
            if blob.status == .rising || blob.status == .dismissing {
                let assumedFps: Float = 60.0
                upwardSpeedPointsPerSec = max(upwardSpeedPointsPerSec, Float(blob.currentSpeed) * assumedFps)
            }
            let upwardSpeedN = (height > 0) ? (upwardSpeedPointsPerSec / height) : 0.0

            if blob.status == .chatBubble || blob.status == .spawningToChat || blob.status == .dismissing {
                
                let shrinkPx: CGFloat = -10
                let wPx = max(blob.bubbleWidth - shrinkPx, 40)
                let hPx = max(blob.bubbleHeight - shrinkPx, 24)
                let w = Float(wPx) / width
                let h = Float(hPx) / height
                let role: Float = (blob.chatRole == .user) ? 1.0 : 0.0
                return BlobData(
                    position: pos,
                    size: SIMD2(w, h),
                    params: SIMD4(1.0, role, blob.wobbleSeed, upwardSpeedN) // type=1 chat rect
                )
            }

            return BlobData(
                position: pos,
                size: SIMD2((Float(blob.baseRadius) / height) * (blob.isDummy ? 1.25 : 1.0), 0.0),
                params: SIMD4(0.0, 0.0, blob.wobbleSeed, upwardSpeedN) // type=0 circle
            )
        }

        // Reservoir: a bottom pool made from multiple large circle blobs.
        // This spans left→right and keeps an organic (non-rect) silhouette.
        let reservoirY: Float = 1.3 
        let reservoirRadius: Float = 0.18 
        let reservoirXs: [Float] = [-0.15, 0.15, 0.50, 0.85, 1.15]
        for x in reservoirXs {
            data.append(
                BlobData(
                    position: SIMD2(x, reservoirY),
                    size: SIMD2(reservoirRadius, 0.0),
                    params: SIMD4(0.0, 0.0, 0.0, 0.0) 
                )
            )
        }

        context.coordinator.renderer?.updateBlobs(data)
    }
    
    public class Coordinator { public var renderer: LavaRenderer? }
}


