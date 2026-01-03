//
//  BallContainerView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import UIKit

/// A view that contains multiple `BallViewWrapper`s and applies physics to them
class BallContainerView: UIView, UICollisionBehaviorDelegate {
    private var dynamicAnimator: UIDynamicAnimator!
    private var collisionBehavior: UICollisionBehavior!
    private var fieldBehavior: UIFieldBehavior!
    private var displayLink: CADisplayLink?
    private var metaballView: MetalMetaballView?
    var motionManager: MotionManager?
    var balls: [Ball]
    private var currentFieldPosition: CGPoint?

    /// Initializes a new `BallContainerView` with the given balls
    /// - Parameter balls: The balls to add to the container
    init(balls: [Ball]) {
        self.balls = balls
        super.init(frame: .zero)
        setupDynamics()
    }

    /// Generates a random color for the balls
    /// - Returns: A random `UIColor`
    func randomColor() -> UIColor {
        let colors: [UIColor] = [.red, .green, .blue, .orange, .purple]

        return colors.randomElement() ?? .red
    }

    override func setNeedsLayout() {
        super.setNeedsLayout()
        setupDynamics()
    }

    required init?(coder: NSCoder) {
        balls = []
        super.init(coder: coder)
        setupDynamics()
    }

    /// Sets up the dynamic animator and behaviors for the balls
    func setupDynamics() {
        dynamicAnimator = UIDynamicAnimator(referenceView: self)
        collisionBehavior = UICollisionBehavior()
        collisionBehavior.translatesReferenceBoundsIntoBoundary = false
        dynamicAnimator.addBehavior(collisionBehavior)

        fieldBehavior = UIFieldBehavior.springField()
        fieldBehavior.strength = 0.4
        fieldBehavior.position = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
        currentFieldPosition = fieldBehavior.position
        dynamicAnimator.addBehavior(fieldBehavior)
        collisionBehavior.collisionDelegate = self
        setupMetaballViewIfNeeded()
        startDisplayLink()
        updateBalls(balls)
    }

    private func setupMetaballViewIfNeeded() {
        if metaballView == nil {
            let m = MetalMetaballView(frame: bounds)
            m.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            insertSubview(m, at: 0)
            metaballView = m
        }
    }

    private func startDisplayLink() {
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(step))
        displayLink?.preferredFramesPerSecond = 30
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func step() {
        guard let metaballView = metaballView else { return }
        var wrappers: [BallViewWrapper] = []
        var blobs: [MetalMetaballView.Blob] = []
        // read motion rotation for subtle offset
        let rotation = motionManager?.rotationRate ?? .init()
        // scale factors tuned for subtlety
        let offsetX = CGFloat(rotation.y) * -40.0
        let offsetY = CGFloat(rotation.x) * -40.0
        for subview in subviews {
            if let b = subview as? BallViewWrapper {
                wrappers.append(b)
                var center = b.center
                let radius = max(10, b.bounds.width / 2)
                let color = b.ball.color ?? UIColor.systemBlue
                // apply a small parallax offset to blob centers for refraction effect
                center.x += offsetX * 0.5
                center.y += offsetY * 0.5
                blobs.append(MetalMetaballView.Blob(center: center, radius: radius, color: color))
            }
        }

        // Simple merge detection: if two blobs overlap sufficiently, merge them
        if let pair = detectMergePair(in: wrappers) {
            performMerge(pair.0, pair.1)
        }

        // Smoothly move the spring field origin based on device rotation for physical flow
        if let _ = motionManager {
            let target = CGPoint(x: bounds.midX + offsetX * 0.6, y: bounds.midY + offsetY * 0.6)
            if let current = currentFieldPosition {
                // lerp toward target
                let alpha: CGFloat = 0.12
                let nx = current.x + (target.x - current.x) * alpha
                let ny = current.y + (target.y - current.y) * alpha
                currentFieldPosition = CGPoint(x: nx, y: ny)
            } else {
                currentFieldPosition = target
            }
            if let p = currentFieldPosition {
                fieldBehavior.position = p
            }
        }

        metaballView.update(blobs: blobs)
    }

    private func detectMergePair(in wrappers: [BallViewWrapper]) -> (BallViewWrapper, BallViewWrapper)? {
        let count = wrappers.count
        for i in 0..<count {
            let a = wrappers[i]
            if a.isMerging { continue }
            for j in (i+1)..<count {
                let b = wrappers[j]
                if b.isMerging { continue }
                let dx = a.center.x - b.center.x
                let dy = a.center.y - b.center.y
                let dist = sqrt(dx*dx + dy*dy)
                let rA = a.bounds.width/2
                let rB = b.bounds.width/2
                if dist < (rA + rB) * 0.85 {
                    return (a, b)
                }
            }
        }
        return nil
    }

    private func blendColors(_ c1: UIColor, _ c2: UIColor, weight1: CGFloat, weight2: CGFloat) -> UIColor {
        var r1: CGFloat=0, g1: CGFloat=0, b1: CGFloat=0, a1: CGFloat=0
        var r2: CGFloat=0, g2: CGFloat=0, b2: CGFloat=0, a2: CGFloat=0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let w = max(0.001, weight1 + weight2)
        let rr = (r1 * weight1 + r2 * weight2) / w
        let gg = (g1 * weight1 + g2 * weight2) / w
        let bb = (b1 * weight1 + b2 * weight2) / w
        let aa = (a1 * weight1 + a2 * weight2) / w
        return UIColor(red: rr, green: gg, blue: bb, alpha: aa)
    }

    private func performMerge(_ a: BallViewWrapper, _ b: BallViewWrapper) {
        guard !a.isMerging && !b.isMerging else { return }
        a.isMerging = true
        b.isMerging = true

        // Compute merged properties
        let mid = CGPoint(x: (a.center.x + b.center.x)/2, y: (a.center.y + b.center.y)/2)
        let sizeA = a.bounds.width
        let sizeB = b.bounds.width
        let newSize = max(sizeA, sizeB) * 1.15
        let newRadius = newSize / 2

        let colorA = a.ball.color ?? UIColor.systemBlue
        let colorB = b.ball.color ?? UIColor.systemBlue
        // area-weighted blend
        let weightA = pow(sizeA/2, 2)
        let weightB = pow(sizeB/2, 2)
        let blended = blendColors(colorA, colorB, weight1: weightA, weight2: weightB)

        // Choose view and other metadata from the larger ball
        let chosenBall = (sizeA >= sizeB) ? a.ball : b.ball
        var newBall = Ball(level: max(a.ball.level, b.ball.level), name: chosenBall.name, view: chosenBall.view, image: chosenBall.image, textSize: chosenBall.textSize, color: blended, startPosition: mid)

        // Create new wrapper
        let newFrame = CGRect(x: mid.x - newRadius, y: mid.y - newRadius, width: newSize, height: newSize)
        let newWrapper = BallViewWrapper(frame: newFrame, ball: newBall)
        newWrapper.layer.cornerRadius = newRadius
        newWrapper.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        addSubview(newWrapper)
        collisionBehavior.addItem(newWrapper)
        fieldBehavior.addItem(newWrapper)
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        newWrapper.addGestureRecognizer(tapGestureRecognizer)
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        newWrapper.addGestureRecognizer(panGestureRecognizer)

        // Animate creation and removal
        UIView.animate(withDuration: 0.28, animations: {
            newWrapper.transform = .identity
        })

        UIView.animate(withDuration: 0.28, delay: 0.05, options: [], animations: {
            a.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            a.alpha = 0
            b.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            b.alpha = 0
        }, completion: { _ in
            // remove old wrappers from dynamics and superview
            self.collisionBehavior.removeItem(a)
            self.collisionBehavior.removeItem(b)
            self.fieldBehavior.removeItem(a)
            self.fieldBehavior.removeItem(b)
            a.removeFromSuperview()
            b.removeFromSuperview()

            // Update balls model array
            var newBalls: [Ball] = []
            for sub in self.subviews {
                if let bw = sub as? BallViewWrapper {
                    newBalls.append(bw.ball)
                }
            }
            newBalls.append(newBall)
            self.balls = newBalls
            // Persist blended color for the chosen ball name
            if let hex = blended.toHex() {
                var dict = UserDefaults.standard.dictionary(forKey: "ballColors") as? [String: String] ?? [:]
                dict[newBall.name] = hex
                UserDefaults.standard.setValue(dict, forKey: "ballColors")
            }
        })
    }

    /// Updates the ball views with the given balls
    /// - Parameter balls: The balls to update the container with
    func updateBalls(_ balls: [Ball]) {
        self.balls = balls
        removeAllBallViews()

        for (index, ball) in self.balls.enumerated() {

            let size: CGFloat = CGFloat(80 + 30 * ball.level)
            var overlapping = true
            var position = CGPoint.zero

            while overlapping {
                // Generate a random position within the screen bounds
                position = CGPoint(
                    x: CGFloat.random(in: size/2..<UIScreen.main.bounds.width - size/2),
                    y: CGFloat.random(in: size/2..<UIScreen.main.bounds.height - size/2)
                )

                // Check if the new ball overlaps with any existing balls or hits the screen bounds
                overlapping = balls.contains(where: { existingBall in
                    let distance = sqrt(
                        pow(position.x - existingBall.startPosition.x, 2) +
                        pow(position.y - existingBall.startPosition.y, 2)
                    )
                    return distance < size + 5 // Check if distance is less than size
                }) || position.x - size/2 <= 20 || position.x + size/2 >= UIScreen.main.bounds.width - 20 || position.y - size/2 <= 20 || position.y + size/2 >= UIScreen.main.bounds.height - 20
            }


            self.balls[index].startPosition = position

            if self.balls[index].color == nil {
                self.balls[index].color = randomColor()
            }

            let ballView = BallViewWrapper(frame: CGRect(x: ball.startPosition.x, y: ball.startPosition.y, width: size, height: size), ball: ball)
            ballView.layer.cornerRadius = size / 2
            ballView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            addSubview(ballView)
            collisionBehavior.addItem(ballView)
            fieldBehavior.addItem(ballView)

            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            ballView.addGestureRecognizer(tapGestureRecognizer)
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            ballView.addGestureRecognizer(panGestureRecognizer)

            var delay = Double(index) * 0.15

            if ball.level >= 3 {
                delay = 0
            }
            UIView.animate(withDuration: 0.3, delay: delay, options: [], animations: {
                ballView.transform = .identity
            }, completion: nil)
        }
    }

    /// Removes all ball views from the container
    private func removeAllBallViews() {
        subviews.forEach { view in
            if let ballView = view as? BallViewWrapper {
                collisionBehavior.removeItem(ballView)
                fieldBehavior.removeItem(ballView)
                ballView.removeFromSuperview()
            }
        }
    }

    /// Handles panning gestures on the ball views
    /// - Parameter gestureRecognizer: The gesture recognizer that detected the pan gesture
    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: self)

        switch gestureRecognizer.state {
        case .changed:
            guard let ballView = gestureRecognizer.view as? BallViewWrapper else {
                return
            }
            ballView.center.x += translation.x
            ballView.center.y += translation.y

            ballView.addLinearVelocity(velocity: CGPoint(x: 1, y: 1))
            let push = UIPushBehavior(items: [ballView], mode: .continuous)
            push.magnitude = 4
            dynamicAnimator.updateItem(usingCurrentState: gestureRecognizer.view!)
            gestureRecognizer.setTranslation(.zero, in: self)
        case .ended, .cancelled, .failed:
            guard let ballView = gestureRecognizer.view as? BallViewWrapper else {
                return
            }
        default:
            break
        }
    }

    /// Handles tap gestures on the ball views
    /// - Parameter gestureRecognizer: The gesture recognizer that detected the tap gesture
    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let tappedBallView = gestureRecognizer.view as? BallViewWrapper else {
            return
        }

        if tappedBallView.isTapped {
            tappedBallView.closeView()
        }

        // Disable interaction with other balls during the transition
        var animatedBalls = [BallViewWrapper]()
        for subview in subviews {
            if let otherBallView = subview as? BallViewWrapper {
                otherBallView.isUserInteractionEnabled = false
                animatedBalls.append(otherBallView)
            }
        }

        tappedBallView.isTapped = true
        var isReadyToDismiss = false
        for (index, ballView) in animatedBalls.enumerated() {
            if index <= animatedBalls.count {
                isReadyToDismiss = true
            }
            var delay = 0.4 / Double(index + 1)
            if ballView.ball.level >= 4
            { delay = 0 }

            dynamicAnimator.removeAllBehaviors()
            UIView.animate(withDuration: 0.3, delay: delay, options: [], animations: {
                ballView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)

                self.dynamicAnimator.updateItem(usingCurrentState: ballView)

            }, completion: { _ in

                if !isReadyToDismiss { return }
                let balls = self.balls

                self.removeAllBallViews()
                tappedBallView.openView(onDisappear: {
                    self.setupDynamics()
                    self.updateBalls(balls)
                })

            })
        }
    }
}