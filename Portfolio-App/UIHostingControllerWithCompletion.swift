//
//  UIHostingControllerWithCompletion.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

/// A custom `UIHostingController` that includes a completion handler for when the view is dismissed.
class UIHostingControllerWithCompletion: UIHostingController<AnyView> {
    /// The completion handler to be called when the view is dismissed.
    var dismissalCompletion: (() -> Void)?

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismissalCompletion?()
    }

    // Implement UIModalPresentationDelegate method
    func presentationControllerDidDismiss(_: UIPresentationController) {
        dismissalCompletion?()
    }
}
