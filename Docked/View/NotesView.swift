//
//  NotesView.swift
//  Docked
//
//  The strip between the video and the tab bar is short, so the resting view
//  is a scrollable preview. Tapping it opens an editor that slides up over
//  this same area — which already sits below the TV layout — rather than a
//  separate full-screen sheet. `NotesStore.text` autosaves on every edit.
//

import SwiftUI

struct NotesView: View {
    @Environment(NotesStore.self) private var store
    /// Kept for call-site compatibility; the inline editor already lives
    /// below the TV so it isn't needed for placement.
    var topClearance: CGFloat
    @State private var editing = false
    @FocusState private var focused: Bool

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
            .onTapGesture { open() }

            footer

            if editing {
                editor
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .onChange(of: editing) { _, on in
            if on { DispatchQueue.main.async { focused = true } } else { focused = false }
        }
    }

    private func open() {
        withAnimation(.easeOut(duration: 0.22)) { editing = true }
    }
    private func close() {
        focused = false
        withAnimation(.easeOut(duration: 0.2)) { editing = false }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("\(wordCount) words")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button(action: close) {
                    Text("Done").font(.system(size: 14, weight: .heavy))
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(Theme.accent, in: Capsule())
                        .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.ultraThinMaterial)

            TextEditor(text: $store.text)
                .focused($focused)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
        }
        .background(Theme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.hairline))
        .shadow(color: .black.opacity(0.28), radius: 14, y: -2)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Text("\(wordCount) words · \(store.text.count) chars")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button { open() } label: {
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
