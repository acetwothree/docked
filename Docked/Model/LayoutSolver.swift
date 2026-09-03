//
//  LayoutSolver.swift
//  Docked
//
//  Pure geometry, in FULL-SCREEN coordinates (y = 0 is the physical top of the
//  display). RootView feeds a full-screen ZStack (an inner GeometryReader with
//  `.ignoresSafeArea()`) and passes the safe-area insets, so the tab bar can be
//  kept inside the safe area while the video border reaches the screen edge
//  where the real PiP window floats.
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

    // Border thickness: thin on the inner sides, more on the screen-edge side.
    static let bezel: CGFloat = 7
    static let bezelOuter: CGFloat = 12

    // ---- iPhone PiP band, calibrated from on-device screenshots. Nudge:
    //      · topBorderGap    — gap below the status bar / island to the border
    //      · bottomBorderGap — gap from the physical bottom to the border
    //      · bandAspect      — video width / height (smaller = taller) ----
    static let bandSideInset: CGFloat = 12
    static let topBorderGap: CGFloat = 4
    static let bottomBorderGap: CGFloat = 4
    static let bandAspect: CGFloat = 1.82

    /// `size` is the FULL screen size; `insetTop` / `insetBottom` are the
    /// safe-area insets.
    static func solve(_ layout: VideoLayout, size: CGSize,
                      insetTop: CGFloat, insetBottom: CGFloat) -> SolvedLayout {
        let W = size.width, H = size.height
        let TAB = tabHeight
        let occupiesTop = layout == .top

        let bw = (W - bandSideInset * 2).rounded()
        let bh = (bw / bandAspect).rounded()
        let vH = bh + bezel + bezelOuter          // full border height

        let pip: CGRect
        let video: CGRect
        if occupiesTop {
            let vMinY = insetTop + topBorderGap   // just under the status bar / island
            video = CGRect(x: bandSideInset - bezel, y: vMinY,
                           width: bw + bezel * 2, height: vH)
            pip = CGRect(x: bandSideInset, y: vMinY + bezelOuter, width: bw, height: bh)
        } else {
            let vMaxY = H - bottomBorderGap       // just above the physical bottom
            video = CGRect(x: bandSideInset - bezel, y: vMaxY - vH,
                           width: bw + bezel * 2, height: vH)
            pip = CGRect(x: bandSideInset, y: vMaxY - bezelOuter - bh, width: bw, height: bh)
        }

        // Tab bar hugs the safe-area edge the video doesn't — always tappable.
        let tab = occupiesTop
            ? CGRect(x: 0, y: H - insetBottom - TAB, width: W, height: TAB)
            : CGRect(x: 0, y: insetTop, width: W, height: TAB)

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
