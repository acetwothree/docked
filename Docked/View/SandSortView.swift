//
//  SandSortView.swift
//  Docked
//
//  A little sand-sorting puzzle. Tap a tube to lift its top run of one colour,
//  tap another to pour it in (matching colour or empty only). Get every tube
//  to a single colour to solve. Solved-count persists.
//

import SwiftUI

struct SandSortView: View {
    @AppStorage("docked.sand.solved") private var solvedCount: Int = 0

    @State private var tubes: [[Int]] = []
    @State private var picked: Int = -1
    @State private var moveTick = 0
    @State private var winTick = 0

    private let capacity = 4
    private let colors: [Color] = [
        Color(hex: "E0473E"), Color(hex: "F2B90C"),
        Color(hex: "3EA1E0"), Color(hex: "3ECF7A"),
    ]

    var body: some View {
        VStack(spacing: 12) {
            Text(isWon ? "Solved!  Tap New for another" : "Sort each tube to one colour")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(isWon ? Color.green : Color.secondary)

            HStack(alignment: .bottom, spacing: 14) {
                ForEach(Array(tubes.indices), id: \.self) { i in
                    tubeView(i)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Text("SOLVED  \(solvedCount)")
                    .font(.system(size: 11, weight: .heavy)).tracking(1)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    newPuzzle()
                } label: {
                    Label("New", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: moveTick)
        .sensoryFeedback(.success, trigger: winTick)
        .onAppear { if tubes.isEmpty { newPuzzle() } }
    }

    private func tubeView(_ i: Int) -> some View {
        let tube = tubes[i]
        let lifted = picked == i
        return VStack(spacing: 3) {
            ForEach(Array(0..<capacity), id: \.self) { slot in
                let fromBottom = capacity - 1 - slot
                let fill: Color = fromBottom < tube.count
                    ? colors[tube[fromBottom] % colors.count]
                    : Color.primary.opacity(0.05)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(fill)
                    .frame(height: 24)
            }
        }
        .padding(4)
        .frame(width: 42)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(lifted ? Theme.accent : Theme.hairline, lineWidth: lifted ? 2 : 1)
        )
        .offset(y: lifted ? -10 : 0)
        .animation(.snappy(duration: 0.16), value: picked)
        .contentShape(Rectangle())
        .onTapGesture { tap(i) }
    }

    // MARK: logic

    private func tap(_ i: Int) {
        if picked < 0 {
            if !tubes[i].isEmpty { picked = i }
            return
        }
        if picked == i { picked = -1; return }
        pour(from: picked, to: i)
        picked = -1
    }

    private func pour(from a: Int, to b: Int) {
        var src = tubes[a]
        var dst = tubes[b]
        guard let moving = src.last else { return }
        if let top = dst.last, top != moving { return }
        if dst.count >= capacity { return }

        var moved = 0
        while let s = src.last, s == moving, dst.count < capacity {
            dst.append(s)
            src.removeLast()
            moved += 1
        }
        guard moved > 0 else { return }

        tubes[a] = src
        tubes[b] = dst
        moveTick += 1
        if isWon {
            winTick += 1
            solvedCount += 1
        }
    }

    private var isWon: Bool {
        tubes.allSatisfy { tube in
            tube.isEmpty || (tube.count == capacity && Set(tube).count == 1)
        }
    }

    private func newPuzzle() {
        let colorCount = 4
        var units: [Int] = []
        for c in 0..<colorCount {
            for _ in 0..<capacity { units.append(c) }
        }
        units.shuffle()

        var built: [[Int]] = []
        for c in 0..<colorCount {
            let start = c * capacity
            built.append(Array(units[start..<(start + capacity)]))
        }
        built.append([])
        built.append([])

        tubes = built
        picked = -1
    }
}
