//
//  PiPSettings.swift
//  Docked
//
//  Best-effort jump to iOS Settings ▸ General ▸ Picture in Picture. Apple's
//  only public API (`openSettingsURLString`) lands on the app's own pane, so we
//  try the semi-documented `App-Prefs:` deep links first and fall back through
//  progressively less specific targets.
//

import UIKit

enum PiPSettings {
    static func open() {
        let candidates = [
            "App-Prefs:root=General&path=PICTURE_IN_PICTURE",
            "App-Prefs:root=General&path=PICTURE-IN-PICTURE",
            "App-Prefs:root=General",
            "App-Prefs:",
            UIApplication.openSettingsURLString,
        ]
        tryNext(candidates, 0)
    }

    private static func tryNext(_ list: [String], _ i: Int) {
        guard i < list.count, let url = URL(string: list[i]) else { return }
        UIApplication.shared.open(url, options: [:]) { ok in
            if !ok { tryNext(list, i + 1) }
        }
    }
}
