//
//  TabBarView.swift
//  Docked
//
//  The footer: a single centred button showing the current activity, which
//  opens the categorised picker panel. Settings / Plus / Theme live on the TV
//  console instead.
//

import SwiftUI

struct TabBarView: View {
    @Environment(AppModel.self) private var app
    var onPicker: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button(action: onPicker) {
                HStack(spacing: 8) {
                    Image(systemName: app.module.systemImage).font(.system(size: 17, weight: .semibold))
                    Text(app.module.title).font(.system(size: 15, weight: .heavy))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 22)
                .frame(height: 44)
                .frame(maxWidth: 320)
                .background(Theme.accent.opacity(0.16), in: Capsule())
                .foregroundStyle(Theme.accent)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.elevated)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
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
        // create
        .init(title: "Mind Map",  systemImage: "brain",                     category: .create),
        // play
        .init(title: "2048",      systemImage: "square.grid.3x3.fill",      category: .play),
        .init(title: "Solitaire", systemImage: "suit.spade.fill",          category: .play),
        // fidget
        .init(title: "Spinner",     systemImage: "fan.fill",               category: .fidget),
        .init(title: "Kinetic Sand", systemImage: "hand.draw.fill",        category: .fidget),
        // 2 player (same phone)
        .init(title: "Connect 4",    systemImage: "circle.grid.cross.fill", category: .versus),
        .init(title: "Dots & Boxes", systemImage: "square.grid.4x3.fill",   category: .versus),
    ]

    private var closeToBottom: Bool { solved.occupiesTop }   // tab bar is the footer

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
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
            if !closeToBottom { grabBar }

            HStack {
                Text("Choose an activity")
                    .font(.system(size: 15, weight: .heavy))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16)
            .padding(.top, closeToBottom ? 14 : 4)
            .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(ActivityCategory.allCases) { section($0) }
                    Color.clear.frame(height: 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.visible)
            .overlay(alignment: .bottom) { scrollHint }

            if closeToBottom { grabBar }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.hairline))
    }

    /// Fade + chevron so it's obvious the list scrolls to more categories.
    private var scrollHint: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Theme.elevated.opacity(0), Theme.elevated],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 30)
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
                .background(Theme.elevated)
        }
        .allowsHitTesting(false)
    }

    /// The only thing that carries the swipe-to-close gesture, so it never
    /// fights the scroll view. Also closes on tap.
    private var grabBar: some View {
        Capsule().fill(Color.secondary.opacity(0.55))
            .frame(width: 44, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .contentShape(Rectangle())
            .onTapGesture(perform: onClose)
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { v in
                        dragOffset = closeToBottom ? max(0, v.translation.height) : min(0, v.translation.height)
                    }
                    .onEnded { v in
                        let past = closeToBottom ? v.translation.height > 48 : v.translation.height < -48
                        if past { onClose() }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { dragOffset = 0 }
                    }
            )
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
