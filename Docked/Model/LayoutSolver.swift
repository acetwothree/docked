//
//  LayoutSolver.swift
//  Docked
//
//  Pure geometry. Given the safe-area size (which already excludes the
//  Dynamic Island / notch and the home indicator), it returns the rectangles
//  every part of the UI occupies.
//
//  `pip` is the footprint the iOS Picture-in-Picture window actually takes
//  (measured from real iPhone screenshots). `video` is the pixel-art TV frame
//  drawn around it — slightly larger on every side so the bezel stays visible
//  once the user drags their PiP window into the opening. Everything else
//  (content, zen grid, edit targets) keeps clear of `video`, not just `pip`.
//

import CoreGraphics

struct SolvedLayout {
    var pip: CGRect           // the real PiP window footprint (the frame's opening)
    var video: CGRect         // the TV frame outer bounds — pip grown by the bezel
    var tab: CGRect
    var tabIsHeader: Bool
    var content: CGRect       // doodle / notes / runner — full-width band away from the video
    var zenField: CGRect      // zen puzzle — everything except the tab bar
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
    static let endMargin: CGFloat = 10
    static let gap: CGFloat = 12
    static let tabHeight: CGFloat = 64          // was 52 — bigger finger targets

    /// TV-frame bezel thickness added around the PiP footprint.
    static func bezel(isCorner: Bool) -> (side: CGFloat, top: CGFloat, bottom: CGFloat) {
        isCorner ? (9, 9, 15) : (12, 12, 21)
    }

    static func solve(_ layout: VideoLayout, size: CGSize) -> SolvedLayout {
        let W = size.width, H = size.height
        let MX = sideMargin, MY = endMargin, G = gap, TAB = tabHeight

        // PiP footprints from real iPhone screenshots (16:9).
        let cw = min(max(W * 0.37, 132), 150)
        let ch = (cw * 9.0 / 16.0).rounded()
        let bw = W - MX * 2
        let bh = (bw * 9.0 / 16.0).rounded()

        let occupiesTop = layout.occupiesTop
        let isCorner = layout.isCorner
        let b = bezel(isCorner: isCorner)

        // PiP footprint, nudged in from the screen edge by the bezel so the
        // frame has room to show all the way around.
        let pip: CGRect
        switch layout {
        case .topLeft:     pip = CGRect(x: MX + b.side, y: MY + b.top, width: cw, height: ch)
        case .topRight:    pip = CGRect(x: W - MX - b.side - cw, y: MY + b.top, width: cw, height: ch)
        case .bottomLeft:  pip = CGRect(x: MX + b.side, y: H - MY - b.bottom - ch, width: cw, height: ch)
        case .bottomRight: pip = CGRect(x: W - MX - b.side - cw, y: H - MY - b.bottom - ch, width: cw, height: ch)
        case .top:         pip = CGRect(x: MX + b.side, y: MY + b.top, width: bw - 2 * b.side, height: bh)
        case .bottom:      pip = CGRect(x: MX + b.side, y: H - MY - b.bottom - bh, width: bw - 2 * b.side, height: bh)
        }

        let video = CGRect(x: pip.minX - b.side, y: pip.minY - b.top,
                           width: pip.width + 2 * b.side, height: pip.height + b.top + b.bottom)

        // Tab bar sits on the edge opposite the video.
        let tab = occupiesTop
            ? CGRect(x: 0, y: H - TAB, width: W, height: TAB)
            : CGRect(x: 0, y: 0, width: W, height: TAB)

        // Content fills the band between the frame and the tab bar.
        let cTop = occupiesTop ? video.maxY + G : tab.maxY + G
        let cBot = occupiesTop ? tab.minY - G : video.minY - G
        let content = CGRect(x: MX, y: cTop, width: W - MX * 2, height: max(60, cBot - cTop))

        let zenField = occupiesTop
            ? CGRect(x: 0, y: 0, width: W, height: H - TAB)
            : CGRect(x: 0, y: TAB, width: W, height: H - TAB)

        return SolvedLayout(
            pip: pip, video: video, tab: tab, tabIsHeader: !occupiesTop,
            content: content, zenField: zenField,
            isCorner: isCorner, occupiesTop: occupiesTop
        )
    }

    struct EditTarget: Identifiable {
        let layout: VideoLayout
        let rect: CGRect
        var id: String { layout.rawValue }
    }

    /// Six big finger targets laid out as a 3-wide × 2-tall grid (left /
    /// centre / right columns, top / bottom rows — so position still maps to
    /// meaning). The whole grid is placed in whichever vertical half the
    /// current PiP window is NOT covering, so a floating video can't hide it.
    static func editTargets(size: CGSize, current: VideoLayout) -> [EditTarget] {
        let W = size.width, H = size.height
        let MX = sideMargin
        let colGap: CGFloat = 10, rowGap: CGFloat = 12
        let cw = (W - 2 * MX - 2 * colGap) / 3
        let ch = min(max(cw * 0.82, 92), 128)

        // Clear band: the half the current PiP isn't occupying.
        let s = solve(current, size: size)
        let clearTop = current.occupiesTop ? s.video.maxY + 26 : 30
        let clearBot = current.occupiesTop ? H - 30 : s.video.minY - 26
        let gridH = ch * 2 + rowGap
        let topY = max(clearTop, min(clearBot - gridH, (clearTop + clearBot) / 2 - gridH / 2))
        let botY = topY + ch + rowGap

        let cx = [MX, MX + cw + colGap, MX + 2 * (cw + colGap)]
        return [
            EditTarget(layout: .topLeft,     rect: CGRect(x: cx[0], y: topY, width: cw, height: ch)),
            EditTarget(layout: .top,          rect: CGRect(x: cx[1], y: topY, width: cw, height: ch)),
            EditTarget(layout: .topRight,    rect: CGRect(x: cx[2], y: topY, width: cw, height: ch)),
            EditTarget(layout: .bottomLeft,  rect: CGRect(x: cx[0], y: botY, width: cw, height: ch)),
            EditTarget(layout: .bottom,       rect: CGRect(x: cx[1], y: botY, width: cw, height: ch)),
            EditTarget(layout: .bottomRight, rect: CGRect(x: cx[2], y: botY, width: cw, height: ch)),
        ]
    }
}
