//
//  TabBarView.swift
//  Docked
//
//  The module switcher. Lives as a header or a footer depending on where the
//  video sits, so it's never under the floating window.
//

import SwiftUI

struct TabBarView: View {
    @Environment(AppModel.self) private var app
    var isHeader: Bool
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ActivityModule.allCases) { mod in
                tab(mod)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.elevated)
        .overlay(alignment: isHeader ? .bottom : .top) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }

    private func tab(_ mod: ActivityModule) -> some View {
        let selected = app.module == mod
        return Button {
            withAnimation(.snappy(duration: 0.26)) { app.module = mod }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: mod.systemImage)
                Text(mod.title)
            }
            .font(.system(size: 13.5, weight: .bold))
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background {
                if selected {
                    Capsule().fill(Theme.accent.opacity(0.18))
                        .matchedGeometryEffect(id: "activePill", in: pill)
                }
            }
            .foregroundStyle(selected ? Theme.accent : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}
