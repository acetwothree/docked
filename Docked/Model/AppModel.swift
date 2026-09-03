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
        static let zenHigh = "docked.zen.highScore"
        static let pinned = "docked.pinnedModules"
        static let clickPen = "docked.clickPen.count"
    }

    var layout: VideoLayout { didSet { store(layout.rawValue, K.layout) } }
    var module: ActivityModule { didSet { store(module.rawValue, K.module) } }
    var showHint: Bool { didSet { store(showHint, K.hint) } }
    var theme: AppTheme { didSet { store(theme.rawValue, K.theme) } }
    var haptics: Bool { didSet { store(haptics, K.haptics) } }
    var hasOnboarded: Bool { didSet { store(hasOnboarded, K.onboarded) } }
    var debugOverlay: Bool { didSet { store(debugOverlay, K.debug) } }
    var runnerHighScore: Int { didSet { store(runnerHighScore, K.highScore) } }
    var zenHighScore: Int { didSet { store(zenHighScore, K.zenHigh) } }

    /// Lifetime tally for the Clicker fidget. Never reset — not even by
    /// "Clear all app data".
    var clickPenCount: Int { didSet { store(clickPenCount, K.clickPen) } }

    /// Which modules show directly in the bar; the rest live under "More".
    var pinnedModules: [ActivityModule] {
        didSet { store(pinnedModules.map(\.rawValue), K.pinned) }
    }

    static let defaultPinned: [ActivityModule] = [.doodle, .zen, .pop]

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
        zenHighScore = d.integer(forKey: K.zenHigh)
        clickPenCount = d.integer(forKey: K.clickPen)
        if let raw = d.array(forKey: K.pinned) as? [String] {
            let restored = raw.compactMap(ActivityModule.init(rawValue:))
            pinnedModules = restored.isEmpty ? AppModel.defaultPinned : restored
        } else {
            pinnedModules = AppModel.defaultPinned
        }
    }

    func togglePinned(_ mod: ActivityModule) {
        if let i = pinnedModules.firstIndex(of: mod) {
            if pinnedModules.count > 1 { pinnedModules.remove(at: i) }
        } else {
            pinnedModules.append(mod)
        }
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
        zenHighScore = 0
        layout = .top
        module = .doodle
        pinnedModules = AppModel.defaultPinned
        showHint = true
        debugOverlay = false
        hasOnboarded = false
    }
}
