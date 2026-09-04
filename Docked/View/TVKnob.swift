//
//  TVKnob.swift
//  Docked
//
//  A console knob for the TV cabinet: a round, lightly knurled dial with the
//  icon engraved into its face. Presses in briefly on tap — no spinning, no
//  floating chips, nothing that reads as a modern UI button.
//

import SwiftUI

struct TVKnob: View {
    var icon: String
    var palette: TVPalette
    var action: () -> Void

    @State private var pressed = false

    private let d = LayoutSolver.knobDiameter

    var body: some View {
        Button {
            pressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { pressed = false }
        } label: {
            ZStack {
                Canvas { ctx, size in
                    let r = min(size.width, size.height) / 2
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let face = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)

                    // knurled rim — short radial ticks around the edge
                    var ticks = Path()
                    let count = 24
                    for i in 0..<count {
                        let a = Double(i) / Double(count) * 2 * .pi
                        let ca = CGFloat(cos(a)), sa = CGFloat(sin(a))
                        ticks.move(to: CGPoint(x: c.x + ca * (r - 1.5), y: c.y + sa * (r - 1.5)))
                        ticks.addLine(to: CGPoint(x: c.x + ca * (r - 4.5), y: c.y + sa * (r - 4.5)))
                    }
                    ctx.stroke(ticks, with: .color(palette.key.opacity(0.35)), lineWidth: 1)

                    // dial face — raised: light from top-left
                    ctx.fill(Path(ellipseIn: face.insetBy(dx: 3, dy: 3)),
                             with: .radialGradient(
                                Gradient(colors: [palette.hi, palette.mid, palette.deep]),
                                center: CGPoint(x: c.x - r * 0.28, y: c.y - r * 0.28),
                                startRadius: 0, endRadius: r * 1.4))

                    // bezel + inner rim
                    ctx.stroke(Path(ellipseIn: face.insetBy(dx: 1, dy: 1)),
                               with: .color(palette.key.opacity(0.7)), lineWidth: 1.5)
                    ctx.stroke(Path(ellipseIn: face.insetBy(dx: 4.5, dy: 4.5)),
                               with: .color(palette.hi.opacity(0.4)), lineWidth: 1)
                }

                // engraved icon: dark cut with a hairline light edge below it
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(palette.key.opacity(0.62))
                    .shadow(color: palette.hi.opacity(0.55), radius: 0, x: 0.7, y: 0.9)
            }
            .frame(width: d, height: d)
            .scaleEffect(pressed ? 0.93 : 1)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1.5)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
