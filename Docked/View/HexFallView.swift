//
//  HexFallView.swift
//  Docked
//
//  SwiftUI shell around `HexFallScene` (SpriteKit does the actual physics).
//  Tap a brick to delete it and guide the hexagon down the endless tower —
//  don't let it roll off either edge.
//

import SwiftUI
import SpriteKit

struct HexFallView: View {
    @Environment(AppModel.self) private var app
    @State private var scene = HexFallScene(size: CGSize(width: 320, height: 420))
    @State private var score = 0
    @State private var best: Int
    @State private var over = false
    @State private var tapTick = 0
    @State private var overTick = 0

    init(highScore: Int) {
        _best = State(initialValue: highScore)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                stat("SCORE", score)
                Spacer()
                stat("BEST", max(best, score))
                Spacer()
                Button { scene.reset() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 30)
                }
                .buttonStyle(.plain)
            }

            GeometryReader { geo in
                SpriteView(scene: sized(scene, to: geo.size), options: [.allowsTransparency])
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture().onEnded { v in
                            // The scroll camera moves, so the SwiftUI tap
                            // location needs the scene's own conversion, not
                            // a fixed Y-flip against the scene's static size.
                            scene.handleTap(at: scene.scenePoint(fromView: v.location, viewSize: geo.size))
                        }
                    )
            }

            Text(over ? "Off the edge — resetting…" : "Tap bricks to guide it down")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(over ? Color.orange : Color.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            scene.onScoreChange = { score = $0 }
            scene.onTapHit = { tapTick += 1 }
            scene.onGameOver = {
                if score > best { best = score }
                over = true
                overTick += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    over = false
                    scene.reset()
                }
            }
        }
        .onChange(of: best) { _, v in app.hexHighScore = v }
        .sensoryFeedback(.impact(weight: .light), trigger: tapTick) { _, _ in app.haptics }
        .sensoryFeedback(.error, trigger: overTick) { _, _ in app.haptics }
    }

    /// Keeps the scene's own size in step with the space SwiftUI actually
    /// gives it (the module area can change — e.g. the TV gets stretched).
    private func sized(_ scene: HexFallScene, to size: CGSize) -> HexFallScene {
        if size.width > 10, size.height > 10,
           abs(scene.size.width - size.width) > 1 || abs(scene.size.height - size.height) > 1 {
            scene.size = size
        }
        return scene
    }

    private func stat(_ label: String, _ v: Int) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(.secondary)
            Text("\(v)").font(.system(size: 18, weight: .black)).monospacedDigit()
        }
    }
}
