import Foundation
import CoreGraphics
import simd

/// Converts `MenuBlobState` instances into renderer `BlobData` records.
public enum LavaBlobFactory {
    public static func makeBlobData(
        from blobs: [MenuBlobState],
        containerSize: CGSize,
        time: Float,
        showReservoir: Bool = true,
        detailRect: CGRect? = nil
    ) -> [BlobData] {
        var out: [BlobData] = []
        let width = Float(containerSize.width)
        let height = Float(containerSize.height)
        guard width > 0 && height > 0 else { return out }

        let cullPaddingPx: Float = 320

        let reservoirY: Float = 1.16
        let reservoirRadius: Float = 0.24
        let reservoirSpan: Float = 1.30
        let reservoirLeft: Float = -0.15
        let targetSpacingPx: Float = 140.0

        func wobbleOffsetPx(seed: Float) -> SIMD2<Float> {
            let ampPx = height * 0.008
            let dx = sin(time * 1.2 + seed) * ampPx
            let dy = cos(time * 0.9 + seed) * ampPx
            return SIMD2(dx, dy)
        }

        // Helper to append a blob
        func push(positionPxX px: Float, positionPxY py: Float, size: SIMD2<Float>, params: SIMD4<Float>) {
            let pos = SIMD2(px / width, py / height)
            out.append(BlobData(position: pos, size: size, params: params))
        }

        for blob in blobs {
            if blob.status == .idle { continue }
            var px = Float(blob.position.x)
            var py = Float(blob.position.y)

            if blob.status != .chatBubble && blob.status != .spawningToChat && blob.status != .dismissing {
                let w = wobbleOffsetPx(seed: blob.wobbleSeed)
                px += w.x
                py += w.y
            }

            // Chat bubble (rect) handling
            if blob.status == .chatBubble || blob.status == .spawningToChat || blob.status == .dismissing {
                let wPx = max(blob.bubbleWidth, 40)
                let hPx = max(blob.bubbleHeight, 24)
                let halfH = Float(hPx) * 0.5
                if (py + halfH) < -cullPaddingPx || (py - halfH) > height + cullPaddingPx {
                    continue
                }
                let w = Float(wPx) / width
                let h = Float(hPx) / height
                let role: Float = (blob.chatRole == .user) ? 1.0 : 0.0

                push(positionPxX: px, positionPxY: py, size: SIMD2(w, h), params: SIMD4(1.0, role, blob.wobbleSeed, 0.0))
                continue
            }

            // Circle blobs culling
            if py < -cullPaddingPx || py > height + cullPaddingPx { continue }

            let tempN = Float(max(0, min(1, blob.temperature)))
            let expansion = 1.0 + (0.18 * tempN)
            let radiusPx = Float(blob.baseRadius) * expansion

            push(positionPxX: px, positionPxY: py, size: SIMD2((radiusPx / height), 0.0), params: SIMD4(0.0, blob.status == .debris ? -0.2 : tempN, blob.wobbleSeed, 0.0))
        }

        // Detail rect
        if let rect = detailRect {
            let cx = Float(rect.midX) / width
            let cy = Float(rect.midY) / height
            let w = Float(rect.width) / width
            let h = Float(rect.height) / height
            out.append(BlobData(position: SIMD2(cx, cy), size: SIMD2(w, h), params: SIMD4(1.0, 2.0, 0.0, 0.0)))
        }

        // Reservoir generation
        if showReservoir {
            let spacingNormFromPx = max(0.01, targetSpacingPx / width)
            let maxSpacingForOverlap = 2.0 * reservoirRadius * (height / width) * 0.95
            let spacingNorm = min(spacingNormFromPx, maxSpacingForOverlap)
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

            for (i, x) in reservoirXs.enumerated() {
                let seed = Float(i) * 1.2345
                let wob = wobbleOffsetPx(seed: seed)
                let px = x * width + wob.x
                let py = reservoirY * height + wob.y
                out.append(BlobData(position: SIMD2(px / width, py / height), size: SIMD2(reservoirRadius, 0.0), params: SIMD4(0.0, 0.0, seed, 0.0)))
            }

            if reservoirXs.count >= 2 {
                let step: Float = reservoirXs[1] - reservoirXs[0]
                let halfStep = step * 0.5
                let secondRowY = reservoirY + 0.035
                for (i, x) in reservoirXs.enumerated() {
                    let seed = Float(i) * 1.2345 + 5.0
                    let wob = wobbleOffsetPx(seed: seed)
                    let px = (x + halfStep) * width + wob.x
                    let py = secondRowY * height + wob.y
                    out.append(BlobData(position: SIMD2(px / width, py / height), size: SIMD2(reservoirRadius * 0.95, 0.0), params: SIMD4(0.0, 0.0, seed, 0.0)))
                }
            }

            if reservoirXs.count >= 4 && width / height > 1.6 {
                let thirdRowY = reservoirY + 0.07
                for (i, x) in reservoirXs.enumerated() {
                    let seed = Float(i) * 1.2345 + 9.0
                    let wob = wobbleOffsetPx(seed: seed)
                    let px = x * width + wob.x
                    let py = thirdRowY * height + wob.y
                    out.append(BlobData(position: SIMD2(px / width, py / height), size: SIMD2(reservoirRadius * 0.9, 0.0), params: SIMD4(0.0, 0.0, seed, 0.0)))
                }
            }
        }

        return out
    }
}
