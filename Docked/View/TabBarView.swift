//
//  TabBarView.swift
//  Docked
//
//  Pinned modules + a "More" menu for the rest, then the two labelled
//  controls (Layout, Settings). Header or footer depending on where the
//  video sits.
//

import SwiftUI

struct TabBarView: View {
    @Environment(AppModel.self) private var app
    var isHeader: Bool
    var onLayout: () -> Void
    var onSettings: () -> Void

    private var pinned: [ActivityModule] {
        var list = ActivityModule.allCases.filter { app.pinnedModules.contains($0) }
        if !list.contains(app.module) { list.insert(app.module, at: 0) }
        return list
    }
    private var overflow: [ActivityModule] {
        ActivityModule.allCases.filter { !pinned.contains($0) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(pinned) { mod in
                modeButton(mod)
            }
            if !overflow.isEmpty {
                Menu {
                    ForEach(overflow) { mod in
                        Button {
                            withAnimation(.snappy(duration: 0.24)) { app.module = mod }
                        } label: {
                            Label(mod.title, systemImage: mod.systemImage)
                        }
                    }
                } label: {
                    cell(icon: "ellipsis.circle.fill", text: "More", tint: false)
                }
            }

            Rectangle().fill(Theme.hairline).frame(width: 1, height: 34).padding(.horizontal, 3)

            iconButton("rectangle.on.rectangle.angled", "Layout", active: app.isEditingLayout, action: onLayout)
            iconButton("gearshape.fill", "Settings", active: false, action: onSettings)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.elevated)
        .overlay(alignment: isHeader ? .bottom : .top) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }

    private func modeButton(_ mod: ActivityModule) -> some View {
        let selected = app.module == mod
        return Button {
            withAnimation(.snappy(duration: 0.24)) { app.module = mod }
        } label: {
            cell(icon: mod.systemImage, text: mod.title, tint: selected)
        }
        .buttonStyle(.plain)
    }

    private func iconButton(_ name: String, _ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            cell(icon: name, text: label, tint: active)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func cell(icon: String, text: String, tint: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 19))
            Text(text)
                .font(.system(size: 9, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .padding(.vertical, 4)
        .background {
            if tint {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.accent.opacity(0.16))
            }
        }
        .foregroundStyle(tint ? Theme.accent : Color.secondary)
        .contentShape(Rectangle())
    }
}
