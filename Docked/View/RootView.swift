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

                // real knob buttons, dropped onto the drawn wells
                consoleKnobs(s)

                // the speaker grille doubles as the "stretch screen" control
                stretchHandle(s)

                if app.debugOverlay {
                    DebugOverlay(solved: s)
                }

                if showPicker {
                    ActivityPickerPanel(
                        solved: s,
                        current: app.module,
                        favorites: app.favorites,
                        hasPlus: store.hasPlus,
                        themeTint: app.tvTheme.palette.mid,
                        onPick: { picked in
                            if picked.isPlus && !store.hasPlus {
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showPlus = true }
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPlus) {
            PlusSheet()
                .presentationDetents([.medium, .large])
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

    /// The speaker grille on the bottom-left of the console is the screen-fit
    /// control: drag it up or down to stretch the TV so the border wraps
    /// whatever video is playing. It's always on screen, so there's no
    /// separate grabber to find. Onboarding + Settings ▸ How to use explain it.
    private func stretchHandle(_ s: SolvedLayout) -> some View {
        let zoneW: CGFloat = 84
        let cx = s.console.minX + 8 + zoneW / 2
        return ZStack {
            // A faint up/down cue sitting just right of the drawn grille bars,
            // so the grille reads as a control without adding clutter.
            Image(systemName: "arrow.up.and.down")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(app.tvTheme.palette.hi.opacity(stretching ? 0.9 : 0.4))
                .offset(x: 30)
        }
        .frame(width: zoneW, height: s.console.height)
        .contentShape(Rectangle())
        .position(x: cx, y: s.console.midY)
        .gesture(
            DragGesture(minimumDistance: 1)
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
        .accessibilityLabel("Stretch TV screen to fit your video")
    }

    /// The three console knobs, positioned over the wells drawn by VideoFrameView.
    @ViewBuilder
    private func consoleKnobs(_ s: SolvedLayout) -> some View {
        let centers = LayoutSolver.knobCenters(inConsole: s.console)
        let pal = app.tvTheme.palette
        ZStack {
            if centers.count == 3 {
                TVKnob(icon: "gearshape.fill", palette: pal) {
                    endEditing(); showSettings = true
                }
                .position(centers[0])

                TVKnob(icon: "paintpalette.fill", palette: pal) {
                    if store.hasPlus {
                        withAnimation(.easeInOut(duration: 0.25)) { app.tvTheme = app.tvTheme.next }
                    } else {
                        endEditing(); showPlus = true
                    }
                }
                .position(centers[1])

                TVKnob(icon: "sparkles", palette: pal) {
                    endEditing(); showPlus = true
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
        case .mindmap:   MindMapView()
        case .game:      RunnerGameView()
        case .flow:      FlowView()
        case .idle:      IdleGameView()
        case .sand:      SandSortView()
        case .merge:     MergeView()
        case .drop:      MergeDropView()
        case .marble:    MarbleView()
        case .pop:       PopView()
        case .click:     ClickPenView()
        case .scratch:   ScratchGameView()
        case .spinner:   SpinnerView()
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
