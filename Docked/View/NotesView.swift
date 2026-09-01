//
//  NotesView.swift
//  Docked
//
//  A plain scratchpad. `TextEditor` bound straight to `NotesStore.text`,
//  which autosaves. A placeholder shows through while empty.
//

import SwiftUI

struct NotesView: View {
    @Environment(NotesStore.self) private var store
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.paper)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                            .strokeBorder(Theme.ink.opacity(0.08))
                    }

                if store.text.isEmpty {
                    Text("Jot down quotes, timestamps, show notes…")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $store.text)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .padding(12)
            }
            .frame(maxHeight: .infinity)

            footer
        }
    }

    private var footer: some View {
        HStack {
            Text("\(wordCount) words · \(store.text.count) chars")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if focused {
                Button("Done") { focused = false }
                    .font(.callout.weight(.semibold))
            }

            Button(role: .destructive) {
                store.text = ""
            } label: {
                Image(systemName: "trash")
            }
            .font(.system(size: 16, weight: .semibold))
            .disabled(store.text.isEmpty)
        }
        .padding(.horizontal, 2)
    }

    private var wordCount: Int {
        store.text.split { $0 == " " || $0.isNewline }.count
    }
}
