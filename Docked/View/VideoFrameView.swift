//
//  VideoFrameView.swift
//  Docked
//
//  The pixel-art CRT "television" that marks where the floating video goes.
//  Drawn with a Canvas of integer-aligned rectangles so it stays crisp at
//  any size. The centre stays open — the live PiP window sits on top of it.
//

import SwiftUI

struct VideoFrameView: View {
    var layout: VideoLayout
    var dimHint: Bool

    private var isSmall: Bool { layout.isCorner }

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                drawBezel(ctx, size: size)
            }

            // "Drag your video here" hint, inset to the screen opening.
            hint
                .padding(.horizontal, bezel + 6)
                .padding(.top, bezel + 2)
                .padding(.bottom, (isSmall ? 15 : 24))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(dimHint ? 0.22 : 1)
                .animation(.easeInOut(duration: 0.6), value: dimHint)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            if layout.showsAntenna {
                Antenna()
                    .frame(width: 46, height: 16)
                    .offset(y: -13)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Video drop zone, \(layout.label)")
    }

    // MARK: Hint

    @ViewBuilder private var hint: some View {
        VStack(spacing: isSmall ? 3 : 6) {
            Image(systemName: "tv.fill")
                .font(.system(size: isSmall ? 15 : 22))
            Text("DRAG YOUR VIDEO HERE")
                .font(.system(size: isSmall ? 8.5 : 12, weight: .heavy))
                .tracking(isSmall ? 1.4 : 2.5)
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

    // MARK: Bezel drawing

    private var bezel: CGFloat { isSmall ? 9 : 14 }
    private func chin(for h: CGFloat) -> CGFloat {
        isSmall ? 13 : min(26, max(18, (h * 0.13).rounded()))
    }

    private func drawBezel(_ ctx: GraphicsContext, size: CGSize) {
        let w = size.width.rounded(), h = size.height.rounded()
        let B = bezel
        let CHIN = chin(for: h)
        let K: CGFloat = 2

        func fill(_ x: CGFloat, _ y: CGFloat, _ ww: CGFloat, _ hh: CGFloat, _ c: Color) {
            guard ww > 0, hh > 0 else { return }
            ctx.fill(Path(CGRect(x: x, y: y, width: ww, height: hh)), with: .color(c))
        }
        typealias T = Theme.TV

        // base plate + body
        fill(0, 0, w, h, T.key)
        fill(K, K, w - 2*K, h - 2*K, T.tan)

        // bevel highlights / shades
        fill(K, K, w - 2*K, K, T.hi)
        fill(K, K, K, h - 2*K, T.hi)
        fill(K, h - 2*K, w - 2*K, K, T.lo)
        fill(w - 2*K, K, K, h - 2*K, T.lo)

        // inner mid-tone band
        fill(2*K, 2*K, w - 4*K, B - 2*K, T.mid)
        fill(2*K, h - CHIN, w - 4*K, K, T.mid)
        fill(2*K, 2*K, B - 2*K, h - 2*K - CHIN, T.mid)
        fill(w - B, 2*K, B - 2*K, h - 2*K - CHIN, T.mid)

        // screen recess ring
        let sx = B, sy = B, sxr = w - B, syb = h - CHIN
        fill(sx - K, sy - K, sxr - sx + 2*K, K, T.key)
        fill(sx - K, syb, sxr - sx + 2*K, K, T.key)
        fill(sx - K, sy - K, K, syb - sy + 2*K, T.key)
        fill(sxr, sy - K, K, syb - sy + 2*K, T.key)
        fill(sx - 2, sy - 2, sxr - sx + 4, 2, T.deep)
        // dark glass so the empty slot reads as a screen
        fill(sx, sy, sxr - sx, syb - sy, T.glass)

        // chunky stepped corners
        func notch(_ cx: CGFloat, _ cy: CGFloat, _ dx: CGFloat, _ dy: CGFloat) {
            fill(cx, cy, 3*K, 3*K, T.key)
            fill(cx + dx*K, cy + dy*K, 2*K, 2*K, T.tan)
            fill(cx + dx*2*K, cy + dy*2*K, K, K, T.tan)
        }
        notch(0, 0, 1, 1)
        notch(w - 3*K, 0, -1, 1)
        notch(0, h - 3*K, 1, -1)
        notch(w - 3*K, h - 3*K, -1, -1)

        // corner screws
        func screw(_ x: CGFloat, _ y: CGFloat) {
            fill(x, y, 2*K, 2*K, T.deep)
            fill(x, y, K, K, T.hi)
            fill(x + K, y + K, K, K, T.lo)
        }
        let so: CGFloat = isSmall ? 3 : 4
        screw(so, so); screw(w - so - 2*K, so)
        screw(so, h - CHIN + 2); screw(w - so - 2*K, h - CHIN + 2)

        // chin: speaker grille + power LED
        if !isSmall {
            for i in 0..<7 {
                for j in 0..<2 {
                    fill(8 + CGFloat(i)*3, h - CHIN + 7 + CGFloat(j)*4, K, K, T.deep)
                }
            }
            fill(w - 15, h - CHIN + 8, 3*K, 3*K, T.led)
            fill(w - 14, h - CHIN + 9, K, K, T.ledHi)
            fill(w/2 - 6, h - 4, 12, K, T.lo)
        } else {
            fill(w - 9, h - CHIN + 4, 2*K, 2*K, T.led)
            fill(w - 8, h - CHIN + 5, K, K, T.ledHi)
        }
    }
}

/// Two little antenna nubs for the top layouts.
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
