//
//  RootView.swift
//  Docked
//
//  The single screen. Nested GeometryReaders give a full-screen coordinate
//  space; `LayoutSolver` places the TV cabinet at the top, a centred activity
//  chooser at the bottom, and the module in between. Settings / Theme / Plus
//  live on the console knobs.
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
    @State private var showPicker = false
    @State private var showPlus = false
    /// Set just before opening the paywall so it can name what the user tapped.
    @State private var plusContext: String? = nil
    /// When the paywall was opened from a locked picker card, reopen the picker
    /// on dismiss so "Maybe later" lands back where the user was.
    @State private var reopenPickerAfterPlus = false
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

                    // module content
                    moduleHost(solved: s)
                    .frame(width: s.content.width, height: s.content.height)
                    .clipShape(RoundedRectangle(cornerRadius: moduleCorner, style: .continuous))
                    .position(x: s.content.midX, y: s.content.midY)

                // footer — just the activity chooser, centred
                TabBarView(onPicker: { endEditing(); showPicker = true })
                    .frame(width: s.tab.width, height: s.tab.height)
                    .position(x: s.tab.midX, y: s.tab.midY)

                // the TV set — one wood cabinet, screen + console
                VideoFrameView(hole: s.holeInFrame,
                               consoleRect: s.consoleInFrame,
                               dimHint: hintDim,
                               palette: app.tvTheme.palette,
                               showBadge: app.tvBadge)
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

                if showPicker {
                    ActivityPickerPanel(
                        solved: s,
                        current: app.module,
                        favorites: app.favorites,
                        hasPlus: store.entitled,
                        themeTint: app.tvTheme.palette.mid,
                        onPick: { picked in
                            if picked.isPlus && !store.entitled {
                                plusContext = "\(picked.title) — \(picked.blurb)"
                                reopenPickerAfterPlus = true
                                showPicker = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { showPlus = true }
                            } else {
                                withAnimation(.snappy(duration: 0.24)) { app.module = picked }
                                showPicker = false
                            }
                        },
                        onToggleFav: { app.toggleFavorite($0) },
                        onClose: { showPicker = false }
                    )
                    .zIndex(15)
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
                .animation(.easeInOut(duration: 0.25), value: app.module)
                .animation(.easeInOut(duration: 0.22), value: showPicker)
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
            plusContext = nil
            if reopenPickerAfterPlus && !store.entitled {
                showPicker = true
            }
            reopenPickerAfterPlus = false
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
            if phase == .active { Task { await store.refreshEntitlements() } }
        }
    }

    private var moduleCorner: CGFloat {
        (app.module == .zen || app.module == .pop) ? 0 : 20
    }

    private func endEditing() {
        _ = UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
                // Left → right: Premium, Theme, Settings (settings is the
                // right-most, easiest-reach knob).
                TVKnob(icon: "sparkles", palette: pal) {
                    endEditing(); plusContext = nil; showPlus = true
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

    @ViewBuilder
    private func moduleHost(solved s: SolvedLayout) -> some View {
        if app.module == .zen {
            ZenPuzzleView(tabsAreHeader: s.tabIsHeader, layoutKey: app.layout, highScore: app.zenHighScore)
        } else {
            framed(moduleBody)
        }
    }

    @ViewBuilder
    private var moduleBody: some View {
        switch app.module {
        case .doodle:    DoodlePadView()
        case .notes:     NotesView()
        case .game:      RunnerGameView()
        case .flow:      FlowView()
        case .merge:     MergeView()
        case .drop:      MergeDropView()
        case .marble:    MarbleView()
        case .pop:       PopView()
        case .click:     ClickPenView()
        case .scratch:   ScratchGameView()
        case .blackjack: BlackjackView()
        case .ksand:     KineticSandView()
        case .tictactoe: TicTacToeView()
        case .connect4:  ConnectFourView()
        case .dots:      DotsBoxesView()
        case .zen:       EmptyView()   // handled above
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
            box(solved.tab, "tab", .blue)
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
