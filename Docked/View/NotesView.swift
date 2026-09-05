//
//  NotesView.swift
//  Docked
//
//  The strip between the video and the tab bar is too short to type in with
//  the keyboard up, so the inline view is a scrollable preview and editing
//  happens in a full-height sheet. `NotesStore.text` autosaves on every edit.
//

import SwiftUI

struct NotesView: View {
    @Environment(NotesStore.self) private var store
    /// How far down the true screen the TV/video zone reaches — the editor
    /// sheet uses this exact value so it can never sit under the video,
    /// wherever the user actually parks it.
    var topClearance: CGFloat
    @State private var editing = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                Text(store.text.isEmpty ? "Tap to jot quotes, timestamps, notes…" : store.text)
                    .font(.body)
                    .foregroundStyle(store.text.isEmpty ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 48)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { editing = true }

            footer
        }
        .sheet(isPresented: $editing) {
            NotesEditorSheet(store: store, topClearance: topClearance)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackgroundInteraction(.enabled)
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Text("\(wordCount) words · \(store.text.count) chars")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button { editing = true } label: {
                Label("Edit", systemImage: "pencil").font(.system(size: 14, weight: .semibold))
            }
            ShareLink(item: store.text) { Image(systemName: "square.and.arrow.up") }
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
    var topClearance: CGFloat
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        GeometryReader { geo in
            // Start the writing area exactly below the TV/video zone (plus a
            // little breathing room) — never a guess, so the video can never
            // cover the text you're typing. Clamped so a heavily stretched TV
            // still leaves a usable typing band.
            let topInset = min(max(64, topClearance + 20), geo.size.height * 0.7)

            ZStack(alignment: .top) {
                Theme.backdrop.ignoresSafeArea()

                TextEditor(text: $store.text)
                    .focused($focused)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.top, topInset)
                    .padding(.bottom, 8)

                HStack(spacing: 10) {
                    Text("\(wordCount) words")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button { dismiss() } label: {
                        Text("Done").font(.system(size: 14, weight: .heavy))
                            .padding(.horizontal, 16).padding(.vertical, 7)
                            .background(Theme.accent, in: Capsule())
                            .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial)

                Text("Text starts here, clear of the floating video. Drag the video aside if it still overlaps.")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.top, topInset - 22)
                    .allowsHitTesting(false)
            }
        }
        .onAppear { focused = true }
    }

    private var wordCount: Int {
        store.text.split { $0 == " " || $0.isNewline }.count
    }
}
