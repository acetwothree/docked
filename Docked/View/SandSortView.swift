//
//  SandSortView.swift
//  Docked
//
//  Sand-sort puzzle with level progression. Tap a tube to lift its top run of
//  one colour, tap another to pour it in (matching colour or empty only). Get
//  every tube to a single colour to clear the level. Unlimited undo. Level
//  persists.
//

import SwiftUI

struct SandSortView: View {
    @AppStorage("docked.sand.level") private var level: Int = 1

    @State private var tubes: [[Int]] = []
    @State private var history: [[[Int]]] = []
    @State private var picked: Int = -1
    @State private var moveTick = 0
    @State private var winTick = 0
    @State private var cleared = false

    private let capacity = 4
    private let colors: [Color] = [
        Color(hex: "E0473E"), Color(hex: "F2B90C"), Color(hex: "3EA1E0"),
        Color(hex: "3ECF7A"), Color(hex: "D94FD9"), Color(hex: "6C6CE0"),
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("LEVEL \(level)")
                    .font(.system(size: 13, weight: .heavy)).tracking(1)
                    .foregroundStyle(.secondary)
                Spacer()
                Button { undo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 30)
                        .foregroundStyle(history.isEmpty ? Color.secondary.opacity(0.4) : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(history.isEmpty)

                Button { newLevel(level) } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 30)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(tubes.indices), id: \.self) { i in
                    tubeView(i)
                }
            }

            if cleared {
                Text("Level \(level) cleared!")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.green)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: moveTick)
        .sensoryFeedback(.success, trigger: winTick)
        .onAppear { if tubes.isEmpty { newLevel(level) } }
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
                    .frame(height: 26)
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
        guard !cleared else { return }
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

        history.append(tubes)
        tubes[a] = src
        tubes[b] = dst
        moveTick += 1

        if isWon {
            cleared = true
            winTick += 1
            let next = level + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                level = next
                newLevel(next)
            }
        }
    }

    private func undo() {
        guard let prev = history.popLast() else { return }
        tubes = prev
        picked = -1
        cleared = false
    }

    private var isWon: Bool {
        tubes.allSatisfy { tube in
            tube.isEmpty || (tube.count == capacity && Set(tube).count == 1)
        }
    }

    private func newLevel(_ n: Int) {
        let cc = min(3 + (n - 1) / 2, 6)
        var units: [Int] = []
        for c in 0..<cc {
            for _ in 0..<capacity { units.append(c) }
        }
        units.shuffle()

        var built: [[Int]] = []
        for c in 0..<cc {
            let start = c * capacity
            built.append(Array(units[start..<(start + capacity)]))
        }
        built.append([])
        built.append([])

        tubes = built
        history = []
        picked = -1
        cleared = false
    }
}
