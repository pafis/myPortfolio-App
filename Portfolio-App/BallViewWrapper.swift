//
//  BallViewWrapper.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

class BallViewWrapper: UIView {
    var ball: Ball // A Ball object that contains information about the ball
    let label: UILabel = .init() // A label to display the name of the ball
    private var imageView = UIImageView() // An image view to display the image of the ball
    var isTapped = false // A boolean to indicate if the ball has been tapped
    let dynamicItemBehavior: UIDynamicItemBehavior // A dynamic item behavior to add physics to the ball

    // MARK: - Overrides
    override var center: CGPoint {
        get { return super.center }
        set { super.center = newValue }
    }

    // MARK: - Initializers
    init(frame: CGRect, ball: Ball) {
        self.ball = ball

        dynamicItemBehavior = UIDynamicItemBehavior(items: [])
        imageView = UIImageView(image: ball.image)
        imageView.contentMode = .scaleAspectFill

        super.init(frame: frame)
        imageView.layer.cornerRadius = bounds.width / 2
        imageView.clipsToBounds = true
        backgroundColor = self.ball.color
        addSubview(imageView)
        sendSubviewToBack(imageView)
        setupLabel()
        setupDynamics()
    }
 override func layoutSubviews() {
            super.layoutSubviews()
            imageView.frame = bounds
        }
    required init?(coder: NSCoder) {
        ball = Ball(level: 0, name: "Pascal Fischer", view: AnyView(EmptyView()), image: UIImage(), textSize: 10)
        dynamicItemBehavior = UIDynamicItemBehavior(items: [])

        super.init(coder: coder)
        setupDynamics()

        setupLabel()
    }

    // MARK: - Public Methods
    func openView(onDisappear: @escaping () -> Void) {
        ball.view.onDisappear(perform: onDisappear)
        let modalViewController = UIHostingControllerWithCompletion(rootView: ball.view)
        modalViewController.dismissalCompletion = onDisappear
        modalViewController.modalPresentationStyle = .pageSheet

        UIApplication.shared.windows.first?.rootViewController?.present(modalViewController, animated: true, completion: nil)
    }

    func closeView() {
        return
            UIView.animate(withDuration: 0.3) {
                self.transform = .identity
                self.alpha = 1.0
            } completion: { _ in
                self.isTapped = false
            }
    }

    func addLinearVelocity(velocity: CGPoint) {
        dynamicItemBehavior.addLinearVelocity(velocity, for: self)
    }

    // MARK: - Private Methods
    /// Sets up the label to display the name of the ball.
    private func setupLabel() {
        label.textAlignment = .center
        label.textColor = .white
        label.text = ball.name
        label.font = UIFont.systemFont(ofSize: ball.textSize)
        addSubview(label)

        // Adjust the label's position to be centered within the view
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    /// Sets up the dynamics for the ball.
    private func setupDynamics() {
        dynamicItemBehavior.addItem(self)
        dynamicItemBehavior.angularResistance = 10
        dynamicItemBehavior.friction = 1
        dynamicItemBehavior.elasticity = 0.1
        dynamicItemBehavior.resistance = 1
        dynamicItemBehavior.density = 2
        dynamicItemBehavior.allowsRotation = false

        layer.cornerRadius = bounds.width / 2

        guard let superview = superview else { return }
        let animator = UIDynamicAnimator(referenceView: superview)
        animator.addBehavior(dynamicItemBehavior)
    }

    // MARK: - UIDynamicItem
    override var collisionBoundsType: UIDynamicItemCollisionBoundsType {
        return .ellipse
    }
}