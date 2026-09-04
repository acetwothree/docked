//
//  ZenPuzzleModel.swift
//  Docked
//
//  A block-drop puzzle: a 3-slot dock of random polyominoes, dragged onto a
//  grid that fills the screen around the video slot. Full rows / columns
//  clear. When none of the 3 dock pieces fit anywhere, the run ends, the
//  board wipes and the high score is kept. Changing the video layout mid-run
//  also wipes the board so you can build around the new position.
//
//  Ported from the "Cat Cafe Hustle" drag-and-drop core loop, with the
//  multiplayer transport, round timer and combo system removed.
//

import SwiftUI

struct ZenShape: Identifiable {
    let id = UUID()
    /// Filled cells as (row, col) offsets from the shape's top-left.
    let cells: [(Int, Int)]
    /// Gradient stops [light, base, dark].
    let palette: [Color]

    var width: Int { (cells.map { $0.1 }.max() ?? 0) + 1 }
    var height: Int { (cells.map { $0.0 }.max() ?? 0) + 1 }

    var gradient: LinearGradient {
        LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

@Observable
final class ZenPuzzleModel {

    enum Phase: Equatable { case play, over }

    // MARK: Grid state
    private(set) var cols = 0
    private(set) var rows = 0
    /// nil = empty, otherwise the placed piece's palette.
    private(set) var board: [[[Color]?]] = []

    private(set) var dock: [ZenShape?] = [nil, nil, nil]
    private(set) var score = 0
    private(set) var phase: Phase = .play
    /// Set of "r,c" keys currently animating out from a line clear.
    private(set) var clearing: Set<String> = []
    /// Bumps every time one or more lines clear — a haptic trigger.
    private(set) var clearEvents = 0
    /// Bumps on every successful placement — a light haptic trigger.
    private(set) var placeEvents = 0

    var highScore: Int

    private var pendingWipe = true
    /// A board restored from disk (palette indices, 0 = empty), applied by
    /// `configure` once the grid size is known and matches.
    private var pendingRestore: [[Int]]? = nil

    private static let boardKey = "docked.zen.board"
    private static let scoreKey = "docked.zen.score"

    init(highScore: Int) {
        self.highScore = highScore
        dock = [Self.roll(), Self.roll(), Self.roll()]
        if let data = UserDefaults.standard.data(forKey: Self.boardKey),
           let grid = try? JSONDecoder().decode([[Int]].self, from: data),
           !grid.isEmpty, grid.contains(where: { $0.contains { $0 != 0 } }) {
            pendingRestore = grid
            score = UserDefaults.standard.integer(forKey: Self.scoreKey)
        }
    }

    // MARK: Layout — called by the view when the grid size / video hole changes

    private func emptyBoard(cols: Int, rows: Int) -> [[[Color]?]] {
        let row: [[Color]?] = Array(repeating: nil, count: max(1, cols))
        return Array(repeating: row, count: max(1, rows))
    }

    /// Set the grid dimensions; wipes the board when they change or a reset
    /// is pending — unless a saved board of the same size is waiting.
    func configure(cols: Int, rows: Int) {
        let dimsChanged = cols != self.cols || rows != self.rows
        self.cols = max(1, cols)
        self.rows = max(1, rows)

        if let grid = pendingRestore, grid.count == self.rows,
           grid.allSatisfy({ $0.count == self.cols }) {
            board = grid.map { row in
                row.map { $0 == 0 ? nil : Self.palettes[($0 - 1) % Self.palettes.count] }
            }
            pendingRestore = nil
            pendingWipe = false
            return
        }
        pendingRestore = nil

        if pendingWipe || dimsChanged {
            board = emptyBoard(cols: self.cols, rows: self.rows)
            pendingWipe = false
        }
    }

    // MARK: Persistence

    private func paletteIndex(_ colors: [Color]) -> Int {
        Self.palettes.firstIndex(of: colors) ?? 0
    }

    private func saveBoard() {
        let grid = board.map { row in
            row.map { $0 == nil ? 0 : paletteIndex($0!) + 1 }
        }
        if let data = try? JSONEncoder().encode(grid) {
            UserDefaults.standard.set(data, forKey: Self.boardKey)
        }
        UserDefaults.standard.set(score, forKey: Self.scoreKey)
    }

    private func clearSaved() {
        UserDefaults.standard.removeObject(forKey: Self.boardKey)
        UserDefaults.standard.removeObject(forKey: Self.scoreKey)
    }

    // MARK: Run control

    func resetRun() {
        score = 0
        phase = .play
        clearing.removeAll()
        pendingWipe = true
        pendingRestore = nil
        dock = [Self.roll(), Self.roll(), Self.roll()]
        if cols > 0, rows > 0 {
            board = emptyBoard(cols: cols, rows: rows)
            pendingWipe = false
        }
        clearSaved()
    }

    // MARK: Placement

    func canPlace(_ shape: ZenShape, atRow ar: Int, col ac: Int) -> Bool {
        for (dr, dc) in shape.cells {
            let r = ar + dr, c = ac + dc
            guard r >= 0, c >= 0, r < rows, c < cols else { return false }
            if board[r][c] != nil { return false }
        }
        return true
    }

    /// Commit a drop. Returns true if it landed.
    @discardableResult
    func place(slot: Int, shape: ZenShape, atRow ar: Int, col ac: Int) -> Bool {
        guard phase == .play, canPlace(shape, atRow: ar, col: ac) else { return false }
        for (dr, dc) in shape.cells { board[ar + dr][ac + dc] = shape.palette }
        score += shape.cells.count
        placeEvents += 1

        let cleared = clearFullLines()
        if cleared > 0 { score += cleared * 10 + (cleared - 1) * 6 }

        // Refill the used slot right away so there are always 3 options —
        // keeps the 6×6 board approachable.
        dock[slot] = Self.roll()

        let alive = dock.compactMap { $0 }
        if !alive.isEmpty, !alive.contains(where: { self.fitsAnywhere($0) }) {
            phase = .over
            highScore = max(highScore, score)
            clearSaved()
        } else {
            saveBoard()
        }
        return true
    }

    func fitsAnywhere(_ shape: ZenShape) -> Bool {
        guard rows >= shape.height, cols >= shape.width else { return false }
        for r in 0...(rows - shape.height) {
            for c in 0...(cols - shape.width) where canPlace(shape, atRow: r, col: c) {
                return true
            }
        }
        return false
    }

    private func clearFullLines() -> Int {
        var fullRows: [Int] = [], fullCols: [Int] = []
        for r in 0..<rows where (0..<cols).allSatisfy({ board[r][$0] != nil }) { fullRows.append(r) }
        for c in 0..<cols where (0..<rows).allSatisfy({ board[$0][c] != nil }) { fullCols.append(c) }
        guard !fullRows.isEmpty || !fullCols.isEmpty else { return 0 }

        var keys: Set<String> = []
        for r in fullRows { for c in 0..<cols { keys.insert("\(r),\(c)") } }
        for c in fullCols { for r in 0..<rows { keys.insert("\(r),\(c)") } }
        for k in keys {
            let p = k.split(separator: ",").compactMap { Int($0) }
            if p.count == 2 { board[p[0]][p[1]] = nil }
        }
        clearing = keys
        clearEvents += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.clearing.removeAll()
        }
        return fullRows.count + fullCols.count
    }

    // MARK: Shape library (weighted)

    private static let templates: [(w: Int, cells: [(Int, Int)])] = [
        (4, [(0,0)]),
        (6, [(0,0),(0,1)]), (6, [(0,0),(1,0)]),
        (6, [(0,0),(0,1),(0,2)]), (6, [(0,0),(1,0),(2,0)]),
        (5, [(0,0),(1,0),(1,1)]), (5, [(0,0),(0,1),(1,0)]), (5, [(0,0),(0,1),(1,1)]), (5, [(0,1),(1,0),(1,1)]),
        (6, [(0,0),(0,1),(1,0),(1,1)]),
        (4, [(0,0),(0,1),(0,2),(0,3)]), (4, [(0,0),(1,0),(2,0),(3,0)]),
        (4, [(0,0),(1,0),(2,0),(2,1)]), (4, [(0,0),(0,1),(0,2),(1,0)]),
        (4, [(0,0),(0,1),(1,1),(2,1)]), (4, [(1,0),(1,1),(1,2),(0,2)]),
        (4, [(0,1),(1,1),(2,0),(2,1)]), (4, [(0,0),(1,0),(1,1),(1,2)]),
        (4, [(0,0),(0,1),(1,0),(2,0)]), (4, [(0,0),(0,1),(0,2),(1,2)]),
        (4, [(0,1),(0,2),(1,0),(1,1)]), (4, [(0,0),(0,1),(1,1),(1,2)]),
        (4, [(0,0),(0,1),(0,2),(1,1)]), (4, [(0,1),(1,0),(1,1),(2,1)]),
        (2, [(0,0),(0,1),(0,2),(1,0),(1,1),(1,2)]), (2, [(0,0),(0,1),(1,0),(1,1),(2,0),(2,1)]),
        (2, [(0,0),(1,0),(2,0),(2,1),(2,2)]), (2, [(0,1),(1,0),(1,1),(1,2),(2,1)]),
        // (3x3 block removed — too large for the 6x6 board.)
    ]

    private static let palettes: [[Color]] = [
        [Color(hex: "FF8A7D"), Color(hex: "E0473E"), Color(hex: "A82F28")],
        [Color(hex: "FFE066"), Color(hex: "F2B90C"), Color(hex: "B3860A")],
        [Color(hex: "F5A3F5"), Color(hex: "D94FD9"), Color(hex: "9C2F9C")],
        [Color(hex: "FFB877"), Color(hex: "F2883C"), Color(hex: "B35D22")],
        [Color(hex: "8ECDF5"), Color(hex: "3EA1E0"), Color(hex: "256A99")],
        [Color(hex: "8EF0B0"), Color(hex: "3ECF7A"), Color(hex: "25995A")],
    ]

    private static let totalWeight = templates.reduce(0) { $0 + $1.w }

    static func roll() -> ZenShape {
        var r = Int.random(in: 0..<totalWeight)
        var chosen = templates[0]
        for t in templates {
            if r < t.w { chosen = t; break }
            r -= t.w
        }
        return ZenShape(cells: chosen.cells, palette: palettes.randomElement()!)
    }
}
