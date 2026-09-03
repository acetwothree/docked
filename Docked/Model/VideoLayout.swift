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
    case doodle, notes, mindmap
    case game, zen, flow, idle, sand, merge, drop, marble
    case pop, click, scratch, spinner, ksand
    case tictactoe, connect4, dots
    var id: String { rawValue }

    var category: ActivityCategory {
        switch self {
        case .doodle, .notes, .mindmap: .create
        case .game, .zen, .flow, .idle, .sand, .merge, .drop, .marble: .play
        case .pop, .click, .scratch, .spinner, .ksand: .fidget
        case .tictactoe, .connect4, .dots: .versus
        }
    }

    var title: String {
        switch self {
        case .doodle: "Doodle"
        case .notes: "Notes"
        case .mindmap: "Mind Map"
        case .game: "Runner"
        case .zen: "Blocks"
        case .flow: "Flow"
        case .idle: "Garden Idle"
        case .sand: "Sand Sort"
        case .merge: "2048"
        case .drop: "Merge"
        case .marble: "Roll"
        case .pop: "Pop"
        case .click: "Clicker"
        case .scratch: "Scratcher"
        case .spinner: "Spinner"
        case .ksand: "Kinetic Sand"
        case .tictactoe: "Tic-Tac-Toe"
        case .connect4: "Connect 4"
        case .dots: "Dots & Boxes"
        }
    }
    var systemImage: String {
        switch self {
        case .doodle: "scribble.variable"
        case .notes: "note.text"
        case .mindmap: "brain"
        case .game: "figure.run"
        case .zen: "square.grid.2x2.fill"
        case .flow: "point.3.connected.trianglepath.dotted"
        case .idle: "leaf.fill"
        case .sand: "chart.bar.fill"
        case .merge: "square.stack.3d.up.fill"
        case .drop: "circle.grid.2x2.fill"
        case .marble: "circle.fill"
        case .pop: "circle.hexagongrid.fill"
        case .click: "hand.tap.fill"
        case .scratch: "rectangle.dashed"
        case .spinner: "fan.fill"
        case .ksand: "hand.draw.fill"
        case .tictactoe: "number"
        case .connect4: "circle.grid.cross.fill"
        case .dots: "square.grid.4x3.fill"
        }
    }

    /// Activities behind Docked Plus. The free set stays genuinely useful on
    /// its own — sketching, notes, a runner, Blocks, 2048, three fidgets and
    /// Tic-Tac-Toe — so the app has real value without subscribing.
    var isPlus: Bool {
        switch self {
        case .doodle, .notes, .game, .zen, .merge, .pop, .click, .spinner, .tictactoe:
            return false
        case .mindmap, .flow, .idle, .sand, .drop, .marble, .scratch, .ksand, .connect4, .dots:
            return true
        }
    }

    /// A colour per category — used to tint the picker cards.
    var tint: Color {
        switch category {
        case .create: Color(hex: "4A9CFF")
        case .play:   Color(hex: "3ECF7A")
        case .fidget: Color(hex: "C77DFF")
        case .versus: Color(hex: "FF8A3D")
        }
    }
}
