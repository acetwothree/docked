//
//  DockedApp.swift
//  Docked
//
//  A single-screen "second screen" dashboard that reshapes itself around
//  iPhone's floating system video window (Picture in Picture).
//
//  The app never plays video itself — iOS owns the floating PiP window.
//  Docked's job is to keep every control, canvas and button *out from under*
//  wherever the user parks that window.
//

import SwiftUI

@main
struct DockedApp: App {

    // App-wide state. `@State` owns these @Observable models for the whole
    // process lifetime; child views read them via `@Environment`.
    @State private var appModel = AppModel()
    @State private var notes = NotesStore()
    @State private var doodle = DoodleStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .environment(notes)
                .environment(doodle)
                .tint(Theme.accent)
        }
    }
}
