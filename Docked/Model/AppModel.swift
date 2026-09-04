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
        static let tvTheme = "docked.tvTheme"
        static let tvBadge = "docked.tvBadge"
        static let tvStretch = "docked.tvStretch"
        static let favorites = "docked.favorites"
        static let module = "docked.module"
        static let theme = "docked.theme"
        static let haptics = "docked.haptics"
        static let onboarded = "docked.onboarded"
        static let debug = "docked.debugOverlay"
        static let highScore = "docked.runner.highScore"
        static let zenHigh = "docked.zen.highScore"
        static let pinned = "docked.pinnedModules"
        static let clickPen = "docked.clickPen.count"
        static let clickerMuted = "docked.clicker.muted"
        static let flowLevel = "docked.flow.level"
        static let popClears = "docked.pop.clears"
        static let tttGames = "docked.ttt.games"
        static let coins = "docked.casino.coins"
        static let coinsSeeded = "docked.casino.seeded"
    }

    static let startingCoins = 250

    /// The video always sits in the top band now — kept as a constant so the
    /// layout code keeps working without a UI toggle.
    let layout: VideoLayout = .top

    var tvTheme: TVTheme { didSet { store(tvTheme.rawValue, K.tvTheme) } }
    /// Etched "DOCKED · FREE APP" text on the console (nice for ad recordings).
    var tvBadge: Bool { didSet { store(tvBadge, K.tvBadge) } }
    /// Extra points added to the screen opening's height, so the user can drag
    /// the TV to wrap whatever the current video source's aspect ratio is.
    var tvStretch: CGFloat { didSet { store(Double(tvStretch), K.tvStretch) } }
    /// Starred activities, shown in a Favorites row at the top of the picker.
    var favorites: [ActivityModule] { didSet { store(favorites.map(\.rawValue), K.favorites) } }
    var module: ActivityModule { didSet { store(module.rawValue, K.module) } }
    var theme: AppTheme { didSet { store(theme.rawValue, K.theme) } }
    var haptics: Bool { didSet { store(haptics, K.haptics) } }
    var hasOnboarded: Bool { didSet { store(hasOnboarded, K.onboarded) } }
    var debugOverlay: Bool { didSet { store(debugOverlay, K.debug) } }
    var runnerHighScore: Int { didSet { store(runnerHighScore, K.highScore) } }
    var zenHighScore: Int { didSet { store(zenHighScore, K.zenHigh) } }

    // Lightweight per-activity progress trackers.
    var flowLevel: Int { didSet { store(flowLevel, K.flowLevel) } }
    var popClearCount: Int { didSet { store(popClearCount, K.popClears) } }
    var tttGames: Int { didSet { store(tttGames, K.tttGames) } }

    /// Play-money chips for the Gambling section. Seeded once; you can never
    /// end up stuck at zero (see `ensureChips`).
    var coins: Int { didSet { store(coins, K.coins) } }

    /// Lifetime tally for the Clicker fidget. Never reset — not even by
    /// "Clear all app data".
    var clickPenCount: Int { didSet { store(clickPenCount, K.clickPen) } }
    /// Mutes just the Clicker's click sound (haptic still fires).
    var clickerMuted: Bool { didSet { store(clickerMuted, K.clickerMuted) } }

    /// Which modules show directly in the bar; the rest live under "More".
    var pinnedModules: [ActivityModule] {
        didSet { store(pinnedModules.map(\.rawValue), K.pinned) }
    }

    static let defaultPinned: [ActivityModule] = [.doodle, .zen, .pop]

    init() {
        let d = UserDefaults.standard
        tvTheme = TVTheme(rawValue: d.string(forKey: K.tvTheme) ?? "") ?? .walnut
        tvBadge = (d.object(forKey: K.tvBadge) as? Bool) ?? true
        tvStretch = CGFloat(d.double(forKey: K.tvStretch))   // 0 when unset
        favorites = (d.array(forKey: K.favorites) as? [String] ?? []).compactMap(ActivityModule.init(rawValue:))
        module = ActivityModule(rawValue: d.string(forKey: K.module) ?? "") ?? .doodle
        theme = AppTheme(rawValue: d.string(forKey: K.theme) ?? "") ?? .system
        haptics = (d.object(forKey: K.haptics) as? Bool) ?? true
        hasOnboarded = d.bool(forKey: K.onboarded)
        debugOverlay = d.bool(forKey: K.debug)
        runnerHighScore = d.integer(forKey: K.highScore)
        zenHighScore = d.integer(forKey: K.zenHigh)
        clickPenCount = d.integer(forKey: K.clickPen)
        clickerMuted = d.bool(forKey: K.clickerMuted)
        flowLevel = d.integer(forKey: K.flowLevel)
        popClearCount = d.integer(forKey: K.popClears)
        tttGames = d.integer(forKey: K.tttGames)
        if d.bool(forKey: K.coinsSeeded) {
            coins = d.integer(forKey: K.coins)
        } else {
            coins = AppModel.startingCoins
            d.set(true, forKey: K.coinsSeeded)
        }
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

    // MARK: Casino chips

    /// Take a bet. Returns false if the balance can't cover it.
    @discardableResult
    func placeBet(_ amount: Int) -> Bool {
        guard amount > 0, coins >= amount else { return false }
        coins -= amount
        return true
    }

    func awardChips(_ amount: Int) {
        guard amount > 0 else { return }
        coins += amount
    }

    /// Guarantees you can always keep playing: if the balance falls below what
    /// a single minimum bet needs, quietly top it back up.
    func ensureChips(min minimum: Int) {
        if coins < minimum {
            coins = Swift.max(minimum * 10, 100)
        }
    }

    func toggleFavorite(_ mod: ActivityModule) {
        if let i = favorites.firstIndex(of: mod) {
            favorites.remove(at: i)
        } else {
            favorites.append(mod)
        }
    }
    func isFavorite(_ mod: ActivityModule) -> Bool { favorites.contains(mod) }

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
        flowLevel = 0
        popClearCount = 0
        tttGames = 0
        coins = AppModel.startingCoins
        module = .doodle
        favorites = []
        pinnedModules = AppModel.defaultPinned
        debugOverlay = false
        hasOnboarded = false
    }
}
