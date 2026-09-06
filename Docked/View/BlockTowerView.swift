//
//  BlockTowerView.swift
//  Docked
//
//  SwiftUI shell around `BlockTowerScene`. The hovering piece starts centred;
//  drag to slide it by however far your finger moves, lift to drop. The NEXT
//  piece is drawn small in the header, well clear of the play area. Real
//  physics decides whether the stack holds.
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
    @State private var lockTick = 0
    @State private var overTick = 0
    @State private var nextShape: TetrominoShape = .o
    /// x the hovering piece sat at when the current drag began — the drag
    /// moves it relative to this, so it never teleports to the finger.
    @State private var dragAnchorX: CGFloat? = nil

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
                nextPreview(nextShape)
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
                            .onChanged { v in
                                if dragAnchorX == nil { dragAnchorX = scene.currentPieceX }
                                scene.moveCurrent(toX: (dragAnchorX ?? 0) + v.translation.width)
                            }
                            .onEnded { _ in
                                dragAnchorX = nil
                                scene.dropCurrent()
                            }
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
            scene.onLock = { lockTick += 1 }
            scene.onNextShapeChange = { nextShape = $0 }
            scene.onGameOver = {
                if score > best {
                    best = score
                    if score >= 6 { ReviewPrompt.shared.recordDelight() }
                }
                over = true
                overTick += 1
                Analytics.shared.gameOver("blocktower", score: score)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                    over = false
                    scene.reset()
                }
            }
        }
        .onChange(of: best) { _, v in app.towerHighScore = v }
        .sensoryFeedback(.impact(weight: .light), trigger: landTick) { _, _ in app.haptics }
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.9), trigger: lockTick) { _, _ in app.haptics }
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

    /// The next piece, drawn small in the header so it's unmistakably a
    /// preview and never overlaps the play area.
    private func nextPreview(_ shape: TetrominoShape) -> some View {
        let cells = shape.cells
        let u: CGFloat = 6
        let gap: CGFloat = 1
        return VStack(spacing: 2) {
            Text("NEXT").font(.system(size: 7, weight: .heavy)).tracking(1).foregroundStyle(.tertiary)
            ZStack(alignment: .topLeading) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, rc in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(hex: "F2B90C"))
                        .frame(width: u, height: u)
                        .offset(x: CGFloat(rc.col) * (u + gap), y: CGFloat(rc.row) * (u + gap))
                }
            }
            .frame(width: CGFloat(shape.colSpan) * (u + gap),
                   height: CGFloat(shape.rowSpan) * (u + gap), alignment: .topLeading)
        }
        .frame(width: 42, height: 34)
    }
}
