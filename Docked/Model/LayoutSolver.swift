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
    var tabIsHeader: Bool
    var content: CGRect       // everything below the cabinet — the game grid or an open module
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

    static let bezelSide: CGFloat = 10
    static let bezelTop: CGFloat = 18          // extra wood above the video so an
                                              // offset PiP can't reach the corners
    static let bezelBottom: CGFloat = 4        // thin wood between screen and console
    static let consoleHeight: CGFloat = 62

    // ---- calibrated from on-device screenshots ----
    static let bandSideInset: CGFloat = 12
    static let topBorderGap: CGFloat = -8      // border top vs the island bottom
    static let bandAspect: CGFloat = 1.82

    /// User drag range for the screen-height stretch (added to `bh`).
    static let stretchRange: ClosedRange<CGFloat> = -16 ... 120

    static func solve(_ layout: VideoLayout, size: CGSize,
                      insetTop: CGFloat, insetBottom: CGFloat,
                      stretch: CGFloat = 0) -> SolvedLayout {
        let W = size.width, H = size.height

        let bw = (W - bandSideInset * 2).rounded()
        let s = min(max(stretch, stretchRange.lowerBound), stretchRange.upperBound)
        let bh = (bw / bandAspect).rounded() + s

        let vMinY = insetTop + topBorderGap
        let cabinetH = bezelTop + bh + bezelBottom + consoleHeight

        let video = CGRect(x: bandSideInset - bezelSide, y: vMinY,
                           width: bw + bezelSide * 2, height: cabinetH)
        let pip = CGRect(x: bandSideInset, y: vMinY + bezelTop, width: bw, height: bh)
        let console = CGRect(x: video.minX, y: vMinY + bezelTop + bh + bezelBottom,
                             width: video.width, height: consoleHeight)

        // Everything below the cabinet, down to the safe area — the game grid
        // when nothing's open, or the active module framed inside it.
        let G: CGFloat = 8
        let cTop = video.maxY + G
        let cBot = H - insetBottom - 4
        let content = CGRect(x: 8, y: cTop, width: W - 16, height: max(80, cBot - cTop))

        // Blocks reads `tabIsHeader` as "dock at the top of the play area"; keep
        // its dock at the bottom, near the thumbs.
        return SolvedLayout(
            pip: pip, video: video, console: console, tabIsHeader: false,
            content: content, occupiesTop: true
        )
    }

    // ---- Console knobs ----
    static let knobDiameter: CGFloat = 34

    struct KnobLayout {
        var back: CGPoint      // alone, far left
        var theme: CGPoint     // paired with settings, far right
        var settings: CGPoint
        var all: [CGPoint] { [back, theme, settings] }
    }

    /// Back sits alone on the left (it's the odd one out — it only does
    /// anything once a game is open); Theme + Settings pair up on the right,
    /// leaving the middle of the console free for the engraved label.
    static func knobLayout(inConsole c: CGRect) -> KnobLayout {
        let d = knobDiameter
        let gap: CGFloat = 12
        let cy = c.midY
        let backX = c.minX + 16 + d / 2
        let settingsX = c.maxX - 16 - d / 2
        let themeX = settingsX - d - gap
        return KnobLayout(back: CGPoint(x: backX, y: cy),
                          theme: CGPoint(x: themeX, y: cy),
                          settings: CGPoint(x: settingsX, y: cy))
    }
}
