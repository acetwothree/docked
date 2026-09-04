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
    case gamble = "Gambling"
    var id: String { rawValue }
}

enum ActivityModule: String, CaseIterable, Identifiable {
    case doodle, notes
    case game, zen, flow, merge, drop, marble, brawl
    case pop, click, ksand
    case scratch, blackjack
    case tictactoe, connect4, dots
    var id: String { rawValue }

    var category: ActivityCategory {
        switch self {
        case .doodle, .notes: .create
        case .game, .zen, .flow, .merge, .drop, .marble, .brawl: .play
        case .pop, .click, .ksand: .fidget
        case .scratch, .blackjack: .gamble
        case .tictactoe, .connect4, .dots: .versus
        }
    }

    var title: String {
        switch self {
        case .doodle: "Doodle"
        case .notes: "Notes"
        case .game: "Runner"
        case .zen: "Blocks"
        case .flow: "Flow"
        case .merge: "2048"
        case .drop: "Merge"
        case .marble: "Roll"
        case .brawl: "Brawl"
        case .pop: "Pop"
        case .click: "Clicker"
        case .ksand: "Kinetic Sand"
        case .scratch: "Scratcher"
        case .blackjack: "Blackjack"
        case .tictactoe: "Tic-Tac-Toe"
        case .connect4: "Connect 4"
        case .dots: "Dots & Boxes"
        }
    }
    var systemImage: String {
        switch self {
        case .doodle: "scribble.variable"
        case .notes: "note.text"
        case .game: "figure.run"
        case .zen: "square.grid.2x2.fill"
        case .flow: "point.3.connected.trianglepath.dotted"
        case .merge: "square.stack.3d.up.fill"
        case .drop: "circle.grid.2x2.fill"
        case .marble: "circle.fill"
        case .brawl: "burst.fill"
        case .pop: "circle.hexagongrid.fill"
        case .click: "hand.tap.fill"
        case .ksand: "hand.draw.fill"
        case .scratch: "rectangle.dashed"
        case .blackjack: "suit.club.fill"
        case .tictactoe: "number"
        case .connect4: "circle.grid.cross.fill"
        case .dots: "square.grid.4x3.fill"
        }
    }

    /// Activities behind Docked Plus. The free set stays genuinely useful on
    /// its own — sketching, notes, Blocks, Roll, Merge, two fidgets, the
    /// gambling loop and Tic-Tac-Toe — so the app has real value unpaid.
    var isPlus: Bool {
        switch self {
        case .doodle, .notes, .zen, .drop, .marble, .pop, .click,
             .scratch, .blackjack, .tictactoe:
            return false
        case .game, .flow, .merge, .brawl, .ksand, .connect4, .dots:
            return true
        }
    }

    /// One line describing what the activity does — shown on the paywall when
    /// the user taps something locked, so the upsell is specific.
    var blurb: String {
        switch self {
        case .doodle: "A freehand sketch pad."
        case .notes: "A quick scratch notepad."
        case .game: "An endless one-thumb runner."
        case .zen: "A block-drop line-clear puzzle."
        case .flow: "Connect the matching dots without crossing."
        case .merge: "Slide-to-merge number tiles (2048)."
        case .drop: "Drop blocks into columns; equal ones merge."
        case .marble: "Slide a marble to paint every tile of the maze."
        case .brawl: "Swipe to fend off enemies from all four sides."
        case .pop: "A sheet of endless bubble wrap."
        case .click: "A tally clicker with a satisfying tick."
        case .scratch: "Scratch-off cards — match three to win chips."
        case .blackjack: "Simple blackjack against the dealer."
        case .ksand: "Rake patterns into a zen sand tray."
        case .tictactoe: "Two-player noughts and crosses."
        case .connect4: "Two-player four-in-a-row."
        case .dots: "Two-player dots and boxes."
        }
    }

    /// A colour per category — used to tint the picker cards.
    var tint: Color {
        switch category {
        case .create: Color(hex: "4A9CFF")
        case .play:   Color(hex: "3ECF7A")
        case .fidget: Color(hex: "C77DFF")
        case .versus: Color(hex: "FF8A3D")
        case .gamble: Color(hex: "F5C518")
        }
    }
}
