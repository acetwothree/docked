//
//  MergeDropView.swift
//  Docked
//
//  "Merge" — a tiny column dropper. Drag across the board to aim, release over
//  a column to drop the next block; equal blocks stacked on each other merge
//  into the next tier and everything falls. Best score persists.
//

import SwiftUI

struct MergeDropView: View {
    @AppStorage("docked.drop.best") private var best: Int = 0

    private let cols = 5
    private let rows = 8

    @State private var grid: [Int] = Array(repeating: 0, count: 40)
    @State private var next = 1
    @State private var score = 0
    @State private var over = false
    @State private var dropTick = 0
    @State private var mergeTick = 0

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
            HStack {
                Text("SCORE \(score)").font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Text("BEST \(max(best, score))").font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Button { newGame() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary).frame(width: 34, height: 30)
                }
                .buttonStyle(.plain)
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
                        // ghost of the block that will drop
                        blockTile(next, side: cw - 8)
                            .opacity(0.4)
                            .position(x: CGFloat(hc) * cw + cw / 2, y: ch / 2)
                    }

                    ForEach(Array(0..<40), id: \.self) { i in
                        cellView(i, cw: cw, ch: ch)
                    }

                    // the block in flight
                    if let f = falling {
                        blockTile(f.val, side: cw - 4)
                            .position(x: CGFloat(f.col) * cw + cw / 2, y: f.y)
                    }
                }
                .frame(width: boardW, height: boardH)
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
        .sensoryFeedback(.impact(weight: .light), trigger: dropTick)
        .sensoryFeedback(.impact(weight: .medium), trigger: mergeTick)
        .onAppear { if grid.allSatisfy({ $0 == 0 }) { newGame() } }
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
            .animation(.snappy(duration: 0.12), value: grid)
    }

    private func color(_ v: Int) -> Color {
        let hues: [Double] = [0.09, 0.13, 0.33, 0.52, 0.62, 0.78, 0.92, 0.03]
        return Color(hue: hues[(v - 1) % hues.count], saturation: 0.72, brightness: 0.85)
    }

    // MARK: logic

    private func clampCol(_ x: Int) -> Int { min(max(x, 0), cols - 1) }

    private func newGame() {
        grid = Array(repeating: 0, count: 40)
        score = 0
        over = false
        falling = nil
        hoverCol = nil
        next = Int.random(in: 1...3)
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
        falling = FallingPiece(col: col, val: val, y: ch / 2)
        let dur = min(0.36, 0.08 + Double(max(1, landing)) * 0.035)
        withAnimation(.easeIn(duration: dur)) {
            falling?.y = endY
        } completion: {
            grid[landing * cols + col] = val
            falling = nil
            dropTick += 1
            resolve()
            best = max(best, score)
            if topRowFull() { over = true }
        }
    }

    private func topRowFull() -> Bool {
        for c in 0..<cols where grid[c] == 0 { return false }
        return true
    }

    private func resolve() {
        var again = true
        while again {
            again = false
            for c in 0..<cols {
                for r in stride(from: rows - 1, through: 1, by: -1) {
                    let i = r * cols + c
                    let up = (r - 1) * cols + c
                    if grid[i] != 0 && grid[i] == grid[up] {
                        grid[i] += 1
                        grid[up] = 0
                        score += 1 << grid[i]
                        mergeTick += 1
                        again = true
                    }
                }
            }
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
}
