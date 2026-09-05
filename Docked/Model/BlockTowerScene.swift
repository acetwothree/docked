//
//  BlockTowerScene.swift
//  Docked
//
//  "Block Tower" — drag to slide the hovering piece over the stack, release
//  to drop it. Real SpriteKit physics decides whether the stack holds or
//  topples once a piece lands off-centre. Score is how many pieces you land
//  before it goes over.
//

import SpriteKit

final class BlockTowerScene: SKScene {
    var onScoreChange: ((Int) -> Void)?
    var onGameOver: (() -> Void)?
    var onLand: (() -> Void)?

    private(set) var score = 0
    private(set) var isOver = false

    private var current: SKShapeNode?
    private var placed: [SKNode] = []
    private var stackTop: CGFloat = 12

    private static let palette: [SKColor] = [
        SKColor(red: 0.88, green: 0.28, blue: 0.24, alpha: 1),
        SKColor(red: 0.95, green: 0.54, blue: 0.24, alpha: 1),
        SKColor(red: 0.95, green: 0.73, blue: 0.05, alpha: 1),
        SKColor(red: 0.24, green: 0.81, blue: 0.48, alpha: 1),
        SKColor(red: 0.24, green: 0.63, blue: 0.88, alpha: 1),
        SKColor(red: 0.55, green: 0.36, blue: 0.97, alpha: 1),
    ]

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

        let floor = SKNode()
        floor.position = CGPoint(x: size.width / 2, y: 6)
        floor.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width * 2, height: 12))
        floor.physicsBody?.isDynamic = false
        addChild(floor)

        spawnPiece()
    }

    private func pieceHeight() -> CGFloat { min(26, size.height * 0.06) }

    private func spawnPiece() {
        let w = CGFloat.random(in: 0.3...0.44) * size.width
        let h = pieceHeight()
        let node = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 4)
        node.fillColor = Self.palette[score % Self.palette.count]
        node.strokeColor = SKColor.white.withAlphaComponent(0.3)
        node.lineWidth = 1
        let hoverY = min(size.height - h, stackTop + size.height * 0.34)
        node.position = CGPoint(x: size.width / 2, y: hoverY)
        node.name = "hovering"
        node.zPosition = 100
        addChild(node)
        current = node
    }

    /// Called continuously while dragging — the piece just follows x.
    func moveCurrent(toX x: CGFloat) {
        guard let node = current, !isOver else { return }
        let half = node.frame.width / 2
        node.position.x = min(max(x, half), size.width - half)
    }

    func dropCurrent() {
        guard let node = current, !isOver else { return }
        current = nil
        let body = SKPhysicsBody(rectangleOf: CGSize(width: node.frame.width, height: node.frame.height))
        body.friction = 0.9
        body.restitution = 0.02
        body.density = 1
        body.angularDamping = 0.5
        body.linearDamping = 0.1
        node.physicsBody = body
        node.name = "placed"
        placed.append(node)
        score += 1
        onScoreChange?(score)
        onLand?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in
            self?.spawnNext()
        }
    }

    private func spawnNext() {
        guard !isOver else { return }
        stackTop = placed.map { $0.position.y + $0.frame.height / 2 }.max() ?? 14
        spawnPiece()
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isOver else { return }
        // Toppled: a placed piece has tipped hard over, or fallen off the
        // stack entirely. Real physics produced this, not a scripted check —
        // this just recognises it happened.
        let toppled = placed.contains { abs($0.zRotation) > 0.9 || $0.position.y < -40 }
        if toppled {
            isOver = true
            physicsWorld.speed = 0
            onGameOver?()
        }
    }
}
