//
//  NotesStore.swift
//  Docked
//
//  A one-field store for the scratchpad text. Saved to UserDefaults on every
//  edit — small enough that debouncing isn't worth the complexity.
//

import SwiftUI

@Observable
final class NotesStore {
    private let key = "docked.notes.text"

    var text: String {
        didSet { UserDefaults.standard.set(text, forKey: key) }
    }

    init() {
        text = UserDefaults.standard.string(forKey: key) ?? ""
    }
}
