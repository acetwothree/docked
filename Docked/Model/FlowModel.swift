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

    var reached: Int

    init(reached: Int) {
        self.reached = reached
        load(0)
    }

    // MARK: Levels

    static let levels: [FlowLevel] = [
        FlowLevel(size: 5, pairs: [
            (0, FlowCell(r: 0, c: 0), FlowCell(r: 4, c: 1)),
            (1, FlowCell(r: 0, c: 4), FlowCell(r: 3, c: 3)),
            (2, FlowCell(r: 2, c: 1), FlowCell(r: 4, c: 4)),
        ]),
        FlowLevel(size: 5, pairs: [
            (0, FlowCell(r: 0, c: 0), FlowCell(r: 2, c: 2)),
            (1, FlowCell(r: 0, c: 4), FlowCell(r: 4, c: 4)),
            (2, FlowCell(r: 4, c: 0), FlowCell(r: 2, c: 3)),
            (3, FlowCell(r: 1, c: 1), FlowCell(r: 3, c: 3)),
        ]),
        FlowLevel(size: 6, pairs: [
            (0, FlowCell(r: 0, c: 0), FlowCell(r: 5, c: 5)),
            (1, FlowCell(r: 0, c: 5), FlowCell(r: 5, c: 0)),
            (2, FlowCell(r: 1, c: 2), FlowCell(r: 4, c: 3)),
            (3, FlowCell(r: 2, c: 0), FlowCell(r: 3, c: 5)),
        ]),
        FlowLevel(size: 6, pairs: [
            (0, FlowCell(r: 0, c: 1), FlowCell(r: 5, c: 1)),
            (1, FlowCell(r: 0, c: 4), FlowCell(r: 5, c: 4)),
            (2, FlowCell(r: 2, c: 0), FlowCell(r: 2, c: 5)),
            (3, FlowCell(r: 3, c: 0), FlowCell(r: 3, c: 5)),
            (4, FlowCell(r: 0, c: 0), FlowCell(r: 5, c: 5)),
        ]),
        FlowLevel(size: 7, pairs: [
            (0, FlowCell(r: 0, c: 0), FlowCell(r: 6, c: 6)),
            (1, FlowCell(r: 0, c: 6), FlowCell(r: 6, c: 0)),
            (2, FlowCell(r: 3, c: 0), FlowCell(r: 3, c: 6)),
            (3, FlowCell(r: 0, c: 3), FlowCell(r: 6, c: 3)),
            (4, FlowCell(r: 2, c: 2), FlowCell(r: 4, c: 4)),
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
        if !linked { paths[color] = nil }
        checkComplete()
    }

    private func checkComplete() {
        let done = endpoints.keys.allSatisfy { color in
            guard let path = paths[color], let (a, b) = endpoints[color] else { return false }
            return (path.first == a && path.last == b) || (path.first == b && path.last == a)
        }
        if done {
            completions += 1
            reached = max(reached, levelIndex + 1)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
                guard let self else { return }
                self.load(self.levelIndex + 1)
            }
        }
    }

    func restart() { load(levelIndex) }
}
