//
//  ActivityDeckView.swift
//  Docked
//
//  The dashboard that lives inside the free half of the screen: a pill
//  segmented control (Doodle / Notes / Runner) plus a button to reopen the
//  layout picker, and the selected module below.
//

import SwiftUI

struct ActivityDeckView: View {
    @Environment(AppModel.self) private var app
    @Namespace private var pillNamespace

    /// Called when the user taps the layout button.
    var openSettings: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            header

            Group {
                switch app.activeModule {
                case .doodle: DoodlePadView()
                case .notes:  NotesView()
                case .game:   RunnerGameView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        }
        .padding(Theme.pagePadding)
    }

    private var header: some View {
        HStack(spacing: 8) {
            ForEach(ActivityModule.allCases) { module in
                pill(for: module)
            }

            Spacer(minLength: 4)

            Button(action: openSettings) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.title3)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Change video layout")
        }
    }

    private func pill(for module: ActivityModule) -> some View {
        let selected = app.activeModule == module
        return Button {
            withAnimation(.snappy(duration: 0.28)) { app.activeModule = module }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: module.systemImage)
                Text(module.title)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background {
                if selected {
                    Capsule()
                        .fill(Theme.accent.opacity(0.22))
                        .matchedGeometryEffect(id: "activePill", in: pillNamespace)
                }
            }
            .foregroundStyle(selected ? Theme.accent : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}
