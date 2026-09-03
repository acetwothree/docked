//
//  ConnectFourView.swift
//  Docked
//
//  Pass-the-phone Connect 4. Tap a column to drop your disc; four in a row
//  (any direction) wins. Session score.
//

import SwiftUI

struct ConnectFourView: View {
    private let cols = 7
    private let rows = 6

    @State private var grid: [Int] = Array(repeating: 0, count: 42)  // 0 empty, 1 red, 2 yellow
    @State private var turn = 1
    @State private var winner = 0                                    // 0 none, 1, 2, 3 draw
    @State private var winCells: Set<Int> = []
    @State private var redScore = 0
    @State private var yellowScore = 0
    @State private var dropTick = 0
    @State private var winTick = 0

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                disc(1, redScore, active: winner == 0 && turn == 1)
                Spacer()
                Text(statusText).font(.system(size: 13, weight: .heavy)).foregroundStyle(.secondary)
                Spacer()
                disc(2, yellowScore, active: winner == 0 && turn == 2)
            }

            GeometryReader { geo in
                let cw = min(geo.size.width / CGFloat(cols), geo.size.height / CGFloat(rows))
                let boardW = cw * CGFloat(cols)
                let boardH = cw * CGFloat(rows)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.06))
                        .frame(width: boardW, height: boardH)
                    ForEach(Array(0..<42), id: \.self) { i in
                        cellView(i, cw: cw)
                    }
                    HStack(spacing: 0) {
                        ForEach(Array(0..<cols), id: \.self) { c in
                            Rectangle().fill(Color.clear)
                                .frame(width: cw, height: boardH)
                                .contentShape(Rectangle())
                                .onTapGesture { drop(c) }
                        }
                    }
                }
                .frame(width: boardW, height: boardH)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            Button { newGame() } label: {
                let title = winner == 0 ? "Restart" : "Play again"
                Label(title, systemImage: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: dropTick)
        .sensoryFeedback(.success, trigger: winTick)
    }

    private var statusText: String {
        switch winner {
        case 1: return "Red wins"
        case 2: return "Yellow wins"
        case 3: return "Draw"
        default: return turn == 1 ? "Red's turn" : "Yellow's turn"
        }
    }

    private func disc(_ who: Int, _ score: Int, active: Bool) -> some View {
        HStack(spacing: 5) {
            Circle().fill(who == 1 ? Color(red: 0.85, green: 0.25, blue: 0.25) : Color(red: 0.95, green: 0.78, blue: 0.2))
                .frame(width: 16, height: 16)
            Text("\(score)").font(.system(size: 13, weight: .black)).monospacedDigit()
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(active ? Theme.accent.opacity(0.16) : Color.clear, in: Capsule())
    }

    private func cellView(_ i: Int, cw: CGFloat) -> some View {
        let r = i / cols, c = i % cols
        let v = grid[i]
        let hot = winCells.contains(i)
        return Circle()
            .fill(v == 1 ? Color(red: 0.85, green: 0.25, blue: 0.25)
                  : v == 2 ? Color(red: 0.95, green: 0.78, blue: 0.2)
                  : Color.primary.opacity(0.08))
            .overlay { if hot { Circle().stroke(Color.white, lineWidth: 3) } }
            .frame(width: cw - 6, height: cw - 6)
            .position(x: CGFloat(c) * cw + cw / 2, y: CGFloat(r) * cw + cw / 2)
            .animation(.snappy(duration: 0.14), value: grid)
    }

    // MARK: logic

    private func newGame() {
        grid = Array(repeating: 0, count: 42)
        winner = 0
        winCells = []
        turn = 1
    }

    private func drop(_ col: Int) {
        guard winner == 0 else { return }
        var landing = -1
        for r in stride(from: rows - 1, through: 0, by: -1) where grid[r * cols + col] == 0 {
            landing = r
            break
        }
        guard landing >= 0 else { return }
        grid[landing * cols + col] = turn
        dropTick += 1

        if let line = winningLine(landing, col) {
            winner = turn
            winCells = Set(line)
            winTick += 1
            if turn == 1 { redScore += 1 } else { yellowScore += 1 }
        } else if !grid.contains(0) {
            winner = 3
        } else {
            turn = turn == 1 ? 2 : 1
        }
    }

    private func winningLine(_ r: Int, _ c: Int) -> [Int]? {
        let me = grid[r * cols + c]
        let dirs = [(1, 0), (0, 1), (1, 1), (1, -1)]
        for d in dirs {
            var line = [r * cols + c]
            for sgn in [1, -1] {
                var rr = r + d.0 * sgn, cc = c + d.1 * sgn
                while rr >= 0, rr < rows, cc >= 0, cc < cols, grid[rr * cols + cc] == me {
                    line.append(rr * cols + cc)
                    rr += d.0 * sgn
                    cc += d.1 * sgn
                }
            }
            if line.count >= 4 { return line }
        }
        return nil
    }
}
