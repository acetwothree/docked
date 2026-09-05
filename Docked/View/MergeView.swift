//
//  MergeView.swift
//  Docked
//
//  "2048" — swipe to slide the tiles; equal ones merge and add up. Each tile
//  keeps its identity across a move (`Tile.id`), so it visibly SLIDES to its
//  new cell rather than just changing a number at a fixed spot — that's what
//  makes the merge direction legible. A small corner badge flashes the swipe
//  direction too. Best score persists.
//

import SwiftUI

struct MergeView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("docked.merge.best") private var best: Int = 0
    // Board persists across activity switches (timing doesn't matter here).
    @AppStorage("docked.merge.grid") private var savedGrid = ""
    @AppStorage("docked.merge.score") private var savedScore = 0
    @AppStorage("docked.merge.over") private var savedOver = false

    private struct Tile: Identifiable {
        let id = UUID()
        var value: Int
        var row: Int
        var col: Int
        var pop = false   // true briefly right after this tile absorbs a merge
    }

    @State private var tiles: [Tile] = []
    @State private var score = 0
    @State private var over = false
    @State private var moveTick = 0
    @State private var mergeTick = 0
    @State private var bigMergeTick = 0
    @State private var restored = false

    /// The last swipe direction, shown as a brief fading glyph so the input
    /// itself is unambiguous even when nothing on the board can move that way.
    @State private var swipeDir: Dir? = nil
    @State private var swipeOpacity: Double = 0
    @State private var swipeGeneration = 0

    private let n = 4

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                stat("SCORE", score)
                Spacer()
                stat("BEST", max(best, score))
                Spacer()
                Button { newGame() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 30)
                }
                .buttonStyle(.plain)
            }

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                board(side: side)
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Text(hintText)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { v in
                    let dx = v.translation.width, dy = v.translation.height
                    if abs(dx) > abs(dy) { move(dx > 0 ? .right : .left) }
                    else { move(dy > 0 ? .down : .up) }
                }
        )
        .sensoryFeedback(.impact(weight: .light), trigger: moveTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(weight: .medium), trigger: mergeTick) { _, _ in app.haptics }
        .sensoryFeedback(.success, trigger: bigMergeTick) { _, _ in app.haptics }
        .onAppear {
            guard !restored else { return }
            restored = true
            let parts = savedGrid.split(separator: ",").compactMap { Int($0) }
            if parts.count == 16, parts.contains(where: { $0 != 0 }) {
                tiles = (0..<16).compactMap { i in
                    let v = parts[i]
                    guard v != 0 else { return nil }
                    return Tile(value: v, row: i / n, col: i % n)
                }
                score = savedScore
                over = savedOver
            } else {
                newGame()
            }
        }
    }

    private func persist() {
        savedGrid = (0..<16).map { i in String(gridValue(row: i / n, col: i % n)) }.joined(separator: ",")
        savedScore = score
        savedOver = over
    }

    private var hintText: String { over ? "No moves — tap ↻" : "Swipe to merge" }

    private enum Dir { case up, down, left, right }

    private func iconFor(_ d: Dir) -> String {
        switch d {
        case .up: "chevron.up"
        case .down: "chevron.down"
        case .left: "chevron.left"
        case .right: "chevron.right"
        }
    }

    private func stat(_ label: String, _ v: Int) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(.secondary)
            Text("\(v)").font(.system(size: 18, weight: .black)).monospacedDigit()
        }
    }

    private func board(side: CGFloat) -> some View {
        let gap: CGFloat = 6
        let cell = (side - gap * CGFloat(n + 1)) / CGFloat(n)
        return ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.06))
            ForEach(0..<16, id: \.self) { i in
                let r = i / n, c = i % n
                emptySlot(cell: cell, gap: gap, r: r, c: c)
            }
            ForEach(tiles) { tile in
                tileView(tile, cell: cell, gap: gap)
            }
            if let d = swipeDir {
                // A small corner badge, not a shape blocking the board —
                // just enough to confirm which way the swipe registered.
                Image(systemName: iconFor(d))
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 22, height: 22)
                    .background(Theme.paper, in: Circle())
                    .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
                    .opacity(swipeOpacity)
                    .position(x: side - 18, y: 18)
                    .allowsHitTesting(false)
            }
        }
    }

    private func emptySlot(cell: CGFloat, gap: CGFloat, r: Int, c: Int) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.primary.opacity(0.04))
            .frame(width: cell, height: cell)
            .position(x: gap + cell / 2 + CGFloat(c) * (cell + gap),
                      y: gap + cell / 2 + CGFloat(r) * (cell + gap))
    }

    private func tileView(_ tile: Tile, cell: CGFloat, gap: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(tileColor(tile.value))
            .overlay {
                Text("\(tile.value)")
                    .font(.system(size: cell * (tile.value >= 1000 ? 0.28 : 0.4), weight: .black, design: .rounded))
                    .foregroundStyle(tile.value <= 4 ? Color.primary : Color(red: 0.11, green: 0.08, blue: 0.02))
                    .minimumScaleFactor(0.5)
            }
            .frame(width: cell, height: cell)
            .scaleEffect(tile.pop ? 1.14 : 1)
            .position(x: gap + cell / 2 + CGFloat(tile.col) * (cell + gap),
                      y: gap + cell / 2 + CGFloat(tile.row) * (cell + gap))
            .transition(.scale(scale: 0.35).combined(with: .opacity))
            .animation(.spring(response: 0.26, dampingFraction: 0.55), value: tile.pop)
    }

    private func tileColor(_ v: Int) -> Color {
        switch v {
        case 0: return Color.primary.opacity(0.04)
        case 2: return Theme.accent.opacity(0.22)
        case 4: return Theme.accent.opacity(0.36)
        case 8: return Theme.accent.opacity(0.5)
        case 16: return Theme.accent.opacity(0.64)
        case 32: return Theme.accent.opacity(0.78)
        case 64: return Theme.accent.opacity(0.9)
        default: return Theme.accent
        }
    }

    // MARK: logic

    private func newGame() {
        tiles = []
        score = 0
        over = false
        swipeDir = nil
        swipeOpacity = 0
        spawn(); spawn()
        persist()
    }

    private func gridValue(row: Int, col: Int) -> Int {
        tiles.first { $0.row == row && $0.col == col }?.value ?? 0
    }

    private func spawn() {
        var empty: [(Int, Int)] = []
        for r in 0..<n { for c in 0..<n where gridValue(row: r, col: c) == 0 { empty.append((r, c)) } }
        guard let (r, c) = empty.randomElement() else { return }
        tiles.append(Tile(value: Int.random(in: 0..<10) == 0 ? 4 : 2, row: r, col: c))
    }

    /// Coordinates of one row/column, ordered from the edge the swipe pushes
    /// toward (index 0) back to the far edge.
    private func lineCoords(_ i: Int, _ dir: Dir) -> [(row: Int, col: Int)] {
        switch dir {
        case .left:  return (0..<n).map { (row: i, col: $0) }
        case .right: return (0..<n).map { (row: i, col: n - 1 - $0) }
        case .up:    return (0..<n).map { (row: $0, col: i) }
        case .down:  return (0..<n).map { (row: n - 1 - $0, col: i) }
        }
    }

    private func move(_ dir: Dir) {
        guard !over else { return }

        // Direction glyph — flashes on every swipe, whether or not it moves
        // anything, so the input itself always reads clearly.
        swipeDir = dir
        swipeGeneration += 1
        let gen = swipeGeneration
        withAnimation(.easeOut(duration: 0.05)) { swipeOpacity = 0.85 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            guard swipeGeneration == gen else { return }
            withAnimation(.easeOut(duration: 0.25)) { swipeOpacity = 0 }
        }

        var toRemove: Set<UUID> = []
        var didMerge = false
        var didBig = false
        var changed = false
        var updates: [(id: UUID, row: Int, col: Int, value: Int, pop: Bool)] = []

        for i in 0..<n {
            let coords = lineCoords(i, dir)
            let lineTiles: [Tile] = coords.compactMap { rc in tiles.first { $0.row == rc.row && $0.col == rc.col } }

            // Classic 2048 compaction: each tile merges into the one ahead of
            // it at most once per move (a tile born from a merge can't merge
            // again in the same move).
            var placed: [(tile: Tile, merged: Bool)] = []
            for cur in lineTiles {
                if let last = placed.last, !last.merged, last.tile.value == cur.value {
                    var t = last.tile
                    t.value *= 2
                    score += t.value
                    if t.value >= 64 { didBig = true }
                    didMerge = true
                    toRemove.insert(cur.id)
                    placed[placed.count - 1] = (t, true)
                } else {
                    placed.append((cur, false))
                }
            }
            for (slot, rc) in coords.enumerated() where slot < placed.count {
                let (t, merged) = placed[slot]
                if t.row != rc.row || t.col != rc.col { changed = true }
                updates.append((id: t.id, row: rc.row, col: rc.col, value: t.value, pop: merged))
            }
        }
        if !toRemove.isEmpty { changed = true }
        guard changed else { return }

        withAnimation(.easeInOut(duration: 0.14)) {
            for u in updates {
                guard let idx = tiles.firstIndex(where: { $0.id == u.id }) else { continue }
                tiles[idx].row = u.row
                tiles[idx].col = u.col
                tiles[idx].value = u.value
                tiles[idx].pop = u.pop
            }
            tiles.removeAll { toRemove.contains($0.id) }
        }

        moveTick += 1
        if didMerge { mergeTick += 1 }
        if didBig { bigMergeTick += 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { spawn() }
            for idx in tiles.indices { tiles[idx].pop = false }
            best = max(best, score)
            if !anyMoveLeft() { over = true }
            persist()
        }
    }

    private func anyMoveLeft() -> Bool {
        if tiles.count < n * n { return true }
        for r in 0..<n {
            for c in 0..<n {
                let v = gridValue(row: r, col: c)
                if c + 1 < n, v == gridValue(row: r, col: c + 1) { return true }
                if r + 1 < n, v == gridValue(row: r + 1, col: c) { return true }
            }
        }
        return false
    }
}
