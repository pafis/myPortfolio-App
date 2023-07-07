//
//  BallContainerView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI
class BallContainerView: UIView, UICollisionBehaviorDelegate {
    private var dynamicAnimator: UIDynamicAnimator!
     private var collisionBehavior: UICollisionBehavior!
     private var fieldBehavior: UIFieldBehavior!
    var balls: [Ball]

    init(balls: [Ball]) {
        self.balls = balls
        super.init(frame: .zero)
        setupDynamics()
    }
    func randomColor() -> UIColor {
        /*let saturation: CGFloat = 0.9
            let brightness: CGFloat = 0.9
            
            let hue = CGFloat.random(in: 0...1) // Random hue value between 0 and 1*/
        let colors:[UIColor] = [.red, .green, .blue, .orange, .purple]
    
            
        return colors.randomElement() ?? .red

    }
    override func setNeedsLayout() {
        super.setNeedsLayout()
        self.setupDynamics()
    }
    required init?(coder: NSCoder) {
        self.balls = []
        super.init(coder: coder)
        setupDynamics()
    }
    
     func setupDynamics() {
        dynamicAnimator = UIDynamicAnimator(referenceView: self)
        collisionBehavior = UICollisionBehavior()
        collisionBehavior.translatesReferenceBoundsIntoBoundary = true
        dynamicAnimator.addBehavior(collisionBehavior)
        
        fieldBehavior = UIFieldBehavior.springField()
        fieldBehavior.strength = 0.4
        fieldBehavior.position = CGPoint(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2)
        dynamicAnimator.addBehavior(fieldBehavior)
        collisionBehavior.collisionDelegate = self
        updateBalls(balls)
    
    }
    
    func updateBalls(_ balls: [Ball]) {
        self.balls = balls
        removeAllBallViews()
        
        for (index,ball) in self.balls.enumerated() {
            let size: CGFloat = CGFloat(50 + 50 * ball.level)
            let minX = 50
            let maxX = UIScreen.main.bounds.width - size
            let minY = 50
            let maxY = UIScreen.main.bounds.height - size
            
            let x = CGFloat.random(in: CGFloat(minX)...maxX)
            let y = CGFloat.random(in: CGFloat(minX)...maxX)
            
            if(self.balls[index].color == nil)
            {
                self.balls[index].color = randomColor()
            }
            
            let ballView = BallViewWrapper(frame: CGRect(x: x, y: y, width: size, height: size), ball: ball)
            ballView.layer.cornerRadius = size / 2
            ballView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            addSubview(ballView)
            collisionBehavior.addItem(ballView)
            fieldBehavior.addItem(ballView)
            
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            ballView.addGestureRecognizer(tapGestureRecognizer)
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            ballView.addGestureRecognizer(panGestureRecognizer)
            var delay =  Double(index) * 0.15
            if ball.level>=3 {
                delay = 0
            }
            UIView.animate(withDuration: 0.3, delay: delay, options: [], animations: {
                        ballView.transform = .identity
                    }, completion: nil)
        }
    }
    
    private func removeAllBallViews() {
        subviews.forEach { view in
            if let ballView = view as? BallViewWrapper {
                collisionBehavior.removeItem(ballView)
                fieldBehavior.removeItem(ballView)
                ballView.removeFromSuperview()
            }
        }
    }
    
    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: self)
        let velocity = gestureRecognizer.velocity(in: self)
        
        switch gestureRecognizer.state {
        case .changed:
            guard let ballView = gestureRecognizer.view as? BallViewWrapper else {
                return
            }
            ballView.center.x += translation.x
            ballView.center.y += translation.y
            
           
            
            ballView.addLinearVelocity(velocity: CGPoint(x: 1,y: 1))
            let push =  UIPushBehavior(items: [ballView], mode: .continuous)
            push.magnitude=4
            //ballView.dynamicItemBehavior.addChildBehavior(push)
            dynamicAnimator.updateItem(usingCurrentState: gestureRecognizer.view!)
            gestureRecognizer.setTranslation(.zero, in: self)
        case .ended, .cancelled, .failed:
            guard let ballView = gestureRecognizer.view as? BallViewWrapper else {
                return
            }
            break
        default:
            break
        }
    }


    
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
        var isReadyToDismiss = false;
        for (index,ballView) in animatedBalls.enumerated() {
            if(index <= animatedBalls.count){
                isReadyToDismiss = true;
            }
            var delay = 0.4 / Double(index + 1)
            if(ballView.ball.level >= 4)
            {delay = 0 }
            
            
            
            dynamicAnimator.removeAllBehaviors()
            UIView.animate(withDuration: 0.3, delay: delay, options: [], animations: {
            
                ballView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                   
                self.dynamicAnimator.updateItem(usingCurrentState: ballView)

            },completion: {finshed in
            
                if(!isReadyToDismiss) {return}
                let balls = self.balls
                
                self.removeAllBallViews()
                tappedBallView.openView(onDisappear:{
                    self.setupDynamics()
                    self.updateBalls(balls)})
                
            })
        }
    }

}
