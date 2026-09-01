//
//  Theme.swift
//  Docked
//
//  Small, central place for the cozy visual language: one warm accent,
//  a couple of adaptive "paper / ink" tones for the drawing surfaces,
//  and the spring used for every layout reflow.
//

import SwiftUI
import UIKit

enum Theme {

    /// Corner radius shared by cards and canvases.
    static let corner: CGFloat = 22

    /// Inset used inside the content area.
    static let pagePadding: CGFloat = 16

    /// The one animation used whenever the layout shifts around the video.
    static let layoutAnimation: Animation = .spring(response: 0.45, dampingFraction: 0.86)

    /// Warm amber accent. Defined as a literal (not the asset) so it renders
    /// identically inside `Canvas`, which has no environment tint.
    static let accent = Color(red: 0.96, green: 0.72, blue: 0.42)

    /// Adaptive "paper" surface for the doodle pad and notes card.
    static let paper = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.13, blue: 0.16, alpha: 1)
            : UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1)
    })

    /// Adaptive "ink" for strokes / game shapes drawn on `paper`.
    static let ink = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.92, alpha: 1)
            : UIColor(white: 0.10, alpha: 1)
    })

    /// Cozy page backdrop.
    static let backdrop = Color(uiColor: .systemBackground)
}

extension Color {
    /// Build a `Color` from a 6-digit hex string (with or without leading `#`).
    init(hex: String) {
        let raw = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
