//
//  LayoutSolver.swift
//  Docked
//
//  Pure geometry. `pip` is roughly the footprint the iOS Picture-in-Picture
//  window takes; `video` is a thin pixel-art screen border drawn around it so
//  the border stays visible once the user parks their video in the opening.
//
//  Coordinates are the app's safe-area space (y = 0 at the safe-area top).
//  BUT the real PiP window floats at the physical screen edge — outside the
//  safe area — so for a top / bottom band `pip` and `video` are pushed past
//  the safe-area edge by the given inset. RootView draws the video layer with
//  `.ignoresSafeArea()` so that overhang is visible; the tab bar and content
//  stay wholly inside the safe area.
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

    static let tabHeight: CGFloat = 68

    // Border thickness: thin on the three inner sides, thicker on the side that
    // faces the screen edge so none of it hides behind the video / Dynamic
    // Island / home indicator.
    static let bezel: CGFloat = 7
    static let bezelOuter: CGFloat = 16

    // ---- iPhone PiP band, calibrated from on-device screenshots. Nudge:
    //      · bandEdgeOverhang — how far past the physical edge the video sits
    //                           (bigger = video/border start closer to the edge)
    //      · bezelOuter       — how much border shows past the video on that edge
    //      · bandAspect       — trims dead space above/below (bigger = shorter) ----
    static let bandSideInset: CGFloat = 13      // gap from the screen side edge
    static let bandEdgeOverhang: CGFloat = 12   // physical-edge gap to the video's outer edge
    static let bandAspect: CGFloat = 1.90       // video  width / height

    static func solve(_ layout: VideoLayout, size: CGSize,
                      topInset: CGFloat, bottomInset: CGFloat) -> SolvedLayout {
        let W = size.width, H = size.height
        let TAB = tabHeight
        let occupiesTop = layout == .top

        let bw = (W - bandSideInset * 2).rounded()
        let bh = (bw / bandAspect).rounded()

        // PiP footprint. `y` is in safe-area space, so a top band starts at a
        // negative y (above the safe area) and a bottom band ends below it.
        let pip: CGRect = occupiesTop
            ? CGRect(x: bandSideInset, y: -topInset + bandEdgeOverhang, width: bw, height: bh)
            : CGRect(x: bandSideInset, y: H + bottomInset - bandEdgeOverhang - bh, width: bw, height: bh)

        // Border: bezel on the inner sides, bezelOuter on the screen-edge side.
        let video: CGRect = occupiesTop
            ? CGRect(x: pip.minX - bezel, y: pip.minY - bezelOuter,
                     width: pip.width + bezel * 2, height: pip.height + bezelOuter + bezel)
            : CGRect(x: pip.minX - bezel, y: pip.minY - bezel,
                     width: pip.width + bezel * 2, height: pip.height + bezel + bezelOuter)

        // Tab bar hugs the safe-area edge the video doesn't.
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
