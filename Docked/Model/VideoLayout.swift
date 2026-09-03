//
//  VideoLayout.swift
//  Docked
//
//  The six positions an iOS Picture-in-Picture window rests in on iPhone:
//  four small corners, plus a large slot pinned to the top or bottom edge.
//  Footprints are matched to real iPhone PiP screenshots (16:9).
//

import SwiftUI

enum VideoLayout: String, CaseIterable, Identifiable {
    case topLeft, topRight, bottomLeft, bottomRight, top, bottom

    var id: String { rawValue }

    enum Side { case left, right }

    var label: String {
        switch self {
        case .topLeft: "Top-left"
        case .topRight: "Top-right"
        case .bottomLeft: "Bottom-left"
        case .bottomRight: "Bottom-right"
        case .top: "Top"
        case .bottom: "Bottom"
        }
    }

    /// The video is in the top half — app content flows to the bottom.
    var occupiesTop: Bool {
        self == .topLeft || self == .topRight || self == .top
    }

    /// Which side a corner layout hugs (nil for the top/bottom bands).
    var cornerSide: Side? {
        switch self {
        case .topLeft, .bottomLeft: .left
        case .topRight, .bottomRight: .right
        case .top, .bottom: nil
        }
    }

    var isCorner: Bool { cornerSide != nil }

    /// Little antenna nubs are drawn on the frame for top layouts.
    var showsAntenna: Bool {
        self == .top || self == .topLeft || self == .topRight
    }

    var systemImage: String {
        switch self {
        case .topLeft: "arrow.up.left"
        case .topRight: "arrow.up.right"
        case .bottomLeft: "arrow.down.left"
        case .bottomRight: "arrow.down.right"
        case .top: "rectangle.topthird.inset.filled"
        case .bottom: "rectangle.bottomthird.inset.filled"
        }
    }
}

enum ActivityModule: String, CaseIterable, Identifiable {
    case doodle, notes, game, zen, pop
    var id: String { rawValue }
    var title: String {
        switch self {
        case .doodle: "Doodle"
        case .notes: "Notes"
        case .game: "Runner"
        case .zen: "Blocks"
        case .pop: "Pop"
        }
    }
    var systemImage: String {
        switch self {
        case .doodle: "scribble.variable"
        case .notes: "note.text"
        case .game: "figure.run"
        case .zen: "puzzlepiece.fill"
        case .pop: "circle.hexagongrid.fill"
        }
    }
}
