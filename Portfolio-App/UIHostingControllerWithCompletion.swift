//
//  UIHostingControllerWithCompletion.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

class UIHostingControllerWithCompletion: UIHostingController<AnyView> {
    var dismissalCompletion: (() -> Void)?

    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
            dismissalCompletion?()
    }
    // Implement UIModalPresentationDelegate method
       func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
           dismissalCompletion?()
       }
}
