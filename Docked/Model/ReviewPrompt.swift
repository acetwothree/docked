//
//  ReviewPrompt.swift
//  Docked
//
//  A one-time "Enjoying Docked?" nudge. We only arm it after the player has
//  had a few genuinely good beats (a Maze Paint level cleared, a Color In
//  picture finished, a Rings solve, a new Block Tower best) — those are the
//  moments someone is most likely to leave five stars. RootView watches
//  `pending` and shows the alert the next time the player is back on the
//  home grid; whichever button they pick, we never ask again.
//

import SwiftUI

@Observable
final class ReviewPrompt {
    static let shared = ReviewPrompt()

    private let defaults = UserDefaults.standard
    private let kCount = "review.delightCount"
    private let kAsked = "review.asked"

    /// How many good beats it takes before we ask.
    private let threshold = 3

    /// Flipped on once we've crossed the threshold and haven't asked before.
    /// RootView binds an alert to this (only while the home grid is showing).
    var pending = false

    private init() {
        // If a prior session already armed it but never got to show the
        // alert (app closed on the menu), keep it armed.
        if !defaults.bool(forKey: kAsked),
           defaults.integer(forKey: kCount) >= threshold {
            pending = true
        }
    }

    /// Call on a real "nice!" moment. After `threshold` of them, arm the
    /// prompt — once, ever.
    func recordDelight() {
        guard !defaults.bool(forKey: kAsked) else { return }
        let n = defaults.integer(forKey: kCount) + 1
        defaults.set(n, forKey: kCount)
        if n >= threshold { pending = true }
    }

    /// The alert was shown (accepted or dismissed) — done forever.
    func markAsked() {
        pending = false
        defaults.set(true, forKey: kAsked)
    }

    /// Dev reset — wired into "Clear all app data".
    func reset() {
        pending = false
        defaults.removeObject(forKey: kCount)
        defaults.removeObject(forKey: kAsked)
    }
}
