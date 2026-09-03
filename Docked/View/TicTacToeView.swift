//
//  TicTacToeView.swift
//  Docked
//
//  Pass-the-phone tic-tac-toe. X always starts; the loser (or X after a draw)
//  goes first next round. Keeps a session score and a lifetime games-played
//  tally.
//

import SwiftUI

struct TicTacToeView: View {
    @Environment(AppModel.self) private var app

    @State private var board: [String?] = Array(repeating: nil, count: 9)
    @State private var xTurn = true
    @State private var winner: String? = nil      // "X", "O", or "-" for a draw
    @State private var winLine: [Int]? = nil
    @State private var xScore = 0
    @State private var oScore = 0
    @State private var moveTick = 0

    private let lines: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6],
    ]

    var body: some View {
        VStack(spacing: 14) {
            header

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                grid(cell: (side - 16) / 3)
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            footer
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: moveTick)
        .sensoryFeedback(.success, trigger: winner) { _, new in new == "X" || new == "O" }
    }

    private var header: some View {
        HStack {
            score("X", xScore, active: winner == nil && xTurn)
            Spacer()
            Text(statusText)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.secondary)
            Spacer()
            score("O", oScore, active: winner == nil && !xTurn)
        }
    }

    private func score(_ mark: String, _ n: Int, active: Bool) -> some View {
        VStack(spacing: 1) {
            Text(mark).font(.system(size: 15, weight: .black))
            Text("\(n)").font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
        }
        .foregroundStyle(active ? Theme.accent : Color.primary)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(active ? Theme.accent.opacity(0.14) : Color.clear, in: Capsule())
    }

    private var statusText: String {
        switch winner {
        case "X": "X wins"
        case "O": "O wins"
        case "-": "Draw"
        default: xTurn ? "X to move" : "O to move"
        }
    }

    private func grid(cell: CGFloat) -> some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { c in
                        let i = r * 3 + c
                        Button { tap(i) } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.paper)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke((winLine?.contains(i) ?? false) ? Theme.accent : Theme.hairline,
                                                    lineWidth: (winLine?.contains(i) ?? false) ? 3 : 1)
                                    }
                                if let mark = board[i] {
                                    Text(mark)
                                        .font(.system(size: cell * 0.5, weight: .black, design: .rounded))
                                        .foregroundStyle(mark == "X" ? Theme.accent : Color.primary)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .frame(width: cell, height: cell)
                        }
                        .buttonStyle(.plain)
                        .disabled(board[i] != nil || winner != nil)
                    }
                }
            }
        }
        .animation(.snappy(duration: 0.18), value: board)
    }

    private var footer: some View {
        Button {
            withAnimation { newRound() }
        } label: {
            Label(winner == nil ? "Restart" : "Play again", systemImage: "arrow.counterclockwise")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.accent)
        }
        .buttonStyle(.plain)
    }

    // MARK: logic

    private func tap(_ i: Int) {
        guard board[i] == nil, winner == nil else { return }
        board[i] = xTurn ? "X" : "O"
        moveTick += 1

        if let line = lines.first(where: { l in
            let m = board[l[0]]
            return m != nil && m == board[l[1]] && m == board[l[2]]
        }) {
            winner = board[line[0]]
            winLine = line
            if winner == "X" { xScore += 1 } else { oScore += 1 }
            app.tttGames += 1
        } else if !board.contains(where: { $0 == nil }) {
            winner = "-"
            app.tttGames += 1
        } else {
            xTurn.toggle()
        }
    }

    private func newRound() {
        // Loser starts; after a draw, X starts.
        let xStarts = (winner == "O") || (winner != "X")
        board = Array(repeating: nil, count: 9)
        winner = nil
        winLine = nil
        xTurn = xStarts
    }
}
