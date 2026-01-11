//
//  RTFResourceLoader.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 09.01.26.
//

import Foundation
import SwiftUI

enum RTFResourceLoader {
    static func loadAttributedString(named name: String, fileExtension: String = "rtf") -> AttributedString? {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else { return nil }
        guard let text = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) else { return nil }

#if canImport(UIKit)
        return try? AttributedString(text, including: \.uiKit)
#elseif canImport(AppKit)
        return try? AttributedString(text, including: \.appKit)
#else
        return AttributedString(text.string)
#endif
    }
}
