//
//  RootView.swift
//  Docked
//
//  The single screen. Nested GeometryReaders give a full-screen coordinate
//  space; `LayoutSolver` places the TV cabinet at the top, with everything
//  below it given over to the game grid — or, once a game is open, that game
//  behind a small back-arrow header. Settings / Theme / Plus live on the
//  console knobs.
//

import SwiftUI
import UIKit

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(DoodleStore.self) private var doodle
    @Environment(StoreManager.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSettings = false
    @State private var showOnboarding = false
    @State private var showPlus = false
    /// The game currently open; nil shows the grid.
    @State private var openModule: ActivityModule? = nil
    /// Set just before opening the paywall so it can name what the user tapped.
    @State private var plusContext: String? = nil
    /// When the paywall was opened from a locked grid card, open straight into
    /// that game if the purchase went through.
    @State private var pendingModuleAfterPlus: ActivityModule? = nil
    @State private var hintDim = false
    @State private var stretchStart: CGFloat? = nil
    @State private var stretching = false

    var body: some View {
        GeometryReader { safeGeo in
            // Outer reader = safe-area frame → real safe-area insets.
            let insets = safeGeo.safeAreaInsets

            GeometryReader { fullGeo in
                // Inner reader ignores the safe area → full-screen size, origin
                // at the physical top-left. Everything below lays out in that
                // one coordinate space.
                let s = LayoutSolver.solve(app.layout, size: fullGeo.size,
                                           insetTop: insets.top, insetBottom: insets.bottom,
                                           stretch: app.tvStretch)

                ZStack(alignment: .topLeading) {
                    Theme.backdrop

                    // content — the game grid, or the open game
                    contentHost(solved: s)
                    .frame(width: s.content.width, height: s.content.height)
                    .position(x: s.content.midX, y: s.content.midY)

                // the TV set — one wood cabinet, screen + console
                VideoFrameView(hole: s.holeInFrame,
                               consoleRect: s.consoleInFrame,
                               dimHint: hintDim,
                               palette: app.tvTheme.palette,
                               consoleLabel: consoleLabel)
                    .frame(width: s.video.width, height: s.video.height)
                    .position(x: s.video.midX, y: s.video.midY)

                // drag anywhere along the bottom bar of the TV to stretch the
                // screen — drawn BEFORE the knobs so the knob buttons stay on
                // top and keep taking taps
                stretchHandle(s)

                // real knob buttons, dropped onto the drawn wells
                consoleKnobs(s)

                if app.debugOverlay {
                    DebugOverlay(solved: s)
                }

                // First-run onboarding — an overlay, so the live dashboard
                // stays visible (dimmed) behind it.
                if showOnboarding {
                    OnboardingView(topClearance: s.video.maxY) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            app.hasOnboarded = true
                            showOnboarding = false
                        }
                    }
                    .zIndex(20)
                }
                }
                .animation(.easeInOut(duration: 0.22), value: openModule)
                .animation(.easeInOut(duration: 0.3), value: showOnboarding)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(app.theme.colorScheme)
        .sheet(isPresented: $showSettings) {
            SettingsView(onShowPlus: {
                showSettings = false
                plusContext = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showPlus = true }
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPlus, onDismiss: {
            if store.entitled, let pending = pendingModuleAfterPlus {
                app.module = pending
                withAnimation(.snappy(duration: 0.24)) { openModule = pending }
            }
            plusContext = nil
            pendingModuleAfterPlus = nil
        }) {
            PlusSheet(context: plusContext)
                .presentationDragIndicator(.visible)
        }
        .task {
            hintDim = false
            try? await Task.sleep(for: .seconds(5))
            hintDim = true
        }
        .task { await store.start() }
        .onAppear { showOnboarding = !app.hasOnboarded }
        .onChange(of: app.hasOnboarded) { _, done in
            // "Replay onboarding" from Settings flips this while RootView is
            // already on screen, so react to it here (not just in onAppear).
            if !done { showOnboarding = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { doodle.saveNow() }
            if phase == .active {
                Task { await store.refreshEntitlements() }
            }
        }
    }

    private func endEditing() {
        _ = UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// The console text: the open game's name, or the app's own name when
    /// nothing's open — or always the app name if the developer has forced it
    /// on (Settings ▸ Developer), handy for recording ads without a game name
    /// showing.
    private var consoleLabel: String {
        guard !app.tvBadge, let mod = openModule else { return "DOCKED · FREE iOS APP" }
        return mod.title.uppercased()
    }

    /// The whole bottom bar of the TV cabinet is the screen-fit control: press
    /// and drag anywhere along it — the wood strip, the speaker grille, between
    /// and around the knobs — up or down to stretch the screen so the border
    /// wraps whatever video is playing. The knob buttons are drawn on top and
    /// still take taps; a drag that starts off a knob grabs the bar.
    /// Onboarding + Settings ▸ How to use explain it.
    private func stretchHandle(_ s: SolvedLayout) -> some View {
        // A little taller than the console so the very bottom edge is grabbable.
        let zoneH = s.console.height + 14
        return ZStack(alignment: .bottomLeading) {
            Color.clear
            Image(systemName: "arrow.up.and.down")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(app.tvTheme.palette.hi.opacity(stretching ? 0.95 : 0.42))
                .padding(.leading, 12)
                .padding(.bottom, 9)
        }
        .frame(width: s.console.width, height: zoneH)
        .contentShape(Rectangle())
        .position(x: s.console.midX, y: s.console.midY + 4)
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { v in
                    if stretchStart == nil {
                        stretchStart = app.tvStretch
                        stretching = true
                    }
                    let base = stretchStart ?? app.tvStretch
                    app.tvStretch = min(max(base + v.translation.height, LayoutSolver.stretchRange.lowerBound),
                                        LayoutSolver.stretchRange.upperBound)
                }
                .onEnded { _ in
                    stretchStart = nil
                    withAnimation(.easeOut(duration: 0.2)) { stretching = false }
                }
        )
        .accessibilityLabel("Drag to stretch the TV screen to fit your video")
    }

    /// The three console knobs, positioned over the wells drawn by VideoFrameView.
    @ViewBuilder
    private func consoleKnobs(_ s: SolvedLayout) -> some View {
        let centers = LayoutSolver.knobCenters(inConsole: s.console)
        let pal = app.tvTheme.palette
        ZStack {
            if centers.count == 3 {
                // Left → right: Back, Theme, Settings (settings is the
                // right-most, easiest-reach knob). Back only does anything once
                // a game is open — Docked Plus lives in Settings and on locked
                // game cards instead of its own knob now.
                TVKnob(icon: "chevron.left", palette: pal, enabled: openModule != nil) {
                    endEditing()
                    withAnimation(.snappy(duration: 0.22)) { openModule = nil }
                }
                .position(centers[0])

                TVKnob(icon: "paintpalette.fill", palette: pal) {
                    if store.entitled {
                        withAnimation(.easeInOut(duration: 0.25)) { app.tvTheme = app.tvTheme.next }
                    } else {
                        endEditing()
                        plusContext = "This knob switches the TV between colour themes."
                        showPlus = true
                    }
                }
                .position(centers[1])

                TVKnob(icon: "gearshape.fill", palette: pal) {
                    endEditing(); showSettings = true
                }
                .position(centers[2])
            }
        }
        .allowsHitTesting(true)
    }

    // MARK: content — the game grid, or an open game (back arrow is a TV knob)

    @ViewBuilder
    private func contentHost(solved s: SolvedLayout) -> some View {
        if let mod = openModule {
            if mod == .zen {
                ZenPuzzleView(tabsAreHeader: s.tabIsHeader, layoutKey: app.layout,
                             highScore: app.zenHighScore)
            } else {
                framed(moduleBody(mod, topClearance: s.video.maxY))
                    .clipShape(RoundedRectangle(cornerRadius: mod == .pop ? 0 : 20, style: .continuous))
            }
        } else {
            GameGridView(
                hasPlus: store.entitled,
                favorites: app.favorites,
                onPick: pick,
                onToggleFav: { app.toggleFavorite($0) }
            )
        }
    }

    private func pick(_ picked: ActivityModule) {
        if picked.isPlus && !store.entitled {
            plusContext = "\(picked.title) — \(picked.blurb)"
            pendingModuleAfterPlus = picked
            showPlus = true
        } else {
            endEditing()
            app.module = picked
            withAnimation(.snappy(duration: 0.24)) { openModule = picked }
        }
    }

    @ViewBuilder
    private func moduleBody(_ mod: ActivityModule, topClearance: CGFloat) -> some View {
        switch mod {
        case .doodle:  DoodlePadView()
        case .notes:   NotesView(topClearance: topClearance)
        case .color:   ColorView()
        case .merge:   MergeView()
        case .drop:    MergeDropView()
        case .marble:  MarbleView()
        case .brawl:   BrawlView()
        case .spot:    SpotView()
        case .pop:     PopView()
        case .click:   ClickPenView()
        case .rings:   RingsView()
        case .ksand:   KineticSandView()
        case .sandfall: SandFallView(highScore: app.sandHighScore)
        case .zen:     EmptyView()   // handled above
        }
    }

    private func framed(_ content: some View) -> some View {
        ZStack { Theme.paper; content }
            .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline) }
    }
}

/// Developer aid — outlines each region with its pixel size.
private struct DebugOverlay: View {
    var solved: SolvedLayout
    var body: some View {
        ZStack(alignment: .topLeading) {
            box(solved.pip, "pip", .orange)
            box(solved.video, "frame", .red)
            box(solved.console, "console", .yellow)
            box(solved.content, "content", .green)
        }
        .allowsHitTesting(false)
    }
    private func box(_ r: CGRect, _ name: String, _ c: Color) -> some View {
        Rectangle()
            .strokeBorder(c, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .overlay(alignment: .topLeading) {
                Text("\(name) \(Int(r.width))×\(Int(r.height))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(c)
                    .padding(2)
            }
            .frame(width: r.width, height: r.height)
            .position(x: r.midX, y: r.midY)
    }
}
