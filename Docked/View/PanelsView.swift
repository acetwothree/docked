//
//  PanelsView.swift
//  Docked
//
//  "Panels" (premium) — a rotate-and-match puzzle. Tap a tile to spin the 2×2
//  block it sits in; line up three or more of the same number and they clear
//  and everything drops. Some tiles are bombs with a countdown — clear them in
//  a match before they hit zero.
//
//  Original mechanic, original art. No third-party assets.
//

import SwiftUI

struct PanelsView: View {
    @Environment(AppModel.self) private var app

    private let cols = 6
    private let rows = 7

    @State private var value: [Int] = []      // 1...3, 0 = empty (transient)
    @State private var bomb: [Int] = []       // 0 = none, else moves left
    @State private var score = 0
    @State private var moves = 0
    @State private var over = false
    @State private var spinTick = 0
    @State private var clearTick = 0
    @State private var bombTick = 0
    @State private var overTick = 0

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("SCORE \(score)").font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Text(over ? "Boom — tap ↻" : "Tap a tile to spin its 2×2")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(.secondary)
                Spacer()
                Button { newGame() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary).frame(width: 34, height: 30)
                }
                .buttonStyle(.plain)
            }

            GeometryReader { geo in
                let gap: CGFloat = 4
                let fitW: CGFloat = geo.size.width
                let fitH: CGFloat = geo.size.height / CGFloat(rows) * CGFloat(cols)
                let cw: CGFloat = (min(fitW, fitH) - gap * CGFloat(cols + 1)) / CGFloat(cols)
                let boardW: CGFloat = cw * CGFloat(cols) + gap * CGFloat(cols + 1)
                let boardH: CGFloat = cw * CGFloat(rows) + gap * CGFloat(rows + 1)
                ZStack(alignment: .topLeading) {
                    ForEach(Array(0..<(cols * rows)), id: \.self) { i in
                        tile(i, cw: cw, gap: gap)
                    }
                }
                .frame(width: boardW, height: boardH)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: spinTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(weight: .medium), trigger: clearTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: bombTick) { _, _ in app.haptics }
        .sensoryFeedback(.error, trigger: overTick) { _, _ in app.haptics }
        .onAppear { if value.count != cols * rows { newGame() } }
    }

    private func tile(_ i: Int, cw: CGFloat, gap: CGFloat) -> some View {
        let r = i / cols, c = i % cols
        let v = value.indices.contains(i) ? value[i] : 0
        let b = bomb.indices.contains(i) ? bomb[i] : 0
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(v == 0 ? Color.primary.opacity(0.05) : tileColor(v))
            .overlay {
                if v > 0 {
                    Text("\(v)")
                        .font(.system(size: cw * 0.42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .overlay {
                if b > 0 {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.red, lineWidth: 2.5)
                        .overlay(alignment: .topTrailing) {
                            Text("\(b)").font(.system(size: cw * 0.28, weight: .black))
                                .foregroundStyle(.white)
                                .padding(2)
                                .background(Color.red, in: Circle())
                                .offset(x: 4, y: -4)
                        }
                }
            }
            .frame(width: cw, height: cw)
            .position(x: gap + cw / 2 + CGFloat(c) * (cw + gap),
                      y: gap + cw / 2 + CGFloat(r) * (cw + gap))
            .animation(.snappy(duration: 0.14), value: value)
            .onTapGesture { spin(atRow: r, col: c) }
    }

    private func tileColor(_ v: Int) -> Color {
        switch v {
        case 1: return Color(hex: "4A9CFF")
        case 2: return Color(hex: "3ECF7A")
        default: return Color(hex: "FF8A3D")
        }
    }

    // MARK: logic

    private func idx(_ r: Int, _ c: Int) -> Int { r * cols + c }

    private func newGame() {
        value = (0..<(cols * rows)).map { _ in Int.random(in: 1...3) }
        bomb = Array(repeating: 0, count: cols * rows)
        score = 0
        moves = 0
        over = false
        // settle any accidental starting matches without scoring
        _ = resolveBoard(scoring: false)
    }

    private func spin(atRow r: Int, col c: Int) {
        guard !over else { return }
        let r0 = min(r, rows - 2), c0 = min(c, cols - 2)
        let a = idx(r0, c0), bb = idx(r0, c0 + 1)
        let cc = idx(r0 + 1, c0 + 1), d = idx(r0 + 1, c0)
        // clockwise: TL<-BL, TR<-TL, BR<-TR, BL<-BR
        let tl = value[a], tr = value[bb], br = value[cc], bl = value[d]
        value[a] = bl; value[bb] = tl; value[cc] = tr; value[d] = br
        let tlB = bomb[a], trB = bomb[bb], brB = bomb[cc], blB = bomb[d]
        bomb[a] = blB; bomb[bb] = tlB; bomb[cc] = trB; bomb[d] = brB
        spinTick += 1
        moves += 1

        let cleared = resolveBoard(scoring: true)
        if cleared > 0 { clearTick += 1; score += cleared * 5 }

        // tick every bomb down; a defused one is already gone (value cleared).
        var warned = false
        for i in bomb.indices where bomb[i] > 0 {
            bomb[i] -= 1
            if bomb[i] <= 0 { over = true }
            else if bomb[i] <= 2 { warned = true }
        }
        if warned && !over { bombTick += 1 }
        if over { overTick += 1; return }

        // occasionally arm a new bomb on a filled tile
        if moves % 5 == 0 {
            let candidates = value.indices.filter { value[$0] > 0 && bomb[$0] == 0 }
            if let t = candidates.randomElement() { bomb[t] = 9 }
        }
    }

    /// Clears runs of 3+, applies gravity, refills. Returns total cells cleared.
    @discardableResult
    private func resolveBoard(scoring: Bool) -> Int {
        var total = 0
        var again = true
        var guardCount = 0
        while again && guardCount < 40 {
            guardCount += 1
            again = false
            var clear = Set<Int>()
            // rows
            for r in 0..<rows {
                var run = 1
                for c in 1..<cols {
                    if value[idx(r, c)] != 0, value[idx(r, c)] == value[idx(r, c - 1)] {
                        run += 1
                    } else {
                        if run >= 3 { for k in (c - run)..<c { clear.insert(idx(r, k)) } }
                        run = 1
                    }
                }
                if run >= 3 { for k in (cols - run)..<cols { clear.insert(idx(r, k)) } }
            }
            // cols
            for c in 0..<cols {
                var run = 1
                for r in 1..<rows {
                    if value[idx(r, c)] != 0, value[idx(r, c)] == value[idx(r - 1, c)] {
                        run += 1
                    } else {
                        if run >= 3 { for k in (r - run)..<r { clear.insert(idx(k, c)) } }
                        run = 1
                    }
                }
                if run >= 3 { for k in (rows - run)..<rows { clear.insert(idx(k, c)) } }
            }
            if clear.isEmpty { break }
            for i in clear { value[i] = 0; bomb[i] = 0 }
            total += clear.count
            again = true

            // gravity per column
            for c in 0..<cols {
                var stackV: [Int] = []
                var stackB: [Int] = []
                for r in (0..<rows).reversed() {
                    if value[idx(r, c)] != 0 { stackV.append(value[idx(r, c)]); stackB.append(bomb[idx(r, c)]) }
                }
                for r in (0..<rows).reversed() {
                    let k = rows - 1 - r
                    if k < stackV.count {
                        value[idx(r, c)] = stackV[k]; bomb[idx(r, c)] = stackB[k]
                    } else {
                        value[idx(r, c)] = Int.random(in: 1...3); bomb[idx(r, c)] = 0
                    }
                }
            }
        }
        _ = scoring
        return total
    }
}
