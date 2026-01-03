//
//  LavaRenderer.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 1/3/26.
//

import SwiftUI
import MetalKit

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
    public var blobs: [SIMD4<Float>] = []
    let startTime = Date()

    public init?(device: MTLDevice) {
        self.device = device
        guard let q = device.makeCommandQueue() else { return nil }
        self.commandQueue = q
        do {
            guard let library = device.makeDefaultLibrary() else { return nil }

            let vertexFunction = library.makeFunction(name: "vertex_main")
            let fragmentFunction = library.makeFunction(name: "fragment_main")

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
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else { return }
        
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        encoder.setRenderPipelineState(pipelineState)
        
        let vertices: [SIMD2<Float>] = [[-1, -1], [1, -1], [-1, 1], [1, -1], [1, 1], [-1, 1]]
        encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<SIMD2<Float>>.stride, index: 0)
        
        let time = Float(Date().timeIntervalSince(startTime))
        
        var uniforms = Uniforms(
            resolution: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            blobCount: Int32(blobs.count),
            threshold: 0.38,
            time: time
        )
        
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        if !blobs.isEmpty {
            encoder.setFragmentBytes(blobs, length: blobs.count * MemoryLayout<SIMD4<Float>>.stride, index: 1)
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
        
        view.drawableSize = view.bounds.size
        
        if let device = view.device {
            let renderer = LavaRenderer(device: device)
            context.coordinator.renderer = renderer
            view.delegate = renderer
        }
        return view
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {
        let width = Float(containerSize.width)
        let height = Float(containerSize.height)
        
        var data = blobs.filter { $0.status != .idle }.map { blob in
            return SIMD4(Float(blob.position.x) / width, Float(blob.position.y) / height, Float(blob.baseRadius) / height, blob.wobbleSeed)
        }
        
        let decorativeRadius: Float = 0.10
        let marginPxForSpacing: Float = 60

        let usableWidth = 0.6
        let countAcross = Int((width) * 0.1)

        let topY = 1.0 + 0.15
        let step: Float = (countAcross > 1) ? (Float(usableWidth) / Float(countAcross - 1)) : 0.0
        let startX: Float = 0.2
        for i in 0..<countAcross {
            let x = startX + Float(i) * step
            data.append(SIMD4(x, Float(topY), decorativeRadius, 1000.0 + Float(i)))
        }

        let bottomY = 0.0 - 0.3
        for i in 0..<countAcross {
            let x = startX + Float(i) * step
            data.append(SIMD4(x, Float(bottomY), decorativeRadius, 2000.0 + Float(i)))
        }

      
        uiView.drawableSize = uiView.bounds.size

        context.coordinator.renderer?.blobs = data
    }
    
    public class Coordinator { public var renderer: LavaRenderer? }
}

