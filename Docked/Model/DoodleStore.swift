//
//  DoodleStore.swift
//  Docked
//
//  Holds the doodle as a list of strokes and persists it to a JSON file in
//  Documents. Points are stored NORMALISED (0...1) to the canvas, so a
//  doodle keeps its shape when the layout — and therefore the canvas size —
//  changes underneath it.
//

import SwiftUI

/// One freehand stroke.
struct DoodleStroke: Identifiable, Codable {
    var id = UUID()
    var points: [CGPoint]   // normalised 0...1
    var colorHex: String
    var width: Double
}

@Observable
final class DoodleStore {

    private(set) var strokes: [DoodleStroke] = []

    /// Debounce handle for background saves.
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    private var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("doodle.json")
    }

    init() {
        load()
    }

    // MARK: Mutations

    func append(_ stroke: DoodleStroke) {
        strokes.append(stroke)
        scheduleSave()
    }

    func undo() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        scheduleSave()
    }

    func clear() {
        guard !strokes.isEmpty else { return }
        strokes.removeAll()
        scheduleSave()
    }

    // MARK: Persistence

    private func load() {
        guard
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([DoodleStroke].self, from: data)
        else { return }
        strokes = decoded
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = strokes
        let url = fileURL
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Flush immediately — called when the app is backgrounded.
    func saveNow() {
        saveTask?.cancel()
        guard let data = try? JSONEncoder().encode(strokes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
