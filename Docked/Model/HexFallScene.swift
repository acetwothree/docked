//
//  HexFallScene.swift
//  Docked
//
//  "Hex Fall" — a hexagon balances on top of a tower of stacked coloured
//  blocks. Tap a block to remove it; real SpriteKit rigid-body physics does
//  the rest — anything above an emptied gap tumbles the way gravity and its
//  own weight distribution says it should. Score is how many blocks you can
//  clear before the hexagon itself falls off the tower.
//
//  The tower is built once with every block already a dynamic physics body —
//  SpriteKit's contact/resting-body resolution is what keeps it standing
//  still on its own; nothing is pinned or scripted. That's also why removing
//  one block is enough to make the whole stack above it react realistically.
//

import SpriteKit

final class HexFallScene: SKScene {
    var onScoreChange: ((Int) -> Void)?
    var onGameOver: (() -> Void)?
    var onTapHit: (() -> Void)?

    private(set) var score = 0
    private(set) var isOver = false

    private var hexagon: SKShapeNode!
    private var blockNodes: [SKNode] = []

    private static let blockCategory: UInt32 = 0x1 << 0
    private static let hexCategory: UInt32 = 0x1 << 1
    private static let floorCategory: UInt32 = 0x1 << 2

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
        buildTower()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // A meaningfully different size (e.g. the TV was stretched while this
        // wasn't visible) — rebuild fresh rather than leave the tower
        // mis-placed relative to the new bounds.
        if !isOver, abs(oldSize.width - size.width) > 20 || abs(oldSize.height - size.height) > 20 {
            buildTower()
        }
    }

    func reset() {
        buildTower()
    }

    private func buildTower() {
        removeAllChildren()
        blockNodes = []
        score = 0
        isOver = false
        onScoreChange?(0)
        physicsWorld.speed = 1

        guard size.width > 10, size.height > 10 else { return }

        let floor = SKNode()
        floor.position = CGPoint(x: size.width / 2, y: 6)
        floor.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width * 2, height: 12))
        floor.physicsBody?.isDynamic = false
        floor.physicsBody?.categoryBitMask = Self.floorCategory
        addChild(floor)

        let layerCount = 7
        let towerWidth = size.width * 0.62
        let blockH = min(28, size.height * 0.075)
        let originX = size.width / 2
        var y: CGFloat = 14 + blockH / 2

        for layer in 0..<layerCount {
            let pieces = Int.random(in: 2...3)
            let color = Self.palette[layer % Self.palette.count]
            var cuts: [CGFloat] = (1..<pieces).map { _ in CGFloat.random(in: 0.3...0.7) }.sorted()
            cuts = [0] + cuts + [1]
            for i in 0..<pieces {
                let w0 = cuts[i], w1 = cuts[i + 1]
                let segW = max(18, (w1 - w0) * towerWidth - 3)
                let cx = originX - towerWidth / 2 + (w0 + w1) / 2 * towerWidth
                let node = SKShapeNode(rectOf: CGSize(width: segW, height: blockH), cornerRadius: 4)
                node.fillColor = color
                node.strokeColor = SKColor.white.withAlphaComponent(0.25)
                node.lineWidth = 1
                node.position = CGPoint(x: cx, y: y)
                node.name = "block"
                node.zPosition = CGFloat(layer)
                let body = SKPhysicsBody(rectangleOf: CGSize(width: segW, height: blockH))
                body.categoryBitMask = Self.blockCategory
                body.friction = 0.85
                body.restitution = 0.02
                body.density = 1
                body.angularDamping = 0.4
                body.linearDamping = 0.15
                node.physicsBody = body
                addChild(node)
                blockNodes.append(node)
            }
            y += blockH
        }

        // the hexagon, balanced on top
        let hexRadius = min(towerWidth * 0.3, blockH * 1.6)
        let hexPath = Self.polygonPath(sides: 6, radius: hexRadius)
        hexagon = SKShapeNode(path: hexPath)
        hexagon.fillColor = SKColor(red: 0.24, green: 0.63, blue: 0.88, alpha: 1)
        hexagon.strokeColor = .white
        hexagon.lineWidth = 1.5
        hexagon.position = CGPoint(x: originX, y: y + hexRadius * 0.7)
        hexagon.zPosition = CGFloat(layerCount + 1)
        let hexBody = SKPhysicsBody(polygonFrom: hexPath)
        hexBody.categoryBitMask = Self.hexCategory
        hexBody.friction = 0.9
        hexBody.restitution = 0.02
        hexBody.density = 0.6
        hexBody.angularDamping = 0.5
        hexBody.linearDamping = 0.15
        hexagon.physicsBody = hexBody
        addChild(hexagon)
    }

    /// Removes the topmost block under the touch, if any. Real physics takes
    /// over from there — nothing else is scripted.
    func handleTap(at point: CGPoint) {
        guard !isOver else { return }
        let hit = nodes(at: point).first { $0.name == "block" }
        guard let node = hit else { return }
        node.physicsBody = nil
        blockNodes.removeAll { $0 === node }
        node.run(.sequence([.group([.fadeOut(withDuration: 0.18), .scale(to: 0.7, duration: 0.18)]),
                            .removeFromParent()]))
        score += 1
        onScoreChange?(score)
        onTapHit?()
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isOver, hexagon != nil else { return }
        // The hexagon fell off the tower (or off the visible board entirely).
        if hexagon.position.y < 4 || hexagon.position.x < -60 || hexagon.position.x > size.width + 60 {
            isOver = true
            physicsWorld.speed = 0
            onGameOver?()
        }
        // Clean up any blocks that toppled off-screen so they don't pile up
        // as dead physics bodies forever.
        for node in blockNodes where node.position.y < -80 {
            node.removeFromParent()
        }
        blockNodes.removeAll { $0.parent == nil }
    }

    private static func polygonPath(sides: Int, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<sides {
            let angle = Double(i) / Double(sides) * 2 * .pi - .pi / 2
            let pt = CGPoint(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}
