//
//  LavaMenuContainer.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 1/3/26.
//
import SwiftUI

struct LavaMenuContainer: View {
    let menuItems = ["Home", "About", "Work", "Labs", "Store", "Contact"]
    @State private var blobs: [MenuBlobState] = []
    
    @State private var timer = Timer.publish(every: 1 / 60, on: .main, in: .common).autoconnect()
    
    @State private var lastSpawn: Date = .now
    @State private var nextSpawnDelay: TimeInterval = 1.0
    @State private var queueIndex = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                MetalLavaView(blobs: blobs, containerSize: geo.size)
                    .ignoresSafeArea(.all)
              
                ForEach(blobs.indices, id: \.self) { i in
                    let b = blobs[i]
                    if b.status == .rising && !b.isDummy {
                        Text(b.text)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .position(b.position)
                    }
                }
            }
            .onAppear { initialize(geo.size) }
            .onReceive(timer) { _ in update(geo.size) }
        }
        .ignoresSafeArea(.all)
    }

    private func initialize(_ size: CGSize) {
        blobs = menuItems.map { MenuBlobState(text: $0, isDummy: false) }
        for _ in 0..<12 { blobs.append(MenuBlobState(text: "", isDummy: true)) }
    }
    
    // --- 1. SAFE SPAWN (Start them apart) ---
    private func getSafeSpawnX(in width: CGFloat) -> CGFloat {
        let margin: CGFloat = 80
        let minDistance: CGFloat = 120
        let range = margin...(width - margin)
        
        for _ in 0..<10 {
            let candidate = CGFloat.random(in: range)
            let hasCollision = blobs.contains { b in
                !b.isDummy && b.status != .idle && abs(b.position.x - candidate) < minDistance
            }
            if !hasCollision { return candidate }
        }
        return CGFloat.random(in: range)
    }

    // --- 2. TRAFFIC CONTROL (Velocity Braking) ---
    private func adjustTraffic() {
        let laneWidth: CGFloat = 130.0
        let safeDistance: CGFloat = 180.0
        
        for i in blobs.indices {
            blobs[i].currentSpeed = blobs[i].baseSpeed
        }
        
        for i in 0..<blobs.count {
            guard !blobs[i].isDummy, blobs[i].status == .rising else { continue }
            for j in 0..<blobs.count {
                if i == j { continue }
                guard !blobs[j].isDummy, blobs[j].status == .rising else { continue }
                if abs(blobs[i].position.x - blobs[j].position.x) < laneWidth {
                    let distY = blobs[i].position.y - blobs[j].position.y
                    if distY > 0 && distY < safeDistance {
                        blobs[i].currentSpeed = min(blobs[i].currentSpeed, blobs[j].currentSpeed)
                    }
                }
            }
        }
    }

    private func update(_ size: CGSize) {
        let now = Date()
        
        if now.timeIntervalSince(lastSpawn) > nextSpawnDelay {
            if let i = blobs.firstIndex(where: { !$0.isDummy && $0.status == .idle && $0.text == menuItems[queueIndex] }) {
                let safeX = getSafeSpawnX(in: size.width)
                blobs[i].spawn(x: safeX, y: size.height + 80)
                queueIndex = (queueIndex + 1) % menuItems.count
                lastSpawn = now
                nextSpawnDelay = .random(in: 2.0...3.5)
            }
            else if let i = blobs.firstIndex(where: { $0.isDummy && $0.status == .idle }) {
                blobs[i].spawn(x: .random(in: 40...size.width-40), y: size.height + 80)
                lastSpawn = now
                nextSpawnDelay = .random(in: 1.0...2.5)
            }
        }
        
        adjustTraffic()

        for i in blobs.indices where blobs[i].status != .idle {
            switch blobs[i].status {
            case .rising:
                blobs[i].position.y -= blobs[i].currentSpeed
                if blobs[i].position.y < -60 { blobs[i].status = .idle }
            case .waiting:
                if now.timeIntervalSince(blobs[i].waitStart) > blobs[i].waitTime { blobs[i].status = .sinking }
            case .sinking:
                blobs[i].position.y += (blobs[i].baseSpeed * 0.7)
                if blobs[i].position.y > size.height + 100 { blobs[i].status = .idle }
            default: break
            }
        }
    }
}

struct LavaMenuContainer_Previews: PreviewProvider {
    static var previews: some View {
        LavaMenuContainer()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
