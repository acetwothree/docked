//
//  LayoutSolver.swift
//  Docked
//
//  Pure geometry. `pip` is roughly the footprint the iOS Picture-in-Picture
//  window takes; `video` is a thin pixel-art screen border drawn around it so
//  the border stays visible once the user parks their video in the opening.
//  Every other region keeps clear of `video`.
//

import CoreGraphics

struct SolvedLayout {
    var pip: CGRect           // approximate PiP window footprint (the opening)
    var video: CGRect         // the pixel border — pip grown by a thin bezel
    var tab: CGRect
    var tabIsHeader: Bool
    var content: CGRect       // doodle / notes / runner / pop — a clean rect away from the video
    var isCorner: Bool
    var occupiesTop: Bool

    /// The opening, in `video`-local coordinates (for VideoFrameView).
    var holeInFrame: CGRect {
        CGRect(x: pip.minX - video.minX, y: pip.minY - video.minY,
               width: pip.width, height: pip.height)
    }
}

enum LayoutSolver {

    static let tabHeight: CGFloat = 68
    static let bezel: CGFloat = 8              // border thickness on every side

    // ---- iPhone PiP presets (only two sizes exist). Calibrated from
    //      on-device screenshots; nudge these until the border wraps snug. ----
    static let bandEdgeInset: CGFloat = 10     // large PiP: gap from the screen side edge
    static let bandTopInset: CGFloat = 3       // large PiP: gap from the safe-area top/bottom
    static let bandAspect: CGFloat = 1.78      // large PiP  width / height (≈16:9)
    static let cornerWidthFrac: CGFloat = 0.54 // small PiP: fraction of screen width
    static let cornerEdgeInset: CGFloat = 9    // small PiP: gap from the screen edge
    static let cornerAspect: CGFloat = 1.85    // small PiP  width / height

    static func solve(_ layout: VideoLayout, size: CGSize) -> SolvedLayout {
        let W = size.width, H = size.height
        let B = bezel
        let TAB = tabHeight

        let cw = (W * cornerWidthFrac).rounded()
        let chh = (cw / cornerAspect).rounded()
        let bw = (W - bandEdgeInset * 2).rounded()
        let bh = (bw / bandAspect).rounded()

        let occupiesTop = layout.occupiesTop
        let isCorner = layout.isCorner

        // PiP footprint — the actual floating-window rectangle.
        let pip: CGRect
        switch layout {
        case .topLeft:     pip = CGRect(x: cornerEdgeInset, y: cornerEdgeInset, width: cw, height: chh)
        case .topRight:    pip = CGRect(x: W - cornerEdgeInset - cw, y: cornerEdgeInset, width: cw, height: chh)
        case .bottomLeft:  pip = CGRect(x: cornerEdgeInset, y: H - cornerEdgeInset - chh, width: cw, height: chh)
        case .bottomRight: pip = CGRect(x: W - cornerEdgeInset - cw, y: H - cornerEdgeInset - chh, width: cw, height: chh)
        case .top:         pip = CGRect(x: bandEdgeInset, y: bandTopInset, width: bw, height: bh)
        case .bottom:      pip = CGRect(x: bandEdgeInset, y: H - bandTopInset - bh, width: bw, height: bh)
        }

        let video = pip.insetBy(dx: -B, dy: -B)

        let tab = occupiesTop
            ? CGRect(x: 0, y: H - TAB, width: W, height: TAB)
            : CGRect(x: 0, y: 0, width: W, height: TAB)

        // Content = a clean full-width rect between the video and the tab bar.
        let G: CGFloat = 8
        let cTop = occupiesTop ? video.maxY + G : tab.maxY + G
        let cBot = occupiesTop ? tab.minY - G : video.minY - G
        let content = CGRect(x: 8, y: cTop, width: W - 16, height: max(60, cBot - cTop))

        return SolvedLayout(
            pip: pip, video: video, tab: tab, tabIsHeader: !occupiesTop,
            content: content, isCorner: isCorner, occupiesTop: occupiesTop
        )
    }

    struct EditTarget: Identifiable {
        let layout: VideoLayout
        let rect: CGRect
        var id: String { layout.rawValue }
    }

    /// Six big finger targets as a 3-wide × 2-tall grid, placed in whichever
    /// vertical half the current PiP window is NOT covering.
    static func editTargets(size: CGSize, current: VideoLayout) -> [EditTarget] {
        let W = size.width, H = size.height
        let MX: CGFloat = 12
        let colGap: CGFloat = 10, rowGap: CGFloat = 12
        let cw = (W - 2 * MX - 2 * colGap) / 3
        let ch = min(max(cw * 0.82, 92), 128)

        let s = solve(current, size: size)
        let clearTop = current.occupiesTop ? s.video.maxY + 26 : 30
        let clearBot = current.occupiesTop ? H - 30 : s.video.minY - 26
        let gridH = ch * 2 + rowGap
        let topY = max(clearTop, min(clearBot - gridH, (clearTop + clearBot) / 2 - gridH / 2))
        let botY = topY + ch + rowGap

        let cx = [MX, MX + cw + colGap, MX + 2 * (cw + colGap)]
        return [
            EditTarget(layout: .topLeft,     rect: CGRect(x: cx[0], y: topY, width: cw, height: ch)),
            EditTarget(layout: .top,         rect: CGRect(x: cx[1], y: topY, width: cw, height: ch)),
            EditTarget(layout: .topRight,    rect: CGRect(x: cx[2], y: topY, width: cw, height: ch)),
            EditTarget(layout: .bottomLeft,  rect: CGRect(x: cx[0], y: botY, width: cw, height: ch)),
            EditTarget(layout: .bottom,      rect: CGRect(x: cx[1], y: botY, width: cw, height: ch)),
            EditTarget(layout: .bottomRight, rect: CGRect(x: cx[2], y: botY, width: cw, height: ch)),
        ]
    }
}
