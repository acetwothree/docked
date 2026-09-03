//
//  RootView.swift
//  Docked
//
//  The single screen. A GeometryReader gives the safe-area size to
//  `LayoutSolver`, which returns the rectangle for every region. Doodle /
//  Notes / Runner get the full-width band away from the video; Zen Puzzle
//  gets the whole area and builds around the video. The tab bar carries the
//  four modes plus the move-video / settings pair, and always sits on the
//  edge the video doesn't.
//

import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(DoodleStore.self) private var doodle
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSettings = false
    @State private var showOnboarding = false
    @State private var hintDim = false

    var body: some View {
        GeometryReader { geo in
            let s = LayoutSolver.solve(app.layout, size: geo.size)
            let fillsToEdge = app.module == .zen || app.module == .pop

            ZStack(alignment: .topLeading) {
                Theme.backdrop.ignoresSafeArea()

                // module content
                moduleHost(solved: s)
                    .frame(width: s.content.width, height: s.content.height)
                    .clipShape(RoundedRectangle(cornerRadius: fillsToEdge ? 0 : 20, style: .continuous))
                    .position(x: s.content.midX, y: s.content.midY)

                // tab bar — modes + control pair
                TabBarView(isHeader: s.tabIsHeader,
                           onLayout: { withAnimation(.easeInOut(duration: 0.2)) { app.isEditingLayout = true } },
                           onSettings: { showSettings = true })
                    .frame(width: s.tab.width, height: s.tab.height)
                    .position(x: s.tab.midX, y: s.tab.midY)

                // pixel-art TV frame (bezel shows around the PiP window)
                VideoFrameView(layout: app.layout, hole: s.holeInFrame, dimHint: hintDim)
                    .frame(width: s.video.width, height: s.video.height)
                    .position(x: s.video.midX, y: s.video.midY)

                if app.debugOverlay {
                    DebugOverlay(solved: s)
                }

                if app.isEditingLayout {
                    EditLayoutOverlay(
                        size: geo.size,
                        current: app.layout,
                        onPick: { picked in
                            withAnimation(Theme.layoutAnimation) { app.layout = picked }
                            app.isEditingLayout = false
                        },
                        onCancel: { app.isEditingLayout = false }
                    )
                    .transition(.opacity)
                }
            }
            .animation(Theme.layoutAnimation, value: app.layout)
            .animation(.easeInOut(duration: 0.2), value: app.isEditingLayout)
            .animation(.easeInOut(duration: 0.25), value: app.module)
        }
        .preferredColorScheme(app.theme.colorScheme)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { app.hasOnboarded = true; showOnboarding = false }
        }
        .task(id: app.layout) {
            hintDim = false
            try? await Task.sleep(for: .seconds(5))
            hintDim = true
        }
        .onAppear { showOnboarding = !app.hasOnboarded }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { doodle.saveNow() }
        }
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
