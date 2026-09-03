//
//  TabBarView.swift
//  Docked
//
//  Pinned activity tabs fill the leading space; a compact "More" opens a
//  clean sheet with the rest. Layout / Settings sit snug at the trailing end.
//

import SwiftUI

struct TabBarView: View {
    @Environment(AppModel.self) private var app
    var isHeader: Bool
    var onLayout: () -> Void
    var onSettings: () -> Void

    @State private var showMore = false

    private var pinned: [ActivityModule] {
        var list = ActivityModule.allCases.filter { app.pinnedModules.contains($0) }
        if !list.contains(app.module) { list.append(app.module) }
        return list
    }
    private var overflow: [ActivityModule] {
        ActivityModule.allCases.filter { !pinned.contains($0) }
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(pinned) { mod in
                tab(mod.systemImage, mod.title, tint: app.module == mod, fills: true) {
                    withAnimation(.snappy(duration: 0.24)) { app.module = mod }
                }
            }
            if !overflow.isEmpty {
                tab("ellipsis", "More", tint: false, fills: false) { showMore = true }
            }

            Rectangle().fill(Theme.hairline).frame(width: 1, height: 32).padding(.horizontal, 3)

            tab("rectangle.on.rectangle.angled", "Layout", tint: app.isEditingLayout, fills: false, action: onLayout)
            tab("gearshape.fill", "Settings", tint: false, fills: false, action: onSettings)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.elevated)
        .overlay(alignment: isHeader ? .bottom : .top) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
        .sheet(isPresented: $showMore) {
            MoreSheet(
                hidden: overflow,
                onPick: { picked in
                    withAnimation(.snappy(duration: 0.24)) { app.module = picked }
                    showMore = false
                },
                onManage: { showMore = false; onSettings() }
            )
            .presentationDetents([.height(CGFloat(max(overflow.count, 1)) * 62 + 150)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.elevated)
        }
    }

    private func tab(_ icon: String, _ text: String, tint: Bool, fills: Bool,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 19))
                Text(text)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: fills ? .infinity : nil, minHeight: 52)
            .frame(width: fills ? nil : 52)
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
        .buttonStyle(.plain)
        .accessibilityLabel(text)
    }
}

/// The "More" sheet — bigger, cleaner rows than a stock context menu.
struct MoreSheet: View {
    var hidden: [ActivityModule]
    var onPick: (ActivityModule) -> Void
    var onManage: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("More activities")
                .font(.system(size: 16, weight: .heavy))
                .padding(.top, 20).padding(.bottom, 12)

            ForEach(hidden) { mod in
                Button { onPick(mod) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: mod.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(Theme.accent.opacity(0.16),
                                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .foregroundStyle(Theme.accent)
                        Text(mod.title).font(.system(size: 16, weight: .semibold))
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 22).padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button(action: onManage) {
                Label("Choose which tabs show", systemImage: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}
