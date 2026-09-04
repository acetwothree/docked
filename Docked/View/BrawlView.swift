//
//  BrawlView.swift
//  Docked
//
//  "Brawl" (premium) — you're the block in the middle. Enemies march in along
//  the four cardinal paths. Swipe toward one that's in the ring to strike it.
//  Let one reach you and you lose a heart; survive the waves.
//

import SwiftUI
import Combine

struct BrawlView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("docked.brawl.best") private var best = 0

    @State private var game = BrawlModel()
    @State private var lastTick = Date()
    @State private var hitTick = 0
    @State private var hurtTick = 0
    @State private var swipeTick = 0
    /// Direction of the last swipe + when it happened, for the slash arc.
    @State private var slashDir: Int? = nil
    @State private var slashAt = Date()

    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                canvas(size: geo.size, tick: lastTick)
                hud
                overlay
            }
            .contentShape(Rectangle())
            .onTapGesture { game.tap() }
            .gesture(
                DragGesture(minimumDistance: 16)
                    .onEnded { v in
                        guard game.phase == .running else { game.tap(); return }
                        let dx = v.translation.width, dy = v.translation.height
                        let dir = abs(dx) > abs(dy) ? (dx > 0 ? 1 : 3) : (dy > 0 ? 2 : 0)
                        slashDir = dir
                        slashAt = Date()
                        swipeTick += 1
                        if game.strike(dir) { hitTick += 1 }
                    }
            )
            .onReceive(ticker) { _ in
                let now = Date()
                let dt = CGFloat(now.timeIntervalSince(lastTick))
                lastTick = now
                let livesBefore = game.lives
                game.step(dt: dt)
                if game.lives < livesBefore { hurtTick += 1 }
            }
        }
        .onChange(of: game.phase) { _, p in
            if p == .over, game.score > best { best = game.score }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: swipeTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: hitTick) { _, _ in app.haptics }
        .sensoryFeedback(.error, trigger: hurtTick) { _, _ in app.haptics }
    }

    private func canvas(size: CGSize, tick: Date) -> some View {
        _ = tick
        return Canvas { ctx, cs in
            let c = CGPoint(x: cs.width / 2, y: cs.height / 2)
            let reach = min(cs.width, cs.height) / 2 - 12
            let ringR = reach * BrawlModel.strikeDist
            let dirs: [CGPoint] = [CGPoint(x: 0, y: -1), CGPoint(x: 1, y: 0),
                                   CGPoint(x: 0, y: 1), CGPoint(x: -1, y: 0)]

            // soft vignette background
            ctx.fill(Path(CGRect(origin: .zero, size: cs)),
                     with: .radialGradient(Gradient(colors: [Theme.accent.opacity(0.06), .clear]),
                                           center: c, startRadius: 0, endRadius: reach))

            // lane guides — fade toward the centre
            for d in dirs {
                var p = Path()
                p.move(to: CGPoint(x: c.x + d.x * ringR, y: c.y + d.y * ringR))
                p.addLine(to: CGPoint(x: c.x + d.x * reach, y: c.y + d.y * reach))
                ctx.stroke(p, with: .color(Theme.ink.opacity(0.08)),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5, 9]))
            }

            // strike ring — a soft glow plus a crisp edge
            let ringRect = CGRect(x: c.x - ringR, y: c.y - ringR, width: ringR * 2, height: ringR * 2)
            ctx.fill(Path(ellipseIn: ringRect), with: .color(Theme.accent.opacity(0.07)))
            ctx.stroke(Path(ellipseIn: ringRect), with: .color(Theme.accent.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 2, dash: [3, 5]))

            // slash arc from the last swipe
            if let sd = slashDir {
                let age = Date().timeIntervalSince(slashAt)
                if age < 0.22 {
                    let o = 1 - age / 0.22
                    let d = dirs[sd]
                    let ang = atan2(Double(d.y), Double(d.x))
                    var arc = Path()
                    arc.addArc(center: c, radius: ringR + 8,
                               startAngle: .radians(ang - 0.6), endAngle: .radians(ang + 0.6),
                               clockwise: false)
                    ctx.stroke(arc, with: .color(Theme.accent.opacity(o)),
                               style: StrokeStyle(lineWidth: CGFloat(6 * o + 2), lineCap: .round))
                }
            }

            // enemies
            for e in game.enemies {
                let d = dirs[e.dir]
                let px = c.x + d.x * reach * e.dist
                let py = c.y + d.y * reach * e.dist
                let inRing = e.dist <= BrawlModel.strikeDist
                let s: CGFloat = inRing ? 24 : 20
                let col = inRing ? Theme.accent : Theme.ink.opacity(0.78)
                let r = CGRect(x: px - s / 2, y: py - s / 2, width: s, height: s)
                ctx.fill(Path(roundedRect: r, cornerRadius: 5, style: .continuous), with: .color(col))
                if inRing {
                    ctx.stroke(Path(roundedRect: r.insetBy(dx: -3, dy: -3), cornerRadius: 7),
                               with: .color(Theme.accent.opacity(0.3)), lineWidth: 2)
                }
            }

            // player — soft glow + a slow idle bob
            let bob = CGFloat(sin(Double(game.elapsed) * 2.2)) * 2
            let ps: CGFloat = 36
            let prect = CGRect(x: c.x - ps / 2, y: c.y - ps / 2 + bob, width: ps, height: ps)
            ctx.fill(Path(ellipseIn: prect.insetBy(dx: -8, dy: -8)),
                     with: .color(Theme.accent.opacity(0.18)))
            ctx.fill(Path(roundedRect: prect, cornerRadius: 9, style: .continuous),
                     with: .color(Theme.accent))
        }
    }

    private var hud: some View {
        VStack {
            HStack {
                Text("\(game.score)").font(.headline.monospacedDigit()).foregroundStyle(Theme.ink)
                Spacer()
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < game.lives ? "heart.fill" : "heart")
                            .font(.system(size: 13))
                            .foregroundStyle(i < game.lives ? Color.red : Color.secondary)
                    }
                }
            }
            .padding(14)
            Spacer()
        }
    }

    @ViewBuilder private var overlay: some View {
        switch game.phase {
        case .ready:
            prompt("Tap to fight", "Swipe toward an enemy in the ring to hit it")
        case .over:
            prompt("Down!", "Score \(game.score) · tap to retry")
        case .running:
            EmptyView()
        }
    }

    private func prompt(_ t: String, _ s: String) -> some View {
        VStack(spacing: 6) {
            Text(t).font(.title3.bold())
            Text(s).font(.footnote).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 22).padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .foregroundStyle(Theme.ink)
    }
}

@Observable
final class BrawlModel {
    enum Phase: Equatable { case ready, running, over }
    struct Enemy: Identifiable { let id = UUID(); var dir: Int; var dist: CGFloat }

    static let strikeDist: CGFloat = 0.34

    private(set) var phase: Phase = .ready
    private(set) var enemies: [Enemy] = []
    private(set) var score = 0
    private(set) var lives = 3
    private(set) var elapsed: CGFloat = 0

    private var spawnCountdown: CGFloat = 1.1
    private var speed: CGFloat = 0.14

    func tap() {
        switch phase {
        case .ready, .over:
            enemies.removeAll(); score = 0; lives = 3
            spawnCountdown = 0.9; speed = 0.14; elapsed = 0
            phase = .running
        case .running:
            break
        }
    }

    @discardableResult
    func strike(_ dir: Int) -> Bool {
        guard phase == .running else { return false }
        let inRange = enemies.enumerated()
            .filter { $0.element.dir == dir && $0.element.dist <= Self.strikeDist }
            .min(by: { $0.element.dist < $1.element.dist })
        guard let hit = inRange else { return false }
        enemies.remove(at: hit.offset)
        score += 1
        return true
    }

    func step(dt rawDt: CGFloat) {
        guard phase == .running else { return }
        let dt = min(rawDt, 1.0 / 30.0)
        elapsed += dt
        speed = 0.14 + elapsed * 0.006

        for i in enemies.indices { enemies[i].dist -= speed * dt }

        if let breach = enemies.firstIndex(where: { $0.dist <= 0 }) {
            enemies.remove(at: breach)
            lives -= 1
            if lives <= 0 { phase = .over; return }
        }

        spawnCountdown -= dt
        if spawnCountdown <= 0 {
            enemies.append(Enemy(dir: Int.random(in: 0..<4), dist: 1))
            let base = max(0.45, 1.2 - elapsed * 0.02)
            spawnCountdown = CGFloat.random(in: base...(base + 0.6))
        }
    }
}
