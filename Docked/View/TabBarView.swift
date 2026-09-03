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
            .presentationDetents([.medium, .large])
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

struct ActivityPickerSheet: View {
    var current: ActivityModule
    var onPick: (ActivityModule) -> Void

    private let cols = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            Text("Choose an activity")
                .font(.system(size: 16, weight: .heavy))
                .padding(.top, 20).padding(.bottom, 14)

            ScrollView {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(ActivityModule.allCases) { mod in
                        let on = mod == current
                        Button { onPick(mod) } label: {
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
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
