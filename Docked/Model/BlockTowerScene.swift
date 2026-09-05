//
//  BlockTowerScene.swift
//  Docked
//
//  "Block Tower" — a real tetromino piece hovers near the top; drag to slide
//  it (two faint guide lines show where it'll come down), release (or the
//  view's gesture) to drop it. Real SpriteKit physics — slow and forgiving,
//  tuned for "satisfying to stack" over "punishing" — decides whether the
//  stack holds. The run only ends when a piece actually touches the visible
//  ground platform (any piece after the first two) — merely tipping while
//  still resting somewhere on the pile doesn't.
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
    private var floorTopY: CGFloat = 6
    private var guideLeft: SKShapeNode?
    private var guideRight: SKShapeNode?

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -5.5)   // slower — easier to place with intent
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

        // A visible platform, not just an invisible collider — it's obvious
        // where "the real ground" is and when a piece has actually hit it.
        let platformH: CGFloat = 14
        let platform = SKShapeNode(rectOf: CGSize(width: size.width, height: platformH))
        platform.fillColor = SKColor(red: 0.16, green: 0.17, blue: 0.2, alpha: 1)
        platform.strokeColor = SKColor.white.withAlphaComponent(0.2)
        platform.lineWidth = 1
        platform.position = CGPoint(x: size.width / 2, y: platformH / 2)
        platform.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width * 2, height: platformH))
        platform.physicsBody?.isDynamic = false
        addChild(platform)
        floorTopY = platformH

        let left = SKShapeNode(rectOf: CGSize(width: 2, height: 10))
        left.fillColor = SKColor.white.withAlphaComponent(0.25)
        left.strokeColor = .clear
        left.zPosition = 5
        left.isHidden = true
        addChild(left)
        guideLeft = left
        let right = SKShapeNode(rectOf: CGSize(width: 2, height: 10))
        right.fillColor = SKColor.white.withAlphaComponent(0.25)
        right.strokeColor = .clear
        right.zPosition = 5
        right.isHidden = true
        addChild(right)
        guideRight = right

        spawnPiece()
    }

    /// Bigger blocks — easier to see and to place with intent.
    private func cellSize() -> CGFloat { min(34, size.width * 0.15) }

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
        node.physicsBody?.friction = 1.0
        node.physicsBody?.restitution = 0
        node.physicsBody?.angularDamping = 0.8
        node.physicsBody?.linearDamping = 0.3
        addChild(node)
        current = node
        updateGuides()
    }

    /// Called continuously while dragging — the piece just follows x.
    func moveCurrent(toX x: CGFloat) {
        guard let node = current, !isOver else { return }
        let half = node.calculateAccumulatedFrame().width / 2
        node.position.x = min(max(x, half), size.width - half)
        updateGuides()
    }

    private func updateGuides() {
        guard let node = current else {
            guideLeft?.isHidden = true
            guideRight?.isHidden = true
            return
        }
        let f = node.calculateAccumulatedFrame()
        let h = max(4, f.minY - floorTopY)
        let midY = floorTopY + h / 2
        guideLeft?.isHidden = false
        guideRight?.isHidden = false
        guideLeft?.path = CGPath(roundedRect: CGRect(x: -1, y: -h / 2, width: 2, height: h), cornerWidth: 1, cornerHeight: 1, transform: nil)
        guideLeft?.position = CGPoint(x: f.minX, y: midY)
        guideRight?.path = CGPath(roundedRect: CGRect(x: -1, y: -h / 2, width: 2, height: h), cornerWidth: 1, cornerHeight: 1, transform: nil)
        guideRight?.position = CGPoint(x: f.maxX, y: midY)
    }

    func dropCurrent() {
        guard let node = current, !isOver else { return }
        current = nil
        guideLeft?.isHidden = true
        guideRight?.isHidden = true
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
        // The only way this ends: a piece — beyond the first couple, which
        // get a free pass while the base is still forming — actually rests
        // on the ground platform. Merely tipping while still somewhere on
        // the pile is not a loss; real physics is forgiving enough to let a
        // wobble settle back down.
        let hitGround = placed.count > 2 && placed.dropFirst(2).contains {
            $0.calculateAccumulatedFrame().minY < floorTopY + 3
        }
        if hitGround {
            isOver = true
            physicsWorld.speed = 0
            onGameOver?()
        }
    }
}
