//
//  VideoFrameView.swift
//  Docked
//
//  The whole TV set, drawn as one wood cabinet: the screen opening near the
//  top (the app background shows through, so unfilled PiP area reads as
//  letterbox bars) and a console strip along the bottom with a speaker grille,
//  the "DOCKED" name and three recessed knob wells. RootView drops the real
//  knob buttons onto the wells.
//

import SwiftUI

struct VideoFrameView: View {
    /// Screen opening, in this view's local coordinates.
    var hole: CGRect
    /// Console strip, in this view's local coordinates.
    var consoleRect: CGRect
    var dimHint: Bool
    var palette: TVPalette
    var showBadge: Bool = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in draw(ctx, size: size) }

            hintView
                .frame(width: max(0, hole.width - 18), height: max(0, hole.height - 18))
                .position(x: hole.midX, y: hole.midY)
                .opacity(dimHint ? 0.34 : 1)
                .animation(.easeInOut(duration: 0.6), value: dimHint)
                .allowsHitTesting(false)
        }
        .accessibilityElement()
        .accessibilityLabel("Video drop zone")
    }

    @ViewBuilder private var hintView: some View {
        VStack(spacing: 6) {
            Image(systemName: "tv.fill").font(.system(size: 20))
            Text("DRAG YOUR VIDEO HERE")
                .font(.system(size: 11, weight: .heavy)).tracking(2.2)
            Text("your video turns the screen on")
                .font(.system(size: 9.5)).foregroundStyle(.secondary)
        }
        .foregroundStyle(Theme.accent)
        .shadow(color: .black.opacity(0.6), radius: 3)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.6)
        .lineLimit(2)
    }

    private func draw(_ ctx: GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let outerR: CGFloat = 16
        let innerR: CGFloat = min(14, hole.width / 6, hole.height / 6)

        // Pull the opening in on the sides (and a touch on the top) so an
        // offset PiP video never shows a black sliver past the border.
        let innerRect = CGRect(x: hole.minX + 6.5, y: hole.minY + 2.5,
                               width: hole.width - 13, height: hole.height - 5)

        let cabinet = Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: outerR)
        let screen = Path(roundedRect: innerRect, cornerRadius: innerR)

        // --- wood cabinet fill ---
        ctx.fill(cabinet, with: .linearGradient(
            Gradient(colors: [palette.hi.opacity(0.9), palette.tan, palette.lo]),
            startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)))

        // subtle vertical wood streaks
        var streakX: CGFloat = 8
        while streakX < w - 8 {
            ctx.fill(Path(CGRect(x: streakX, y: 4, width: 1, height: h - 8)),
                     with: .color(palette.key.opacity(0.05)))
            streakX += 13
        }

        // --- the screen opening: app background shows through ---
        ctx.fill(screen, with: .color(Theme.backdrop))

        // recess shadow around the screen
        ctx.stroke(screen, with: .color(palette.key.opacity(0.85)), lineWidth: 2.5)
        ctx.stroke(Path(roundedRect: innerRect.insetBy(dx: -3, dy: -3), cornerRadius: innerR + 3),
                   with: .color(palette.hi.opacity(0.35)), lineWidth: 1)

        // --- ridge line between screen area and console ---
        let ridgeY = consoleRect.minY - 2
        ctx.fill(Path(CGRect(x: 6, y: ridgeY, width: w - 12, height: 1.5)),
                 with: .color(palette.key.opacity(0.5)))
        ctx.fill(Path(CGRect(x: 6, y: ridgeY + 1.5, width: w - 12, height: 1)),
                 with: .color(palette.hi.opacity(0.3)))

        // --- speaker grille (left of the console) ---
        let grilleTop = consoleRect.minY + 10
        let grilleBottom = consoleRect.maxY - 10
        var gx = consoleRect.minX + 14
        for _ in 0..<8 {
            ctx.fill(Path(roundedRect: CGRect(x: gx, y: grilleTop, width: 3, height: grilleBottom - grilleTop),
                                       cornerRadius: 1.5),
                     with: .color(palette.key.opacity(0.32)))
            gx += 6
        }

        // --- engraved badge on the console (shifted right of the grille so the
        // drag cue near the bottom-left corner doesn't collide with it) ---
        if showBadge {
            let badge = "DOCKED · FREE iOS APP"
            let bx = gx + 22
            let cy = consoleRect.midY
            let font = Font.system(size: 10, weight: .black, design: .rounded)
            // A light halo in every direction first (carries it on the dark
            // woods), then the dark cut on top (carries it on the pale woods) —
            // so the text always has an edge whatever the console tone is.
            let halo = Text(badge).font(font).foregroundColor(palette.hi.opacity(0.85))
            for off in [CGSize(width: -0.8, height: -0.8), CGSize(width: 0.8, height: -0.8),
                        CGSize(width: -0.8, height: 0.8), CGSize(width: 0.8, height: 0.8)] {
                ctx.draw(halo, at: CGPoint(x: bx + off.width, y: cy + off.height), anchor: .leading)
            }
            ctx.draw(Text(badge).font(font).foregroundColor(palette.deep.opacity(0.95)),
                     at: CGPoint(x: bx, y: cy), anchor: .leading)
        }

        // --- knob wells ---
        for c in LayoutSolver.knobCenters(inConsole: consoleRect) {
            let d = LayoutSolver.knobDiameter + 8
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - d/2, y: c.y - d/2, width: d, height: d)),
                     with: .color(palette.deep.opacity(0.5)))
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - d/2, y: c.y - d/2, width: d, height: d)),
                       with: .color(palette.key.opacity(0.4)), lineWidth: 1)
        }

        // cabinet keyline (no top-corner rivets — the video can drift over
        // the top corners, so there's nothing there to cover).
        ctx.stroke(cabinet, with: .color(palette.key.opacity(0.9)), lineWidth: 1.5)
    }
}
