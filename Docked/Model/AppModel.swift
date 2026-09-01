//
//  AppModel.swift
//  Docked
//
//  App-wide state + preferences, all persisted to UserDefaults on change.
//

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system, dark, light
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

@Observable
final class AppModel {

    private enum K {
        static let layout = "docked.layout"
        static let module = "docked.module"
        static let hint = "docked.showHint"
        static let theme = "docked.theme"
        static let haptics = "docked.haptics"
        static let onboarded = "docked.onboarded"
        static let debug = "docked.debugOverlay"
        static let highScore = "docked.runner.highScore"
    }

    var layout: VideoLayout { didSet { store(layout.rawValue, K.layout) } }
    var module: ActivityModule { didSet { store(module.rawValue, K.module) } }
    var showHint: Bool { didSet { store(showHint, K.hint) } }
    var theme: AppTheme { didSet { store(theme.rawValue, K.theme) } }
    var haptics: Bool { didSet { store(haptics, K.haptics) } }
    var hasOnboarded: Bool { didSet { store(hasOnboarded, K.onboarded) } }
    var debugOverlay: Bool { didSet { store(debugOverlay, K.debug) } }
    var runnerHighScore: Int { didSet { store(runnerHighScore, K.highScore) } }

    /// Transient — true while the tap-to-place layout editor is open.
    var isEditingLayout = false

    init() {
        let d = UserDefaults.standard
        layout = VideoLayout(rawValue: d.string(forKey: K.layout) ?? "") ?? .top
        module = ActivityModule(rawValue: d.string(forKey: K.module) ?? "") ?? .doodle
        showHint = (d.object(forKey: K.hint) as? Bool) ?? true
        theme = AppTheme(rawValue: d.string(forKey: K.theme) ?? "") ?? .system
        haptics = (d.object(forKey: K.haptics) as? Bool) ?? true
        hasOnboarded = d.bool(forKey: K.onboarded)
        debugOverlay = d.bool(forKey: K.debug)
        runnerHighScore = d.integer(forKey: K.highScore)
    }

    private func store(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    // MARK: Developer actions

    func resetOnboarding() { hasOnboarded = false }

    func clearAllData(notes: NotesStore, doodle: DoodleStore) {
        notes.text = ""
        doodle.clear()
        runnerHighScore = 0
        layout = .top
        module = .doodle
        showHint = true
        debugOverlay = false
        hasOnboarded = false
    }
}
