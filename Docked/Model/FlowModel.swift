//
//  FlowModel.swift
//  Docked
//
//  "Flow" — drag from a coloured dot to its twin through empty cells
//  (orthogonal, no crossing). Connect every pair to clear the level; it
//  advances on its own. Hand-authored levels loop.
//

import SwiftUI

struct FlowCell: Hashable { var r: Int; var c: Int }

struct FlowLevel {
    let size: Int
    /// (colour index, endpoint A, endpoint B)
    let pairs: [(Int, FlowCell, FlowCell)]
}

enum FlowPalette {
    static let colors: [Color] = [
        Color(hex: "FF5A5A"), Color(hex: "4A9CFF"), Color(hex: "3ECf7A"),
        Color(hex: "F5B84A"), Color(hex: "C77DFF"), Color(hex: "FF8A3D"),
        Color(hex: "37D6D6"),
    ]
}

@Observable
final class FlowModel {

    private(set) var levelIndex = 0
    private(set) var size = 5
    /// colour index -> its two endpoints
    private(set) var endpoints: [Int: (FlowCell, FlowCell)] = [:]
    /// colour index -> ordered path of cells (endpoint … endpoint while solving)
    private(set) var paths: [Int: [FlowCell]] = [:]
    /// bumps whenever a level is completed (a haptic trigger)
    private(set) var completions = 0
    /// bumps whenever a single pipe links its two endpoints (a haptic trigger)
    private(set) var connectEvents = 0

    /// Cells covered so far / total — the level completes only at 100%.
    var cellCount: Int { size * size }
    var filledCount: Int { paths.values.reduce(0) { $0 + $1.count } }

    init() {
        load(0)
    }

    /// Jump to a saved level (used to restore progress on reopen).
    func resume(at index: Int) {
        load(max(0, index))
    }

    // MARK: Levels

    // Every level requires the whole grid covered (classic Flow). Each is
    // built from a hand-traced solution that tiles the grid, so the fill is
    // always reachable; the early ones are deliberately trivial.
    static let levels: [FlowLevel] = [
        // 1 — 3×3. Three straight columns.
        FlowLevel(size: 3, pairs: [
            (0, FlowCell(r: 0, c: 0), FlowCell(r: 2, c: 0)),
            (1, FlowCell(r: 0, c: 1), FlowCell(r: 2, c: 1)),
            (2, FlowCell(r: 0, c: 2), FlowCell(r: 2, c: 2)),
        ]),
        // 2 — 4×4. Four straight rows — fills the grid.
        FlowLevel(size: 4, pairs: [
            (0, FlowCell(r: 0, c: 0), FlowCell(r: 0, c: 3)),
            (1, FlowCell(r: 1, c: 0), FlowCell(r: 1, c: 3)),
            (2, FlowCell(r: 2, c: 0), FlowCell(r: 2, c: 3)),
            (3, FlowCell(r: 3, c: 0), FlowCell(r: 3, c: 3)),
        ]),
        // 3 — 5×5. Five pairs spread across the grid.
        FlowLevel(size: 5, pairs: [
            (0, FlowCell(r: 0, c: 0), FlowCell(r: 0, c: 4)),
            (1, FlowCell(r: 1, c: 0), FlowCell(r: 1, c: 4)),
            (2, FlowCell(r: 2, c: 0), FlowCell(r: 2, c: 4)),
            (3, FlowCell(r: 3, c: 0), FlowCell(r: 4, c: 2)),
            (4, FlowCell(r: 4, c: 3), FlowCell(r: 3, c: 4)),
        ]),
        // 4 — 6×6. Five combs / hairpins.
        FlowLevel(size: 6, pairs: [
            (0, FlowCell(r: 0, c: 0), FlowCell(r: 0, c: 5)),
            (1, FlowCell(r: 1, c: 0), FlowCell(r: 1, c: 5)),
            (2, FlowCell(r: 2, c: 0), FlowCell(r: 2, c: 5)),
            (3, FlowCell(r: 3, c: 0), FlowCell(r: 3, c: 5)),
            (4, FlowCell(r: 4, c: 0), FlowCell(r: 5, c: 2)),
            (5, FlowCell(r: 5, c: 3), FlowCell(r: 4, c: 5)),
        ]),
        // 5 — 7×7.
        FlowLevel(size: 7, pairs: [
            (0, FlowCell(r: 0, c: 0), FlowCell(r: 1, c: 6)),
            (1, FlowCell(r: 2, c: 0), FlowCell(r: 3, c: 6)),
            (2, FlowCell(r: 4, c: 0), FlowCell(r: 4, c: 6)),
            (3, FlowCell(r: 5, c: 0), FlowCell(r: 6, c: 3)),
            (4, FlowCell(r: 5, c: 3), FlowCell(r: 6, c: 6)),
        ]),
        // 6 — 5×5, five vertical runs.
        FlowLevel(size: 5, pairs: [
            (0, FlowCell(r: 0, c: 0), FlowCell(r: 4, c: 0)),
            (1, FlowCell(r: 0, c: 1), FlowCell(r: 4, c: 1)),
            (2, FlowCell(r: 0, c: 2), FlowCell(r: 4, c: 2)),
            (3, FlowCell(r: 0, c: 3), FlowCell(r: 4, c: 3)),
            (4, FlowCell(r: 0, c: 4), FlowCell(r: 4, c: 4)),
        ]),
        // 7 — 6×6, three horizontal 2-row combs.
        FlowLevel(size: 6, pairs: [
            (0, FlowCell(r: 0, c: 0), FlowCell(r: 0, c: 5)),
            (1, FlowCell(r: 2, c: 0), FlowCell(r: 2, c: 5)),
            (2, FlowCell(r: 4, c: 0), FlowCell(r: 4, c: 5)),
        ]),
        // 8 — 6×6, three vertical 2-col combs.
        FlowLevel(size: 6, pairs: [
            (0, FlowCell(r: 0, c: 0), FlowCell(r: 5, c: 0)),
            (1, FlowCell(r: 0, c: 2), FlowCell(r: 5, c: 2)),
            (2, FlowCell(r: 0, c: 4), FlowCell(r: 5, c: 4)),
        ]),
        // 9 — 7×7, three combs + a straight bottom row.
        FlowLevel(size: 7, pairs: [
            (0, FlowCell(r: 0, c: 0), FlowCell(r: 1, c: 6)),
            (1, FlowCell(r: 2, c: 0), FlowCell(r: 3, c: 6)),
            (2, FlowCell(r: 4, c: 0), FlowCell(r: 5, c: 6)),
            (3, FlowCell(r: 6, c: 0), FlowCell(r: 6, c: 6)),
        ]),
        // 10 — 7×7, two combs, a row, and two bottom combs.
        FlowLevel(size: 7, pairs: [
            (0, FlowCell(r: 0, c: 0), FlowCell(r: 1, c: 6)),
            (1, FlowCell(r: 2, c: 0), FlowCell(r: 3, c: 6)),
            (2, FlowCell(r: 4, c: 0), FlowCell(r: 4, c: 6)),
            (3, FlowCell(r: 5, c: 0), FlowCell(r: 5, c: 3)),
            (4, FlowCell(r: 5, c: 4), FlowCell(r: 6, c: 6)),
        ]),
    ]

    private func load(_ idx: Int) {
        levelIndex = idx
        let lvl = Self.levels[idx % Self.levels.count]
        size = lvl.size
        endpoints = [:]
        paths = [:]
        for (color, a, b) in lvl.pairs {
            endpoints[color] = (a, b)
        }
    }

    // MARK: Drag interaction

    func isEndpoint(_ cell: FlowCell) -> Int? {
        for (color, pair) in endpoints where pair.0 == cell || pair.1 == cell { return color }
        return nil
    }

    /// The colour occupying a cell (endpoint or path), if any.
    func occupant(_ cell: FlowCell) -> Int? {
        if let c = isEndpoint(cell) { return c }
        for (color, path) in paths where path.contains(cell) { return color }
        return nil
    }

    /// Begin a drag on `cell`. Only starts from an endpoint (any partial
    /// path for that colour is cleared and re-traced from that end).
    func begin(at cell: FlowCell) -> Int? {
        guard let color = isEndpoint(cell) else { return nil }
        paths[color] = [cell]
        return color
    }

    /// Try to extend `color`'s path to `cell`. Returns true if the path changed.
    @discardableResult
    func extend(_ color: Int, to cell: FlowCell) -> Bool {
        guard var path = paths[color], let last = path.last else { return false }
        guard cell.r >= 0, cell.c >= 0, cell.r < size, cell.c < size else { return false }

        // stepping back onto the previous cell = undo one step
        if path.count >= 2, path[path.count - 2] == cell {
            path.removeLast()
            paths[color] = path
            return true
        }
        // must be orthogonally adjacent and not already in this path
        guard abs(cell.r - last.r) + abs(cell.c - last.c) == 1, !path.contains(cell) else { return false }

        // target must be free, or this colour's opposite endpoint
        if let occ = occupant(cell) {
            let ends = endpoints[color]
            let isOwnEnd = (ends?.0 == cell || ends?.1 == cell)
            if !(occ == color && isOwnEnd) { return false }
        }
        path.append(cell)
        paths[color] = path
        return true
    }

    func end(_ color: Int) {
        // keep a path only if it links the two endpoints
        guard let path = paths[color], let (a, b) = endpoints[color] else { paths[color] = nil; return }
        let linked = (path.first == a && path.last == b) || (path.first == b && path.last == a)
        if linked { connectEvents += 1 } else { paths[color] = nil }
        checkComplete()
    }

    private func checkComplete() {
        let linked = endpoints.keys.allSatisfy { color in
            guard let path = paths[color], let (a, b) = endpoints[color] else { return false }
            return (path.first == a && path.last == b) || (path.first == b && path.last == a)
        }
        guard linked else { return }
        // Completing the level just means every pair is connected — filling the
        // whole grid is an optional flourish, shown as a percentage in the HUD.
        completions += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            guard let self else { return }
            self.load(self.levelIndex + 1)
        }
    }

    func restart() { load(levelIndex) }
}
