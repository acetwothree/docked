//
//  VideoLayout.swift
//  Docked
//
//  The six exact resting states iOS gives a floating Picture-in-Picture
//  window, plus the geometry solver that turns a chosen state into two
//  rectangles: where the video guide sits, and where the app is allowed
//  to put content (always fully clear of the video).
//

import SwiftUI

enum VideoLayout: String, CaseIterable, Identifiable {
    // Small PiP — one of the four screen corners.
    case smallTopLeft
    case smallTopRight
    case smallBottomLeft
    case smallBottomRight
    // Large PiP — spanning the full width, docked to the top or the bottom.
    case largeTop
    case largeBottom

    var id: String { rawValue }

    var isLarge: Bool { self == .largeTop || self == .largeBottom }

    /// True when the video occupies the top band of the screen, meaning all
    /// app content must flow to the bottom.
    var occupiesTop: Bool {
        switch self {
        case .smallTopLeft, .smallTopRight, .largeTop: return true
        case .smallBottomLeft, .smallBottomRight, .largeBottom: return false
        }
    }

    /// Short label for menus and the drop-zone caption.
    var title: String {
        switch self {
        case .smallTopLeft: return "Top Left"
        case .smallTopRight: return "Top Right"
        case .smallBottomLeft: return "Bottom Left"
        case .smallBottomRight: return "Bottom Right"
        case .largeTop: return "Top · Wide"
        case .largeBottom: return "Bottom · Wide"
        }
    }

    var systemImage: String {
        switch self {
        case .smallTopLeft: return "arrow.up.left"
        case .smallTopRight: return "arrow.up.right"
        case .smallBottomLeft: return "arrow.down.left"
        case .smallBottomRight: return "arrow.down.right"
        case .largeTop: return "rectangle.topthird.inset.filled"
        case .largeBottom: return "rectangle.bottomthird.inset.filled"
        }
    }
}

/// Pure geometry. Given the available (safe-area) size, hands back the
/// video guide rectangle and the content rectangle. The content rectangle
/// is always a full-width band on the opposite side of the video — even for
/// the corner layouts — so no interactive element can ever sit under the
/// floating window.
struct LayoutSolver {
    var layout: VideoLayout
    var size: CGSize

    /// Outer breathing room.
    private var margin: CGFloat { 14 }

    /// Gap between the video band and the content band.
    private var gap: CGFloat { 14 }

    /// Small PiP guide size (~16:9), clamped to a sensible range.
    private var smallVideo: CGSize {
        let w = min(max(size.width * 0.42, 150), 240)
        return CGSize(width: w, height: (w * 9.0 / 16.0).rounded())
    }

    /// Large PiP guide size — full width, ~46% tall.
    private var largeVideo: CGSize {
        CGSize(width: max(size.width - margin * 2, 0),
               height: (size.height * 0.46).rounded())
    }

    /// The dashed "television frame" the user drags their video onto.
    var videoRect: CGRect {
        switch layout {
        case .smallTopLeft:
            return CGRect(origin: CGPoint(x: margin, y: margin), size: smallVideo)
        case .smallTopRight:
            return CGRect(origin: CGPoint(x: size.width - smallVideo.width - margin, y: margin),
                          size: smallVideo)
        case .smallBottomLeft:
            return CGRect(origin: CGPoint(x: margin, y: size.height - smallVideo.height - margin),
                          size: smallVideo)
        case .smallBottomRight:
            return CGRect(origin: CGPoint(x: size.width - smallVideo.width - margin,
                                          y: size.height - smallVideo.height - margin),
                          size: smallVideo)
        case .largeTop:
            return CGRect(origin: CGPoint(x: margin, y: margin), size: largeVideo)
        case .largeBottom:
            return CGRect(origin: CGPoint(x: margin, y: size.height - largeVideo.height - margin),
                          size: largeVideo)
        }
    }

    /// The region the app is allowed to draw interactive content in.
    var contentRect: CGRect {
        let v = videoRect
        if layout.occupiesTop {
            let top = v.maxY + gap
            return CGRect(x: 0, y: top, width: size.width, height: max(0, size.height - top))
        } else {
            let bottom = v.minY - gap
            return CGRect(x: 0, y: 0, width: size.width, height: max(0, bottom))
        }
    }
}
