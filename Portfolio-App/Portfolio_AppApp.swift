//
//  Portfolio_AppApp.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 16.06.23.
//

import SwiftUI

@main
struct Portfolio_AppApp: App {
    // Composition root
    private let container = AppDependencyContainer()

    var body: some Scene {
        WindowGroup {
            ContentView(chatService: container.chatService, model: container.contentViewModel)
        }
    }
}
