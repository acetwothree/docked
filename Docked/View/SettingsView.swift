//
//  SettingsView.swift
//  Docked
//
//  Custom card layout (not a stock grouped Form). Ordered most-used first:
//  Picture-in-Picture help, appearance, video layout, about, developer.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(NotesStore.self) private var notes
    @Environment(DoodleStore.self) private var doodle
    @Environment(\.dismiss) private var dismiss

    @State private var confirmWipe = false
    @State private var showDev = false

    var body: some View {
        @Bindable var app = app

        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {

                    card("Picture-in-Picture") {
                        NavigationLink { PiPHelpView() } label: {
                            row(icon: "questionmark.circle.fill", "How to use it",
                                trailing: { chevron })
                        }
                        divider
                        row(icon: "rectangle.on.rectangle.angled", "Video position") {
                            Picker("", selection: $app.layout) {
                                Text("Top").tag(VideoLayout.top)
                                Text("Bottom").tag(VideoLayout.bottom)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 150)
                        }
                        divider
                        row(icon: "tv", "Show “drag here” hint") {
                            Toggle("", isOn: $app.showHint).labelsHidden()
                        }
                    }

                    card("Appearance") {
                        row(icon: "circle.lefthalf.filled", "Theme") {
                            Picker("", selection: $app.theme) {
                                ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 190)
                        }
                        divider
                        row(icon: "hand.tap.fill", "Haptics") {
                            Toggle("", isOn: $app.haptics).labelsHidden()
                        }
                    }

                    card("About") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Docked turns the space around your floating video into a doodle pad, notepad and a few quick games — and keeps every control out from under the video.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("Version").font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text("1.0").font(.system(size: 13)).foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                    }

                    DisclosureGroup(isExpanded: $showDev) {
                        VStack(spacing: 0) {
                            VStack(spacing: 0) {
                                devButton("Replay onboarding", "arrow.counterclockwise") {
                                    app.hasOnboarded = false
                                    dismiss()
                                }
                                divider
                                devButton("Reset Runner best", "gauge") { app.runnerHighScore = 0 }
                                divider
                                devButton("Reset Blocks best", "gauge") { app.zenHighScore = 0 }
                            }
                            divider
                            VStack(spacing: 0) {
                                row(icon: "ladybug.fill", "Layout debug overlay") {
                                    Toggle("", isOn: $app.debugOverlay).labelsHidden()
                                }
                                divider
                                devButton("Clear all app data", "trash", destructive: true) {
                                    confirmWipe = true
                                }
                            }
                        }
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline))
                        .padding(.top, 8)
                    } label: {
                        Text("DEVELOPER")
                            .font(.system(size: 11, weight: .heavy)).tracking(0.8)
                            .foregroundStyle(.secondary)
                    }
                    .tint(.secondary)
                }
                .padding(18)
            }
            .background(Theme.backdrop.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .tint(Theme.accent)
            .alert("Clear all app data?", isPresented: $confirmWipe) {
                Button("Cancel", role: .cancel) {}
                Button("Erase", role: .destructive) {
                    app.clearAllData(notes: notes, doodle: doodle)
                    dismiss()
                }
            } message: {
                Text("Notes, doodle, scores and preferences reset, and onboarding shows again.")
            }
        }
    }

    // MARK: pieces

    private var chevron: some View {
        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(.tertiary)
    }
    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 46)
    }

    private func card<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy)).tracking(0.8)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline))
        }
    }

    private func row<T: View>(icon: String, _ label: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(label).font(.system(size: 15))
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .frame(minHeight: 46)
    }

    private func devButton(_ label: String, _ icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            row(icon: icon, label) { EmptyView() }
                .foregroundStyle(destructive ? Color.red : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
