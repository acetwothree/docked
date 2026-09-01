//
//  LayoutSolver.swift
//  Docked
//
//  Pure geometry. Given the safe-area size (which already excludes the
//  Dynamic Island / notch and the home indicator), it returns the rectangles
//  every part of the UI occupies. The video slot is the only region nothing
//  interactive is placed in — everything else is packed edge to edge.
//

import CoreGraphics

struct SolvedLayout {
    var video: CGRect
    var tab: CGRect
    var tabIsHeader: Bool          // true = tabs pinned to the top, false = bottom
    var content: CGRect
    var controls: CGRect
    var controlsIsSideStrip: Bool  // true = beside a corner video, false = floating in content
    var showsChip: Bool
    var isCorner: Bool
    var occupiesTop: Bool
}

enum LayoutSolver {

    static let sideMargin: CGFloat = 12
    static let endMargin: CGFloat = 10
    static let gap: CGFloat = 10
    static let tabHeight: CGFloat = 52

    static func solve(_ layout: VideoLayout, size: CGSize) -> SolvedLayout {
        let W = size.width, H = size.height
        let MX = sideMargin, MY = endMargin, G = gap, TAB = tabHeight

        // Footprints from real iPhone PiP screenshots (16:9).
        let cw = min(max(W * 0.37, 132), 150)
        let ch = (cw * 9.0 / 16.0).rounded()
        let bw = W - MX * 2
        let bh = (bw * 9.0 / 16.0).rounded()

        let occupiesTop = layout.occupiesTop
        let isCorner = layout.isCorner

        // Video slot.
        let video: CGRect
        switch layout {
        case .topLeft:     video = CGRect(x: MX, y: MY, width: cw, height: ch)
        case .topRight:    video = CGRect(x: W - MX - cw, y: MY, width: cw, height: ch)
        case .bottomLeft:  video = CGRect(x: MX, y: H - MY - ch, width: cw, height: ch)
        case .bottomRight: video = CGRect(x: W - MX - cw, y: H - MY - ch, width: cw, height: ch)
        case .top:         video = CGRect(x: MX, y: MY, width: bw, height: bh)
        case .bottom:      video = CGRect(x: MX, y: H - MY - bh, width: bw, height: bh)
        }

        // Tab bar sits on the edge opposite the video.
        let tab = occupiesTop
            ? CGRect(x: 0, y: H - TAB, width: W, height: TAB)
            : CGRect(x: 0, y: 0, width: W, height: TAB)

        // Content fills the band between the video and the tab bar.
        let cTop = occupiesTop ? video.maxY + G : tab.maxY + G
        let cBot = occupiesTop ? tab.minY - G : video.minY - G
        let content = CGRect(x: MX, y: cTop, width: W - MX * 2, height: max(60, cBot - cTop))

        // Controls: beside a corner video, or floating in the content corner
        // nearest the tab bar for the band layouts.
        var controls: CGRect
        var sideStrip = false
        var showsChip = false
        if let side = layout.cornerSide {
            sideStrip = true
            showsChip = true
            switch side {
            case .left:
                let x = video.maxX + G
                controls = CGRect(x: x, y: video.minY, width: W - MX - x, height: video.height)
            case .right:
                controls = CGRect(x: MX, y: video.minY, width: video.minX - G - MX, height: video.height)
            }
        } else {
            let cwid: CGFloat = 92, chgt: CGFloat = 42
            let x = content.maxX - cwid
            let y = occupiesTop ? content.maxY - chgt : content.minY
            controls = CGRect(x: x, y: y, width: cwid, height: chgt)
        }

        return SolvedLayout(
            video: video, tab: tab, tabIsHeader: !occupiesTop,
            content: content, controls: controls,
            controlsIsSideStrip: sideStrip, showsChip: showsChip,
            isCorner: isCorner, occupiesTop: occupiesTop
        )
    }

    struct EditTarget: Identifiable {
        let layout: VideoLayout
        let rect: CGRect
        var id: String { layout.rawValue }
    }

    /// Target rectangles for the edit-layout overlay (4 corners + 2 centre bands).
    static func editTargets(size: CGSize) -> [EditTarget] {
        let W = size.width, H = size.height
        let MX = sideMargin, MY = endMargin
        let cw = min(max(W * 0.37, 132), 150)
        let ch = (cw * 9.0 / 16.0).rounded()
        let midX = MX + cw + 8
        let midW = W - 2 * midX
        return [
            EditTarget(layout: .topLeft,     rect: CGRect(x: MX, y: MY, width: cw, height: ch)),
            EditTarget(layout: .topRight,    rect: CGRect(x: W - MX - cw, y: MY, width: cw, height: ch)),
            EditTarget(layout: .bottomLeft,  rect: CGRect(x: MX, y: H - MY - ch, width: cw, height: ch)),
            EditTarget(layout: .bottomRight, rect: CGRect(x: W - MX - cw, y: H - MY - ch, width: cw, height: ch)),
            EditTarget(layout: .top,         rect: CGRect(x: midX, y: MY, width: midW, height: ch)),
            EditTarget(layout: .bottom,      rect: CGRect(x: midX, y: H - MY - ch, width: midW, height: ch)),
        ]
    }
}
