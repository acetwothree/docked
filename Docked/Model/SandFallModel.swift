//
//  SandFallModel.swift
//  Docked
//
//  "Sand Fall" — coloured tetromino-shaped clusters fall down a grid; on
//  landing they crumble into loose grains of sand that trickle and settle
//  (straight down, or diagonally if blocked) instead of staying rigid.
//  A row clears when it's completely full AND every grain in it is the same
//  colour. Lose when a new piece can't spawn.
//
//  Each grain keeps a stable identity (`Grain.id`) across settle passes so
//  the view can animate it sliding to its new cell, rather than cells just
//  changing colour in place.
//

import SwiftUI

struct Grain: Identifiable {
    let id = UUID()
    var row: Int
    var col: Int
    let color: Color
}

@Observable
final class SandFallModel {
    enum Phase: Equatable { case play, over }

    let cols: Int
    let rows: Int

    private(set) var grains: [Grain] = []
    /// The falling piece's cells, in board coordinates (row can be negative
    /// while it's still entering from above the top edge).
    private(set) var activeCells: [(row: Int, col: Int)] = []
    private(set) var activeColor: Color = .white
    private(set) var score = 0
    private(set) var best: Int
    private(set) var phase: Phase = .play
    /// Rows currently flashing before they're removed.
    private(set) var clearingRows: Set<Int> = []

    private(set) var lockTick = 0
    private(set) var clearTick = 0
    private(set) var overTick = 0

    private static let palette: [Color] = [
        Color(hex: "E0473E"), Color(hex: "F2883C"), Color(hex: "F2B90C"),
        Color(hex: "3ECF7A"), Color(hex: "3EA1E0"), Color(hex: "C77DFF"),
    ]

    /// Row offsets are relative to a shape's own top; each is later shifted so
    /// the piece spawns just above the visible grid.
    private static let templates: [[(row: Int, col: Int)]] = [
        [(0, 0), (0, 1), (0, 2), (0, 3)],              // I
        [(0, 0), (0, 1), (1, 0), (1, 1)],              // O
        [(0, 0), (0, 1), (0, 2), (1, 1)],              // T
        [(0, 1), (0, 2), (1, 0), (1, 1)],              // S
        [(0, 0), (0, 1), (1, 1), (1, 2)],              // Z
        [(0, 0), (1, 0), (1, 1), (1, 2)],              // J
        [(0, 2), (1, 0), (1, 1), (1, 2)],              // L
    ]

    init(cols: Int = 9, rows: Int = 14, best: Int) {
        self.cols = cols
        self.rows = rows
        self.best = best
        spawn()
    }

    // MARK: spawn / occupancy

    private func occupiedSet() -> Set<Int> {
        Set(grains.map { $0.row * cols + $0.col })
    }

    private func spawn() {
        let template = Self.templates.randomElement()!
        let minRow = template.map(\.row).min() ?? 0
        let minCol = template.map(\.col).min() ?? 0
        let maxCol = template.map(\.col).max() ?? 0
        let width = maxCol - minCol + 1
        let shiftRow = -1 - minRow                       // top row lands at -1
        let shiftCol = (cols - width) / 2 - minCol
        activeCells = template.map { (row: $0.row + shiftRow, col: $0.col + shiftCol) }
        activeColor = Self.palette.randomElement()!

        if !canPlace(activeCells) {
            phase = .over
            overTick += 1
        }
    }

    private func canPlace(_ cells: [(row: Int, col: Int)]) -> Bool {
        let occ = occupiedSet()
        for c in cells {
            guard c.col >= 0, c.col < cols, c.row < rows else { return false }
            if c.row >= 0, occ.contains(c.row * cols + c.col) { return false }
        }
        return true
    }

    // MARK: player input

    func moveActive(dCol: Int) {
        guard phase == .play else { return }
        let moved = activeCells.map { (row: $0.row, col: $0.col + dCol) }
        if canPlace(moved) { activeCells = moved }
    }

    func rotateActive() {
        guard phase == .play, let pivot = activeCells.first else { return }
        let rotated = activeCells.map { c -> (row: Int, col: Int) in
            let dr = c.row - pivot.row, dc = c.col - pivot.col
            return (row: pivot.row + dc, col: pivot.col - dr)
        }
        if canPlace(rotated) { activeCells = rotated }
    }

    /// One tick of the fall — moves down if possible, else locks. Returns
    /// true while the piece is still falling.
    @discardableResult
    func stepDown() -> Bool {
        guard phase == .play else { return false }
        let moved = activeCells.map { (row: $0.row + 1, col: $0.col) }
        if canPlace(moved) {
            activeCells = moved
            return true
        } else {
            lock()
            return false
        }
    }

    func hardDrop() {
        guard phase == .play else { return }
        while stepDown() {}
    }

    private func lock() {
        for c in activeCells where c.row >= 0 {
            grains.append(Grain(row: c.row, col: c.col, color: activeColor))
        }
        activeCells = []
        lockTick += 1
    }

    // MARK: settle (falling-sand relaxation)

    /// One relaxation pass: every grain falls straight down if it can, else
    /// slides diagonally if a diagonal is open. Call repeatedly (the view
    /// drives this on a short timer) until it returns false.
    @discardableResult
    func settleStep() -> Bool {
        guard phase == .play else { return false }
        var occ = occupiedSet()
        var moved = false
        // Bottom-to-top so a grain never falls twice in the same pass.
        let order = grains.indices.sorted { grains[$0].row > grains[$1].row }
        for i in order {
            let g = grains[i]
            guard g.row + 1 < rows else { continue }
            let below = (g.row + 1) * cols + g.col
            if !occ.contains(below) {
                occ.remove(g.row * cols + g.col)
                grains[i].row += 1
                occ.insert(grains[i].row * cols + grains[i].col)
                moved = true
                continue
            }
            let leftCol = g.col - 1, rightCol = g.col + 1
            let canLeft = leftCol >= 0 && !occ.contains((g.row + 1) * cols + leftCol)
            let canRight = rightCol < cols && !occ.contains((g.row + 1) * cols + rightCol)
            guard canLeft || canRight else { continue }
            let goLeft = canLeft && (!canRight || Bool.random())
            occ.remove(g.row * cols + g.col)
            grains[i].col = goLeft ? leftCol : rightCol
            grains[i].row += 1
            occ.insert(grains[i].row * cols + grains[i].col)
            moved = true
        }
        return moved
    }

    /// Rows that are completely full AND a single colour throughout.
    func fullMonoRows() -> [Int] {
        var full: [Int] = []
        for r in 0..<rows {
            let rowGrains = grains.filter { $0.row == r }
            guard rowGrains.count == cols, let first = rowGrains.first?.color else { continue }
            if rowGrains.allSatisfy({ $0.color == first }) { full.append(r) }
        }
        return full
    }

    /// Marks rows as clearing (for the flash), actually removed a beat later
    /// by `finishClearing`.
    func beginClearing(_ rowsToClear: [Int]) {
        guard !rowsToClear.isEmpty else { return }
        clearingRows = Set(rowsToClear)
        clearTick += 1
    }

    func finishClearing() {
        guard !clearingRows.isEmpty else { return }
        let n = clearingRows.count
        grains.removeAll { clearingRows.contains($0.row) }
        score += n * 100 + (n - 1) * 40
        best = max(best, score)
        clearingRows = []
    }

    func afterLockShouldSpawnNext() {
        guard phase == .play else { return }
        spawn()
    }

    func resetRun() {
        grains = []
        activeCells = []
        score = 0
        phase = .play
        clearingRows = []
        spawn()
    }
}
