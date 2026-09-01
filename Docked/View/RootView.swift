//
//  RootView.swift
//  Docked
//
//  The single screen. A GeometryReader gives the safe-area size to
//  `LayoutSolver`, which returns the rectangle for every region. Everything
//  is packed edge to edge; only the video slot is left empty. Switching
//  layouts glides the whole UI with one spring.
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

            ZStack(alignment: .topLeading) {
                Theme.backdrop.ignoresSafeArea()

                // module content
                ModuleHost()
                    .frame(width: s.content.width, height: s.content.height)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline)
                    }
                    .position(x: s.content.midX, y: s.content.midY)

                // tab bar (header / footer)
                TabBarView(isHeader: s.tabIsHeader)
                    .frame(width: s.tab.width, height: s.tab.height)
                    .position(x: s.tab.midX, y: s.tab.midY)

                // pixel-art TV frame
                VideoFrameView(layout: app.layout, dimHint: hintDim)
                    .frame(width: s.video.width, height: s.video.height)
                    .position(x: s.video.midX, y: s.video.midY)

                // floating controls
                ControlsCluster(solved: s, openSettings: { showSettings = true })
                    .frame(width: s.controls.width, height: s.controls.height, alignment: .topLeading)
                    .position(x: s.controls.midX, y: s.controls.midY)
                    .opacity(app.isEditingLayout ? 0 : 1)

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
}

/// Hosts the active activity module, sized by RootView to the content rect.
private struct ModuleHost: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ZStack {
            Theme.paper
            switch app.module {
            case .doodle: DoodlePadView()
            case .notes:  NotesView()
            case .game:   RunnerGameView()
            }
        }
    }
}

/// Developer aid — outlines each region with its pixel size.
private struct DebugOverlay: View {
    var solved: SolvedLayout
    var body: some View {
        ZStack(alignment: .topLeading) {
            box(solved.video, "video", .red)
            box(solved.content, "content", .green)
            box(solved.tab, "tab", .blue)
            box(solved.controls, "controls", .yellow)
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
