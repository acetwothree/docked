//
//  BlockTowerView.swift
//  Docked
//
//  SwiftUI shell around `BlockTowerScene`. Drag anywhere to slide the
//  hovering piece; lift your finger to drop it. Real physics decides whether
//  the stack holds.
//

import SwiftUI
import SpriteKit

struct BlockTowerView: View {
    @Environment(AppModel.self) private var app
    @State private var scene = BlockTowerScene(size: CGSize(width: 320, height: 420))
    @State private var score = 0
    @State private var best: Int
    @State private var over = false
    @State private var landTick = 0
    @State private var overTick = 0

    init(highScore: Int) {
        _best = State(initialValue: highScore)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                stat("HEIGHT", score)
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
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in scene.moveCurrent(toX: v.location.x) }
                            .onEnded { _ in scene.dropCurrent() }
                    )
            }

            Text(over ? "That touched down — resetting…" : "Drag to slide · lift to drop")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(over ? Color.orange : Color.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            scene.onScoreChange = { score = $0 }
            scene.onLand = { landTick += 1 }
            scene.onGameOver = {
                if score > best { best = score }
                over = true
                overTick += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    over = false
                    scene.reset()
                }
            }
        }
        .onChange(of: best) { _, v in app.towerHighScore = v }
        .sensoryFeedback(.impact(weight: .light), trigger: landTick) { _, _ in app.haptics }
        .sensoryFeedback(.error, trigger: overTick) { _, _ in app.haptics }
    }

    private func sized(_ scene: BlockTowerScene, to size: CGSize) -> BlockTowerScene {
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
