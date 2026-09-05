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
    var id: String { rawValue }
}

// Declaration order is also the order the home grid shows them in: doodle,
// Color Blocks, Color, Maze Paint, Number Merge and Pop lead (the most-used
// free activities), then the rest of the free set, then every Plus activity
// last.
enum ActivityModule: String, CaseIterable, Identifiable {
    case doodle, zen, color, marble, drop, pop, notes, click, rings, sandfall, merge, brawl, spot, ksand
    var id: String { rawValue }

    var category: ActivityCategory {
        switch self {
        case .doodle, .notes, .color: .create
        case .zen, .merge, .drop, .marble, .brawl, .spot, .sandfall: .play
        case .pop, .click, .ksand, .rings: .fidget
        }
    }

    var title: String {
        switch self {
        case .doodle: "Doodle"
        case .notes: "Notes"
        case .color: "Color"
        case .zen: "Color Blocks"
        case .merge: "2048"
        case .drop: "Number Merge"
        case .marble: "Maze Paint"
        case .brawl: "Brawl"
        case .spot: "Spot"
        case .pop: "Pop"
        case .click: "Clicker"
        case .ksand: "Kinetic Sand"
        case .rings: "Rings"
        case .sandfall: "Sand Fall"
        }
    }

    var systemImage: String {
        switch self {
        case .doodle: "scribble.variable"
        case .notes: "note.text"
        case .color: "paintbrush.pointed.fill"
        case .zen: "square.grid.2x2.fill"
        case .merge: "square.stack.3d.up.fill"
        case .drop: "circle.grid.2x2.fill"
        case .marble: "circle.fill"
        case .brawl: "burst.fill"
        case .spot: "eye.fill"
        case .pop: "circle.hexagongrid.fill"
        case .click: "hand.tap.fill"
        case .ksand: "hand.draw.fill"
        case .rings: "circle.circle.fill"
        case .sandfall: "hourglass"
        }
    }

    /// Activities behind Docked Plus.
    var isPlus: Bool {
        switch self {
        case .doodle, .notes, .color, .zen, .drop, .marble, .pop, .click, .rings, .sandfall:
            return false
        case .merge, .brawl, .spot, .ksand:
            return true
        }
    }

    /// One line describing what the activity does — shown on the paywall.
    var blurb: String {
        switch self {
        case .doodle: "A freehand sketch pad."
        case .notes: "A quick scratch notepad."
        case .color: "Tap-to-fill colouring scenes."
        case .zen: "A block-drop line-clear puzzle."
        case .merge: "Swipe to slide and merge matching number tiles."
        case .drop: "Drop numbered pieces into columns; equal ones merge."
        case .marble: "Slide a marble to paint every tile of the maze."
        case .brawl: "Swipe to fend off enemies from all four sides."
        case .spot: "Find the one creature that matches, against the clock."
        case .pop: "A sheet of endless bubble wrap."
        case .click: "A tally clicker with a satisfying tick."
        case .ksand: "Rake patterns into a zen sand tray."
        case .rings: "Stack the rings smallest-on-top — the classic tower puzzle."
        case .sandfall: "Colourful falling-sand tetrominoes — clear a line by filling it with one colour."
        }
    }

    /// A colour per category — used to tint the picker cards.
    var tint: Color {
        switch category {
        case .create: Color(hex: "4A9CFF")
        case .play:   Color(hex: "3ECF7A")
        case .fidget: Color(hex: "C77DFF")
        }
    }
}
