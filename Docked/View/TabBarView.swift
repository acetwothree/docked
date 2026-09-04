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

/// Categorised activity picker. Rendered as an overlay sized to the module
/// area (never under the video or the tab bar), and closed by a tap outside,
/// a tap on the grab handle, or one swipe toward the tab-bar edge.
struct ActivityPickerPanel: View {
    var solved: SolvedLayout
    var current: ActivityModule
    var favorites: [ActivityModule]
    var hasPlus: Bool
    var chips: Int
    var chipRefillAt: Date?
    var themeTint: Color
    var onPick: (ActivityModule) -> Void
    var onToggleFav: (ActivityModule) -> Void
    var onClose: () -> Void

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        // Start higher than the module area — it's fine for the panel to cover
        // the bottom lip of the TV cabinet, it just makes the list taller.
        let top = solved.console.midY
        let bottom = solved.tab.minY - 8
        let h = max(220, bottom - top)
        return ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
                .transition(.opacity)

            panel
                .frame(width: solved.tab.width - 16, height: h)
                .position(x: solved.tab.midX, y: top + h / 2)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var favMods: [ActivityModule] {
        favorites.filter { m in ActivityModule.allCases.contains(m) }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose an activity")
                    .font(.system(size: 15, weight: .heavy))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !favMods.isEmpty {
                        favSection
                    }
                    ForEach(ActivityCategory.allCases) { freeSection($0) }
                    premiumSection
                    Color.clear.frame(height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 26)
            }
            .scrollIndicators(.visible)
            .overlay(alignment: .bottom) { scrollHint }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.hairline))
    }

    /// Fade + a floating chevron so it's obvious the list scrolls further.
    private var scrollHint: some View {
        LinearGradient(colors: [Theme.elevated.opacity(0), Theme.elevated],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: 40)
            .overlay(alignment: .center) {
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.secondary)
                    .offset(y: -6)
            }
            .allowsHitTesting(false)
    }

    private var favSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("FAVORITES", systemImage: "star.fill")
                .font(.system(size: 11, weight: .heavy)).tracking(1)
                .foregroundStyle(Theme.accent)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(favMods) { liveCard($0) }
            }
        }
    }

    /// One category's free activities. Premium ones live in `premiumSection`.
    @ViewBuilder
    private func freeSection(_ cat: ActivityCategory) -> some View {
        let mods = ActivityModule.allCases.filter { $0.category == cat && !$0.isPlus }
        if !mods.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(cat.rawValue.uppercased())
                        .font(.system(size: 11, weight: .heavy)).tracking(1)
                        .foregroundStyle(.secondary)
                    if cat == .gamble {
                        Spacer()
                        gambleChips
                    }
                }
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(mods) { liveCard($0) }
                }
            }
        }
    }

    /// Chip balance for the whole Gambling section, plus the refill countdown
    /// when you've hit zero.
    @ViewBuilder private var gambleChips: some View {
        HStack(spacing: 6) {
            Label("\(chips)", systemImage: "circle.fill")
                .font(.system(size: 11, weight: .heavy)).monospacedDigit()
                .foregroundStyle(Color(hex: "F5C518"))
            if chips == 0, let at = chipRefillAt {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let secs = max(0, Int(at.timeIntervalSince(ctx.date).rounded(.up)))
                    Text("+50 in \(secs)s")
                        .font(.system(size: 10, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var premiumSection: some View {
        let mods = ActivityModule.allCases.filter { $0.isPlus }
        let heading = hasPlus ? "PREMIUM" : "PREMIUM · DOCKED PLUS"
        return VStack(alignment: .leading, spacing: 8) {
            Label(heading, systemImage: "sparkles")
                .font(.system(size: 11, weight: .heavy)).tracking(1)
                .foregroundStyle(Theme.accent)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(mods) { liveCard($0) }
            }
        }
    }

    private func liveCard(_ mod: ActivityModule) -> some View {
        let on = mod == current
        let fav = favorites.contains(mod)
        let locked = mod.isPlus && !hasPlus
        return Button { onPick(mod) } label: {
            VStack(spacing: 7) {
                Image(systemName: mod.systemImage)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(on ? Color(red: 0.11, green: 0.08, blue: 0.02) : mod.tint)
                Text(mod.title).font(.system(size: 12.5, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .foregroundStyle(on ? Color(red: 0.11, green: 0.08, blue: 0.02) : Color.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .opacity(locked ? 0.72 : 1)
            .background(on ? AnyShapeStyle(Theme.accent.opacity(0.9))
                          : AnyShapeStyle(themeTint.opacity(0.16)),
                       in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(on ? Color.clear : mod.tint.opacity(0.35))
            }
            .overlay(alignment: .bottomTrailing) {
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locked ? "\(mod.title), Docked Plus" : mod.title)
        .overlay(alignment: .topTrailing) {
            Button { onToggleFav(mod) } label: {
                Image(systemName: fav ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(fav ? Theme.accent : Color.secondary.opacity(0.7))
                    .padding(9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

}
