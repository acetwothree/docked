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
    /// 1 right when a life is lost, eased back to 0 — flashes the player red.
    @State private var hitFlash: CGFloat = 0

    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                canvas(size: geo.size, tick: lastTick, hitFlash: hitFlash)
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
                if game.lives < livesBefore {
                    hurtTick += 1
                    hitFlash = 1
                }
                // Decayed by hand, in step with the same 60Hz tick that
                // drives the rest of this Canvas — SwiftUI's implicit
                // animation system doesn't interpolate a value read straight
                // inside a Canvas closure, so this is what actually fades it.
                if hitFlash > 0 { hitFlash = max(0, hitFlash - dt / 0.4) }
            }
        }
        .onChange(of: game.phase) { _, p in
            if p == .over, game.score > best { best = game.score }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: swipeTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: hitTick) { _, _ in app.haptics }
        .sensoryFeedback(.error, trigger: hurtTick) { _, _ in app.haptics }
        .sensoryFeedback(.success, trigger: game.blastTick) { _, _ in app.haptics }
    }

    private func canvas(size: CGSize, tick: Date, hitFlash: CGFloat) -> some View {
        _ = tick
        return Canvas { ctx, cs in
            let c = CGPoint(x: cs.width / 2, y: cs.height / 2)
            let reach = min(cs.width, cs.height) / 2 - 6
            let ringR = reach * BrawlModel.strikeDist
            let dirs: [CGPoint] = [CGPoint(x: 0, y: -1), CGPoint(x: 1, y: 0),
                                   CGPoint(x: 0, y: 1), CGPoint(x: -1, y: 0)]

            // one solid arena floor — a mat, not a set of crossing axis lines
            let floorRect = CGRect(x: c.x - reach, y: c.y - reach, width: reach * 2, height: reach * 2)
            ctx.fill(Path(ellipseIn: floorRect), with: .color(Theme.ink.opacity(0.05)))
            ctx.stroke(Path(ellipseIn: floorRect), with: .color(Theme.ink.opacity(0.12)), lineWidth: 2)

            // slash — a wedge that shoots from the player toward the swipe;
            // this alone shows the reach, so there's no separate ring drawn.
            if let sd = slashDir {
                let age = Date().timeIntervalSince(slashAt)
                if age < 0.1 {
                    let o = CGFloat(1 - age / 0.1)
                    let d = dirs[sd]
                    let ang = atan2(Double(d.y), Double(d.x))
                    let len = ringR + 14
                    let a1 = ang - 0.34, a2 = ang + 0.34
                    var wedge = Path()
                    wedge.move(to: c)
                    wedge.addLine(to: CGPoint(x: c.x + CGFloat(cos(a1)) * len, y: c.y + CGFloat(sin(a1)) * len))
                    wedge.addLine(to: CGPoint(x: c.x + CGFloat(cos(a2)) * len, y: c.y + CGFloat(sin(a2)) * len))
                    wedge.closeSubpath()
                    ctx.fill(wedge, with: .color(Theme.accent.opacity(0.55 * o)))
                }
            }

            // enemies — plain ones always look the same; the rare powerup
            // ones are deliberately a different colour, since standing out
            // is the whole point of the signal.
            for e in game.enemies {
                let d = dirs[e.dir]
                let px = c.x + d.x * reach * e.dist
                let py = c.y + d.y * reach * e.dist
                let s: CGFloat = 26
                let r = CGRect(x: px - s / 2, y: py - s / 2, width: s, height: s)
                let color: Color = {
                    switch e.kind {
                    case .normal: return Theme.ink.opacity(0.8)
                    case .freeze: return Color(hex: "4AC7F0")
                    case .blast: return Color(hex: "F2883C")
                    }
                }()
                ctx.fill(Path(roundedRect: r, cornerRadius: 6, style: .continuous), with: .color(color))
                if e.kind != .normal {
                    ctx.stroke(Path(roundedRect: r, cornerRadius: 6, style: .continuous),
                              with: .color(.white.opacity(0.7)), lineWidth: 1.5)
                }
            }

            // player — soft glow + a slow idle bob; flashes red on a hit (a
            // plain red fill composited on top at `hitFlash` opacity, rather
            // than trying to hand-blend RGB — much simpler and theme-safe)
            let bob = CGFloat(sin(Double(game.elapsed) * 2.2)) * 2
            let ps: CGFloat = 42
            let prect = CGRect(x: c.x - ps / 2, y: c.y - ps / 2 + bob, width: ps, height: ps)
            ctx.fill(Path(ellipseIn: prect.insetBy(dx: -9, dy: -9)),
                     with: .color((hitFlash > 0 ? Color.red : Theme.accent).opacity(0.18 + 0.3 * hitFlash)))
            ctx.fill(Path(roundedRect: prect, cornerRadius: 11, style: .continuous),
                     with: .color(Theme.accent))
            if hitFlash > 0 {
                ctx.fill(Path(roundedRect: prect, cornerRadius: 11, style: .continuous),
                         with: .color(Color.red.opacity(hitFlash)))
            }
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
            .padding(10)
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

    /// Sits at the bottom, not the middle — so it reads as a hint rather than
    /// a dialog blocking the arena from view before you've even started.
    private func prompt(_ t: String, _ s: String) -> some View {
        VStack {
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                Text(t).font(.title3.bold())
                Text(s).font(.footnote).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22).padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(Theme.ink)
        }
        .padding(.bottom, 12)
    }
}

@Observable
final class BrawlModel {
    enum Phase: Equatable { case ready, running, over }
    enum EnemyKind: Equatable { case normal, freeze, blast }
    struct Enemy: Identifiable { let id = UUID(); var dir: Int; var dist: CGFloat; var kind: EnemyKind = .normal }

    /// An enemy anywhere from the centre out to here is a valid target — a
    /// generous window, not a knife-edge at the ring.
    static let strikeDist: CGFloat = 0.46

    private(set) var phase: Phase = .ready
    private(set) var enemies: [Enemy] = []
    private(set) var score = 0
    private(set) var lives = 3
    private(set) var elapsed: CGFloat = 0
    /// Bumps whenever a blast powerup clears the board — a haptic/visual cue.
    private(set) var blastTick = 0

    private var spawnCountdown: CGFloat = 1.1
    private var speed: CGFloat = 0.12
    /// While > 0, enemy speed is cut way down — a Freeze powerup's effect.
    private(set) var freezeTimeLeft: CGFloat = 0

    func tap() {
        switch phase {
        case .ready, .over:
            enemies.removeAll(); score = 0; lives = 3
            spawnCountdown = 0.22; speed = 0.30; elapsed = 0; freezeTimeLeft = 0
            // Three enemies already on the board so it's a fight from the first tap.
            for d in Array(0..<4).shuffled().prefix(3) {
                enemies.append(Enemy(dir: d, dist: CGFloat.random(in: 0.7...1.0)))
            }
            phase = .running
        case .running:
            break
        }
    }

    /// A little slack so an enemy whose edge is just touching the ring still
    /// counts — roughly one enemy-radius past the ring line. Generous on
    /// purpose: this is a "feels good" leniency on top of a reach that reads
    /// (and is drawn) exactly the same either way.
    static let strikeSlack: CGFloat = 0.15

    @discardableResult
    func strike(_ dir: Int) -> Bool {
        guard phase == .running else { return false }
        let inRange = enemies.enumerated()
            .filter { $0.element.dir == dir && $0.element.dist <= Self.strikeDist + Self.strikeSlack }
            .min(by: { $0.element.dist < $1.element.dist })
        guard let hit = inRange else { return false }
        let kind = enemies[hit.offset].kind
        enemies.remove(at: hit.offset)
        score += 1
        switch kind {
        case .normal: break
        case .freeze: freezeTimeLeft = 4
        case .blast:
            score += enemies.count
            enemies.removeAll()
            blastTick += 1
        }
        return true
    }

    func step(dt rawDt: CGFloat) {
        guard phase == .running else { return }
        let dt = min(rawDt, 1.0 / 30.0)
        elapsed += dt
        if freezeTimeLeft > 0 { freezeTimeLeft = max(0, freezeTimeLeft - dt) }
        let baseSpeed = 0.30 + elapsed * 0.009
        speed = freezeTimeLeft > 0 ? baseSpeed * 0.35 : baseSpeed

        for i in enemies.indices { enemies[i].dist -= speed * dt }

        if let breach = enemies.firstIndex(where: { $0.dist <= 0 }) {
            enemies.remove(at: breach)
            lives -= 1
            if lives <= 0 { phase = .over; return }
        }

        spawnCountdown -= dt
        if spawnCountdown <= 0 {
            // Rare powerup enemies — visually distinct on purpose, since
            // that's the whole point of the signal.
            let roll = Double.random(in: 0..<1)
            let kind: EnemyKind = roll < 0.06 ? .freeze : (roll < 0.12 ? .blast : .normal)
            enemies.append(Enemy(dir: Int.random(in: 0..<4), dist: 1, kind: kind))
            let base = max(0.22, 0.75 - elapsed * 0.03)
            spawnCountdown = CGFloat.random(in: base...(base + 0.4))
        }
    }
}
