//
//  SpotView.swift
//  Docked
//
//  "Spot" (premium) — one creature is shown as the target; find its exact
//  match in the crowd before the timer runs out. Each round adds more
//  look-alikes. Wrong taps cost you time.
//
//  Original mechanic, original art. No third-party assets.
//

import SwiftUI

struct SpotView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("docked.spot.best") private var best = 0

    private struct Creature: Equatable { var hue: Int; var shape: Int; var hat: Int }

    @State private var target = Creature(hue: 0, shape: 0, hat: 0)
    @State private var crowd: [Creature] = []
    @State private var answer = 0
    @State private var round = 1
    @State private var score = 0
    @State private var timeLeft: Double = 20
    @State private var running = false
    @State private var wrongIdx: Int? = nil
    @State private var hitTick = 0
    @State private var missTick = 0
    @State private var overTick = 0

    private let cols = 4

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("ROUND \(round)").font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("SCORE \(score)").font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f", max(0, timeLeft)))
                    .font(.system(size: 13, weight: .black)).monospacedDigit()
                    .foregroundStyle(timeLeft < 5 ? Color.red : Color.primary)
            }

            HStack(spacing: 8) {
                Text("FIND THIS ONE").font(.system(size: 11, weight: .heavy)).foregroundStyle(.secondary)
                creatureView(target, side: 44)
                    .background(Theme.accent.opacity(0.12),
                               in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            GeometryReader { geo in
                let n = crowd.count
                let rowsN = max(1, (n + cols - 1) / cols)
                let sw: CGFloat = (geo.size.width - CGFloat(cols + 1) * 6) / CGFloat(cols)
                let sh: CGFloat = (geo.size.height - CGFloat(rowsN + 1) * 6) / CGFloat(rowsN)
                let side: CGFloat = min(sw, sh)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: cols), spacing: 6) {
                    ForEach(Array(crowd.enumerated()), id: \.offset) { pair in
                        creatureView(pair.element, side: max(24, side))
                            .frame(maxWidth: .infinity)
                            .opacity(wrongIdx == pair.offset ? 0.3 : 1)
                            .onTapGesture {
                                if running { pick(pair.offset) } else { start() }
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            if !running {
                Text(score > 0 ? "Time! Tap to play again" : "Tap to start")
                    .font(.system(size: 13, weight: .heavy)).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { if !running { start() } }
        .sensoryFeedback(.success, trigger: hitTick) { _, _ in app.haptics }
        .sensoryFeedback(.error, trigger: missTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: overTick) { _, _ in app.haptics }
        .onAppear { if crowd.isEmpty { deal() } }
        .task(id: running) {
            guard running else { return }
            while running, timeLeft > 0, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                timeLeft -= 0.1
            }
            if timeLeft <= 0, running { endGame() }
        }
    }

    private func creatureView(_ c: Creature, side: CGFloat) -> some View {
        let col = Color(hue: Double(c.hue) / 6.0, saturation: 0.7, brightness: 0.9)
        return ZStack {
            Group {
                switch c.shape {
                case 0: Circle().fill(col)
                case 1: RoundedRectangle(cornerRadius: side * 0.28, style: .continuous).fill(col)
                default: RoundedRectangle(cornerRadius: side * 0.5, style: .continuous).fill(col)
                }
            }
            .frame(width: side * 0.82, height: side * 0.82)
            // eyes
            HStack(spacing: side * 0.16) {
                Circle().fill(.white).frame(width: side * 0.14, height: side * 0.14)
                Circle().fill(.white).frame(width: side * 0.14, height: side * 0.14)
            }
            .offset(y: side * 0.04)
            // hat
            Group {
                switch c.hat {
                case 1: Circle().fill(Theme.ink).frame(width: side * 0.18, height: side * 0.18)
                        .offset(y: -side * 0.42)
                case 2: Triangle().fill(Theme.ink).frame(width: side * 0.3, height: side * 0.22)
                        .offset(y: -side * 0.44)
                default: EmptyView()
                }
            }
        }
        .frame(width: side, height: side)
    }

    // MARK: logic

    private func randomCreature() -> Creature {
        Creature(hue: .random(in: 0..<6), shape: .random(in: 0..<3), hat: .random(in: 0..<3))
    }

    private func deal() {
        target = randomCreature()
        let count = min(24, 6 + round * 2)
        var list: [Creature] = []
        while list.count < count - 1 {
            let c = randomCreature()
            if c != target { list.append(c) }
        }
        answer = Int.random(in: 0..<count)
        list.insert(target, at: answer)
        crowd = list
        wrongIdx = nil
    }

    private func start() {
        round = 1; score = 0; timeLeft = 20
        deal()
        running = true
    }

    private func pick(_ i: Int) {
        guard running else { return }
        if i == answer {
            score += round * 10
            round += 1
            timeLeft = min(timeLeft + 4, 30)
            hitTick += 1
            deal()
        } else {
            timeLeft -= 3
            missTick += 1
            wrongIdx = i
            if timeLeft <= 0 { endGame() }
        }
    }

    private func endGame() {
        running = false
        if score > best { best = score }
        overTick += 1
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
