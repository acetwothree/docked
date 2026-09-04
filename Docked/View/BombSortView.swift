//
//  BombSortView.swift
//  Docked
//
//  "Bomb Sort" (premium) — bombs drift down, black or red, each with a burning
//  wick. Flick red ones left into the red bin and black ones right into the
//  black bin before the wick runs out. It speeds up and the bombs start
//  arriving from wider and wider as you go.
//

import SwiftUI
import Combine

struct BombSortView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("docked.bombsort.best") private var best = 0

    @State private var model = BombSortModel()
    @State private var lastTick = Date()

    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let bombR: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            ZStack {
                // bins
                bin(color: Color(hex: "E0473E"), label: "RED", align: .bottomLeading, W: W, H: H)
                bin(color: Theme.ink.opacity(0.85), label: "BLACK", align: .bottomTrailing, W: W, H: H)

                ForEach(model.bombs) { b in
                    bombView(b)
                        .position(x: b.x, y: b.y)
                        .gesture(
                            DragGesture(minimumDistance: 12)
                                .onEnded { v in
                                    guard abs(v.translation.width) > 24 else { return }
                                    model.flick(id: b.id, dir: v.translation.width > 0 ? 1 : -1)
                                }
                        )
                }

                hud
                overlay(W: W, H: H)
            }
            .contentShape(Rectangle())
            .onTapGesture { if model.phase != .running { model.start() } }
            .onReceive(ticker) { _ in
                let now = Date()
                let dt = CGFloat(min(now.timeIntervalSince(lastTick), 1.0 / 30.0))
                lastTick = now
                model.step(dt: dt, W: W, H: H, bombR: bombR)
            }
        }
        .onChange(of: model.phase) { _, p in
            if p == .over, model.score > best { best = model.score }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.sortTick) { _, _ in app.haptics }
        .sensoryFeedback(.error, trigger: model.boomTick) { _, _ in app.haptics }
    }

    private func bombView(_ b: BombSortModel.Bomb) -> some View {
        ZStack {
            Circle()
                .fill(b.red ? Color(hex: "E0473E") : Theme.ink.opacity(0.9))
                .frame(width: bombR * 2, height: bombR * 2)
            // wick, burning down
            Capsule()
                .fill((b.wick / b.maxWick) < 0.35 ? Color.orange : Color(hex: "C8A25A"))
                .frame(width: 3, height: max(2, 12 * (b.wick / b.maxWick)))
                .offset(y: -bombR - 5)
        }
    }

    private func bin(color: Color, label: String, align: Alignment, W: CGFloat, H: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 9, weight: .black)).foregroundStyle(.white)
        }
        .frame(width: W * 0.34, height: 40)
        .background(color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align)
        .padding(6)
    }

    private var hud: some View {
        VStack {
            HStack {
                Text("\(model.score)").font(.headline.monospacedDigit()).foregroundStyle(Theme.ink)
                Spacer()
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < model.lives ? "heart.fill" : "heart")
                            .font(.system(size: 13))
                            .foregroundStyle(i < model.lives ? Color.red : Color.secondary)
                    }
                }
            }
            .padding(14)
            Spacer()
        }
    }

    @ViewBuilder private func overlay(W: CGFloat, H: CGFloat) -> some View {
        if model.phase != .running {
            VStack(spacing: 6) {
                Text(model.phase == .over ? "Boom!" : "Bomb Sort").font(.title3.bold())
                Text(model.phase == .over ? "Score \(model.score) · tap to retry"
                     : "Flick red ⬅︎ · flick black ➡︎")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22).padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(Theme.ink)
        }
    }
}

@Observable
final class BombSortModel {
    enum Phase: Equatable { case ready, running, over }

    struct Bomb: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var red: Bool
        var wick: CGFloat
        var maxWick: CGFloat
        var flick: Int = 0   // 0 falling · -1 flying left · 1 flying right
    }

    private(set) var phase: Phase = .ready
    private(set) var bombs: [Bomb] = []
    private(set) var score = 0
    private(set) var lives = 3
    private(set) var sortTick = 0
    private(set) var boomTick = 0

    private var elapsed: CGFloat = 0
    private var spawnCd: CGFloat = 0.8

    func start() {
        bombs.removeAll(); score = 0; lives = 3; elapsed = 0; spawnCd = 0.8
        phase = .running
    }

    func flick(id: UUID, dir: Int) {
        guard phase == .running,
              let i = bombs.firstIndex(where: { $0.id == id }), bombs[i].flick == 0 else { return }
        bombs[i].flick = dir
        let correct = (bombs[i].red && dir < 0) || (!bombs[i].red && dir > 0)
        if correct {
            score += 1
            sortTick += 1
        } else {
            bombs.remove(at: i)
            loseLife()
        }
    }

    private func loseLife() {
        lives -= 1
        boomTick += 1
        if lives <= 0 { phase = .over }
    }

    func step(dt: CGFloat, W: CGFloat, H: CGFloat, bombR: CGFloat) {
        guard phase == .running else { return }
        elapsed += dt
        let fall = 80 + elapsed * 2.6

        for i in bombs.indices {
            if bombs[i].flick == 0 {
                bombs[i].y += fall * dt
                bombs[i].wick -= dt
            } else {
                bombs[i].x += CGFloat(bombs[i].flick) * 560 * dt
            }
        }

        // one consequence per frame keeps index maths simple
        if let j = bombs.firstIndex(where: { $0.flick == 0 && $0.wick <= 0 }) {
            bombs.remove(at: j); loseLife(); return
        }
        if let j = bombs.firstIndex(where: { $0.flick == 0 && $0.y > H - 46 }) {
            bombs.remove(at: j); loseLife(); return
        }
        bombs.removeAll { $0.flick != 0 && ($0.x < -60 || $0.x > W + 60) }

        spawnCd -= dt
        if spawnCd <= 0 {
            let spread = min(0.42, 0.05 + elapsed * 0.006)
            let x = W * (0.5 + CGFloat.random(in: -spread...spread))
            let wick = max(1.7, 4.0 - elapsed * 0.028)
            bombs.append(Bomb(x: min(W - bombR, max(bombR, x)), y: -20,
                              red: Bool.random(), wick: wick, maxWick: wick))
            spawnCd = max(0.5, 1.25 - elapsed * 0.011) * CGFloat.random(in: 0.8...1.2)
        }
    }
}
