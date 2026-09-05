//
//  HexFallScene.swift
//  Docked
//
//  "Hex Fall" — a hexagon balances flat on top of a tower built from real
//  tetromino pieces (packed tight, uniform 2-row height so they snap
//  together without gaps). Tap a piece to remove it; SpriteKit's own
//  rigid-body physics decides what tumbles — nothing is scripted. Once a
//  tower is mostly cleared a fresh one grows back under the hexagon, so a
//  run only ends when the hexagon itself goes over.
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

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -6.2)   // a bit slower/floatier than default
        buildEverything()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if !isOver, abs(oldSize.width - size.width) > 20 || abs(oldSize.height - size.height) > 20 {
            buildEverything()
        }
    }

    func reset() { buildEverything() }

    private func buildEverything() {
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
        addChild(floor)

        let topY = buildTower(fromY: 14)
        placeHexagon(atY: topY)
    }

    /// Packs rows of real (2-row-tall, so every row snaps to the same
    /// height) tetromino pieces left to right, filling as much of the
    /// tower's width as each row allows, and returns the Y just above the
    /// last row — where the hexagon sits.
    @discardableResult
    private func buildTower(fromY startY: CGFloat) -> CGFloat {
        let towerWidth = size.width * 0.86          // fill most of the width
        let cell = min(24, towerWidth / 6)
        let leftX = size.width / 2 - towerWidth / 2
        var y = startY

        for rowIndex in 0..<6 {
            let color = TetrominoBuilder.palette[rowIndex % TetrominoBuilder.palette.count]
            var x = leftX
            while x < leftX + towerWidth - cell * 1.4 {
                let shape = TetrominoShape.twoRow.randomElement()!
                let w = CGFloat(shape.colSpan) * cell
                if x + w > leftX + towerWidth + cell * 0.4 { break }
                let node = TetrominoBuilder.makeNode(shape: shape, cell: cell, color: color)
                node.position = CGPoint(x: x + w / 2, y: y + CGFloat(shape.rowSpan) * cell / 2)
                node.name = "block"
                node.zPosition = CGFloat(rowIndex)
                addChild(node)
                blockNodes.append(node)
                x += w
            }
            y += CGFloat(2) * cell   // every row here is 2 cells tall
        }
        return y
    }

    private func placeHexagon(atY y: CGFloat) {
        let hexRadius = min(size.width * 0.86 * 0.22, 32)
        let hexPath = TetrominoBuilder.polygonPath(sides: 6, radius: hexRadius)
        let hex = SKShapeNode(path: hexPath)
        hex.fillColor = SKColor(red: 0.24, green: 0.63, blue: 0.88, alpha: 1)
        hex.strokeColor = .white
        hex.lineWidth = 1.5
        // Flat-top, so it sits flush on the tower instead of balanced on a point.
        hex.position = CGPoint(x: size.width / 2, y: y + hexRadius * 0.87)
        hex.zPosition = 50
        let body = SKPhysicsBody(polygonFrom: hexPath)
        body.friction = 0.9
        body.restitution = 0.02
        body.density = 0.6
        body.angularDamping = 0.5
        body.linearDamping = 0.15
        hex.physicsBody = body
        addChild(hex)
        hexagon = hex
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
            return
        }
        // Clean up anything that toppled off-screen so it doesn't pile up as
        // a dead physics body forever.
        for node in blockNodes where node.position.y < -100 || node.parent == nil {
            node.removeFromParent()
        }
        blockNodes.removeAll { $0.parent == nil }

        // "Infinite" in the sense that a run only ends when the hexagon
        // falls — once the current tower is mostly cleared, grow a fresh one
        // underneath it rather than letting the game just end for lack of
        // material.
        if blockNodes.count <= 3, hexagon.parent != nil {
            regrow()
        }
    }

    private func regrow() {
        let oldHex = hexagon
        for node in blockNodes { node.removeFromParent() }
        blockNodes = []
        let topY = buildTower(fromY: 14)
        oldHex?.removeFromParent()
        placeHexagon(atY: topY)
    }
}
