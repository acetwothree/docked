//
//  NotesView.swift
//  Docked
//
//  A plain scratchpad. `TextEditor` bound straight to `NotesStore.text`,
//  which autosaves. Fills the content area; a slim footer floats at the base.
//

import SwiftUI

struct NotesView: View {
    @Environment(NotesStore.self) private var store
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var store = store

        ZStack(alignment: .bottom) {
            ZStack(alignment: .topLeading) {
                if store.text.isEmpty {
                    Text("Jot quotes, timestamps, show notes…")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $store.text)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                Button("Done") { focused = false }.font(.callout.weight(.semibold))
            }
            Button(role: .destructive) { store.text = "" } label: { Image(systemName: "trash") }
                .font(.system(size: 15, weight: .semibold))
                .disabled(store.text.isEmpty)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.ultraThinMaterial)
    }

    private var wordCount: Int {
        store.text.split { $0 == " " || $0.isNewline }.count
    }
}
