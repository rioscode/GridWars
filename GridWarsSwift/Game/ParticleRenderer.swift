@preconcurrency import SpriteKit

@MainActor
final class ParticleRenderer {
    let node = SKNode()

    // Compound paths lose repeated additive coverage where particle lines overlap.
    // Keep lazy persistent nodes, but reuse one immutable unit path per visible line.
    private let shapeLineLayer = SKNode()
    private let spriteLayer = SKNode()
    private var shapeLines: [SKShapeNode] = []
    private var sprites: [SKSpriteNode] = []
    private var visibleShapeLineCount = 0
    private var visibleSpriteCount = 0
    private var graphicsSetIndex = 0
    private var particleTexture: SKTexture?
    private let prewarmTarget: Int

    init(capacity: Int = 2_048) {
        prewarmTarget = min(max(0, capacity), 768)
        shapeLines.reserveCapacity(capacity)
        sprites.reserveCapacity(capacity)

        // Style 3 draws the complete line pass before its complete bloom-image pass.
        shapeLineLayer.zPosition = 1
        spriteLayer.zPosition = 2
        node.addChild(shapeLineLayer)
        node.addChild(spriteLayer)
    }

    func setGraphicsSet(_ setIndex: Int) {
        guard setIndex != graphicsSetIndex else { return }
        graphicsSetIndex = setIndex
        particleTexture = nil
        guard !sprites.isEmpty else { return }
        let texture = currentParticleTexture()
        for sprite in sprites { sprite.texture = texture }
    }

    func render(
        _ simulation: ParticleSimulation,
        style: Int = 0,
        interpolationAlpha: CGFloat = 1
    ) {
        guard (0...3).contains(style) else {
            hideAll()
            return
        }

        var visualIndex = 0
        for particle in simulation.particles where particle.activeFrames > 0 {
            let color = boostedColor(particle.color, multiplier: style == 2 ? 1.5 : 1.25)
            let position = particle.presentationPosition(interpolationAlpha: interpolationAlpha)
            let velocity = particle.presentationVelocity(interpolationAlpha: interpolationAlpha)

            switch style {
            case 0, 1:
                let line = shapeLine(at: visualIndex)
                configureShapeLine(
                    line,
                    velocity: velocity,
                    position: position,
                    color: color,
                    style: style
                )
            case 2:
                let sprite = particleSprite(at: visualIndex)
                configureParticleSprite(
                    sprite,
                    velocity: velocity,
                    position: position,
                    color: color
                )
            case 3:
                let line = shapeLine(at: visualIndex)
                let sprite = particleSprite(at: visualIndex)
                configureShapeLine(
                    line,
                    velocity: velocity,
                    position: position,
                    color: color,
                    style: style
                )
                configureBloomSprite(
                    sprite,
                    velocity: velocity,
                    position: position,
                    color: color
                )
            default:
                break
            }
            visualIndex += 1
        }

        updateVisibleCounts(for: style, count: visualIndex)
        prewarmPools(for: style)
    }

    func hideAll() {
        hideShapeLines(after: 0)
        hideSprites(after: 0)
    }

    private func shapeLine(at index: Int) -> SKShapeNode {
        if index == shapeLines.count {
            let path = CGMutablePath()
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: 1, y: 0))
            let line = SKShapeNode(path: path)
            line.blendMode = .add
            line.lineCap = .butt
            line.glowWidth = 0
            line.isHidden = true
            shapeLineLayer.addChild(line)
            shapeLines.append(line)
        }
        return shapeLines[index]
    }

    private func particleSprite(at index: Int) -> SKSpriteNode {
        if index == sprites.count {
            let sprite = SKSpriteNode(texture: currentParticleTexture())
            sprite.blendMode = .add
            sprite.colorBlendFactor = 1
            sprite.isHidden = true
            spriteLayer.addChild(sprite)
            sprites.append(sprite)
        }
        return sprites[index]
    }

    private func configureShapeLine(
        _ line: SKShapeNode,
        velocity: CGVector,
        position: CGPoint,
        color: SKColor,
        style: Int
    ) {
        line.position = OriginalLineRasterRule.scenePixelCenter(position)
        line.xScale = velocity.length * 2
        line.yScale = 1
        line.zRotation = atan2(velocity.dy, velocity.dx)
        line.strokeColor = color
        line.lineWidth = style == 0 ? 1 : 2
        line.alpha = style == 0
            ? 1
            : OriginalBlendRule.spriteKitAdditiveNodeAlpha(
                sourceAlpha: style == 1 ? 0.9 : 0.8
            )
        line.isHidden = false
    }

    private func configureParticleSprite(
        _ sprite: SKSpriteNode,
        velocity: CGVector,
        position: CGPoint,
        color: SKColor
    ) {
        sprite.color = color
        sprite.position = CGPoint(
            x: position.x + velocity.dx,
            y: position.y + velocity.dy
        )
        sprite.size = CGSize(width: 7.5, height: 7.5)
        sprite.zRotation = 0
        sprite.alpha = 1
        sprite.isHidden = false
    }

    private func configureBloomSprite(
        _ sprite: SKSpriteNode,
        velocity: CGVector,
        position: CGPoint,
        color: SKColor
    ) {
        sprite.color = color
        sprite.position = CGPoint(
            x: position.x + velocity.dx,
            y: position.y + velocity.dy
        )
        sprite.size = CGSize(
            width: max(0.1, velocity.length * 6),
            height: 18
        )
        sprite.zRotation = atan(velocity.dy / velocity.dx)
        sprite.alpha = 0.25
        sprite.isHidden = false
    }

    private func updateVisibleCounts(for style: Int, count: Int) {
        hideShapeLines(after: style == 0 || style == 1 || style == 3 ? count : 0)
        hideSprites(after: style == 2 || style == 3 ? count : 0)
    }

    private func prewarmPools(for style: Int) {
        let budget = 16
        if style == 0 || style == 1 || style == 3 {
            for _ in 0..<min(budget, max(0, prewarmTarget - shapeLines.count)) {
                _ = shapeLine(at: shapeLines.count)
            }
        }
        if style == 2 || style == 3 {
            for _ in 0..<min(budget, max(0, prewarmTarget - sprites.count)) {
                _ = particleSprite(at: sprites.count)
            }
        }
    }

    private func hideShapeLines(after count: Int) {
        if count < visibleShapeLineCount {
            for index in count..<visibleShapeLineCount { shapeLines[index].isHidden = true }
        }
        visibleShapeLineCount = count
    }

    private func hideSprites(after count: Int) {
        if count < visibleSpriteCount {
            for index in count..<visibleSpriteCount { sprites[index].isHidden = true }
        }
        visibleSpriteCount = count
    }

    private func currentParticleTexture() -> SKTexture {
        if let particleTexture { return particleTexture }
        let texture = OriginalGraphics.texture(named: "particle", setIndex: graphicsSetIndex)
        particleTexture = texture
        return texture
    }

    private func boostedColor(_ color: ParticleColor, multiplier: CGFloat) -> SKColor {
        SKColor(
            red: CGFloat(min(255, Int(CGFloat(color.red) * multiplier))) / 255,
            green: CGFloat(min(255, Int(CGFloat(color.green) * multiplier))) / 255,
            blue: CGFloat(min(255, Int(CGFloat(color.blue) * multiplier))) / 255,
            alpha: 1
        )
    }
}
