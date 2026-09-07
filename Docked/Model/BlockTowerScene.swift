//
//  BlockTowerScene.swift
//  Docked
//
//  "Block Tower" — a small tetromino hovers well above the tower; drag to
//  slide it, lift to drop. The moment a piece lands and stops it FREEZES
//  solid with a quick highlight — the built tower can never topple after
//  that, only the piece in the air can still go wrong. Drop a piece clear
//  off the side and it's a loss.
//
//  Every 10 of HEIGHT a free flat platform locks flush onto the current tip
//  to give you a fresh surface, and a faint numbered marker is dropped at the
//  tip every 5 — both pinned to the HEIGHT score, not to screen distance, so
//  they always read true. A stone platform in the water is "the ground"; a
//  piece that falls back to it after the first couple ends the run.
//

import SpriteKit

final class BlockTowerScene: SKScene {
    var onScoreChange: ((Int) -> Void)?
    var onGameOver: (() -> Void)?
    var onLand: (() -> Void)?                     // fired the instant a piece is dropped
    var onLock: (() -> Void)?                     // fired when a piece freezes into place
    var onNextShapeChange: ((TetrominoShape) -> Void)?   // the SwiftUI header draws the preview

    private(set) var score = 0
    private(set) var isOver = false

    private var current: SKNode?
    private var placed: [SKNode] = []
    private var floorTopY: CGFloat = 0
    private var cam: SKCameraNode!
    private var nextShape: TetrominoShape = .o

    private var camTargetY: CGFloat = 0
    private var awaitingSettle = false
    private var settledFrames = 0
    private var awaitSince: TimeInterval = 0
    private var lastPieceY: CGFloat = .greatestFiniteMagnitude
    private var spawnPending = false

    /// Draw pool: the seven classic tetrominoes plus the oddballs at ~2×
    /// weight, so the weird shapes are what you mostly get.
    private static let spawnBag: [TetrominoShape] = {
        let classic: [TetrominoShape] = [.i, .o, .t, .s, .z, .j, .l]
        let odd: [TetrominoShape] = [.plus, .cup, .bigL, .stairs, .corner, .bar3, .hammer,
                                     .pyramid, .zag, .chair, .notch]
        return classic + odd + odd
    }()

    private var milestoneDone = 0
    private var lastMarker = 0
    private var markers: [SKNode] = []

    private var hoverGap: CGFloat { size.height * 0.26 }
    private func cellSize() -> CGFloat { min(36, size.width * 0.15) }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -11)
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
        cam.removeAllChildren()          // leftover flash nodes live on the camera
        placed = []
        markers = []
        current = nil
        score = 0
        isOver = false
        awaitingSettle = false
        settledFrames = 0
        awaitSince = 0
        spawnPending = false
        milestoneDone = 0
        lastMarker = 0
        physicsWorld.speed = 1
        onScoreChange?(0)
        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
        camTargetY = size.height / 2

        buildGround()
        nextShape = Self.spawnBag.randomElement()!
        onNextShapeChange?(nextShape)
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
        let pedestal = SKShapeNode(rectOf: CGSize(width: pedW, height: floorTopY), cornerRadius: 6)
        pedestal.fillColor = SKColor(red: 0.62, green: 0.66, blue: 0.72, alpha: 1)
        pedestal.strokeColor = SKColor.white.withAlphaComponent(0.15)
        pedestal.lineWidth = 1
        pedestal.position = CGPoint(x: size.width / 2, y: floorTopY / 2)
        pedestal.zPosition = -10
        addChild(pedestal)

        let platW = size.width * 0.46          // narrower base — less slack for a sloppy stack
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

    /// A free, permanently-locked flat bar sitting flush ON TOP of `tipY` (its
    /// underside touches the tower's highest point). Static, so weight never
    /// shifts it.
    private func addMilestonePlatform(onTipY tipY: CGFloat, label: Int) {
        let w = cellSize() * 5.5
        let barH = cellSize() * 0.6
        let y = tipY + barH / 2
        let bar = SKShapeNode(rectOf: CGSize(width: w, height: barH), cornerRadius: 3)
        bar.fillColor = SKColor(red: 0.36, green: 0.40, blue: 0.47, alpha: 1)
        bar.strokeColor = SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 0.9)
        bar.lineWidth = 2
        bar.position = CGPoint(x: size.width / 2, y: y)
        bar.zPosition = 8
        bar.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: w, height: barH))
        bar.physicsBody?.isDynamic = false
        bar.physicsBody?.friction = 1
        addChild(bar)
        placed.append(bar)                       // counts as solid tower

        let tag = SKLabelNode(text: "\(label)")
        tag.fontName = "AvenirNext-Bold"
        tag.fontSize = cellSize() * 0.7
        tag.fontColor = SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1)
        tag.verticalAlignmentMode = .center
        tag.position = CGPoint(x: size.width / 2 + w / 2 + cellSize(), y: y)
        tag.zPosition = 8
        addChild(tag)
    }

    // MARK: height markers

    /// A faint full-width line + number dropped at the tower tip whenever
    /// HEIGHT passes another multiple of 5 — so a marker labelled "15" really
    /// is where the 15th piece settled.
    private func addHeightMarker(atY y: CGFloat, value: Int) {
        let line = SKShapeNode(rectOf: CGSize(width: size.width * 1.6, height: 1))
        line.fillColor = SKColor.white.withAlphaComponent(0.06)
        line.strokeColor = .clear
        line.position = CGPoint(x: size.width / 2, y: y)
        line.zPosition = -5
        addChild(line)

        let n = SKLabelNode(text: "\(value)")
        n.fontName = "AvenirNext-Bold"
        n.fontSize = cellSize() * 0.55
        n.fontColor = SKColor.white.withAlphaComponent(0.12)
        n.verticalAlignmentMode = .center
        n.position = CGPoint(x: cellSize() * 1.2, y: y)
        n.zPosition = -5
        addChild(n)

        markers.append(line); markers.append(n)
    }

    private func cullMarkers() {
        let floorCull = cam.position.y - size.height * 1.6
        markers.removeAll { m in
            if m.position.y < floorCull { m.removeFromParent(); return true }
            return false
        }
    }

    // MARK: pieces

    private func currentStackTopY() -> CGFloat {
        placed.map { $0.calculateAccumulatedFrame().maxY }.max() ?? floorTopY
    }

    private func spawnPiece() {
        guard !isOver else { return }
        spawnPending = false
        let cell = cellSize()
        let shape = nextShape
        nextShape = Self.spawnBag.randomElement()!
        onNextShapeChange?(nextShape)

        let color = TetrominoBuilder.palette[score % TetrominoBuilder.palette.count]
        let node = TetrominoBuilder.makeNode(shape: shape, cell: cell, color: color)
        let h = CGFloat(shape.rowSpan) * cell
        // Spawn a little off-centre (random side) so every piece needs a real
        // aim — you can't just tap-drop a straight column without steering.
        let spawnX = size.width / 2 + CGFloat.random(in: -1.3...1.3) * cell
        let halfW = node.calculateAccumulatedFrame().width / 2
        node.position = CGPoint(x: min(max(spawnX, halfW), size.width - halfW),
                                y: currentStackTopY() + hoverGap + h / 2)
        node.name = "hovering"
        node.zPosition = 100
        node.physicsBody?.isDynamic = false
        node.physicsBody?.friction = 1.0
        node.physicsBody?.restitution = 0
        node.physicsBody?.angularDamping = 0.55       // tips more readily
        node.physicsBody?.linearDamping = 0.02        // barely any air drag — it must fall
        addChild(node)
        current = node
    }

    /// The hovering piece's current x — the view anchors a drag to this so the
    /// piece tracks finger movement relative to where it already is (centred),
    /// instead of snapping to wherever the finger first lands.
    var currentPieceX: CGFloat { current?.position.x ?? size.width / 2 }

    func moveCurrent(toX x: CGFloat) {
        guard let node = current, !isOver else { return }
        let half = node.calculateAccumulatedFrame().width / 2
        node.position.x = min(max(x, half), size.width - half)
    }

    func dropCurrent() {
        guard let node = current, !isOver else { return }
        current = nil
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
        lastPieceY = .greatestFiniteMagnitude
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isOver, cam != nil else { return }
        cullMarkers()

        // Safety net: if we somehow have no hovering piece and nothing is
        // settling or queued, the run has stalled — get a piece back on screen.
        if current == nil, !awaitingSettle, !spawnPending {
            spawnPiece()
        }

        if awaitingSettle, let piece = placed.last {
            if awaitSince == 0 { awaitSince = currentTime }
            let elapsed = currentTime - awaitSince
            let f = piece.calculateAccumulatedFrame()

            // Off the side or slid back down onto the base ledge → loss, but
            // only once there's a real tower to lose (the first couple of
            // pieces legitimately sit at ground level).
            let offSide = f.maxX < 4 || f.minX > size.width - 4
            let onGround = f.minY < floorTopY + 4
            if placed.count > 2, offSide || onGround {
                endRun()
                return
            }

            // Fell clear PAST the tower into the water — this piece is never
            // settling. End the run if we have a tower; otherwise quietly
            // swap in a fresh piece so the game can't freeze waiting on it.
            let lost = f.maxY < floorTopY - size.height * 0.5
                || f.minY < cam.position.y - size.height * 1.6
            if lost {
                if placed.count > 2 { endRun(); return }
                piece.removeFromParent()
                if !placed.isEmpty { placed.removeLast() }
                score = max(0, score - 1)
                onScoreChange?(score)
                awaitingSettle = false
                settledFrames = 0
                awaitSince = 0
                spawnPiece()
                return
            }

            // Settle by vertical travel between frames, NOT raw velocity — a
            // freshly-dropped piece reads ~0 velocity on its first frame before
            // gravity takes hold, which used to freeze it in mid-air.
            let movedY = lastPieceY == .greatestFiniteMagnitude
                ? CGFloat.greatestFiniteMagnitude
                : abs(f.midY - lastPieceY)
            lastPieceY = f.midY
            let spin = abs(piece.physicsBody?.angularVelocity ?? 0)
            let creeping = movedY < 0.25 && spin < 0.06
            settledFrames = creeping ? settledFrames + 1 : 0

            // Never lock in the first ~0.45s: the piece has to be allowed to fall.
            if elapsed > 0.45, settledFrames >= 8 || elapsed > 3.5 {
                lockPiece(piece)
                let tip = currentStackTopY()
                if score % 5 == 0, score > lastMarker {
                    addHeightMarker(atY: tip, value: score)
                    lastMarker = score
                }
                if score % 10 == 0, score > milestoneDone {
                    addMilestonePlatform(onTipY: tip, label: score)
                    milestoneDone = score
                }
                camTargetY = max(camTargetY,
                                 min(currentStackTopY() + size.height * 0.05, camTargetY + cellSize() * 4))
                awaitingSettle = false
                settledFrames = 0
                awaitSince = 0
                spawnPending = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
                    guard let self, !self.isOver, self.current == nil else { return }
                    self.spawnPiece()
                }
            }
        }

        // Always keep the whole hovering piece on screen — raise the camera so
        // its top edge sits ~8% below the top of the view.
        if let cur = current {
            let pieceTop = cur.calculateAccumulatedFrame().maxY
            camTargetY = max(camTargetY, pieceTop - size.height * 0.46)
        }

        camTargetY = max(camTargetY, size.height / 2)
        cam.position.y = max(cam.position.y, cam.position.y + (camTargetY - cam.position.y) * 0.12)

        // Backstop: any settled piece beyond the base that ends up on the
        // ground (e.g. a slow slide-off) also ends the run.
        if placed.count > 3,
           placed.dropFirst(3).contains(where: { $0.calculateAccumulatedFrame().minY < floorTopY + 4 }) {
            endRun()
        }
    }

    private func lockPiece(_ piece: SKNode) {
        piece.physicsBody?.isDynamic = false
        onLock?()
        // Flash the block ITSELF white for a beat, then snap it back to colour.
        for case let sq as SKShapeNode in piece.children {
            let baseFill = sq.fillColor
            sq.removeAction(forKey: "lockFlash")
            sq.fillColor = .white
            sq.strokeColor = .white
            let restore = SKAction.run {
                sq.fillColor = baseFill
                sq.strokeColor = SKColor.white.withAlphaComponent(0.25)
            }
            sq.run(.sequence([.wait(forDuration: 0.11), restore]), withKey: "lockFlash")
        }
    }

    private func endRun() {
        guard !isOver else { return }
        isOver = true
        physicsWorld.speed = 0
        onGameOver?()
        runLoseAnimation()
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
