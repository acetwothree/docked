//
//  BlockTowerScene.swift
//  Docked
//
//  "Block Tower" — a real tetromino piece hovers high above the top of the
//  tower you're building; drag to slide it (two faint vertical guide lines
//  show where it'll come down), lift to drop it. Real SpriteKit physics —
//  slow and very forgiving — decides whether the stack holds.
//
//  There's a visible stone platform on a pedestal in the water near the
//  bottom: that's "the ground". The first couple of pieces get a free pass
//  while the base forms; after that, a run ends only when a piece actually
//  falls back down and touches that platform. A wobble that resettles up
//  the pile is fine.
//
//  The camera does NOT move while a piece is falling — it only eases up a
//  little once the piece has landed and come to rest, and it keeps a good
//  stretch of the tower below the top piece in view. It only ever rises.
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
    private var floorTopY: CGFloat = 0
    private var guideLeft: SKShapeNode?
    private var guideRight: SKShapeNode?
    private var cam: SKCameraNode!

    private var camTargetY: CGFloat = 0
    /// True from the moment a piece is dropped until it has settled — the
    /// camera target is frozen for that whole span.
    private var awaitingSettle = false

    /// How high above the tower top a fresh piece hovers.
    private var hoverGap: CGFloat { size.height * 0.34 }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -4.2)   // slow + forgiving
        let camera = SKCameraNode()
        self.camera = camera
        cam = camera
        addChild(camera)
        reset()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard cam != nil else { return }
        if !isOver, abs(oldSize.width - size.width) > 20 || abs(oldSize.height - size.height) > 20 {
            reset()
        }
    }

    func reset() {
        guard cam != nil, size.width > 10, size.height > 10 else { return }
        removeAllChildren()
        addChild(cam)                       // removeAllChildren took the camera too
        placed = []
        current = nil
        score = 0
        isOver = false
        awaitingSettle = false
        physicsWorld.speed = 1
        onScoreChange?(0)
        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
        camTargetY = size.height / 2

        buildGround()
        buildGuides()
        spawnPiece()
    }

    // MARK: scenery

    private func buildGround() {
        floorTopY = size.height * 0.30

        let water = SKShapeNode(rectOf: CGSize(width: size.width * 3, height: size.height * 6))
        water.fillColor = SKColor(red: 0.36, green: 0.79, blue: 0.92, alpha: 1)
        water.strokeColor = .clear
        water.position = CGPoint(x: size.width / 2, y: size.height * 0.14 - size.height * 3)
        water.zPosition = -20
        addChild(water)

        let pedW = size.width * 0.22
        let pedH = floorTopY
        let pedestal = SKShapeNode(rectOf: CGSize(width: pedW, height: pedH), cornerRadius: 6)
        pedestal.fillColor = SKColor(red: 0.62, green: 0.66, blue: 0.72, alpha: 1)
        pedestal.strokeColor = SKColor.white.withAlphaComponent(0.15)
        pedestal.lineWidth = 1
        pedestal.position = CGPoint(x: size.width / 2, y: pedH / 2)
        pedestal.zPosition = -10
        addChild(pedestal)

        let platW = size.width * 0.55
        let platH: CGFloat = max(12, size.height * 0.03)
        let platform = SKShapeNode(rectOf: CGSize(width: platW, height: platH), cornerRadius: 3)
        platform.fillColor = SKColor(red: 0.30, green: 0.34, blue: 0.40, alpha: 1)
        platform.strokeColor = SKColor.white.withAlphaComponent(0.25)
        platform.lineWidth = 1
        platform.position = CGPoint(x: size.width / 2, y: floorTopY - platH / 2)
        platform.zPosition = 1
        platform.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width * 2, height: platH))
        platform.physicsBody?.isDynamic = false
        platform.physicsBody?.friction = 1
        addChild(platform)
    }

    private func buildGuides() {
        for _ in 0..<2 {
            let g = SKShapeNode()
            g.strokeColor = SKColor.white.withAlphaComponent(0.22)
            g.lineWidth = 2
            g.zPosition = 5
            g.isHidden = true
            addChild(g)
            if guideLeft == nil { guideLeft = g } else { guideRight = g }
        }
    }

    /// Bigger blocks — easier to see and to place with intent.
    private func cellSize() -> CGFloat { min(42, size.width * 0.17) }

    private func currentStackTopY() -> CGFloat {
        placed.map { $0.calculateAccumulatedFrame().maxY }.max() ?? floorTopY
    }

    private func spawnPiece() {
        guard !isOver else { return }
        let cell = cellSize()
        let shape = TetrominoShape.allCases.randomElement()!
        let color = TetrominoBuilder.palette[score % TetrominoBuilder.palette.count]
        let node = TetrominoBuilder.makeNode(shape: shape, cell: cell, color: color)

        let h = CGFloat(shape.rowSpan) * cell
        let hoverY = currentStackTopY() + hoverGap + h / 2
        node.position = CGPoint(x: size.width / 2, y: hoverY)
        node.name = "hovering"
        node.zPosition = 100
        node.physicsBody?.isDynamic = false
        node.physicsBody?.friction = 1.0
        node.physicsBody?.restitution = 0
        node.physicsBody?.angularDamping = 0.95
        node.physicsBody?.linearDamping = 0.5
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
        let bottomY = min(f.minY - 4, currentStackTopY())
        guideLeft?.isHidden = false
        guideRight?.isHidden = false
        for (guide, gx) in [(guideLeft, f.minX), (guideRight, f.maxX)] {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: gx, y: bottomY))
            p.addLine(to: CGPoint(x: gx, y: f.minY))
            guide?.path = p
        }
    }

    func dropCurrent() {
        guard let node = current, !isOver else { return }
        current = nil
        guideLeft?.isHidden = true
        guideRight?.isHidden = true
        node.physicsBody?.isDynamic = true
        node.name = "placed"
        placed.append(node)
        score += 1
        onScoreChange?(score)
        onLand?()
        awaitingSettle = true            // freeze the camera target until it rests
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self, !self.isOver else { return }
            self.spawnPiece()
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isOver, cam != nil else { return }

        // Only re-aim the camera once the piece that just dropped has come to
        // rest (or after a safety timeout). While it's still moving, the
        // target — and therefore the camera — holds completely still.
        if awaitingSettle {
            let settled: Bool = {
                guard let b = placed.last?.physicsBody else { return true }
                let v = b.velocity
                return (v.dx * v.dx + v.dy * v.dy) < 90 && abs(b.angularVelocity) < 0.12
            }()
            if settled {
                // Camera sits a little ABOVE the tower top, so most of the
                // screen shows the tower BELOW the newest piece, not sky.
                camTargetY = max(camTargetY, currentStackTopY() + size.height * 0.12)
                awaitingSettle = false
            }
        }
        camTargetY = max(camTargetY, size.height / 2)
        let stepped = cam.position.y + (camTargetY - cam.position.y) * 0.07
        cam.position.y = max(cam.position.y, stepped)

        // Loss: a piece past the first couple falls back to the platform.
        let hitGround = placed.count > 2 && placed.dropFirst(2).contains {
            $0.calculateAccumulatedFrame().minY < floorTopY + 4
        }
        if hitGround {
            isOver = true
            physicsWorld.speed = 0
            onGameOver?()
            runLoseAnimation()
        }
    }

    /// A quick red flash + camera shake instead of the screen just freezing.
    private func runLoseAnimation() {
        let flash = SKShapeNode(rectOf: CGSize(width: size.width * 2.4, height: size.height * 2.4))
        flash.fillColor = SKColor.red
        flash.strokeColor = .clear
        flash.alpha = 0
        flash.zPosition = 500
        flash.position = .zero
        cam.addChild(flash)
        flash.run(.sequence([.fadeAlpha(to: 0.32, duration: 0.05),
                             .fadeAlpha(to: 0, duration: 0.5),
                             .removeFromParent()]))
        cam.run(.sequence([
            .moveBy(x: 7, y: 0, duration: 0.035), .moveBy(x: -14, y: 0, duration: 0.045),
            .moveBy(x: 12, y: 0, duration: 0.045), .moveBy(x: -8, y: 0, duration: 0.045),
            .moveBy(x: 3, y: 0, duration: 0.04), .moveBy(x: 0, y: 0, duration: 0.01),
        ]))
    }
}
