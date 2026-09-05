//
//  MergeDropView.swift
//  Docked
//
//  "Number Merge" — a tiny column dropper. Drag across the board to aim,
//  release over a column to drop the next block; equal blocks stacked on
//  each other merge into the next tier and everything falls. Best score
//  persists.
//

import SwiftUI

struct MergeDropView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("docked.drop.best") private var best: Int = 0
    // Board persists across activity switches (timing doesn't matter here).
    @AppStorage("docked.drop.grid") private var savedGrid = ""
    @AppStorage("docked.drop.score") private var savedScore = 0
    @AppStorage("docked.drop.next") private var savedNext = 1
    @AppStorage("docked.drop.over") private var savedOver = false

    private let cols = 5
    private let rows = 5

    @State private var grid: [Int] = Array(repeating: 0, count: 25)
    @State private var next = 1
    @State private var score = 0
    @State private var over = false
    @State private var restored = false
    @State private var dropTick = 0
    @State private var mergeTick = 0
    @State private var bigMergeTick = 0
    @State private var tripleTick = 0
    /// Whole-board squeeze when a merge resolves.
    @State private var pulse: CGFloat = 1

    /// Column currently under the finger while aiming.
    @State private var hoverCol: Int? = nil
    /// The block mid-fall — no taps accepted until it lands.
    @State private var falling: FallingPiece? = nil

    private struct FallingPiece: Equatable {
        var col: Int
        var val: Int
        var y: CGFloat
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                Text("SCORE \(score)").font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("BEST \(max(best, score))").font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Button { newGame() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary).frame(width: 34, height: 30)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(spacing: 6) {
                Text("NEXT").font(.system(size: 10, weight: .heavy)).foregroundStyle(.tertiary)
                Circle().fill(color(next))
                    .frame(width: 22, height: 22)
                    .overlay(Text("\(1 << next)").font(.system(size: 9, weight: .black)).foregroundStyle(.white))
            }

            GeometryReader { geo in
                let cw = geo.size.width / CGFloat(cols)
                let ch = min(cw, geo.size.height / CGFloat(rows))
                let boardW = cw * CGFloat(cols)
                let boardH = ch * CGFloat(rows)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05))
                        .frame(width: boardW, height: boardH)

                    // aim highlight for the column under the finger
                    if let hc = hoverCol, falling == nil, !over {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color(next).opacity(0.14))
                            .frame(width: cw - 2, height: boardH)
                            .position(x: CGFloat(hc) * cw + cw / 2, y: boardH / 2)
                        // ghost of the block that will drop — floats above the
                        // board entirely so a filled top row never hides it
                        blockTile(next, side: cw - 8)
                            .opacity(0.4)
                            .position(x: CGFloat(hc) * cw + cw / 2, y: -ch * 0.62)
                    }

                    ForEach(Array(0..<(cols * rows)), id: \.self) { i in
                        cellView(i, cw: cw, ch: ch)
                    }

                    // the block in flight
                    if let f = falling {
                        blockTile(f.val, side: cw - 4)
                            .position(x: CGFloat(f.col) * cw + cw / 2, y: f.y)
                    }
                }
                .frame(width: boardW, height: boardH)
                .scaleEffect(pulse)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            guard !over, falling == nil else { return }
                            hoverCol = clampCol(Int(v.location.x / cw))
                        }
                        .onEnded { v in
                            defer { hoverCol = nil }
                            guard !over, falling == nil else { return }
                            drop(clampCol(Int(v.location.x / cw)), ch: ch)
                        }
                )
            }

            Text(over ? "Full — tap ↻" : "Drag to aim, release to drop")
                .font(.system(size: 12, weight: .heavy)).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: dropTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: mergeTick) { _, _ in app.haptics }
        .sensoryFeedback(.success, trigger: bigMergeTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 1.0), trigger: tripleTick) { _, _ in app.haptics }
        .onAppear {
            guard !restored else { return }
            restored = true
            let parts = savedGrid.split(separator: ",").compactMap { Int($0) }
            if parts.count == cols * rows, parts.contains(where: { $0 != 0 }) {
                grid = parts
                score = savedScore
                next = savedNext
                over = savedOver
            } else {
                newGame()
            }
        }
    }

    private func persist() {
        savedGrid = grid.map(String.init).joined(separator: ",")
        savedScore = score
        savedNext = next
        savedOver = over
    }

    private func blockTile(_ v: Int, side: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color(v))
            .overlay {
                Text("\(1 << v)")
                    .font(.system(size: side * 0.34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: side, height: side)
    }

    private func cellView(_ i: Int, cw: CGFloat, ch: CGFloat) -> some View {
        let r = i / cols, c = i % cols
        let v = grid[i]
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(v == 0 ? Color.primary.opacity(0.04) : color(v))
            .overlay {
                if v > 0 {
                    Text("\(1 << v)")
                        .font(.system(size: ch * 0.34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(width: cw - 4, height: ch - 4)
            .position(x: CGFloat(c) * cw + cw / 2, y: CGFloat(r) * ch + ch / 2)
            .animation(.easeInOut(duration: 0.2), value: grid)
    }

    private func color(_ v: Int) -> Color {
        let hues: [Double] = [0.09, 0.13, 0.33, 0.52, 0.62, 0.78, 0.92, 0.03]
        return Color(hue: hues[(v - 1) % hues.count], saturation: 0.72, brightness: 0.85)
    }

    // MARK: logic

    private func clampCol(_ x: Int) -> Int { min(max(x, 0), cols - 1) }

    private func newGame() {
        grid = Array(repeating: 0, count: cols * rows)
        score = 0
        over = false
        falling = nil
        hoverCol = nil
        next = Int.random(in: 1...3)
        persist()
    }

    private func drop(_ col: Int, ch: CGFloat) {
        guard !over, falling == nil else { return }
        var landing = -1
        for r in stride(from: rows - 1, through: 0, by: -1) where grid[r * cols + col] == 0 {
            landing = r
            break
        }
        guard landing >= 0 else { return }

        let val = next
        next = Int.random(in: 1...3)

        let endY = CGFloat(landing) * ch + ch / 2
        falling = FallingPiece(col: col, val: val, y: -ch * 0.62)
        let dur = min(0.4, 0.12 + Double(max(1, landing)) * 0.04)
        withAnimation(.easeIn(duration: dur)) {
            falling?.y = endY
        } completion: {
            grid[landing * cols + col] = val
            falling = nil
            dropTick += 1
            persist()
            resolveStep(origin: landing * cols + col)
        }
    }

    private func squeeze() {
        withAnimation(.easeOut(duration: 0.07)) { pulse = 0.96 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { pulse = 1 }
        }
    }

    private func topRowFull() -> Bool {
        for c in 0..<cols where grid[c] == 0 { return false }
        return true
    }

    // MARK: resolution — one visible step at a time

    /// Do a single merge (any connected group of 2+ equal tiles collapses into
    /// one), animate it, drop the board, then recurse for the cascade so the
    /// player can see each stage.
    private func resolveStep(origin: Int?) {
        guard let group = firstMergeGroup() else {
            best = max(best, score)
            if topRowFull() { over = true }
            persist()
            return
        }
        let v = grid[group[0]]
        let target: Int = {
            if let o = origin, group.contains(o) { return o }
            return group.sorted { a, b in
                let ra = a / cols, rb = b / cols
                if ra != rb { return ra > rb }        // lowest row wins
                return (a % cols) > (b % cols)         // then right-most
            }[0]
        }()
        let bump = group.count >= 3 ? 2 : 1

        withAnimation(.easeInOut(duration: 0.18)) {
            for i in group where i != target { grid[i] = 0 }
            grid[target] = v + bump
        }
        score += (1 << grid[target])
        mergeTick += 1
        if bump == 2 { tripleTick += 1 }
        if grid[target] >= 6 { bigMergeTick += 1 }
        squeeze()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.19) {
            withAnimation(.easeInOut(duration: 0.16)) { applyGravity() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                resolveStep(origin: nil)
            }
        }
    }

    /// Smallest-index cell of the first connected same-value group of size ≥ 2.
    private func firstMergeGroup() -> [Int]? {
        var seen = Set<Int>()
        for start in 0..<(cols * rows) where grid[start] != 0 && !seen.contains(start) {
            let v = grid[start]
            var comp: [Int] = []
            var q = [start]
            seen.insert(start)
            while let cur = q.popLast() {
                comp.append(cur)
                let r = cur / cols, c = cur % cols
                for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                    let nr = r + dr, nc = c + dc
                    guard nr >= 0, nr < rows, nc >= 0, nc < cols else { continue }
                    let ni = nr * cols + nc
                    if !seen.contains(ni) && grid[ni] == v {
                        seen.insert(ni)
                        q.append(ni)
                    }
                }
            }
            if comp.count >= 2 { return comp }
        }
        return nil
    }

    private func applyGravity() {
        for c in 0..<cols {
            var write = rows - 1
            for r in stride(from: rows - 1, through: 0, by: -1) {
                let i = r * cols + c
                if grid[i] != 0 {
                    let wi = write * cols + c
                    if wi != i { grid[wi] = grid[i]; grid[i] = 0 }
                    write -= 1
                }
            }
        }
    }
}
