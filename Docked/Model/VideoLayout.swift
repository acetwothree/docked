//
//  VideoLayout.swift
//  Docked
//
//  Where the iOS Picture-in-Picture window rests: a large band pinned to the
//  top edge or the bottom edge. (The four small-corner positions were removed —
//  the band is the only size worth designing around, and a single tap now just
//  flips between the two.)
//

import SwiftUI

enum VideoLayout: String, CaseIterable, Identifiable {
    case top, bottom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .top: "Top"
        case .bottom: "Bottom"
        }
    }

    /// The video is in the top half — app content flows to the bottom.
    var occupiesTop: Bool { self == .top }

    /// The other layout — tapping the Layout button toggles to this.
    var toggled: VideoLayout { self == .top ? .bottom : .top }

    /// Icon for the toggle button — points the way the video will move.
    var moveIcon: String {
        self == .top ? "arrow.down.to.line" : "arrow.up.to.line"
    }
    var moveLabel: String {
        self == .top ? "Move down" : "Move up"
    }

    var systemImage: String {
        switch self {
        case .top: "rectangle.topthird.inset.filled"
        case .bottom: "rectangle.bottomthird.inset.filled"
        }
    }
}

enum ActivityCategory: String, CaseIterable, Identifiable {
    case create = "Create"
    case play = "Play"
    case fidget = "Fidget"
    case versus = "2 Player"
    var id: String { rawValue }
}

enum ActivityModule: String, CaseIterable, Identifiable {
    case doodle, notes, game, zen, flow, pop, click, tictactoe
    var id: String { rawValue }

    var category: ActivityCategory {
        switch self {
        case .doodle, .notes: .create
        case .game, .zen, .flow: .play
        case .pop, .click: .fidget
        case .tictactoe: .versus
        }
    }

    var title: String {
        switch self {
        case .doodle: "Doodle"
        case .notes: "Notes"
        case .game: "Runner"
        case .zen: "Blocks"
        case .flow: "Flow"
        case .pop: "Pop"
        case .click: "Clicker"
        case .tictactoe: "Tic-Tac-Toe"
        }
    }
    var systemImage: String {
        switch self {
        case .doodle: "scribble.variable"
        case .notes: "note.text"
        case .game: "figure.run"
        case .zen: "square.grid.2x2.fill"
        case .flow: "point.3.connected.trianglepath.dotted"
        case .pop: "circle.hexagongrid.fill"
        case .click: "hand.tap.fill"
        case .tictactoe: "number"
        }
    }
}
