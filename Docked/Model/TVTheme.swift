//
//  TVTheme.swift
//  Docked
//
//  Cabinet colour schemes for the TV set. Cycled by the swatch knob on the
//  console; the choice persists.
//

import SwiftUI

struct TVPalette {
    let key: Color     // dark keylines / engraving
    let hi: Color      // top highlight of the wood / knob
    let tan: Color     // main cabinet colour
    let mid: Color     // knob body / mid tone
    let lo: Color      // shaded lower edge
    let deep: Color    // rivets / deepest shade
}

enum TVTheme: String, CaseIterable, Identifiable {
    case walnut, charcoal, cream, sage

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var next: TVTheme {
        let all = TVTheme.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }

    var palette: TVPalette {
        switch self {
        case .walnut:
            return TVPalette(
                key:  Color(red: 0.13, green: 0.10, blue: 0.08),
                hi:   Color(red: 0.91, green: 0.80, blue: 0.61),
                tan:  Color(red: 0.55, green: 0.38, blue: 0.24),
                mid:  Color(red: 0.71, green: 0.53, blue: 0.31),
                lo:   Color(red: 0.34, green: 0.23, blue: 0.14),
                deep: Color(red: 0.22, green: 0.15, blue: 0.09))
        case .charcoal:
            return TVPalette(
                key:  Color(red: 0.05, green: 0.05, blue: 0.06),
                hi:   Color(red: 0.62, green: 0.64, blue: 0.68),
                tan:  Color(red: 0.20, green: 0.21, blue: 0.24),
                mid:  Color(red: 0.30, green: 0.31, blue: 0.35),
                lo:   Color(red: 0.12, green: 0.13, blue: 0.15),
                deep: Color(red: 0.07, green: 0.07, blue: 0.09))
        case .cream:
            return TVPalette(
                key:  Color(red: 0.36, green: 0.32, blue: 0.26),
                hi:   Color(red: 1.00, green: 0.98, blue: 0.92),
                tan:  Color(red: 0.90, green: 0.85, blue: 0.74),
                mid:  Color(red: 0.82, green: 0.76, blue: 0.63),
                lo:   Color(red: 0.66, green: 0.60, blue: 0.48),
                deep: Color(red: 0.50, green: 0.45, blue: 0.35))
        case .sage:
            return TVPalette(
                key:  Color(red: 0.11, green: 0.16, blue: 0.13),
                hi:   Color(red: 0.78, green: 0.85, blue: 0.72),
                tan:  Color(red: 0.42, green: 0.51, blue: 0.40),
                mid:  Color(red: 0.53, green: 0.62, blue: 0.50),
                lo:   Color(red: 0.27, green: 0.34, blue: 0.26),
                deep: Color(red: 0.18, green: 0.24, blue: 0.18))
        }
    }
}
