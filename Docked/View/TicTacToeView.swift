//
//  TicTacToeView.swift
//  Docked
//
//  Pass-the-phone tic-tac-toe. X starts the first game; the loser (or X after
//  a draw) starts the next. Session score + a lifetime games-played tally.
//

import SwiftUI

struct TicTacToeView: View {
    @Environment(AppModel.self) private var app

    // 0 = empty, 1 = X, 2 = O
    @State private var board: [Int] = Array(repeating: 0, count: 9)
    @State private var turn = 1
    @State private var outcome = 0            // 0 = playing, 1 = X won, 2 = O won, 3 = draw
    @State private var winLine: [Int] = []
    @State private var xScore = 0
    @State private var oScore = 0
    @State private var moveTick = 0
    @State private var winTick = 0

    private let lines: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6],
    ]

    var body: some View {
        VStack(spacing: 14) {
            header

            GeometryReader { geo in
                let s = min(geo.size.width, geo.size.height)
                grid(cell: (s - 16) / 3)
                    .frame(width: s, height: s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Button {
                withAnimation { newRound() }
            } label: {
                let title = outcome == 0 ? "Restart" : "Play again"
                Label(title, systemImage: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: moveTick)
        .sensoryFeedback(.success, trigger: winTick)
    }

    private var header: some View {
        HStack {
            scorePill("X", xScore, active: outcome == 0 && turn == 1)
            Spacer()
            Text(statusText)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.secondary)
            Spacer()
            scorePill("O", oScore, active: outcome == 0 && turn == 2)
        }
    }

    private func scorePill(_ label: String, _ n: Int, active: Bool) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 15, weight: .black))
            Text("\(n)").font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
        }
        .foregroundStyle(active ? Theme.accent : Color.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(active ? Theme.accent.opacity(0.14) : Color.clear, in: Capsule())
    }

    private var statusText: String {
        switch outcome {
        case 1: return "X wins"
        case 2: return "O wins"
        case 3: return "Draw"
        default: return turn == 1 ? "X to move" : "O to move"
        }
    }

    private func grid(cell: CGFloat) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(0..<3), id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(Array(0..<3), id: \.self) { col in
                        cellButton(index: row * 3 + col, cell: cell)
                    }
                }
            }
        }
        .animation(.snappy(duration: 0.18), value: board)
    }

    private func cellButton(index: Int, cell: CGFloat) -> some View {
        let value = board[index]
        let highlighted = winLine.contains(index)
        return Button {
            play(index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.paper)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(highlighted ? Theme.accent : Theme.hairline,
                                  lineWidth: highlighted ? 3 : 1)
                if value != 0 {
                    Text(value == 1 ? "X" : "O")
                        .font(.system(size: cell * 0.5, weight: .black, design: .rounded))
                        .foregroundStyle(value == 1 ? Theme.accent : Color.primary)
                }
            }
            .frame(width: cell, height: cell)
        }
        .buttonStyle(.plain)
        .disabled(value != 0 || outcome != 0)
    }

    // MARK: logic

    private func play(_ i: Int) {
        guard board[i] == 0, outcome == 0 else { return }
        board[i] = turn
        moveTick += 1

        for line in lines {
            if board[line[0]] != 0,
               board[line[0]] == board[line[1]],
               board[line[1]] == board[line[2]] {
                outcome = board[line[0]]
                winLine = line
                winTick += 1
                if outcome == 1 { xScore += 1 } else { oScore += 1 }
                app.tttGames += 1
                return
            }
        }

        if !board.contains(0) {
            outcome = 3
            app.tttGames += 1
            return
        }

        turn = turn == 1 ? 2 : 1
    }

    private func newRound() {
        let loserStarts = outcome == 2 ? 1 : (outcome == 1 ? 2 : 1)
        board = Array(repeating: 0, count: 9)
        winLine = []
        outcome = 0
        turn = loserStarts
    }
}
