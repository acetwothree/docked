//
//  BlockTowerScene.swift
//  Docked
//
//  "Block Tower" — a tetromino hovers well above the top of the tower; drag
//  to slide it (a faint vertical guide line on EACH side shows where it comes
//  down), lift to drop. Real SpriteKit physics decides the fall, but the
//  moment a piece lands and stops it FREEZES solid — the built tower can
//  never topple afterwards, only the piece currently in the air can still go
//  wrong. Very forgiving, tuned for "satisfying to stack".
//
//  A stone platform on a pedestal in the water is "the ground". After the
//  first couple of pieces, a run ends only when a piece actually falls all
//  the way back down and touches that platform.
//
//  The camera holds completely still while a piece falls; once it has
//  settled the view eases up so the next piece drops from high with a real
//  gap, and still shows a good stretch of tower below the top.
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
    private var awaitingSettle = false
    private var settledFrames = 0
    private var awaitSince: TimeInterval = 0

    /// Big gap between the tower top and where a fresh piece hovers.
    private var hoverGap: CGFloat { size.height * 0.30 }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -3.4)   // gentle
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
        addChild(cam)
        placed = []
        current = nil
        score = 0
        isOver = false
        awaitingSettle = false
        settledFrames = 0
        awaitSince = 0
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
        platform.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: platW, height: platH))
        platform.physicsBody?.isDynamic = false
        platform.physicsBody?.friction = 1
        addChild(platform)
    }

    private func buildGuides() {
        for _ in 0..<2 {
            let g = SKShapeNode()
            g.strokeColor = SKColor.white.withAlphaComponent(0.28)
            g.lineWidth = 2
            g.zPosition = 300           // above every piece so both sides show
            g.isHidden = true
            addChild(g)
            if guideLeft == nil { guideLeft = g } else { guideRight = g }
        }
    }

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
        node.physicsBody?.angularDamping = 0.98
        node.physicsBody?.linearDamping = 0.6
        addChild(node)
        current = node
        updateGuides()
    }

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
        node.zPosition = 10
        placed.append(node)
        score += 1
        onScoreChange?(score)
        onLand?()
        awaitingSettle = true
        settledFrames = 0
        awaitSince = 0
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isOver, cam != nil else { return }

        if awaitingSettle {
            if awaitSince == 0 { awaitSince = currentTime }
            let still: Bool = {
                guard let b = placed.last?.physicsBody else { return true }
                let v = b.velocity
                return (v.dx * v.dx + v.dy * v.dy) < 16 && abs(b.angularVelocity) < 0.05
            }()
            settledFrames = still ? settledFrames + 1 : 0
            if settledFrames >= 12 || currentTime - awaitSince > 3.5 {
                // Lock the piece that just landed — the tower can no longer
                // shift underneath the next drops.
                placed.last?.physicsBody?.isDynamic = false
                let want = currentStackTopY() + size.height * 0.05
                camTargetY = max(camTargetY, min(want, camTargetY + cellSize() * 4))
                awaitingSettle = false
                settledFrames = 0
                awaitSince = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    guard let self, !self.isOver, self.current == nil else { return }
                    self.spawnPiece()
                }
            }
        }
        camTargetY = max(camTargetY, size.height / 2)
        let stepped = cam.position.y + (camTargetY - cam.position.y) * 0.12
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
