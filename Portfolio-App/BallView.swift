//
//  BallView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 16.06.23.
//
import SwiftUI
import UIKit

/// This is the UIViewController controlling the BallView ("Main Menu")
class UIBallViewController: UIViewController {
    private var ballView: BallContainerView!
    var balls: [Ball] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create an instance of BallView
        ballView = BallContainerView(balls: balls) // Update with your desired initial configuration
        // Add the BallView as a subview
        view.addSubview(ballView)

        // Set up constraints or frame for the BallView
        ballView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ballView.topAnchor.constraint(equalTo: view.topAnchor),
            ballView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ballView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ballView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Perform any necessary setup or configuration before the view appears
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Set up the dynamics for the BallView
        ballView.setupDynamics()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Perform any necessary cleanup or actions before the view disappears
    }
}

struct BallViewController: UIViewControllerRepresentable {
    let balls: [Ball]

    /// Creates a new instance of `UIBallViewController` with the specified `balls`.
    func makeUIViewController(context _: Context) -> UIBallViewController {
        var ballViewController = UIBallViewController()
        ballViewController.balls = balls
        return ballViewController
    }

    /// Updates the `UIBallViewController` with any changes to the `balls`.
    func updateUIViewController(_: UIBallViewController, context _: Context) {
        // Handle any updates to the view controller, if needed
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}