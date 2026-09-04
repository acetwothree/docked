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
    case gamble = "Gambling"
    var id: String { rawValue }
}

enum ActivityModule: String, CaseIterable, Identifiable {
    case doodle, notes, color
    case game, zen, flow, merge, drop, marble, brawl, spot, bombsort
    case tictactoe, connect4, dots
    case pop, click, ksand, beads
    case scratch, blackjack, poker
    var id: String { rawValue }

    var category: ActivityCategory {
        switch self {
        case .doodle, .notes, .color: .create
        case .game, .zen, .flow, .merge, .drop, .marble, .brawl, .spot, .bombsort,
             .tictactoe, .connect4, .dots: .play
        case .pop, .click, .ksand, .beads: .fidget
        case .scratch, .blackjack, .poker: .gamble
        }
    }

    var title: String {
        switch self {
        case .doodle: "Doodle"
        case .notes: "Notes"
        case .color: "Color"
        case .game: "Fit"
        case .zen: "Blocks"
        case .flow: "Flow"
        case .merge: "2048"
        case .drop: "Merge"
        case .marble: "Roll"
        case .brawl: "Brawl"
        case .spot: "Spot"
        case .bombsort: "Bomb Sort"
        case .tictactoe: "Tic-Tac-Toe"
        case .connect4: "Connect 4"
        case .dots: "Dots & Boxes"
        case .pop: "Pop"
        case .click: "Clicker"
        case .ksand: "Kinetic Sand"
        case .beads: "Beads"
        case .scratch: "Scratcher"
        case .blackjack: "Blackjack"
        case .poker: "Draw Poker"
        }
    }

    var systemImage: String {
        switch self {
        case .doodle: "scribble.variable"
        case .notes: "note.text"
        case .color: "paintbrush.pointed.fill"
        case .game: "figure.walk"
        case .zen: "square.grid.2x2.fill"
        case .flow: "point.3.connected.trianglepath.dotted"
        case .merge: "square.stack.3d.up.fill"
        case .drop: "circle.grid.2x2.fill"
        case .marble: "circle.fill"
        case .brawl: "burst.fill"
        case .spot: "eye.fill"
        case .bombsort: "flame.fill"
        case .tictactoe: "number"
        case .connect4: "circle.grid.cross.fill"
        case .dots: "square.grid.4x3.fill"
        case .pop: "circle.hexagongrid.fill"
        case .click: "hand.tap.fill"
        case .ksand: "hand.draw.fill"
        case .beads: "circle.grid.3x1.fill"
        case .scratch: "rectangle.dashed"
        case .blackjack: "suit.club.fill"
        case .poker: "suit.spade.fill"
        }
    }

    /// Activities behind Docked Plus.
    var isPlus: Bool {
        switch self {
        case .doodle, .notes, .color, .zen, .drop, .marble, .pop, .click, .beads,
             .scratch, .blackjack, .poker:
            return false
        case .game, .flow, .merge, .brawl, .spot, .bombsort, .ksand,
             .tictactoe, .connect4, .dots:
            return true
        }
    }

    /// One line describing what the activity does — shown on the paywall when
    /// the user taps something locked, so the upsell is specific.
    var blurb: String {
        switch self {
        case .doodle: "A freehand sketch pad."
        case .notes: "A quick scratch notepad."
        case .color: "Tap-to-fill colouring sheets."
        case .game: "Time your jumps and lanes to fit through the walls."
        case .zen: "A block-drop line-clear puzzle."
        case .flow: "Connect the matching dots without crossing."
        case .merge: "Slide-to-merge number tiles (2048)."
        case .drop: "Drop blocks into columns; equal ones merge."
        case .marble: "Slide a marble to paint every tile of the maze."
        case .brawl: "Swipe to fend off enemies from all four sides."
        case .spot: "Find the one creature that matches, against the clock."
        case .bombsort: "Flick red and black bombs into their bins before the wicks burn out."
        case .tictactoe: "Two-player noughts and crosses."
        case .connect4: "Two-player four-in-a-row."
        case .dots: "Two-player dots and boxes."
        case .pop: "A sheet of endless bubble wrap."
        case .click: "A tally clicker with a satisfying tick."
        case .ksand: "Rake patterns into a zen sand tray."
        case .beads: "Flick a row of beads back and forth."
        case .scratch: "Scratch-off cards — match three to win chips."
        case .blackjack: "Simple blackjack against the dealer."
        case .poker: "Five-card draw poker against the dealer."
        }
    }

    /// A colour per category — used to tint the picker cards.
    var tint: Color {
        switch category {
        case .create: Color(hex: "4A9CFF")
        case .play:   Color(hex: "3ECF7A")
        case .fidget: Color(hex: "C77DFF")
        case .gamble: Color(hex: "F5C518")
        }
    }
}
