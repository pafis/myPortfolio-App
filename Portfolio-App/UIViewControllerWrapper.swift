//
//  UIViewControllerWrapper.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

/// A wrapper for a `UIViewController` that can be used in a SwiftUI view hierarchy.
struct UIViewControllerWrapper<Content: UIViewController>: UIViewControllerRepresentable {
    /// The modal view controller to be presented.
    let modalViewController: Content

    /// The closure to be called when the view controller is dismissed.
    let onDisappear: () -> Void

    func makeUIViewController(context _: Context) -> UIViewController {
        return modalViewController
    }

    func updateUIViewController(_: UIViewController, context _: Context) {
        // No update needed
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(onDisappear: onDisappear)
    }

    /// A coordinator that handles the dismissal of the view controller.
    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        /// The closure to be called when the view controller is dismissed.
        let onDisappear: () -> Void

        init(onDisappear: @escaping () -> Void) {
            self.onDisappear = onDisappear
            super.init()
        }

        func presentationControllerDidDismiss(_: UIPresentationController) {
            onDisappear()
        }
    }
}