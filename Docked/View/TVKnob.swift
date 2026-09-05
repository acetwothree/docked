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
    /// false dims the knob and disables its tap — used for the back knob
    /// when there's nowhere to go back to (already on the game grid).
    var enabled: Bool = true
    /// A brighter face + accent-coloured icon and rim — used for the back
    /// knob while it's live, so it visibly reads as "press this" rather than
    /// looking like an inert twin of the other two engraved dials.
    var highlight: Bool = false
    var action: () -> Void

    @State private var pressed = false

    private let d = LayoutSolver.knobDiameter

    var body: some View {
        Button {
            guard enabled else { return }
            pressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { pressed = false }
        } label: {
            ZStack {
                // A soft, diffuse glow behind the dial when highlighted — a
                // plain round shape sized bigger than the knob and layered
                // behind it, so it fades out as a circle. (Drawing this
                // inside the Canvas below clipped it to the Canvas's own
                // square bounds, which showed up as a hard yellow square.)
                if highlight {
                    Circle()
                        .fill(RadialGradient(colors: [Theme.accent.opacity(0.55), .clear],
                                             center: .center, startRadius: d * 0.32, endRadius: d * 0.62))
                        .frame(width: d * 1.55, height: d * 1.55)
                        .allowsHitTesting(false)
                }

                Canvas { ctx, size in
                    let r = min(size.width, size.height) / 2
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let face = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)

                    // knurled rim — short radial ticks around the edge
                    // (skipped when highlighted: cleaner, less busy)
                    if !highlight {
                        var ticks = Path()
                        let count = 24
                        for i in 0..<count {
                            let a = Double(i) / Double(count) * 2 * .pi
                            let ca = CGFloat(cos(a)), sa = CGFloat(sin(a))
                            ticks.move(to: CGPoint(x: c.x + ca * (r - 1.5), y: c.y + sa * (r - 1.5)))
                            ticks.addLine(to: CGPoint(x: c.x + ca * (r - 4.5), y: c.y + sa * (r - 4.5)))
                        }
                        ctx.stroke(ticks, with: .color(palette.key.opacity(0.35)), lineWidth: 1)
                    }

                    // dial face. Normally raised (lit top-left). Highlighted,
                    // it reads as pressed in — light comes from the opposite
                    // corner, like the surface tips away and catches the glow
                    // from below instead.
                    let lightCorner = highlight
                        ? CGPoint(x: c.x + r * 0.3, y: c.y + r * 0.3)
                        : CGPoint(x: c.x - r * 0.28, y: c.y - r * 0.28)
                    ctx.fill(Path(ellipseIn: face.insetBy(dx: 3, dy: 3)),
                             with: .radialGradient(
                                Gradient(colors: highlight
                                         ? [Theme.accent.opacity(0.9), palette.mid, palette.deep]
                                         : [palette.hi, palette.mid, palette.deep]),
                                center: lightCorner, startRadius: 0, endRadius: r * 1.4))

                    // bezel + inner rim — the inner one darker when pressed in
                    ctx.stroke(Path(ellipseIn: face.insetBy(dx: 1, dy: 1)),
                               with: .color(palette.key.opacity(highlight ? 0.85 : 0.7)), lineWidth: 1.5)
                    ctx.stroke(Path(ellipseIn: face.insetBy(dx: 4.5, dy: 4.5)),
                               with: .color(highlight ? palette.deep.opacity(0.5) : palette.hi.opacity(0.4)),
                               lineWidth: 1)
                }

                // engraved icon: dark cut with a hairline light edge below it —
                // or, highlighted, bright white so it pops against the glow
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(highlight ? Color.white : palette.key.opacity(0.62))
                    .shadow(color: highlight ? .black.opacity(0.4) : palette.hi.opacity(0.55),
                            radius: highlight ? 1 : 0, x: highlight ? 0 : 0.7, y: highlight ? 0.6 : 0.9)
            }
            .frame(width: d, height: d)
            .scaleEffect(pressed ? 0.93 : 1)
            .opacity(enabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1.5)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
