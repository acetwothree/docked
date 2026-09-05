//
//  BlockTowerScene.swift
//  Docked
//
//  "Block Tower" — a real tetromino piece hovers near the top; drag to slide
//  it, release (or the view's gesture) to drop it. Real SpriteKit physics
//  decides whether the stack holds or topples once a piece lands off-centre.
//  Score is how many pieces you land before it goes over. Missing the stack
//  entirely — any piece after the first couple landing straight on the floor
//  instead of on the pile — ends the run too.
//

import SpriteKit

final class BlockTowerScene: SKScene {
    var onScoreChange: ((Int) -> Void)?
    var onGameOver: (() -> Void)?
    var onLand: (() -> Void)?

    private(set) var score = 0
    private(set) var isOver = false

    private var current: SKNode?
    private var placed: [SKNode] = []
    private var stackTop: CGFloat = 12
    private var floorY: CGFloat = 6

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.6)
        reset()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if !isOver, abs(oldSize.width - size.width) > 20 || abs(oldSize.height - size.height) > 20 {
            reset()
        }
    }

    func reset() {
        removeAllChildren()
        placed = []
        current = nil
        score = 0
        isOver = false
        stackTop = 14
        onScoreChange?(0)
        physicsWorld.speed = 1
        guard size.width > 10, size.height > 10 else { return }

        floorY = 6
        let floor = SKNode()
        floor.position = CGPoint(x: size.width / 2, y: floorY)
        floor.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width * 2, height: 12))
        floor.physicsBody?.isDynamic = false
        addChild(floor)

        spawnPiece()
    }

    private func cellSize() -> CGFloat { min(24, size.width * 0.11) }

    private func spawnPiece() {
        let cell = cellSize()
        let shape = TetrominoShape.allCases.randomElement()!
        let color = TetrominoBuilder.palette[score % TetrominoBuilder.palette.count]
        let node = TetrominoBuilder.makeNode(shape: shape, cell: cell, color: color)
        // Start high up near the top of the board, regardless of stack
        // height, so there's real falling distance every time.
        let h = CGFloat(shape.rowSpan) * cell
        let hoverY = size.height - h / 2 - 16
        node.position = CGPoint(x: size.width / 2, y: hoverY)
        node.name = "hovering"
        node.zPosition = 100
        // Kinematic while hovering — TetrominoBuilder's body is dynamic by
        // default (fine once dropped), but it must NOT fall or react to
        // gravity/collisions until the player releases it.
        node.physicsBody?.isDynamic = false
        addChild(node)
        current = node
    }

    /// Called continuously while dragging — the piece just follows x.
    func moveCurrent(toX x: CGFloat) {
        guard let node = current, !isOver else { return }
        let half = node.calculateAccumulatedFrame().width / 2
        node.position.x = min(max(x, half), size.width - half)
    }

    func dropCurrent() {
        guard let node = current, !isOver else { return }
        current = nil
        // Switch the same compound body from kinematic (hovering) to
        // dynamic — that's what lets it actually fall now.
        node.physicsBody?.isDynamic = true
        node.name = "placed"
        placed.append(node)
        score += 1
        onScoreChange?(score)
        onLand?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.spawnNext()
        }
    }

    private func spawnNext() {
        guard !isOver else { return }
        stackTop = placed.map { $0.calculateAccumulatedFrame().maxY }.max() ?? 14
        spawnPiece()
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isOver else { return }
        // Toppled: a placed piece has tipped hard over, or fallen off the
        // stack entirely. Real physics produced this, not a scripted check —
        // this just recognises it happened.
        let toppled = placed.contains { abs($0.zRotation) > 0.9 || $0.position.y < -60 }
        // Missed the stack: any piece past the first two came to rest flat
        // on the floor instead of landing on the pile.
        let missedStack = placed.count > 2 && placed.dropFirst(2).contains {
            $0.position.y < floorY + cellSize()
        }
        if toppled || missedStack {
            isOver = true
            physicsWorld.speed = 0
            onGameOver?()
        }
    }
}
