//
//  RootView.swift
//  Docked
//
//  The single screen. A GeometryReader hands the safe-area size to
//  `LayoutSolver`, which lays every region out in safe-area coordinates. Only
//  the video border ignores the safe area, so it can nudge a few points past
//  the edge to meet the real PiP window; the tab bar and content stay fully
//  inside the safe area so nothing hides under a system bar. The Layout button
//  just flips top ⇄ bottom.
//

import SwiftUI
import UIKit

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(DoodleStore.self) private var doodle
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSettings = false
    @State private var showOnboarding = false
    @State private var showPicker = false
    @State private var showPlus = false
    @State private var hintDim = false

    var body: some View {
        GeometryReader { safeGeo in
            // Outer reader = safe-area frame → real safe-area insets.
            let insets = safeGeo.safeAreaInsets

            GeometryReader { fullGeo in
                // Inner reader ignores the safe area → full-screen size, origin
                // at the physical top-left. Everything below lays out in that
                // one coordinate space.
                let s = LayoutSolver.solve(app.layout, size: fullGeo.size,
                                           insetTop: insets.top, insetBottom: insets.bottom)

                ZStack(alignment: .topLeading) {
                    Theme.backdrop

                    // module content
                    moduleHost(solved: s)
                    .frame(width: s.content.width, height: s.content.height)
                    .clipShape(RoundedRectangle(cornerRadius: moduleCorner, style: .continuous))
                    .position(x: s.content.midX, y: s.content.midY)

                // tab bar — Move · activity chooser · Settings · Plus
                TabBarView(isHeader: s.tabIsHeader,
                           onLayout: {
                               endEditing()
                               withAnimation(Theme.layoutAnimation) { app.layout = app.layout.toggled }
                           },
                           onPicker: { endEditing(); showPicker = true },
                           onSettings: { endEditing(); showSettings = true },
                           onPlus: { endEditing(); showPlus = true })
                    .frame(width: s.tab.width, height: s.tab.height)
                    .position(x: s.tab.midX, y: s.tab.midY)

                // pixel-art TV frame
                VideoFrameView(hole: s.holeInFrame, dimHint: hintDim)
                    .frame(width: s.video.width, height: s.video.height)
                    .position(x: s.video.midX, y: s.video.midY)

                if app.debugOverlay {
                    DebugOverlay(solved: s)
                }

                if showPicker {
                    ActivityPickerPanel(
                        solved: s,
                        current: app.module,
                        onPick: { picked in
                            withAnimation(.snappy(duration: 0.24)) { app.module = picked }
                            showPicker = false
                        },
                        onClose: { showPicker = false }
                    )
                    .zIndex(15)
                }

                // First-run onboarding — an overlay, so the live dashboard
                // stays visible (dimmed) behind it.
                if showOnboarding {
                    OnboardingView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            app.hasOnboarded = true
                            showOnboarding = false
                        }
                    }
                    .zIndex(20)
                }
                }
                .animation(Theme.layoutAnimation, value: app.layout)
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
            .presentationDetents(settingsDetents)
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPlus) {
            PlusSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task(id: app.layout) {
            hintDim = false
            try? await Task.sleep(for: .seconds(5))
            hintDim = true
        }
        .onAppear { showOnboarding = !app.hasOnboarded }
        .onChange(of: app.hasOnboarded) { _, done in
            // "Replay onboarding" from Settings flips this while RootView is
            // already on screen, so react to it here (not just in onAppear).
            if !done { showOnboarding = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { doodle.saveNow() }
        }
    }

    private var moduleCorner: CGFloat {
        (app.module == .zen || app.module == .pop) ? 0 : 20
    }

    private func endEditing() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var settingsDetents: Set<PresentationDetent> {
        app.layout == .bottom ? [.large] : [.medium, .large]
    }

    @ViewBuilder
    private func moduleHost(solved s: SolvedLayout) -> some View {
        switch app.module {
        case .doodle:
            ZStack { Theme.paper; DoodlePadView() }
                .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline) }
        case .notes:
            ZStack { Theme.paper; NotesView() }
                .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline) }
        case .game:
            ZStack { Theme.paper; RunnerGameView() }
                .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline) }
        case .zen:
            ZenPuzzleView(
                tabsAreHeader: s.tabIsHeader,
                layoutKey: app.layout,
                highScore: app.zenHighScore
            )
        case .pop:
            ZStack { Theme.paper; PopView() }
                .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline) }
        case .flow:
            ZStack { Theme.paper; FlowView() }
                .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline) }
        case .click:
            ZStack { Theme.paper; ClickPenView() }
                .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline) }
        case .tictactoe:
            ZStack { Theme.paper; TicTacToeView() }
                .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline) }
        }
    }
}

/// Developer aid — outlines each region with its pixel size.
private struct DebugOverlay: View {
    var solved: SolvedLayout
    var body: some View {
        ZStack(alignment: .topLeading) {
            box(solved.pip, "pip", .orange)
            box(solved.video, "frame", .red)
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
