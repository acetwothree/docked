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

    static let sideMargin: CGFloat = 12
    static let endMargin: CGFloat = 8
    static let gap: CGFloat = 16               // breathing room from the video / tab bar
    static let tabHeight: CGFloat = 68
    static let bezel: CGFloat = 6              // thin border on every side

    static func solve(_ layout: VideoLayout, size: CGSize) -> SolvedLayout {
        let W = size.width, H = size.height
        let MX = sideMargin, MY = endMargin, G = gap, TAB = tabHeight
        let B = bezel

        // PiP footprints, sized generously so app content always clears the
        // real floating window (better a small gap than an overlap).
        let cornerW = min(max(W * 0.42, 150), 188)
        let cornerH = (cornerW / 1.55).rounded()
        let bandW = W - MX * 2 - B * 2
        let bandH = (bandW / 1.5).rounded()            // ~3:2, matches real large-PiP screenshots

        let occupiesTop = layout.occupiesTop
        let isCorner = layout.isCorner

        // PiP footprint (nudged in from the edge by the border thickness).
        let pip: CGRect
        switch layout {
        case .topLeft:     pip = CGRect(x: MX + B, y: MY + B, width: cornerW, height: cornerH)
        case .topRight:    pip = CGRect(x: W - MX - B - cornerW, y: MY + B, width: cornerW, height: cornerH)
        case .bottomLeft:  pip = CGRect(x: MX + B, y: H - MY - B - cornerH, width: cornerW, height: cornerH)
        case .bottomRight: pip = CGRect(x: W - MX - B - cornerW, y: H - MY - B - cornerH, width: cornerW, height: cornerH)
        case .top:         pip = CGRect(x: MX + B, y: MY + B, width: bandW, height: bandH)
        case .bottom:      pip = CGRect(x: MX + B, y: H - MY - B - bandH, width: bandW, height: bandH)
        }

        let video = pip.insetBy(dx: -B, dy: -B)

        let tab = occupiesTop
            ? CGRect(x: 0, y: H - TAB, width: W, height: TAB)
            : CGRect(x: 0, y: 0, width: W, height: TAB)

        // Content = a clean full-width rect between the video and the tab bar.
        let cTop = occupiesTop ? video.maxY + G : tab.maxY + G
        let cBot = occupiesTop ? tab.minY - G : video.minY - G
        let content = CGRect(x: MX, y: cTop, width: W - MX * 2, height: max(60, cBot - cTop))

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
        let MX = sideMargin
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
