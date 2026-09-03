//
//  TabBarView.swift
//  Docked
//
//  One activity chooser (current activity + a grid picker) plus Layout and
//  Settings. Scales to any number of activities without crowding.
//

import SwiftUI

struct TabBarView: View {
    @Environment(AppModel.self) private var app
    var isHeader: Bool
    var onLayout: () -> Void
    var onSettings: () -> Void

    @State private var showPicker = false

    var body: some View {
        HStack(spacing: 8) {
            Button { showPicker = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: app.module.systemImage).font(.system(size: 17, weight: .semibold))
                    Text(app.module.title).font(.system(size: 15, weight: .heavy))
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Theme.accent.opacity(0.16), in: Capsule())
                .foregroundStyle(Theme.accent)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            control("rectangle.on.rectangle.angled", "Layout", active: app.isEditingLayout, action: onLayout)
            control("gearshape.fill", "Settings", active: false, action: onSettings)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.elevated)
        .overlay(alignment: isHeader ? .bottom : .top) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
        .sheet(isPresented: $showPicker) {
            ActivityPickerSheet(current: app.module) { picked in
                withAnimation(.snappy(duration: 0.24)) { app.module = picked }
                showPicker = false
            }
            .presentationDetents(app.layout == .bottom ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.elevated)
        }
    }

    private func control(_ icon: String, _ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 18))
                Text(label).font(.system(size: 8.5, weight: .bold))
            }
            .frame(width: 52, height: 46)
            .foregroundStyle(active ? Theme.accent : Color.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// A not-yet-built activity, shown greyed with a "SOON" tag so the roadmap
/// is visible inside the picker.
private struct ComingSoon: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let category: ActivityCategory
}

struct ActivityPickerSheet: View {
    var current: ActivityModule
    var onPick: (ActivityModule) -> Void

    private let cols = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    private let soon: [ComingSoon] = [
        .init(title: "Journal",  systemImage: "book.closed.fill",     category: .create),
        .init(title: "Mind Map", systemImage: "brain.head.profile",   category: .create),
        .init(title: "2048",     systemImage: "square.grid.2x2.fill", category: .play),
        .init(title: "Solitaire", systemImage: "suit.spade.fill",     category: .play),
        .init(title: "Timer",    systemImage: "timer",                    category: .focus),
        .init(title: "Breathe",  systemImage: "wind",                     category: .focus),
        .init(title: "Pomodoro", systemImage: "hourglass",               category: .focus),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Text("Choose an activity")
                .font(.system(size: 16, weight: .heavy))
                .padding(.top, 20).padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(ActivityCategory.allCases) { cat in
                        section(cat)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func section(_ cat: ActivityCategory) -> some View {
        let mods = ActivityModule.allCases.filter { $0.category == cat }
        let placeholders = soon.filter { $0.category == cat }

        VStack(alignment: .leading, spacing: 10) {
            Text(cat.rawValue.uppercased())
                .font(.system(size: 11, weight: .heavy)).tracking(1)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(mods) { mod in
                    liveCard(mod)
                }
                ForEach(placeholders) { item in
                    soonCard(item)
                }
            }
        }
    }

    private func liveCard(_ mod: ActivityModule) -> some View {
        let on = mod == current
        return Button { onPick(mod) } label: {
            VStack(spacing: 8) {
                Image(systemName: mod.systemImage)
                    .font(.system(size: 26, weight: .semibold))
                Text(mod.title).font(.system(size: 13, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .background(on ? AnyShapeStyle(Theme.accent.opacity(0.9)) : AnyShapeStyle(Theme.paper),
                       in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(on ? Color.clear : Theme.hairline)
            }
            .foregroundStyle(on ? Color(red: 0.11, green: 0.08, blue: 0.02) : Color.primary)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func soonCard(_ item: ComingSoon) -> some View {
        VStack(spacing: 8) {
            Image(systemName: item.systemImage)
                .font(.system(size: 26, weight: .semibold))
            Text(item.title).font(.system(size: 13, weight: .bold))
            Text("SOON")
                .font(.system(size: 8, weight: .heavy)).tracking(1.5)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Theme.hairline, in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .background(Theme.paper.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .foregroundStyle(.tertiary)
        .accessibilityLabel("\(item.title), coming soon")
    }
}
