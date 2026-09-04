//
//  MergeView.swift
//  Docked
//
//  A tiny 2048. Swipe to slide the tiles; equal ones merge and add up. Best
//  score persists.
//

import SwiftUI

struct MergeView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("docked.merge.best") private var best: Int = 0
    // Board persists across activity switches (timing doesn't matter here).
    @AppStorage("docked.merge.grid") private var savedGrid = ""
    @AppStorage("docked.merge.score") private var savedScore = 0
    @AppStorage("docked.merge.over") private var savedOver = false

    @State private var grid: [Int] = Array(repeating: 0, count: 16)
    @State private var score = 0
    @State private var over = false
    @State private var moveTick = 0
    @State private var mergeTick = 0
    @State private var tripleTick = 0
    @State private var pulse: CGFloat = 1
    @State private var restored = false

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
                    .scaleEffect(pulse)
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
        .sensoryFeedback(.success, trigger: tripleTick) { _, _ in app.haptics }
        .onAppear {
            guard !restored else { return }
            restored = true
            let parts = savedGrid.split(separator: ",").compactMap { Int($0) }
            if parts.count == 16, parts.contains(where: { $0 != 0 }) {
                grid = parts
                score = savedScore
                over = savedOver
            } else {
                newGame()
            }
        }
    }

    private func persist() {
        savedGrid = grid.map(String.init).joined(separator: ",")
        savedScore = score
        savedOver = over
    }

    private var hintText: String { over ? "No moves — tap ↻" : "Swipe to merge" }

    private enum Dir { case up, down, left, right }

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
            ForEach(Array(0..<16), id: \.self) { i in
                tile(i, cell: cell, gap: gap)
            }
        }
        .animation(.easeOut(duration: 0.13), value: grid)
    }

    private func tile(_ i: Int, cell: CGFloat, gap: CGFloat) -> some View {
        let r = i / n, c = i % n
        let v = grid[i]
        return RoundedRectangle(cornerRadius: 8)
            .fill(tileColor(v))
            .overlay {
                if v > 0 {
                    Text("\(v)")
                        .font(.system(size: cell * (v >= 1000 ? 0.28 : 0.4), weight: .black, design: .rounded))
                        .foregroundStyle(v <= 4 ? Color.primary : Color(red: 0.11, green: 0.08, blue: 0.02))
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(width: cell, height: cell)
            .position(x: gap + cell / 2 + CGFloat(c) * (cell + gap),
                      y: gap + cell / 2 + CGFloat(r) * (cell + gap))
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
        grid = Array(repeating: 0, count: 16)
        score = 0
        over = false
        spawn(); spawn()
        persist()
    }

    private func spawn() {
        var empty: [Int] = []
        for i in 0..<16 where grid[i] == 0 { empty.append(i) }
        guard let idx = empty.randomElement() else { return }
        grid[idx] = Int.random(in: 0..<10) == 0 ? 4 : 2
    }

    private func lineIndices(_ i: Int, _ dir: Dir) -> [Int] {
        switch dir {
        case .left:  return (0..<4).map { i * 4 + $0 }
        case .right: return (0..<4).map { i * 4 + (3 - $0) }
        case .up:    return (0..<4).map { $0 * 4 + i }
        case .down:  return (0..<4).map { (3 - $0) * 4 + i }
        }
    }

    private func move(_ dir: Dir) {
        guard !over else { return }
        var changed = false
        var didMerge = false
        var didTriple = false

        for i in 0..<4 {
            let idxs = lineIndices(i, dir)
            var vals: [Int] = []
            for idx in idxs where grid[idx] != 0 { vals.append(grid[idx]) }

            var out: [Int] = []
            var j = 0
            while j < vals.count {
                if j + 2 < vals.count && vals[j] == vals[j + 1] && vals[j] == vals[j + 2] {
                    // three in a row collapse into one, as if two merges landed
                    let merged = vals[j] * 4
                    out.append(merged)
                    score += merged
                    didMerge = true
                    didTriple = true
                    j += 3
                } else if j + 1 < vals.count && vals[j] == vals[j + 1] {
                    let merged = vals[j] * 2
                    out.append(merged)
                    score += merged
                    didMerge = true
                    j += 2
                } else {
                    out.append(vals[j])
                    j += 1
                }
            }
            while out.count < 4 { out.append(0) }

            for k in 0..<4 {
                if grid[idxs[k]] != out[k] { changed = true }
                grid[idxs[k]] = out[k]
            }
        }

        if changed {
            spawn()
            moveTick += 1
            if didMerge { mergeTick += 1 }
            if didTriple { tripleTick += 1 }
            best = max(best, score)
            if !anyMoveLeft() { over = true }
            if didMerge { pop(big: didTriple) }
            persist()
        }
    }

    /// A tiny, non-directional squeeze when tiles merge — a bigger one for a
    /// triple collapse — without the board lurching around.
    private func pop(big: Bool = false) {
        withAnimation(.easeOut(duration: 0.07)) { pulse = big ? 0.92 : 0.97 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(.spring(response: big ? 0.4 : 0.34, dampingFraction: big ? 0.5 : 0.6)) { pulse = 1 }
        }
    }

    private func anyMoveLeft() -> Bool {
        if grid.contains(0) { return true }
        for i in 0..<16 {
            let r = i / 4, c = i % 4
            if c < 3 && grid[i] == grid[i + 1] { return true }
            if r < 3 && grid[i] == grid[i + 4] { return true }
        }
        return false
    }
}
