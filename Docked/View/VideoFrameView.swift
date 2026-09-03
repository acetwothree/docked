//
//  VideoFrameView.swift
//  Docked
//
//  A thin pixel-art screen bezel drawn around the floating video. It's just
//  a border (a few px), with chunky stepped corners and four rivets, so the
//  frame stays visible around the PiP window at whatever size the user
//  leaves it — no chunky TV body that would only line up at one exact size.
//

import SwiftUI

struct VideoFrameView: View {
    var layout: VideoLayout
    /// The opening, in this view's local coordinates.
    var hole: CGRect
    var dimHint: Bool

    private var isSmall: Bool { layout.isCorner }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in draw(ctx, size: size) }

            hintView
                .frame(width: max(0, hole.width - 12), height: max(0, hole.height - 12))
                .position(x: hole.midX, y: hole.midY)
                .opacity(dimHint ? 0.16 : 1)
                .animation(.easeInOut(duration: 0.6), value: dimHint)
                .allowsHitTesting(false)
        }
        .accessibilityElement()
        .accessibilityLabel("Video drop zone, \(layout.label)")
    }

    @ViewBuilder private var hintView: some View {
        VStack(spacing: isSmall ? 2 : 6) {
            Image(systemName: "tv.fill")
                .font(.system(size: isSmall ? 13 : 20))
            Text("DRAG YOUR VIDEO HERE")
                .font(.system(size: isSmall ? 8 : 11, weight: .heavy))
                .tracking(isSmall ? 1 : 2.2)
            if !isSmall {
                Text("float your Picture-in-Picture window into the frame")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(Theme.accent)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.6)
        .lineLimit(2)
    }

    private func draw(_ ctx: GraphicsContext, size: CGSize) {
        let w = size.width.rounded(), h = size.height.rounded()
        let K: CGFloat = 2
        let hx = hole.minX.rounded(), hy = hole.minY.rounded()
        let hw = hole.width.rounded(), hh = hole.height.rounded()

        func fill(_ x: CGFloat, _ y: CGFloat, _ ww: CGFloat, _ hh: CGFloat, _ c: Color) {
            guard ww > 0, hh > 0 else { return }
            ctx.fill(Path(CGRect(x: x, y: y, width: ww, height: hh)), with: .color(c))
        }

        // Border only — four strips around the opening.
        // dark keyline
        fill(0, 0, w, hy, Theme.TV.key)                 // top
        fill(0, hy + hh, w, h - hy - hh, Theme.TV.key)  // bottom
        fill(0, hy, hx, hh, Theme.TV.key)               // left
        fill(hx + hw, hy, w - hx - hw, hh, Theme.TV.key) // right
        // tan body inset 2px
        fill(K, K, w - 2*K, hy - K, Theme.TV.tan)
        fill(K, hy + hh + K, w - 2*K, h - hy - hh - 2*K, Theme.TV.tan)
        fill(K, hy, hx - K, hh, Theme.TV.tan)
        fill(hx + hw + K, hy, w - hx - hw - 2*K, hh, Theme.TV.tan)
        // light bevel on the outer top + left, dark on outer bottom + right
        fill(K, K, w - 2*K, K, Theme.TV.hi)
        fill(K, K, K, h - 2*K, Theme.TV.hi)
        fill(K, h - 2*K, w - 2*K, K, Theme.TV.lo)
        fill(w - 2*K, K, K, h - 2*K, Theme.TV.lo)
        // dark line right at the opening + a glow pixel
        fill(hx - K, hy - K, hw + 2*K, K, Theme.TV.key)
        fill(hx - K, hy + hh, hw + 2*K, K, Theme.TV.key)
        fill(hx - K, hy - K, K, hh + 2*K, Theme.TV.key)
        fill(hx + hw, hy - K, K, hh + 2*K, Theme.TV.key)
        // dark glass so the empty opening reads as a screen (covered once PiP lands)
        fill(hx, hy, hw, hh, Theme.TV.glass)

        // chunky stepped outer corners
        func notch(_ cx: CGFloat, _ cy: CGFloat, _ dx: CGFloat, _ dy: CGFloat) {
            fill(cx, cy, 3*K, 3*K, Theme.TV.key)
            fill(cx + dx*K, cy + dy*K, 2*K, 2*K, Theme.TV.tan)
        }
        notch(0, 0, 1, 1); notch(w - 3*K, 0, -1, 1)
        notch(0, h - 3*K, 1, -1); notch(w - 3*K, h - 3*K, -1, -1)

        // four rivets
        func rivet(_ x: CGFloat, _ y: CGFloat) {
            fill(x, y, 2*K, 2*K, Theme.TV.deep)
            fill(x, y, K, K, Theme.TV.hi)
        }
        let ro: CGFloat = 4
        rivet(ro, ro); rivet(w - ro - 2*K, ro)
        rivet(ro, h - ro - 2*K); rivet(w - ro - 2*K, h - ro - 2*K)
    }
}
