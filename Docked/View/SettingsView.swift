//
//  SettingsView.swift
//  Docked
//
//  Everything-settings: layout, appearance, the Picture-in-Picture help
//  section, about, and an always-visible Developer section.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(NotesStore.self) private var notes
    @Environment(DoodleStore.self) private var doodle
    @Environment(\.dismiss) private var dismiss

    @State private var confirmWipe = false

    var body: some View {
        @Bindable var app = app

        NavigationStack {
            Form {
                // MARK: Video layout
                Section("Video layout") {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            app.isEditingLayout = true
                        }
                    } label: {
                        Label("Change video position", systemImage: "rectangle.on.rectangle.angled")
                    }
                    Toggle("Show “drag here” hint", isOn: $app.showHint)
                    LabeledContent("Currently", value: app.layout.label)
                }

                // MARK: Tabs
                Section {
                    ForEach(ActivityModule.allCases) { mod in
                        Toggle(isOn: Binding(
                            get: { app.pinnedModules.contains(mod) },
                            set: { _ in app.togglePinned(mod) }
                        )) {
                            Label(mod.title, systemImage: mod.systemImage)
                        }
                    }
                } header: {
                    Text("Tabs in the bar")
                } footer: {
                    Text("Modules you turn off here still work — they move into the “More” menu.")
                }

                // MARK: Appearance
                Section("Appearance") {
                    Picker("Theme", selection: $app.theme) {
                        ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Haptics", isOn: $app.haptics)
                }

                // MARK: Help
                Section("Help") {
                    NavigationLink {
                        PiPHelpView()
                    } label: {
                        Label("Picture-in-Picture guide", systemImage: "questionmark.circle")
                    }
                }

                // MARK: About
                Section("About") {
                    Text("Docked turns the space around your floating video into a doodle pad, a notepad and a quick game — and keeps every control out from under the video.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    LabeledContent("Version", value: "1.0 (1)")
                }

                // MARK: Developer
                Section {
                    Button {
                        app.resetOnboarding()
                        dismiss()
                    } label: {
                        Label("Replay onboarding", systemImage: "arrow.counterclockwise")
                    }
                    Button("Reset Runner best") { app.runnerHighScore = 0 }
                    Button("Reset Blocks best") { app.zenHighScore = 0 }
                    Toggle("Layout debug overlay", isOn: $app.debugOverlay)
                    Picker("Force layout", selection: $app.layout) {
                        ForEach(VideoLayout.allCases) { Text($0.label).tag($0) }
                    }
                    Button(role: .destructive) {
                        confirmWipe = true
                    } label: {
                        Label("Clear all app data", systemImage: "trash")
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Visible during development. Hide this section before shipping.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Clear all app data?", isPresented: $confirmWipe) {
                Button("Cancel", role: .cancel) {}
                Button("Erase", role: .destructive) {
                    app.clearAllData(notes: notes, doodle: doodle)
                    dismiss()
                }
            } message: {
                Text("Notes, doodle, high score and preferences will be reset, and onboarding will show again.")
            }
        }
    }
}
