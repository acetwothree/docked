//
//  RunnerModel.swift
//  Docked
//
//  A lane runner: the player is pinned near the bottom in one of three lanes,
//  obstacles scroll down from the top. Swipe left/right to change lane, swipe
//  UP to jump the blocks on the ground, swipe DOWN to slide under the bars
//  hanging from above.
//
//  Pure simulation — no SwiftUI. `step(dt:arenaHeight:)` runs from the view's
//  60 Hz ticker.
//

import SwiftUI

@Observable
final class RunnerModel {

    enum Phase: Equatable { case ready, running, paused, gameOver }
    /// `ground` = a block on the floor → JUMP it. `overhead` = a bar from the
    /// ceiling → SLIDE under it.
    enum Kind: Equatable { case ground, overhead }

    struct Obstacle: Identifiable {
        let id = UUID()
        var lane: Int
        var y: CGFloat
        var kind: Kind
        var scored = false
    }

    let lanes = 3

    private(set) var phase: Phase = .ready
    private(set) var lane = 1
    /// 0 = grounded, up to 1 at the apex of a jump.
    private(set) var hop: CGFloat = 0
    /// > 0 while sliding (crouched).
    private(set) var slide: CGFloat = 0
    private(set) var obstacles: [Obstacle] = []
    private(set) var score: Double = 0
    private(set) var speed: CGFloat = 420

    /// bumps when you clear an obstacle in your lane — a "whoosh" haptic.
    private(set) var dodgeTick = 0

    private var hopTime: CGFloat = 0
    private var slideTime: CGFloat = 0
    private var spawnCountdown: CGFloat = 0.9

    private let hopDuration: CGFloat = 0.56
    private let slideDuration: CGFloat = 0.55
    private let baseSpeed: CGFloat = 420
    private let maxSpeed: CGFloat = 860

    var scoreValue: Int { Int(score) }

    // MARK: intent

    func moveLeft() {
        if phase == .running { lane = max(0, lane - 1) } else { tap() }
    }
    func moveRight() {
        if phase == .running { lane = min(lanes - 1, lane + 1) } else { tap() }
    }

    func jump() {
        guard phase == .running else { tap(); return }
        if hopTime <= 0 && slideTime <= 0 { hopTime = hopDuration }
    }

    func slideDown() {
        guard phase == .running else { tap(); return }
        if slideTime <= 0 && hopTime <= 0 { slideTime = slideDuration }
    }

    /// Tap = start / resume / retry (also a small hop while running).
    func tap() {
        switch phase {
        case .ready, .gameOver: reset(); phase = .running
        case .paused: phase = .running
        case .running: if hopTime <= 0 && slideTime <= 0 { hopTime = hopDuration }
        }
    }

    func pauseIfRunning() { if phase == .running { phase = .paused } }

    private func reset() {
        lane = 1
        hop = 0; slide = 0
        hopTime = 0; slideTime = 0
        obstacles.removeAll()
        score = 0
        speed = baseSpeed
        spawnCountdown = 0.9
    }

    // MARK: simulation

    func step(dt rawDt: CGFloat, arenaHeight: CGFloat) {
        guard phase == .running else { return }
        let dt = min(rawDt, 1.0 / 30.0)

        speed = min(maxSpeed, baseSpeed + CGFloat(score) * 2.2)
        score += Double(dt) * 14

        if hopTime > 0 {
            hopTime -= dt
            let t = max(0, 1 - hopTime / hopDuration)
            hop = CGFloat(sin(Double(t) * Double.pi))
            if hopTime <= 0 { hop = 0; hopTime = 0 }
        }
        if slideTime > 0 {
            slideTime -= dt
            slide = min(1, slideTime * 6)
            if slideTime <= 0 { slide = 0; slideTime = 0 }
        }

        for i in obstacles.indices { obstacles[i].y += speed * dt }
        obstacles.removeAll { $0.y > arenaHeight + 90 }

        spawnCountdown -= dt
        if spawnCountdown <= 0 {
            let l = Int.random(in: 0..<lanes)
            let kind: Kind = Bool.random() ? .ground : .overhead
            obstacles.append(Obstacle(lane: l, y: -80, kind: kind))
            spawnCountdown = max(0.45, CGFloat.random(in: 0.7...1.3) * (baseSpeed / speed))
        }

        let playerY = arenaHeight - 90
        for i in obstacles.indices {
            let o = obstacles[i]
            guard o.lane == lane else { continue }
            if !o.scored && o.y > playerY + 20 {
                obstacles[i].scored = true
                dodgeTick += 1
            }
            guard abs(o.y - playerY) < 30 else { continue }
            let safe: Bool
            switch o.kind {
            case .ground:   safe = hop > 0.3
            case .overhead: safe = slide > 0.4
            }
            if !safe { phase = .gameOver; return }
        }
    }
}
