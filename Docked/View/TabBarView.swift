//
//  TabBarView.swift
//  Docked
//
//  The module switcher plus the two always-there controls (move-video and
//  settings). Header or footer depending on where the video sits. The
//  control pair sits at the trailing end in every layout.
//

import SwiftUI

struct TabBarView: View {
    @Environment(AppModel.self) private var app
    var isHeader: Bool
    var onLayout: () -> Void
    var onSettings: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ActivityModule.allCases) { mod in
                modeButton(mod)
            }
            Spacer(minLength: 4)
            controlPair
        }
        .padding(.horizontal, 6)
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
            VStack(spacing: 3) {
                Image(systemName: mod.systemImage).font(.system(size: 20))
                Text(mod.title).font(.system(size: 10, weight: .bold))
            }
            .frame(minWidth: 54, minHeight: 48)
            .padding(.vertical, 5)
            .padding(.horizontal, 4)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.accent.opacity(0.16))
                }
            }
            .foregroundStyle(selected ? Theme.accent : Color.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var controlPair: some View {
        HStack(spacing: 0) {
            controlButton("rectangle.on.rectangle.angled", "Move video", action: onLayout)
            Rectangle().fill(Theme.hairline).frame(width: 1, height: 30)
            controlButton("gearshape.fill", "Settings", action: onSettings)
        }
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline)
        }
    }

    private func controlButton(_ name: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 50, height: 50)
                .foregroundStyle(.primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
