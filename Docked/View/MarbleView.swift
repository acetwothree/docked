//
//  MarbleView.swift
//  Docked
//
//  "Roll" — swipe and the marble slides until it hits a wall or the edge.
//  Paint every open tile to clear the level. Levels are random mazes (a
//  recursive-backtracker carve), so the corridors twist differently every
//  time and the marble stops at every junction — which means a full sweep is
//  always possible. Grid size grows with the level. Level persists.
//

import SwiftUI

struct MarbleView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("docked.marble.level") private var level: Int = 1

    @State private var cols = 5
    @State private var rows = 5
    @State private var walls: Set<Int> = []
    @State private var openCells: Set<Int> = []
    @State private var visited: Set<Int> = []
    @State private var pos = 0
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
                Text("\(visited.count)/\(openCells.count)")
                    .font(.system(size: 11, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(cleared ? Color.green : Color.secondary)
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

            Text(cleared ? "Cleared!" : "Swipe to roll · cover every tile")
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
        let gap: CGFloat = 3
        let cell = (side - gap * (span + 1)) / span
        let count = cols * rows
        return ZStack {
            ForEach(Array(0..<count), id: \.self) { i in
                cellView(i, cell: cell, gap: gap)
            }
            Circle().fill(Theme.accent)
                .frame(width: cell * 0.72, height: cell * 0.72)
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
        else if visited.contains(i) { fill = Theme.accent.opacity(0.30) }
        else { fill = Color.primary.opacity(0.07) }
        return RoundedRectangle(cornerRadius: 5, style: .continuous)
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
        if visited.count >= openCells.count {
            cleared = true
            winTick += 1
            let next = level + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                level = next
                load(next)
            }
        }
    }

    // MARK: maze generation (recursive backtracker)

    private func load(_ n: Int) {
        let lvl = max(1, n)
        // maze cells per axis grow with the level; *2+1 makes the pixel grid odd.
        let cx = min(3, 2 + lvl / 8)
        let cy = min(3, 2 + lvl / 12)
        let mw = cx * 2 + 1
        let mh = cy * 2 + 1

        var isOpen = [Bool](repeating: false, count: mw * mh)
        func idx(_ x: Int, _ y: Int) -> Int { y * mw + x }

        var stack: [(Int, Int)] = [(0, 0)]
        isOpen[idx(0, 0)] = true
        let dirs = [(2, 0), (-2, 0), (0, 2), (0, -2)]
        while let top = stack.last {
            let (x, y) = top
            let options = dirs.compactMap { d -> (Int, Int)? in
                let nx = x + d.0, ny = y + d.1
                guard nx >= 0, nx < mw, ny >= 0, ny < mh, !isOpen[idx(nx, ny)] else { return nil }
                return (nx, ny)
            }
            if options.isEmpty { stack.removeLast(); continue }
            let (nx, ny) = options.randomElement()!
            isOpen[idx((x + nx) / 2, (y + ny) / 2)] = true   // knock the wall between
            isOpen[idx(nx, ny)] = true
            stack.append((nx, ny))
        }

        cols = mw
        rows = mh
        var w = Set<Int>(); var o = Set<Int>()
        for i in 0..<(mw * mh) { if isOpen[i] { o.insert(i) } else { w.insert(i) } }
        walls = w
        openCells = o
        pos = 0
        visited = [0]
        cleared = false
    }
}
