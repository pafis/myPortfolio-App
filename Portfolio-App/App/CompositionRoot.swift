//
//  CompositionRoot.swift
//  Portfolio-App
//
//  Created by assistant.
//

import Foundation

/// A simple dependency container for application-scoped services.
@MainActor
final class AppDependencyContainer {
    // Shared motion service used by physics/visuals.
    lazy var motionService: MotionServiceProtocol = MotionManager()

    // Shared chat service used across the app.
    lazy var chatService: ChatService = ChatService()

    // Shared view model for the home/content screen.
    lazy var contentViewModel: ContentViewModel = ContentViewModel()

    init() {}
}
