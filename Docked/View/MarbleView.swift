//
//  MarbleView.swift
//  Docked
//
//  "Roll" — swipe and the marble slides until it hits a wall or the edge,
//  painting every tile it crosses. Cover every open tile to clear the level.
//  Levels are 1-wide corridors, so each is solvable. Level persists.
//

import SwiftUI

struct MarbleView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("docked.marble.level") private var level: Int = 1

    @State private var cols = 4
    @State private var rows = 4
    @State private var walls: Set<Int> = []
    @State private var visited: Set<Int> = []
    @State private var pos = 0
    @State private var moveTick = 0
    @State private var winTick = 0
    @State private var cleared = false

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

            Text(cleared ? "Level cleared!" : "Swipe to roll · cover every tile")
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
        .sensoryFeedback(.success, trigger: winTick) { _, _ in app.haptics }
        .onAppear { if walls.isEmpty && visited.count <= 1 { load(level) } }
    }

    private func board(side: CGFloat) -> some View {
        let span = max(cols, rows)
        let gap: CGFloat = 4
        let cell = (side - gap * CGFloat(span + 1)) / CGFloat(span)
        let count = cols * rows
        return ZStack {
            ForEach(Array(0..<count), id: \.self) { i in
                cellView(i, cell: cell, gap: gap)
            }
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
        if walls.contains(i) { fill = Color.primary.opacity(0.5) }
        else if visited.contains(i) { fill = Theme.accent.opacity(0.32) }
        else { fill = Color.primary.opacity(0.07) }
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(fill)
            .frame(width: cell, height: cell)
            .position(x: gap + cell / 2 + CGFloat(c) * (cell + gap),
                      y: gap + cell / 2 + CGFloat(r) * (cell + gap))
    }

    // MARK: logic

    private func roll(_ dc: Int, _ dr: Int) {
        guard !cleared else { return }
        var c = pos % cols
        var r = pos / cols
        var moved = false
        while true {
            let nc = c + dc, nr = r + dr
            if nc < 0 || nc >= cols || nr < 0 || nr >= rows { break }
            let ni = nr * cols + nc
            if walls.contains(ni) { break }
            c = nc; r = nr
            visited.insert(ni)
            moved = true
        }
        if moved {
            pos = r * cols + c
            moveTick += 1
            checkWin()
        }
    }

    private func checkWin() {
        let need = cols * rows - walls.count
        if visited.count >= need {
            cleared = true
            winTick += 1
            let next = level + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                level = next
                load(next)
            }
        }
    }

    private func load(_ n: Int) {
        // (cols, rows, start, wall indices). Walls are spaced single-cell
        // "teeth" (dashed vertical lines), not solid bars — they scatter across
        // the board but still shape a snake path, so painting every open tile
        // stays possible. Each layout below is hand-verified solvable.
        let layouts: [(Int, Int, Int, [Int])] = [
            (4, 4, 0, [1, 5, 9]),
            (4, 5, 0, [1, 5, 9, 13]),
            (5, 5, 0, [1, 6, 11, 16, 8, 13, 18, 23]),
            (6, 5, 0, [1, 7, 13, 19, 9, 15, 21, 27]),
            (6, 6, 0, [1, 7, 13, 19, 25, 9, 15, 21, 27, 33]),
            (7, 5, 0, [1, 8, 15, 22, 10, 17, 24, 31, 5, 12, 19, 26]),
            (5, 6, 0, [1, 6, 11, 16, 21, 8, 13, 18, 23, 28]),
            (7, 6, 0, [1, 8, 15, 22, 29, 10, 17, 24, 31, 38, 5, 12, 19, 26, 33]),
        ]
        let picked = layouts[(max(1, n) - 1) % layouts.count]
        cols = picked.0
        rows = picked.1
        pos = picked.2
        walls = Set(picked.3)
        visited = [picked.2]
        cleared = false
    }
}
