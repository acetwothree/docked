//
//  RootView.swift
//  Docked
//
//  The one screen. A GeometryReader feeds the current safe-area size to
//  `LayoutSolver`, which produces two rectangles:
//
//    • videoRect   – where the dashed "drop your video here" guide sits
//    • contentRect – where the activity dashboard is allowed to live
//
//  Content is positioned into `contentRect` and animated with a single
//  spring, so switching layouts makes the whole dashboard glide to the
//  free half of the screen. Nothing interactive is ever placed under the
//  video.
//

import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(DoodleStore.self) private var doodle
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSettings = false

    var body: some View {
        GeometryReader { geo in
            let solver = LayoutSolver(layout: app.selectedLayout, size: geo.size)

            ZStack(alignment: .topLeading) {
                backdrop

                // The activity dashboard — always inside contentRect.
                ActivityDeckView(openSettings: { showSettings = true })
                    .frame(width: solver.contentRect.width,
                           height: solver.contentRect.height)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: Theme.corner + 6, style: .continuous)
                    )
                    .position(x: solver.contentRect.midX, y: solver.contentRect.midY)

                // The floating-video drop zone.
                if app.showGuide {
                    DropZoneView(layout: app.selectedLayout)
                        .frame(width: solver.videoRect.width,
                               height: solver.videoRect.height)
                        .position(x: solver.videoRect.midX, y: solver.videoRect.midY)
                        .transition(.opacity)
                }
            }
            .animation(Theme.layoutAnimation, value: app.selectedLayout)
            .animation(.easeInOut(duration: 0.25), value: app.showGuide)
        }
        .sheet(isPresented: $showSettings) {
            LayoutSettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            // First launch: show the layout picker straight away.
            if !app.hasOnboarded { showSettings = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { doodle.saveNow() }
        }
    }

    private var backdrop: some View {
        LinearGradient(
            colors: [Theme.backdrop, Theme.accent.opacity(0.10)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    RootView()
        .environment(AppModel())
        .environment(NotesStore())
        .environment(DoodleStore())
}
