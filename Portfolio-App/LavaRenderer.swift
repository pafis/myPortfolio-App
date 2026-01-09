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

    private static let fullScreenQuad: [SIMD2<Float>] = [
        [-1, -1], [1, -1], [-1, 1],
        [1, -1], [1, 1], [-1, 1]
    ]

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
        
        let vertices = Self.fullScreenQuad
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
    var time: Float
    var showReservoir: Bool = true
    var detailRect: CGRect? = nil

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

        context.coordinator.scratch.removeAll(keepingCapacity: true)
        context.coordinator.scratch.reserveCapacity(blobs.count * 2)

        // Culling keeps the fragment shader loop cost stable even with long chat histories.
        let cullPaddingPx: Float = 320

        // Reservoir definition
        let reservoirY: Float = 1.16
        // Increased base radius so reservoir blobs overlap more and appear fuller
        let reservoirRadius: Float = 0.24

        // Dynamically compute reservoir X positions so wide/landscape layouts
        // get more reservoir blobs. We start from a logical normalized span
        // covering slightly beyond the viewport [-0.15 .. 1.15] (span = 1.3).
        // Choose a target spacing in pixels to keep blobs visually dense but
        // not overlapping. Larger screens will produce more blobs.
        let reservoirSpan: Float = 1.30
        let reservoirLeft: Float = -0.15
        let targetSpacingPx: Float = 140.0 // desired spacing between reservoir centers in px
        // Compute normalized spacing (in x normalized to width)
        let spacingNormFromPx = max(0.01, targetSpacingPx / width)
        // To ensure horizontal overlap we must account for aspect scaling used in the shader:
        // shader scales x by aspect = width/height while radii are normalized to height.
        // For two circles to overlap horizontally: dx_norm * aspect < 2 * reservoirRadius
        // => dx_norm < 2 * reservoirRadius / aspect = 2 * reservoirRadius * (height/width)
        let aspect = width > 0 ? (width / height) : 1.0
        let maxSpacingForOverlap = 2.0 * reservoirRadius * (height / width) * 0.95
        let spacingNorm = min(spacingNormFromPx, maxSpacingForOverlap)
        // Ensure spacingNorm is not tiny or zero
        let finalSpacingNorm = max(0.01, spacingNorm)
        let countFloat = reservoirSpan / finalSpacingNorm
        let reservoirCount = max(5, Int(ceil(countFloat)))
        var reservoirXs: [Float] = []
        if reservoirCount <= 1 {
            reservoirXs = [reservoirLeft + reservoirSpan * 0.5]
        } else {
            let step = reservoirSpan / Float(reservoirCount - 1)
            reservoirXs = (0..<reservoirCount).map { i in reservoirLeft + Float(i) * step }
        }

        func wobbleOffsetPx(seed: Float) -> SIMD2<Float> {
            // Keep wobble in pixel space so it matches label wobble exactly.
            // Amplitude is relative to height so it feels consistent across devices.
            let ampPx = height * 0.008
            let dx = sin(time * 1.2 + seed) * ampPx
            let dy = cos(time * 0.9 + seed) * ampPx
            return SIMD2(dx, dy)
        }

        for blob in blobs {
            guard blob.status != .idle else { continue }
            var px = Float(blob.position.x)
            var py = Float(blob.position.y)

            // Apply wobble only to circle blobs (menu/keyword/dummy blobs).
            if blob.status != .chatBubble && blob.status != .spawningToChat && blob.status != .dismissing {
                let w = wobbleOffsetPx(seed: blob.wobbleSeed)
                px += w.x
                py += w.y
            }

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
                // Chat Bubble Logic
                // No helper circles here. The shader handles merging via a soft aura + bridge boost.
                let shrinkPx: CGFloat = 0
                let wPx = max(blob.bubbleWidth - shrinkPx, 40)
                let hPx = max(blob.bubbleHeight - shrinkPx, 24)

                // Cull by bounds so large chat bubbles don't vanish when their center is offscreen.
                let halfH = Float(hPx) * 0.5
                if (py + halfH) < -cullPaddingPx || (py - halfH) > height + cullPaddingPx {
                    continue
                }

                let w = Float(wPx) / width
                let h = Float(hPx) / height
                let role: Float = (blob.chatRole == .user) ? 1.0 : 0.0

                context.coordinator.scratch.append(
                    BlobData(
                        position: pos,
                        size: SIMD2(w, h),
                        params: SIMD4(1.0, role, blob.wobbleSeed, upwardSpeedN) // type=1 chat rect
                    )
                )
                continue
            }

            // Skip circle blobs far outside the viewport.
            if py < -cullPaddingPx || py > height + cullPaddingPx {
                continue
            }

            // Thermal expansion: hotter blobs appear slightly larger.
            let tempN = Float(max(0, min(1, blob.temperature)))
            // Tag debris as "bubble fragments" so the shader can make them harder to merge.
            let tempParam: Float = (blob.status == .debris) ? -0.2 : tempN
            let expansion = 1.0 + (0.18 * tempN)
            let radiusPx = Float(blob.baseRadius) * expansion

            context.coordinator.scratch.append(
                BlobData(
                    position: pos,
                    size: SIMD2((radiusPx / height) * (blob.isDummy ? 1.0 : 1.0), 0.0),
                    params: SIMD4(0.0, tempParam, blob.wobbleSeed, upwardSpeedN) // type=0 circle, y=temp (negative => debris)
                )
            )
        }

        // Detail modal blob: a single large rect blob (chat-rect style).
        // This is used to get a clean rectangular "blob" behind detail content.
        if let rect = detailRect {
            let cx = Float(rect.midX) / width
            let cy = Float(rect.midY) / height
            let w = Float(rect.width) / width
            let h = Float(rect.height) / height
            context.coordinator.scratch.append(
                BlobData(
                    position: SIMD2(cx, cy),
                    size: SIMD2(w, h),
                    params: SIMD4(1.0, 2.0, 0.0, 0.0) // role=2 => "detail" rect (bigger corner radius)
                )
            )
        }

        // Reservoir: a bottom pool made from multiple large circle blobs.
        // This spans left→right and keeps an organic (non-rect) silhouette.
        if showReservoir {
            // Primary row
            for (i, x) in reservoirXs.enumerated() {
                let seed = Float(i) * 1.2345
                let wob = wobbleOffsetPx(seed: seed)
                let px = x * width + wob.x
                let py = reservoirY * height + wob.y
                let pos = SIMD2(px / width, py / height)
                context.coordinator.scratch.append(
                    BlobData(
                        position: pos,
                        size: SIMD2(reservoirRadius, 0.0),
                        params: SIMD4(0.0, 0.0, seed, 0.0)
                    )
                )
            }

            // Add a staggered second row (half-step horizontally) to remove gaps on wide screens
            if reservoirXs.count >= 2 {
                let step: Float = reservoirXs[1] - reservoirXs[0]
                let halfStep = step * 0.5
                let secondRowY = reservoirY + 0.035
                for (i, x) in reservoirXs.enumerated() {
                    let seed = Float(i) * 1.2345 + 5.0
                    let wob = wobbleOffsetPx(seed: seed)
                    let px = (x + halfStep) * width + wob.x
                    let py = secondRowY * height + wob.y
                    let pos = SIMD2(px / width, py / height)
                    context.coordinator.scratch.append(
                        BlobData(
                            position: pos,
                            size: SIMD2(reservoirRadius * 0.95, 0.0),
                            params: SIMD4(0.0, 0.0, seed, 0.0)
                        )
                    )
                }
            }

            // For very wide screens, add a third row to ensure continuous coverage
            if reservoirXs.count >= 4 && width / height > 1.6 {
                let thirdRowY = reservoirY + 0.07
                for (i, x) in reservoirXs.enumerated() {
                    let seed = Float(i) * 1.2345 + 9.0
                    let wob = wobbleOffsetPx(seed: seed)
                    let px = x * width + wob.x
                    let py = thirdRowY * height + wob.y
                    let pos = SIMD2(px / width, py / height)
                    context.coordinator.scratch.append(
                        BlobData(
                            position: pos,
                            size: SIMD2(reservoirRadius * 0.9, 0.0),
                            params: SIMD4(0.0, 0.0, seed, 0.0)
                        )
                    )
                }
            }
        }

        context.coordinator.renderer?.updateBlobs(context.coordinator.scratch)
    }
    
    public class Coordinator {
        public var renderer: LavaRenderer?
        public var scratch: [BlobData] = []
    }
}


