//
//  ReviewPrompt.swift
//  Docked
//
//  A one-time "Enjoying Docked?" nudge. It only arms once the player has
//  BOTH had a few genuinely good beats (a Maze Paint level cleared, a Color
//  In picture finished, a Rings solve, a strong Block Tower run) AND spent
//  at least five minutes actually inside games — so it never fires on a
//  brand-new user who just poked around. RootView watches `pending` and
//  shows the alert the next time the player is back on the home grid;
//  whichever button they pick, we never ask again.
//

import SwiftUI

@Observable
final class ReviewPrompt {
    static let shared = ReviewPrompt()

    private let defaults = UserDefaults.standard
    private let kCount = "review.delightCount"
    private let kAsked = "review.asked"
    private let kPlay  = "review.playSeconds"

    private let winsNeeded = 3
    private let playNeeded: Double = 300        // 5 minutes inside games

    /// RootView binds an alert to this (only while the home grid is showing).
    var pending = false

    private var sessionStart: Date?

    private init() {
        maybeArm()
    }

    // MARK: play-time accounting (fed by RootView)

    func playSessionStarted() {
        sessionStart = Date()
    }

    func playSessionEnded() {
        if let s = sessionStart {
            let add = min(max(0, Date().timeIntervalSince(s)), 3600)
            defaults.set(defaults.double(forKey: kPlay) + add, forKey: kPlay)
            sessionStart = nil
        }
        maybeArm()
    }

    // MARK: delight

    /// Call on a real "nice!" moment.
    func recordDelight() {
        guard !defaults.bool(forKey: kAsked) else { return }
        defaults.set(defaults.integer(forKey: kCount) + 1, forKey: kCount)
        maybeArm()
    }

    // MARK: arming

    private func maybeArm() {
        guard !pending, !defaults.bool(forKey: kAsked) else { return }
        if defaults.integer(forKey: kCount) >= winsNeeded,
           defaults.double(forKey: kPlay) >= playNeeded {
            pending = true
        }
    }

    /// The alert was shown (accepted or dismissed) — done forever.
    func markAsked() {
        pending = false
        defaults.set(true, forKey: kAsked)
    }

    /// Dev reset — wired into "Clear all app data".
    func reset() {
        pending = false
        sessionStart = nil
        [kCount, kAsked, kPlay].forEach { defaults.removeObject(forKey: $0) }
    }
}
