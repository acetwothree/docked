//
//  VideoFrameView.swift
//  Docked
//
//  The pixel-art CRT "television" drawn around the floating video. The bezel
//  fills everything outside `hole`; the user drags their PiP window into the
//  opening so the frame shows all the way around it. Drawn with a Canvas of
//  integer rectangles so it stays crisp at any size.
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
                .frame(width: max(0, hole.width - 8), height: max(0, hole.height - 8))
                .position(x: hole.midX, y: hole.midY)
                .opacity(dimHint ? 0.2 : 1)
                .animation(.easeInOut(duration: 0.6), value: dimHint)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            if layout.showsAntenna {
                Antenna()
                    .frame(width: 48, height: 16)
                    .offset(y: -13)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Video drop zone, \(layout.label)")
    }

    @ViewBuilder private var hintView: some View {
        VStack(spacing: isSmall ? 3 : 6) {
            Image(systemName: "tv.fill")
                .font(.system(size: isSmall ? 14 : 22))
            Text("DRAG YOUR VIDEO HERE")
                .font(.system(size: isSmall ? 8 : 12, weight: .heavy))
                .tracking(isSmall ? 1.2 : 2.4)
            if !isSmall {
                Text("float your Picture-in-Picture window into the frame")
                    .font(.system(size: 10))
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

        // plate + body
        fill(0, 0, w, h, Theme.TV.key)
        fill(K, K, w - 2*K, h - 2*K, Theme.TV.tan)
        // bevel: light top+left, dark bottom+right
        fill(K, K, w - 2*K, K, Theme.TV.hi)
        fill(K, K, K, h - 2*K, Theme.TV.hi)
        fill(K, h - 2*K, w - 2*K, K, Theme.TV.lo)
        fill(w - 2*K, K, K, h - 2*K, Theme.TV.lo)
        // subtle inner mid-tone frame just outside the recess
        fill(hx - 6, hy - 6, hw + 12, 3, Theme.TV.mid)
        fill(hx - 6, hy + hh + 3, hw + 12, 3, Theme.TV.mid)
        fill(hx - 6, hy - 6, 3, hh + 12, Theme.TV.mid)
        fill(hx + hw + 3, hy - 6, 3, hh + 12, Theme.TV.mid)

        // screen recess ring (dark, right at the opening)
        fill(hx - K, hy - K, hw + 2*K, K, Theme.TV.key)
        fill(hx - K, hy + hh, hw + 2*K, K, Theme.TV.key)
        fill(hx - K, hy - K, K, hh + 2*K, Theme.TV.key)
        fill(hx + hw, hy - K, K, hh + 2*K, Theme.TV.key)
        fill(hx - 3, hy - 3, hw + 6, 2, Theme.TV.deep)
        // dark glass so the empty opening reads as a screen
        fill(hx, hy, hw, hh, Theme.TV.glass)

        // chunky stepped outer corners
        func notch(_ cx: CGFloat, _ cy: CGFloat, _ dx: CGFloat, _ dy: CGFloat) {
            fill(cx, cy, 3*K, 3*K, Theme.TV.key)
            fill(cx + dx*K, cy + dy*K, 2*K, 2*K, Theme.TV.tan)
        }
        notch(0, 0, 1, 1); notch(w - 3*K, 0, -1, 1)
        notch(0, h - 3*K, 1, -1); notch(w - 3*K, h - 3*K, -1, -1)

        // corner screws
        func screw(_ x: CGFloat, _ y: CGFloat) {
            fill(x, y, 2*K, 2*K, Theme.TV.deep)
            fill(x, y, K, K, Theme.TV.hi)
            fill(x + K, y + K, K, K, Theme.TV.lo)
        }
        let so: CGFloat = 5
        screw(so, so); screw(w - so - 2*K, so)
        screw(so, h - so - 2*K); screw(w - so - 2*K, h - so - 2*K)

        // chin details, if there's a real bottom bezel below the opening
        let chinTop = hy + hh + 5
        let chinH = h - chinTop - 4
        if chinH >= 8, !isSmall {
            for i in 0..<7 {
                fill(hx + CGFloat(i) * 3, chinTop + 3, K, min(chinH - 4, 12), Theme.TV.deep)
            }
            fill(hx + hw - 14, chinTop + 2, 3*K, 3*K, Theme.TV.led)
            fill(hx + hw - 13, chinTop + 3, K, K, Theme.TV.ledHi)
            fill(w/2 - 6, h - 4, 12, K, Theme.TV.lo)
        } else if chinH >= 5 {
            fill(hx + hw - 8, chinTop + 1, 2*K, 2*K, Theme.TV.led)
        }
    }
}

private struct Antenna: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            var p = Path()
            p.move(to: CGPoint(x: w * 0.42, y: h)); p.addLine(to: CGPoint(x: w * 0.30, y: 2))
            p.move(to: CGPoint(x: w * 0.58, y: h)); p.addLine(to: CGPoint(x: w * 0.70, y: 2))
            ctx.stroke(p, with: .color(Theme.TV.tan), lineWidth: 2)
            ctx.fill(Path(ellipseIn: CGRect(x: w*0.30 - 2.5, y: -0.5, width: 5, height: 5)), with: .color(Theme.TV.hi))
            ctx.fill(Path(ellipseIn: CGRect(x: w*0.70 - 2.5, y: -0.5, width: 5, height: 5)), with: .color(Theme.TV.hi))
        }
    }
}
