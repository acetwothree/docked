//
//  NotesView.swift
//  Docked
//
//  A scratchpad. The strip between the video and the tab bar is too short to
//  edit in with the keyboard up, so the inline view is a scrollable preview
//  and editing happens in a full-height sheet. `NotesStore.text` autosaves.
//

import SwiftUI

struct NotesView: View {
    @Environment(NotesStore.self) private var store
    @State private var editing = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                Text(store.text.isEmpty ? "Jot quotes, timestamps, show notes…" : store.text)
                    .font(.body)
                    .foregroundStyle(store.text.isEmpty ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 48)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { editing = true }

            footer
        }
        .sheet(isPresented: $editing) {
            NotesEditorSheet(store: store)
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Text("\(wordCount) words · \(store.text.count) chars")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button { editing = true } label: {
                Label("Edit", systemImage: "pencil").font(.system(size: 14, weight: .semibold))
            }
            ShareLink(item: store.text) {
                Image(systemName: "square.and.arrow.up")
            }
            .font(.system(size: 15, weight: .semibold))
            .disabled(store.text.isEmpty)

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

private struct NotesEditorSheet: View {
    @Bindable var store: NotesStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: $store.text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .background(Theme.backdrop)
                .padding(.horizontal, 10)
                .navigationTitle("Notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Text("\(wordCount) words").font(.footnote).foregroundStyle(.secondary)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }.fontWeight(.semibold)
                    }
                }
        }
    }

    private var wordCount: Int {
        store.text.split { $0 == " " || $0.isNewline }.count
    }
}
