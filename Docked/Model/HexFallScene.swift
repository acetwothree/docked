//
//  HexFallScene.swift
//  Docked
//
//  "Hex Fall" — guide a flat-top hexagon down an endless tower of packed
//  bricks by tapping bricks out from under it. Bricks are plain STATIC
//  terrain (never fall, never move on their own) — only the hexagon is a
//  real dynamic physics body, so it rolls naturally into whatever gap a tap
//  opens up. A tap deletes its brick instantly, no animation, exactly like
//  disintegrating a step out of a staircase.
//
//  Rows are either "stable" (one full-width bar — removing it drops the
//  hexagon straight down) or "unstable" (several narrower pillars — removing
//  one tips it over into a roll). A camera tracks the hexagon downward
//  (never back up) and new rows keep generating below, so a run only ends
//  when the hexagon rolls off the left/right edge of the tower or is lost
//  below the generated floor. Every so often a solid, unbreakable checkpoint
//  row appears — guaranteed a moment to settle before the next stretch.
//

import SpriteKit

final class HexFallScene: SKScene {
    var onScoreChange: ((Int) -> Void)?
    var onGameOver: (() -> Void)?
    var onTapHit: (() -> Void)?

    private(set) var score = 0
    private(set) var isOver = false

    /// Grid width, in units — every row's segment widths sum to exactly this.
    private let cols = 6
    private var cell: CGFloat = 20

    private var hexagon: SKShapeNode!
    private var bricks: [SKNode] = []
    private var lowestRowY: CGFloat = 0
    private var rowsSinceCheckpoint = 0
    private var blocksDestroyed = 0
    private var startY: CGFloat = 0
    private var cam: SKCameraNode!

    private static let palette: [SKColor] = [
        SKColor(red: 0.88, green: 0.28, blue: 0.24, alpha: 1),
        SKColor(red: 0.95, green: 0.54, blue: 0.24, alpha: 1),
        SKColor(red: 0.24, green: 0.81, blue: 0.48, alpha: 1),
        SKColor(red: 0.24, green: 0.63, blue: 0.88, alpha: 1),
        SKColor(red: 0.55, green: 0.36, blue: 0.97, alpha: 1),
    ]
    private static let checkpointColor = SKColor(red: 0.95, green: 0.83, blue: 0.35, alpha: 1)

    /// Unstable-row blueprints — segment widths (in units) summing to `cols`.
    private static let unstableRows: [[Int]] = [
        [2, 2, 2], [1, 2, 3], [3, 2, 1], [1, 1, 1, 1, 1, 1], [4, 2], [2, 4], [1, 4, 1],
    ]

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -6.2)
        let camera = SKCameraNode()
        self.camera = camera
        cam = camera
        addChild(camera)
        buildEverything()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // SwiftUI can set `scene.size` (via HexFallView's `sized(_:to:)`,
        // called while it's still laying out the SpriteView) BEFORE SpriteKit
        // has actually presented the scene and called `didMove(to:)` — the
        // moment that creates `cam`. Without this guard, that early size
        // change ran `buildEverything()` and force-unwrapped a still-nil
        // `cam`, crashing the instant Hex Fall opened. `didMove` builds the
        // board itself once it does fire, so it's safe to just skip here.
        guard cam != nil else { return }
        if !isOver, abs(oldSize.width - size.width) > 20 || abs(oldSize.height - size.height) > 20 {
            buildEverything()
        }
    }

    func reset() { buildEverything() }

    private func buildEverything() {
        // `reset()` is public (the toolbar's reset button calls it directly)
        // and this force-unwraps `cam` at the bottom — bail out if it's
        // somehow called before `didMove(to:)` has created the camera.
        guard cam != nil else { return }
        for b in bricks { b.removeFromParent() }
        bricks = []
        hexagon?.removeFromParent()
        score = 0
        blocksDestroyed = 0
        rowsSinceCheckpoint = 0
        isOver = false
        onScoreChange?(0)
        physicsWorld.speed = 1
        guard size.width > 10, size.height > 10 else { return }

        cell = size.width / CGFloat(cols)
        lowestRowY = cell * 1.5

        // Enough starting rows to fill the visible board plus a buffer.
        let startRows = max(10, Int(size.height / cell) + 6)
        for _ in 0..<startRows { addRow(forcedStable: bricks.isEmpty) }

        let topY = lowestRowY + cell
        placeHexagon(atY: topY)
        startY = topY
        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    // MARK: row generation

    private func addRow(forcedStable: Bool = false) {
        rowsSinceCheckpoint += 1
        let isCheckpoint = rowsSinceCheckpoint >= 12
        if isCheckpoint { rowsSinceCheckpoint = 0 }

        let widths: [Int] = isCheckpoint || forcedStable || Double.random(in: 0..<1) < 0.2
            ? [cols]
            : Self.unstableRows.randomElement()!
        let color = isCheckpoint ? Self.checkpointColor : Self.palette.randomElement()!

        var x: CGFloat = 0
        for w in widths {
            let segW = CGFloat(w) * cell
            let node = SKShapeNode(rectOf: CGSize(width: segW - 1, height: cell - 1), cornerRadius: 2)
            node.fillColor = color
            node.strokeColor = SKColor.white.withAlphaComponent(0.22)
            node.lineWidth = 1
            node.position = CGPoint(x: x + segW / 2, y: lowestRowY + cell / 2)
            // The physics body covers the FULL cell width (no render gap) so
            // the hexagon can't slip through a purely cosmetic seam.
            node.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: segW, height: cell))
            node.physicsBody?.isDynamic = false
            node.physicsBody?.friction = 0.9
            node.name = isCheckpoint ? "checkpoint" : "brick"
            node.zPosition = 1
            addChild(node)
            bricks.append(node)
            x += segW
        }
        lowestRowY += cell
    }

    private func placeHexagon(atY y: CGFloat) {
        let radius = cell * 0.85
        let path = TetrominoBuilder.polygonPath(sides: 6, radius: radius)
        let hex = SKShapeNode(path: path)
        hex.fillColor = SKColor(red: 0.24, green: 0.63, blue: 0.88, alpha: 1)
        hex.strokeColor = .white
        hex.lineWidth = 1.5
        hex.position = CGPoint(x: size.width / 2, y: y)
        hex.zPosition = 50
        let body = SKPhysicsBody(polygonFrom: path)
        body.friction = 0.7
        body.restitution = 0.01
        body.density = 0.7
        body.angularDamping = 0.3
        body.linearDamping = 0.1
        hex.physicsBody = body
        addChild(hex)
        hexagon = hex
    }

    // MARK: input — converts a tap to scene space accounting for the camera,
    // then deletes whatever brick is under it, instantly, no animation.

    func scenePoint(fromView p: CGPoint, viewSize: CGSize) -> CGPoint {
        let camPos = cam?.position ?? CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = p.x - viewSize.width / 2
        let dy = (viewSize.height - p.y) - viewSize.height / 2
        return CGPoint(x: camPos.x + dx, y: camPos.y + dy)
    }

    func handleTap(at point: CGPoint) {
        guard !isOver else { return }
        guard let node = nodes(at: point).first(where: { $0.name == "brick" }) else { return }
        node.removeFromParent()
        bricks.removeAll { $0 === node }
        blocksDestroyed += 1
        onTapHit?()
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isOver, hexagon != nil, cam != nil else { return }

        // Camera smoothly follows the hexagon downward; `min` with the
        // current position means it can only ever move down, never back up.
        let desiredY = hexagon.position.y + size.height * 0.12
        let smoothed = cam.position.y + (desiredY - cam.position.y) * 0.08
        cam.position = CGPoint(x: size.width / 2, y: min(smoothed, cam.position.y))

        // Keep material coming as the hexagon descends.
        while lowestRowY > cam.position.y - size.height * 1.3 { addRow() }
        // Cull rows well above the camera — off-screen and behind us.
        let cullAbove = cam.position.y + size.height
        for b in bricks where b.position.y > cullAbove { b.removeFromParent() }
        bricks.removeAll { $0.parent == nil }

        // Loss: rolled off either edge, or lost below the generated floor.
        if hexagon.position.x < -cell * 2 || hexagon.position.x > size.width + cell * 2
            || hexagon.position.y < lowestRowY - size.height {
            isOver = true
            physicsWorld.speed = 0
            onGameOver?()
            return
        }

        let depthRows = max(0, Int((startY - hexagon.position.y) / cell))
        let newScore = depthRows + blocksDestroyed
        if newScore != score {
            score = newScore
            onScoreChange?(score)
        }
    }
}
