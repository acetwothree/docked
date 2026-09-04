//
//  RunnerModel.swift
//  Docked
//
//  A lane runner (Subway-Surfers-style): the player is pinned near the bottom
//  in one of three lanes, obstacles scroll down from the top. Swipe left/right
//  to change lane, swipe up (or tap) to hop over the short ones.
//
//  Pure simulation — no SwiftUI. `step(dt:arenaHeight:)` is called from the
//  view's 60 Hz ticker.
//

import SwiftUI

@Observable
final class RunnerModel {

    enum Phase: Equatable { case ready, running, paused, gameOver }
    enum Kind { case block, low }

    struct Obstacle: Identifiable {
        let id = UUID()
        var lane: Int
        var y: CGFloat
        var kind: Kind
    }

    let lanes = 3

    private(set) var phase: Phase = .ready
    private(set) var lane = 1
    /// 0 = grounded, up to 1 at the top of a hop.
    private(set) var hop: CGFloat = 0
    private(set) var obstacles: [Obstacle] = []
    private(set) var score: Double = 0
    private(set) var speed: CGFloat = 300

    private var hopTime: CGFloat = 0
    private var spawnCountdown: CGFloat = 0.9

    private let hopDuration: CGFloat = 0.6
    private let baseSpeed: CGFloat = 300
    private let maxSpeed: CGFloat = 660

    var scoreValue: Int { Int(score) }

    // MARK: intent

    func moveLeft() {
        if phase == .running { lane = max(0, lane - 1) } else { tap() }
    }
    func moveRight() {
        if phase == .running { lane = min(lanes - 1, lane + 1) } else { tap() }
    }

    func jump() {
        if phase == .running {
            if hopTime <= 0 { hopTime = hopDuration }
        } else {
            tap()
        }
    }

    /// Tap = start / resume / retry / hop.
    func tap() {
        switch phase {
        case .ready, .gameOver: reset(); phase = .running
        case .paused: phase = .running
        case .running: if hopTime <= 0 { hopTime = hopDuration }
        }
    }

    func pauseIfRunning() { if phase == .running { phase = .paused } }

    private func reset() {
        lane = 1
        hop = 0
        hopTime = 0
        obstacles.removeAll()
        score = 0
        speed = baseSpeed
        spawnCountdown = 0.9
    }

    // MARK: simulation

    func step(dt rawDt: CGFloat, arenaHeight: CGFloat) {
        guard phase == .running else { return }
        let dt = min(rawDt, 1.0 / 30.0)

        speed = min(maxSpeed, baseSpeed + CGFloat(score) * 1.3)
        score += Double(dt) * 12

        if hopTime > 0 {
            hopTime -= dt
            let t = max(0, 1 - hopTime / hopDuration)   // 0 → 1 over the hop
            hop = CGFloat(sin(Double(t) * Double.pi))    // up then back down
            if hopTime <= 0 { hop = 0; hopTime = 0 }
        }

        for i in obstacles.indices { obstacles[i].y += speed * dt }
        obstacles.removeAll { $0.y > arenaHeight + 80 }

        spawnCountdown -= dt
        if spawnCountdown <= 0 {
            let l = Int.random(in: 0..<lanes)
            let kind: Kind = Bool.random() ? .low : .block
            obstacles.append(Obstacle(lane: l, y: -70, kind: kind))
            spawnCountdown = max(0.5, CGFloat.random(in: 0.75...1.45) * (baseSpeed / speed))
        }

        let playerY = arenaHeight - 88
        for o in obstacles where o.lane == lane {
            guard abs(o.y - playerY) < 32 else { continue }
            if o.kind == .low && hop > 0.35 { continue }   // hopped over it
            phase = .gameOver
            return
        }
    }
}
