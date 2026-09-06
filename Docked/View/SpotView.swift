//
//  SpotView.swift
//  Docked
//
//  "Spot" (premium) — one creature is shown as the target; find its exact
//  match in the crowd. No clock: each correct pick is a level up and the
//  crowd grows. Three wrong picks ends the run.
//
//  Original mechanic, original art. No third-party assets.
//

import SwiftUI

struct SpotView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("docked.spot.bestlevel") private var bestLevel = 1

    private struct Creature: Equatable { var hue: Int; var shape: Int; var hat: Int }

    @State private var target = Creature(hue: 0, shape: 0, hat: 0)
    @State private var crowd: [Creature] = []
    @State private var answer = 0
    @State private var level = 1
    @State private var lives = 3
    @State private var running = false
    @State private var wrongIdx: Int? = nil
    @State private var celebrateIdx: Int? = nil
    @State private var hitTick = 0
    @State private var missTick = 0
    @State private var overTick = 0

    private let cols = 4

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                Text("LEVEL \(level)").font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("BEST \(max(bestLevel, level))").font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { k in
                        Image(systemName: k < lives ? "heart.fill" : "heart")
                            .font(.system(size: 12))
                            .foregroundStyle(k < lives ? Color.red : Color.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
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
                            .scaleEffect(celebrateIdx == pair.offset ? 1.25 : 1)
                            .overlay {
                                if celebrateIdx == pair.offset {
                                    Circle().stroke(Color.green, lineWidth: 3)
                                        .scaleEffect(1.35)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .animation(.spring(response: 0.26, dampingFraction: 0.5), value: celebrateIdx)
                            .onTapGesture {
                                if running { pick(pair.offset) } else { start() }
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            if !running {
                Text(level > 1 ? "Reached level \(level) — tap to play again" : "Tap to start")
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
            HStack(spacing: side * 0.16) {
                Circle().fill(.white).frame(width: side * 0.14, height: side * 0.14)
                Circle().fill(.white).frame(width: side * 0.14, height: side * 0.14)
            }
            .offset(y: side * 0.04)
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
        let count = min(28, 6 + level * 3)
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
        level = 1
        lives = 3
        deal()
        running = true
    }

    private func pick(_ i: Int) {
        guard running else { return }
        if i == answer {
            hitTick += 1
            celebrateIdx = i
            let nextLevel = level + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                guard running else { return }
                level = nextLevel
                deal()
                celebrateIdx = nil
            }
        } else {
            lives -= 1
            missTick += 1
            wrongIdx = i
            if lives <= 0 { endGame() }
        }
    }

    private func endGame() {
        running = false
        bestLevel = max(bestLevel, level)
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
