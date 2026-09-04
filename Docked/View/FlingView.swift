//
//  FlingView.swift
//  Docked
//
//  "Fling" (premium) — hold to charge a launch, release to fling yourself up,
//  then drag left/right to steer through drifting coins. Score is the height
//  you reach plus the coins you grab. Fling again to beat it.
//
//  Original mechanic, original art. No third-party assets.
//

import SwiftUI
import Combine

struct FlingView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("docked.fling.best") private var best = 0

    private enum Phase { case aim, fly, done }

    @State private var phase: Phase = .aim
    @State private var power: CGFloat = 0        // 0…1 while charging
    @State private var charging = false
    @State private var px: CGFloat = 0.5         // 0…1 across the arena
    @State private var vx: CGFloat = 0
    @State private var height: CGFloat = 0       // world units up from the launch pad
    @State private var vy: CGFloat = 0
    @State private var peak: CGFloat = 0
    @State private var coins: [Coin] = []
    @State private var grabbed = 0
    @State private var runScore = 0
    @State private var lastTick = Date()
    @State private var launchTick = 0
    @State private var coinTick = 0
    @State private var landTick = 0

    private struct Coin: Identifiable { let id = UUID(); var x: CGFloat; var h: CGFloat; var got = false }

    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let gravity: CGFloat = 900
    private let maxLaunch: CGFloat = 1500

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            ZStack {
                canvas(W: W, H: H)
                hud
                overlay
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if phase == .aim { charging = true }
                        if phase == .fly {
                            vx = Double(v.translation.width / max(W, 1)) * 3.2
                        }
                    }
                    .onEnded { _ in
                        if phase == .aim, charging { launch() }
                        charging = false
                        if phase == .fly { vx = 0 }
                    }
            )
            .onTapGesture {
                if phase == .done { phase = .aim; power = 0 }
            }
            .onReceive(ticker) { _ in
                let now = Date()
                let dt = CGFloat(min(now.timeIntervalSince(lastTick), 1.0 / 30.0))
                lastTick = now
                step(dt: dt, W: W, H: H)
            }
        }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: launchTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: coinTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: landTick) { _, _ in app.haptics }
    }

    private func canvas(W: CGFloat, H: CGFloat) -> some View {
        Canvas { ctx, cs in
            let groundY = cs.height - 44
            // camera: keep the player ~55% down the screen once it's climbing
            let camH = max(0, height - (cs.height * 0.45) / 1)
            func screenY(_ h: CGFloat) -> CGFloat { groundY - (h - camH) }

            // ground
            ctx.fill(Path(CGRect(x: 0, y: groundY, width: cs.width, height: cs.height - groundY)),
                     with: .color(Theme.ink.opacity(0.14)))

            // coins
            for c in coins where !c.got {
                let y = screenY(c.h)
                guard y > -20, y < cs.height + 20 else { continue }
                let r: CGFloat = 9
                ctx.fill(Path(ellipseIn: CGRect(x: c.x * cs.width - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(Color(hex: "F5C518")))
            }

            // player
            let py = phase == .fly ? screenY(height) : groundY - 8
            let s: CGFloat = 22
            ctx.fill(Path(roundedRect: CGRect(x: px * cs.width - s / 2, y: py - s / 2, width: s, height: s),
                          cornerRadius: 6), with: .color(Theme.accent))

            // charge meter
            if phase == .aim {
                let barW = cs.width * 0.6
                let x = (cs.width - barW) / 2
                let y = cs.height - 70
                ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: barW, height: 10), cornerRadius: 5),
                         with: .color(Theme.ink.opacity(0.12)))
                ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: barW * power, height: 10), cornerRadius: 5),
                         with: .color(Theme.accent))
            }
        }
    }

    private var hud: some View {
        VStack {
            HStack {
                Text("↑ \(Int(peak / 10)) · ◉ \(grabbed)")
                    .font(.system(size: 13, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("BEST \(best)").font(.system(size: 12, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            Spacer()
        }
    }

    @ViewBuilder private var overlay: some View {
        switch phase {
        case .aim:
            box("Hold to charge", "Let go to launch · drag to steer")
        case .done:
            box("+\(runScore)", "Tap to fling again")
        case .fly:
            EmptyView()
        }
    }

    private func box(_ t: String, _ s: String) -> some View {
        VStack(spacing: 6) {
            Text(t).font(.title3.bold())
            Text(s).font(.footnote).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 22).padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .foregroundStyle(Theme.ink)
    }

    // MARK: sim

    private func step(dt: CGFloat, W: CGFloat, H: CGFloat) {
        switch phase {
        case .aim:
            if charging {
                power += dt * 1.4
                if power > 1 { power = 1 }
            }
        case .fly:
            vy -= gravity * dt
            height += vy * dt
            px += vx * dt
            px = min(0.94, max(0.06, px))
            peak = max(peak, height)

            for i in coins.indices where !coins[i].got {
                if abs(coins[i].h - height) < 20, abs(coins[i].x - px) < 0.09 {
                    coins[i].got = true
                    grabbed += 1
                    coinTick += 1
                }
            }
            if height <= 0 {
                height = 0
                phase = .done
                runScore = Int(peak / 10) + grabbed * 5
                if runScore > best { best = runScore }
                landTick += 1
            }
        case .done:
            break
        }
    }

    private func launch() {
        vy = power * maxLaunch
        height = 0
        peak = 0
        vx = 0
        grabbed = 0
        px = 0.5
        // scatter coins up the flight path
        let top = power * maxLaunch * maxLaunch / (2 * gravity)   // ballistic apex
        coins = (0..<14).map { k in
            Coin(x: CGFloat.random(in: 0.12...0.88),
                 h: CGFloat(k + 1) / 15 * top * CGFloat.random(in: 0.7...1.05))
        }
        phase = .fly
        launchTick += 1
    }
}
