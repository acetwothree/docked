//
//  VideoLayout.swift
//  Docked
//
//  The video always rests in a large band at the top of the screen — that's
//  the ergonomic spot (your thumbs never cover it). The `.bottom` case is kept
//  only so the geometry code can be re-enabled later if ever needed; nothing
//  in the UI selects it.
//

import SwiftUI

enum VideoLayout: String, CaseIterable, Identifiable {
    case top, bottom

    var id: String { rawValue }

    /// The video is in the top half — app content flows to the bottom.
    var occupiesTop: Bool { self == .top }
}

enum ActivityCategory: String, CaseIterable, Identifiable {
    case create = "Create"
    case play = "Play"
    case fidget = "Fidget"
    case versus = "2 Player"
    var id: String { rawValue }
}

enum ActivityModule: String, CaseIterable, Identifiable {
    case doodle, notes, game, zen, flow, idle, sand, pop, click, scratch, tictactoe
    var id: String { rawValue }

    var category: ActivityCategory {
        switch self {
        case .doodle, .notes: .create
        case .game, .zen, .flow, .idle, .sand: .play
        case .pop, .click, .scratch: .fidget
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
        case .idle: "Garden"
        case .sand: "Sand Sort"
        case .pop: "Pop"
        case .click: "Clicker"
        case .scratch: "Scratcher"
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
        case .idle: "leaf.fill"
        case .sand: "chart.bar.fill"
        case .pop: "circle.hexagongrid.fill"
        case .click: "hand.tap.fill"
        case .scratch: "rectangle.dashed"
        case .tictactoe: "number"
        }
    }
}
