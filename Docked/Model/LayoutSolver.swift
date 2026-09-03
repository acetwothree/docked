//
//  LayoutSolver.swift
//  Docked
//
//  Pure geometry, in FULL-SCREEN coordinates (y = 0 is the physical top of the
//  display). RootView feeds a full-screen ZStack and passes the safe-area
//  insets. The video always sits in the top band; `video` is the whole TV
//  cabinet (screen bezel + the console strip under it), `console` is the
//  sub-rect where RootView drops the knob buttons.
//

import CoreGraphics

struct SolvedLayout {
    var pip: CGRect           // approximate PiP window footprint (the opening)
    var video: CGRect         // the whole TV cabinet — bezel + console
    var console: CGRect       // knob strip at the bottom of the cabinet (screen coords)
    var tab: CGRect
    var tabIsHeader: Bool
    var content: CGRect       // module area, below the cabinet
    var occupiesTop: Bool

    /// The opening, in `video`-local coordinates (for VideoFrameView).
    var holeInFrame: CGRect {
        CGRect(x: pip.minX - video.minX, y: pip.minY - video.minY,
               width: pip.width, height: pip.height)
    }
    /// The console strip, in `video`-local coordinates.
    var consoleInFrame: CGRect {
        CGRect(x: console.minX - video.minX, y: console.minY - video.minY,
               width: console.width, height: console.height)
    }
}

enum LayoutSolver {

    static let tabHeight: CGFloat = 60

    static let bezelSide: CGFloat = 9
    static let bezelTop: CGFloat = 12
    static let bezelBottom: CGFloat = 4        // thin wood between screen and console
    static let consoleHeight: CGFloat = 62

    // ---- calibrated from on-device screenshots ----
    static let bandSideInset: CGFloat = 12
    static let topBorderGap: CGFloat = -8      // border top vs the island bottom
    static let bandAspect: CGFloat = 1.82

    static func solve(_ layout: VideoLayout, size: CGSize,
                      insetTop: CGFloat, insetBottom: CGFloat) -> SolvedLayout {
        let W = size.width, H = size.height
        let TAB = tabHeight

        let bw = (W - bandSideInset * 2).rounded()
        let bh = (bw / bandAspect).rounded()

        let vMinY = insetTop + topBorderGap
        let cabinetH = bezelTop + bh + bezelBottom + consoleHeight

        let video = CGRect(x: bandSideInset - bezelSide, y: vMinY,
                           width: bw + bezelSide * 2, height: cabinetH)
        let pip = CGRect(x: bandSideInset, y: vMinY + bezelTop, width: bw, height: bh)
        let console = CGRect(x: video.minX, y: vMinY + bezelTop + bh + bezelBottom,
                             width: video.width, height: consoleHeight)

        // Footer: just the activity chooser, inside the safe area.
        let tab = CGRect(x: 0, y: H - insetBottom - TAB, width: W, height: TAB)

        let G: CGFloat = 8
        let cTop = video.maxY + G
        let cBot = tab.minY - G
        let content = CGRect(x: 8, y: cTop, width: W - 16, height: max(80, cBot - cTop))

        // Blocks reads `tabIsHeader` as "dock at the top of the play area"; keep
        // its dock at the bottom, near the thumbs.
        return SolvedLayout(
            pip: pip, video: video, console: console, tab: tab, tabIsHeader: false,
            content: content, occupiesTop: true
        )
    }

    // ---- Console knobs (order: Settings, Theme, Premium) ----
    static let knobDiameter: CGFloat = 34

    /// Three knob centres, right-aligned in the given console rect (works in
    /// whatever coordinate space the rect is expressed in).
    static func knobCenters(inConsole c: CGRect) -> [CGPoint] {
        let d = knobDiameter
        let gap: CGFloat = 12
        let cy = c.midY
        let x3 = c.maxX - 16 - d / 2
        let x2 = x3 - d - gap
        let x1 = x2 - d - gap
        return [CGPoint(x: x1, y: cy), CGPoint(x: x2, y: cy), CGPoint(x: x3, y: cy)]
    }
}
