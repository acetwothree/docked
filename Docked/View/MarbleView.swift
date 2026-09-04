//
//  MarbleView.swift
//  Docked
//
//  "Roll" — swipe and the marble slides until it hits a wall or the edge.
//  Land it on the flag to clear the level. Levels are generated randomly with
//  scattered obstacles and a guaranteed solution (BFS over slide moves), and
//  get bigger / denser / longer as the level number climbs. Level persists.
//

import SwiftUI

struct MarbleView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("docked.marble.level") private var level: Int = 1

    @State private var cols = 5
    @State private var rows = 5
    @State private var walls: Set<Int> = []
    @State private var visited: Set<Int> = []
    @State private var pos = 0
    @State private var goal = 0
    @State private var cleared = false
    @State private var loaded = false
    @State private var moveTick = 0
    @State private var hitTick = 0
    @State private var winTick = 0

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("LEVEL \(level)")
                    .font(.system(size: 13, weight: .heavy)).tracking(1)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { load(level) } label: {
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

            Text(cleared ? "Cleared!" : "Swipe to roll · land on the flag")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(cleared ? Color.green : Color.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 14)
                .onEnded { v in
                    let dx = v.translation.width, dy = v.translation.height
                    if abs(dx) > abs(dy) { roll(dx > 0 ? 1 : -1, 0) }
                    else { roll(0, dy > 0 ? 1 : -1) }
                }
        )
        .sensoryFeedback(.impact(weight: .light), trigger: moveTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: hitTick) { _, _ in app.haptics }
        .sensoryFeedback(.success, trigger: winTick) { _, _ in app.haptics }
        .onAppear { if !loaded { load(level); loaded = true } }
    }

    private func board(side: CGFloat) -> some View {
        let span = CGFloat(max(cols, rows))
        let gap: CGFloat = 4
        let cell = (side - gap * (span + 1)) / span
        let count = cols * rows
        return ZStack {
            ForEach(Array(0..<count), id: \.self) { i in
                cellView(i, cell: cell, gap: gap)
            }
            // goal flag
            Image(systemName: "flag.checkered")
                .font(.system(size: cell * 0.5, weight: .black))
                .foregroundStyle(Color.green)
                .position(x: gap + cell / 2 + CGFloat(goal % cols) * (cell + gap),
                          y: gap + cell / 2 + CGFloat(goal / cols) * (cell + gap))
                .opacity(cleared ? 0.35 : 1)

            Circle().fill(Theme.accent)
                .frame(width: cell * 0.7, height: cell * 0.7)
                .position(x: gap + cell / 2 + CGFloat(pos % cols) * (cell + gap),
                          y: gap + cell / 2 + CGFloat(pos / cols) * (cell + gap))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                .animation(.snappy(duration: 0.14), value: pos)
        }
    }

    private func cellView(_ i: Int, cell: CGFloat, gap: CGFloat) -> some View {
        let c = i % cols, r = i / cols
        let fill: Color
        if walls.contains(i) { fill = Color.primary.opacity(0.55) }
        else if visited.contains(i) { fill = Theme.accent.opacity(0.28) }
        else { fill = Color.primary.opacity(0.07) }
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(fill)
            .frame(width: cell, height: cell)
            .position(x: gap + cell / 2 + CGFloat(c) * (cell + gap),
                      y: gap + cell / 2 + CGFloat(r) * (cell + gap))
    }

    // MARK: movement

    private func roll(_ dc: Int, _ dr: Int) {
        guard !cleared else { return }
        var c = pos % cols
        var r = pos / cols
        var moved = false
        var hitWall = false
        while true {
            let nc = c + dc, nr = r + dr
            if nc < 0 || nc >= cols || nr < 0 || nr >= rows { break }
            let ni = nr * cols + nc
            if walls.contains(ni) { hitWall = true; break }
            c = nc; r = nr
            visited.insert(ni)
            moved = true
        }
        guard moved else { return }
        pos = r * cols + c
        moveTick += 1
        if hitWall { hitTick += 1 }
        if pos == goal {
            cleared = true
            winTick += 1
            let next = level + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                level = next
                load(next)
            }
        }
    }

    // MARK: level generation

    private struct Level {
        let cols: Int, rows: Int, start: Int, goal: Int
        let walls: Set<Int>
    }

    private func load(_ n: Int) {
        let lv = Self.generate(level: n)
        cols = lv.cols
        rows = lv.rows
        walls = lv.walls
        pos = lv.start
        goal = lv.goal
        visited = [lv.start]
        cleared = false
    }

    private static let dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]

    /// Slide from `cell` in `dir` until a wall or edge stops it.
    private static func slide(from cell: Int, _ dir: (Int, Int),
                              cols: Int, rows: Int, walls: Set<Int>) -> Int {
        var c = cell % cols, r = cell / cols
        while true {
            let nc = c + dir.0, nr = r + dir.1
            if nc < 0 || nc >= cols || nr < 0 || nr >= rows { break }
            if walls.contains(nr * cols + nc) { break }
            c = nc; r = nr
        }
        return r * cols + c
    }

    private static func generate(level n: Int) -> Level {
        let lvl = max(1, n)
        let base = min(9, 4 + (lvl - 1) / 5)
        let cols = base
        let rows = min(9, max(4, base + [-1, 0, 1].randomElement()!))
        let count = cols * rows
        let minMoves = min(12, 3 + lvl / 6)

        for attempt in 0..<400 {
            let density = max(0.10, (0.15 + Double(lvl) * 0.010) - Double(attempt) / 3000.0)
            let wallCount = min(count - 3, Int(Double(count) * density))
            var walls = Set<Int>()
            while walls.count < wallCount { walls.insert(Int.random(in: 0..<count)) }

            let open = (0..<count).filter { !walls.contains($0) }
            guard open.count >= 2, let start = open.randomElement() else { continue }

            // BFS over resting positions reachable by sliding
            var dist: [Int: Int] = [start: 0]
            var queue = [start]
            var qi = 0
            while qi < queue.count {
                let cur = queue[qi]; qi += 1
                let d = dist[cur]!
                for dir in dirs {
                    let dest = slide(from: cur, dir, cols: cols, rows: rows, walls: walls)
                    if dest != cur && dist[dest] == nil {
                        dist[dest] = d + 1
                        queue.append(dest)
                    }
                }
            }

            let far = dist.filter { $0.key != start && $0.value >= minMoves }
            if let goal = far.max(by: { $0.value < $1.value })?.key {
                return Level(cols: cols, rows: rows, start: start, goal: goal, walls: walls)
            }
        }

        // Fallback: near-empty board, corner to corner.
        var walls = Set<Int>()
        walls.insert(cols * (rows / 2) + cols / 2)
        return Level(cols: cols, rows: rows, start: 0, goal: count - 1, walls: walls)
    }
}
