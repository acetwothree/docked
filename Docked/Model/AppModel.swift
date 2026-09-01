//
//  AppModel.swift
//  Docked
//
//  App-wide preferences: which video layout is active, whether the drop-zone
//  guide is shown, the selected activity module, and the runner high score.
//  Everything here persists to `UserDefaults` the moment it changes.
//

import SwiftUI

@Observable
final class AppModel {

    private enum Keys {
        static let layout = "docked.layout"
        static let guide = "docked.showGuide"
        static let onboarded = "docked.onboarded"
        static let module = "docked.module"
        static let highScore = "docked.runner.highScore"
    }

    /// Where the user has parked their floating video.
    var selectedLayout: VideoLayout {
        didSet { UserDefaults.standard.set(selectedLayout.rawValue, forKey: Keys.layout) }
    }

    /// Show the dashed "television frame" guide.
    var showGuide: Bool {
        didSet { UserDefaults.standard.set(showGuide, forKey: Keys.guide) }
    }

    /// Has the first-run layout sheet been dismissed at least once?
    var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: Keys.onboarded) }
    }

    /// Currently visible activity.
    var activeModule: ActivityModule {
        didSet { UserDefaults.standard.set(activeModule.rawValue, forKey: Keys.module) }
    }

    /// Best distance reached in the runner mini-game.
    var runnerHighScore: Int {
        didSet { UserDefaults.standard.set(runnerHighScore, forKey: Keys.highScore) }
    }

    init() {
        let defaults = UserDefaults.standard
        selectedLayout = VideoLayout(rawValue: defaults.string(forKey: Keys.layout) ?? "") ?? .largeTop
        showGuide = (defaults.object(forKey: Keys.guide) as? Bool) ?? true
        hasOnboarded = defaults.bool(forKey: Keys.onboarded)
        activeModule = ActivityModule(rawValue: defaults.string(forKey: Keys.module) ?? "") ?? .doodle
        runnerHighScore = defaults.integer(forKey: Keys.highScore)
    }
}

/// The three "second screen" activities.
enum ActivityModule: String, CaseIterable, Identifiable {
    case doodle
    case notes
    case game

    var id: String { rawValue }

    var title: String {
        switch self {
        case .doodle: return "Doodle"
        case .notes: return "Notes"
        case .game: return "Runner"
        }
    }

    var systemImage: String {
        switch self {
        case .doodle: return "scribble.variable"
        case .notes: return "note.text"
        case .game: return "gamecontroller"
        }
    }
}
