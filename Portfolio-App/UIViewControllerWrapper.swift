//
//  UIViewControllerWrapper.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

struct UIViewControllerWrapper<Content: UIViewController>: UIViewControllerRepresentable {
    let modalViewController: Content
    let onDisappear: () -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        return modalViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No update needed
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(onDisappear: onDisappear)
    }
    
    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        let onDisappear: () -> Void
        
        init(onDisappear: @escaping () -> Void) {
            self.onDisappear = onDisappear
            super.init()
        }
        
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            onDisappear()
        }
    }
    
}
