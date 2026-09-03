//
//  VideoFrameView.swift
//  Docked
//
//  A thin screen bezel drawn around the floating video. The opening has the
//  same rounded corners as an iOS PiP window, so the border hugs it. Until a
//  video is parked there the opening shows faint "no-signal" colour bars
//  behind the "drag your video here" prompt.
//

import SwiftUI

struct VideoFrameView: View {
    /// The opening, in this view's local coordinates.
    var hole: CGRect
    var dimHint: Bool

    private let barColors: [Color] = [
        Color(hex: "C7C7C7"), Color(hex: "C8C84A"), Color(hex: "4AC8C8"),
        Color(hex: "4AC85A"), Color(hex: "C84AC0"), Color(hex: "C85050"),
        Color(hex: "5060C8"),
    ]

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
            Image(systemName: "tv.fill")
                .font(.system(size: 20))
            Text("DRAG YOUR VIDEO HERE")
                .font(.system(size: 11, weight: .heavy))
                .tracking(2.2)
            Text("your video turns the screen on")
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(Theme.accent)
        .shadow(color: .black.opacity(0.6), radius: 3)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.6)
        .lineLimit(2)
    }

    private func draw(_ ctx: GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let outerR: CGFloat = 13
        let innerR: CGFloat = min(14, hole.width / 6, hole.height / 6)

        // Pull the opening a hair tighter than the measured PiP rect — kills the
        // sliver of black that otherwise shows between the parked video and the
        // border on the left / right (and a touch more off the bottom).
        let innerRect = CGRect(x: hole.minX + 2.5, y: hole.minY + 1,
                               width: hole.width - 5, height: hole.height - 3.5)

        let outerPath = Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: outerR)
        let innerPath = Path(roundedRect: innerRect, cornerRadius: innerR)

        // --- faint "no-signal" colour bars inside the opening ---
        var screen = ctx
        screen.clip(to: innerPath)
        screen.fill(innerPath, with: .color(Theme.TV.glass))
        let bw = innerRect.width / CGFloat(barColors.count)
        for (i, col) in barColors.enumerated() {
            let bar = CGRect(x: innerRect.minX + CGFloat(i) * bw, y: innerRect.minY,
                             width: bw + 1, height: innerRect.height)
            screen.fill(Path(bar), with: .color(col.opacity(0.15)))
        }
        var y = innerRect.minY
        while y < innerRect.maxY {
            screen.fill(Path(CGRect(x: innerRect.minX, y: y, width: innerRect.width, height: 1)),
                        with: .color(.black.opacity(0.14)))
            y += 4
        }

        // --- the bezel: a rounded donut (outer minus inner), even-odd fill ---
        var donut = outerPath
        donut.addPath(innerPath)
        ctx.fill(donut,
                 with: .linearGradient(
                    Gradient(colors: [Theme.TV.hi, Theme.TV.tan, Theme.TV.lo]),
                    startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)),
                 style: FillStyle(eoFill: true))

        // dark keylines: inside the opening + around the outer edge
        ctx.stroke(innerPath, with: .color(Theme.TV.key), lineWidth: 2)
        ctx.stroke(outerPath, with: .color(Theme.TV.key.opacity(0.9)), lineWidth: 1.5)

        // four corner rivets
        for p in [CGPoint(x: 11, y: 11), CGPoint(x: w - 11, y: 11),
                  CGPoint(x: 11, y: h - 11), CGPoint(x: w - 11, y: h - 11)] {
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)),
                     with: .color(Theme.TV.deep))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1, y: p.y - 1, width: 2, height: 2)),
                     with: .color(Theme.TV.hi))
        }
    }
}
