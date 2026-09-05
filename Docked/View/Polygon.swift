//
//  Polygon.swift
//  Docked
//
//  A regular N-gon inscribed in its frame, pointy-top. Used for the hexagon
//  in Hex Fall (and its home-grid preview icon).
//

import SwiftUI

struct Polygon: Shape {
    var sides: Int

    func path(in rect: CGRect) -> Path {
        guard sides >= 3 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<sides {
            let angle = Double(i) / Double(sides) * 2 * .pi - .pi / 2
            let pt = CGPoint(x: center.x + radius * CGFloat(cos(angle)),
                             y: center.y + radius * CGFloat(sin(angle)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
