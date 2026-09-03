//
//  TabBarView.swift
//  Docked
//
//  The activity chooser (current activity + a categorised picker panel) plus
//  a Layout toggle (flips the video top ⇄ bottom in one tap) and Settings.
//

import SwiftUI

struct TabBarView: View {
    @Environment(AppModel.self) private var app
    var isHeader: Bool
    var onLayout: () -> Void
    var onPicker: () -> Void
    var onSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onPicker) {
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

            control(app.layout.moveIcon, "Move", action: onLayout)
            control("gearshape.fill", "Settings", action: onSettings)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.elevated)
        .overlay(alignment: isHeader ? .bottom : .top) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }

    private func control(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 18))
                Text(label).font(.system(size: 8.5, weight: .bold))
            }
            .frame(width: 52, height: 46)
            .foregroundStyle(Color.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Activity picker panel

/// A not-yet-built activity, shown greyed with a "SOON" tag so the roadmap
/// is visible inside the picker.
private struct ComingSoon: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let category: ActivityCategory
}

/// Categorised activity picker. Rendered as an overlay sized to the module
/// area (never under the video or the tab bar), and closed by a tap outside,
/// a tap on the grab handle, or one swipe toward the tab-bar edge.
struct ActivityPickerPanel: View {
    var solved: SolvedLayout
    var current: ActivityModule
    var onPick: (ActivityModule) -> Void
    var onClose: () -> Void

    @State private var dragOffset: CGFloat = 0

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private let soon: [ComingSoon] = [
        // create — one extra slot
        .init(title: "Mind Map",  systemImage: "brain",                     category: .create),
        // play — three extra slots
        .init(title: "2048",      systemImage: "square.grid.3x3.fill",      category: .play),
        .init(title: "Solitaire", systemImage: "suit.spade.fill",          category: .play),
        .init(title: "Mahjong",   systemImage: "rectangle.grid.2x2.fill",  category: .play),
        // fidget — five extra slots
        .init(title: "Spinner",     systemImage: "fan.fill",               category: .fidget),
        .init(title: "Worry Beads", systemImage: "circle.grid.3x3.fill",   category: .fidget),
        .init(title: "Zen Sand",    systemImage: "wind",                   category: .fidget),
        .init(title: "Click Pen",   systemImage: "pencil.tip",             category: .fidget),
        .init(title: "Fidget Cube", systemImage: "cube.fill",              category: .fidget),
    ]

    private var closeToBottom: Bool { solved.occupiesTop }   // tab bar is the footer

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
                .transition(.opacity)

            panel
                .frame(width: solved.content.width, height: solved.content.height)
                .position(x: solved.content.midX, y: solved.content.midY)
                .offset(y: dragOffset)
                .transition(.move(edge: closeToBottom ? .bottom : .top).combined(with: .opacity))
        }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            if !closeToBottom { handle }

            Text("Choose an activity")
                .font(.system(size: 15, weight: .heavy))
                .padding(.top, closeToBottom ? 14 : 2)
                .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(ActivityCategory.allCases) { section($0) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            if closeToBottom { handle }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.hairline))
        .contentShape(Rectangle())
        .gesture(closeDrag)
    }

    private var handle: some View {
        Capsule().fill(Color.secondary.opacity(0.5))
            .frame(width: 40, height: 5)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: onClose)
    }

    private var closeDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                dragOffset = closeToBottom ? max(0, v.translation.height) : min(0, v.translation.height)
            }
            .onEnded { v in
                let past = closeToBottom ? v.translation.height > 60 : v.translation.height < -60
                if past { onClose() }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragOffset = 0 }
            }
    }

    @ViewBuilder
    private func section(_ cat: ActivityCategory) -> some View {
        let mods = ActivityModule.allCases.filter { $0.category == cat }
        let placeholders = soon.filter { $0.category == cat }

        VStack(alignment: .leading, spacing: 8) {
            Text(cat.rawValue.uppercased())
                .font(.system(size: 11, weight: .heavy)).tracking(1)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(mods) { liveCard($0) }
                ForEach(placeholders) { soonCard($0) }
            }
        }
    }

    private func liveCard(_ mod: ActivityModule) -> some View {
        let on = mod == current
        return Button { onPick(mod) } label: {
            VStack(spacing: 7) {
                Image(systemName: mod.systemImage).font(.system(size: 23, weight: .semibold))
                Text(mod.title).font(.system(size: 12.5, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .background(on ? AnyShapeStyle(Theme.accent.opacity(0.9)) : AnyShapeStyle(Theme.paper),
                       in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(on ? Color.clear : Theme.hairline)
            }
            .foregroundStyle(on ? Color(red: 0.11, green: 0.08, blue: 0.02) : Color.primary)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func soonCard(_ item: ComingSoon) -> some View {
        VStack(spacing: 6) {
            Image(systemName: item.systemImage).font(.system(size: 21, weight: .semibold))
            Text(item.title).font(.system(size: 12, weight: .bold))
                .lineLimit(1).minimumScaleFactor(0.8)
            Text("SOON")
                .font(.system(size: 7.5, weight: .heavy)).tracking(1.5)
                .padding(.horizontal, 5).padding(.vertical, 1.5)
                .background(Color.secondary.opacity(0.25), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .frame(height: 84)
        .background(Theme.paper.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .foregroundStyle(.tertiary)
        .accessibilityLabel("\(item.title), coming soon")
    }
}
