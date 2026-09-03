//
//  LayoutSolver.swift
//  Docked
//
//  Pure geometry. `pip` is roughly the footprint the iOS Picture-in-Picture
//  window takes; `video` is a thin pixel-art screen border drawn around it.
//
//  Everything is in FULL-SCREEN coordinates (y = 0 is the physical top of the
//  display). RootView feeds a full-screen-sized ZStack and passes the
//  safe-area insets so the tab bar clears the Dynamic Island / home indicator
//  while the video border can still reach right to the screen edge where the
//  real PiP window floats.
//

import CoreGraphics

struct SolvedLayout {
    var pip: CGRect           // approximate PiP window footprint (the opening)
    var video: CGRect         // the pixel border — pip grown by a bezel
    var tab: CGRect
    var tabIsHeader: Bool
    var content: CGRect       // module area — a clean rect away from the video
    var occupiesTop: Bool

    /// The opening, in `video`-local coordinates (for VideoFrameView).
    var holeInFrame: CGRect {
        CGRect(x: pip.minX - video.minX, y: pip.minY - video.minY,
               width: pip.width, height: pip.height)
    }
}

enum LayoutSolver {

    static let tabHeight: CGFloat = 66

    // Border thickness: thin on the three inner sides, a little more on the
    // side that faces the screen edge.
    static let bezel: CGFloat = 7
    static let bezelOuter: CGFloat = 11

    // ---- iPhone PiP band, calibrated from on-device screenshots. Nudge:
    //      · topBorderY     — Y of the border's top edge for the .top layout
    //                         (just under the status bar / Dynamic Island)
    //      · bottomBorderGap— gap from the physical bottom to the border's
    //                         bottom edge for the .bottom layout
    //      · bandAspect     — video width / height (bigger = shorter) ----
    static let bandSideInset: CGFloat = 12
    static let topBorderExtraDrop: CGFloat = 4   // extra push below the safe-area top
    static let bottomBorderGap: CGFloat = 3      // border bottom this far off the physical edge
    static let bandAspect: CGFloat = 1.92

    static func solve(_ layout: VideoLayout, size: CGSize,
                      safeTop: CGFloat, safeBottom: CGFloat) -> SolvedLayout {
        let W = size.width, H = size.height
        let TAB = tabHeight
        let occupiesTop = layout == .top

        let bw = (W - bandSideInset * 2).rounded()
        let bh = (bw / bandAspect).rounded()

        // The border's outer edge on the screen-edge side.
        let borderEdgeY: CGFloat = occupiesTop
            ? safeTop + topBorderExtraDrop          // just under the island
            : H - bottomBorderGap                   // just above the physical bottom

        let pip: CGRect
        let video: CGRect
        if occupiesTop {
            let vy = borderEdgeY
            video = CGRect(x: bandSideInset - bezel, y: vy,
                           width: bw + bezel * 2, height: bh + bezelOuter + bezel)
            pip = CGRect(x: bandSideInset, y: vy + bezelOuter, width: bw, height: bh)
        } else {
            let vMaxY = borderEdgeY
            video = CGRect(x: bandSideInset - bezel, y: vMaxY - (bh + bezelOuter + bezel),
                           width: bw + bezel * 2, height: bh + bezelOuter + bezel)
            pip = CGRect(x: bandSideInset, y: vMaxY - bezelOuter - bh, width: bw, height: bh)
        }

        // Tab bar hugs the safe-area edge the video doesn't, inside the inset.
        let tab = occupiesTop
            ? CGRect(x: 0, y: H - safeBottom - TAB, width: W, height: TAB)
            : CGRect(x: 0, y: safeTop, width: W, height: TAB)

        // Content = a clean full-width rect between the video and the tab bar.
        let G: CGFloat = 8
        let cTop = occupiesTop ? video.maxY + G : tab.maxY + G
        let cBot = occupiesTop ? tab.minY - G : video.minY - G
        let content = CGRect(x: 8, y: cTop, width: W - 16, height: max(80, cBot - cTop))

        return SolvedLayout(
            pip: pip, video: video, tab: tab, tabIsHeader: !occupiesTop,
            content: content, occupiesTop: occupiesTop
        )
    }
}
