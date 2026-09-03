//
//  PiPSettings.swift
//  Docked
//
//  Best-effort jump to iOS Settings ▸ General, where "Picture in Picture"
//  lives. Apple's only public API (`openSettingsURLString`) lands on the app's
//  own settings pane, which has nothing to toggle — so we first try the
//  semi-documented `App-Prefs:` deep link and fall back to the app pane if the
//  system refuses it.
//

import UIKit

enum PiPSettings {
    static func open() {
        let fallback = URL(string: UIApplication.openSettingsURLString)

        guard let general = URL(string: "App-Prefs:root=General") else {
            if let fallback { UIApplication.shared.open(fallback) }
            return
        }

        UIApplication.shared.open(general, options: [:]) { ok in
            if !ok, let fallback { UIApplication.shared.open(fallback) }
        }
    }
}
