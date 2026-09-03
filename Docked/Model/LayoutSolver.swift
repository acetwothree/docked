//
//  LayoutSolver.swift
//  Docked
//
//  Pure geometry, in the app's SAFE-AREA coordinate space (y = 0 is the top of
//  the safe area, just under the status bar / Dynamic Island; y = H is the top
//  of the home-indicator strip). The tab bar always sits fully inside the safe
//  area so its controls are never under a system bar. Only the video border is
//  allowed to nudge a few points past the safe edge (RootView gives that one
//  layer `.ignoresSafeArea()`), so it can meet the real PiP window.
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
    //      · topBorderInset    — Y of the border's top edge for .top (small +ve
    //                            keeps it under the status bar / island)
    //      · bottomBorderBleed — how far the border's bottom edge sits past the
    //                            safe-area bottom for .bottom (toward the home bar)
    //      · bandAspect        — video width / height (smaller = taller) ----
    static let bandSideInset: CGFloat = 12
    static let topBorderInset: CGFloat = 2
    static let bottomBorderBleed: CGFloat = 8
    static let bandAspect: CGFloat = 1.82

    static func solve(_ layout: VideoLayout, size: CGSize) -> SolvedLayout {
        let W = size.width, H = size.height
        let TAB = tabHeight
        let occupiesTop = layout == .top

        let bw = (W - bandSideInset * 2).rounded()
        let bh = (bw / bandAspect).rounded()
        let vH = bh + bezel + bezelOuter          // full border height

        let pip: CGRect
        let video: CGRect
        if occupiesTop {
            video = CGRect(x: bandSideInset - bezel, y: topBorderInset,
                           width: bw + bezel * 2, height: vH)
            pip = CGRect(x: bandSideInset, y: topBorderInset + bezelOuter, width: bw, height: bh)
        } else {
            let vMaxY = H + bottomBorderBleed
            video = CGRect(x: bandSideInset - bezel, y: vMaxY - vH,
                           width: bw + bezel * 2, height: vH)
            pip = CGRect(x: bandSideInset, y: vMaxY - bezelOuter - bh, width: bw, height: bh)
        }

        // Tab bar hugs the safe-area edge the video doesn't — always tappable.
        let tab = occupiesTop
            ? CGRect(x: 0, y: H - TAB, width: W, height: TAB)
            : CGRect(x: 0, y: 0, width: W, height: TAB)

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
