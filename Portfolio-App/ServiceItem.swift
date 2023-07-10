//
//  ServiceItem.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import Foundation

/// A struct that represents a service item.
struct ServicesItem: Hashable {
    /// The title of the service item.
    let title: String

    /// The name of the icon used to represent the service item.
    let icon: String

    /// The text displayed in the service item.
    let text: String
}