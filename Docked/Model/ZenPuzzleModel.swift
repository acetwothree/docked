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
    /// true = permanently unavailable (under the video).
    private(set) var blocked: [[Bool]] = []

    private(set) var dock: [ZenShape?] = [nil, nil, nil]
    private(set) var score = 0
    private(set) var phase: Phase = .play
    /// Set of "r,c" keys currently animating out from a line clear.
    private(set) var clearing: Set<String> = []

    var highScore: Int

    private var pendingWipe = true

    init(highScore: Int) {
        self.highScore = highScore
        dock = [Self.roll(), Self.roll(), Self.roll()]
    }

    // MARK: Layout — called by the view when the grid size / video hole changes

    private func emptyBoard(cols: Int, rows: Int) -> [[[Color]?]] {
        let row: [[Color]?] = Array(repeating: nil, count: max(1, cols))
        return Array(repeating: row, count: max(1, rows))
    }

    /// `blockedMask[r][c]` marks cells hidden under the video.
    func configure(cols: Int, rows: Int, blockedMask: [[Bool]]) {
        let dimsChanged = cols != self.cols || rows != self.rows
        self.cols = max(1, cols)
        self.rows = max(1, rows)
        self.blocked = blockedMask
        if pendingWipe || dimsChanged {
            board = emptyBoard(cols: self.cols, rows: self.rows)
            pendingWipe = false
        }
    }

    // MARK: Run control

    func resetRun() {
        score = 0
        phase = .play
        clearing.removeAll()
        pendingWipe = true
        dock = [Self.roll(), Self.roll(), Self.roll()]
        if cols > 0, rows > 0 {
            board = emptyBoard(cols: cols, rows: rows)
            pendingWipe = false
        }
    }

    // MARK: Placement

    func canPlace(_ shape: ZenShape, atRow ar: Int, col ac: Int) -> Bool {
        for (dr, dc) in shape.cells {
            let r = ar + dr, c = ac + dc
            guard r >= 0, c >= 0, r < rows, c < cols else { return false }
            if blocked.indices.contains(r), blocked[r].indices.contains(c), blocked[r][c] { return false }
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

        let cleared = clearFullLines()
        if cleared > 0 { score += cleared * 10 + (cleared - 1) * 6 }

        dock[slot] = nil
        if dock.allSatisfy({ $0 == nil }) {
            dock = [Self.roll(), Self.roll(), Self.roll()]
        }

        let alive = dock.compactMap { $0 }
        if !alive.isEmpty, !alive.contains(where: { self.fitsAnywhere($0) }) {
            phase = .over
            highScore = max(highScore, score)
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
        func occupied(_ r: Int, _ c: Int) -> Bool {
            board[r][c] != nil || (blocked.indices.contains(r) && blocked[r].indices.contains(c) && blocked[r][c])
        }
        var fullRows: [Int] = [], fullCols: [Int] = []
        for r in 0..<rows where (0..<cols).allSatisfy({ occupied(r, $0) }) { fullRows.append(r) }
        for c in 0..<cols where (0..<rows).allSatisfy({ occupied($0, c) }) { fullCols.append(c) }
        guard !fullRows.isEmpty || !fullCols.isEmpty else { return 0 }

        var keys: Set<String> = []
        for r in fullRows { for c in 0..<cols { keys.insert("\(r),\(c)") } }
        for c in fullCols { for r in 0..<rows { keys.insert("\(r),\(c)") } }
        for k in keys {
            let p = k.split(separator: ",").compactMap { Int($0) }
            if p.count == 2, !(blocked.indices.contains(p[0]) && blocked[p[0]].indices.contains(p[1]) && blocked[p[0]][p[1]]) {
                board[p[0]][p[1]] = nil
            }
        }
        clearing = keys
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
        (1, [(0,0),(0,1),(0,2),(1,0),(1,1),(1,2),(2,0),(2,1),(2,2)]),
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
