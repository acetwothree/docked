//
//  TabBarView.swift
//  Docked
//
//  The module switcher plus the two always-there controls (move-video and
//  settings). Lives as a header or a footer depending on where the video
//  sits, so it's never under the floating window. The control pair sits at
//  the trailing end in every layout — the only two things there, grouped so
//  it's obvious what they do.
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
        .padding(.horizontal, 8)
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
            VStack(spacing: 2) {
                Image(systemName: mod.systemImage).font(.system(size: 17))
                Text(mod.title).font(.system(size: 8.5, weight: .bold))
            }
            .frame(minWidth: 44)
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.accent.opacity(0.16))
                }
            }
            .foregroundStyle(selected ? Theme.accent : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    private var controlPair: some View {
        HStack(spacing: 0) {
            controlButton("rectangle.on.rectangle.angled", "Move video", action: onLayout)
            Rectangle().fill(Theme.hairline).frame(width: 1, height: 24)
            controlButton("gearshape.fill", "Settings", action: onSettings)
        }
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.hairline)
        }
    }

    private func controlButton(_ name: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 40, height: 40)
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
