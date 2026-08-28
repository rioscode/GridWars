@preconcurrency import SpriteKit

@MainActor
final class OriginalHUDRenderer {
    let node = SKNode()
    var graphicsSetIndex = 0

    private enum TextSlot {
        case lives
        case bombs
        case score
        case highScore
        case multiplier
        case debug
        case status
        case message
    }

    private struct TextLayout: Equatable {
        let text: String
        let x: CGFloat
        let y: CGFloat
        let scale: CGFloat
        let arenaHeight: CGFloat
    }

    private let font = OriginalVectorFont()
    private let content = SKNode()
    private let lifeIcon = SKSpriteNode()
    private let bombIcon = SKSpriteNode()
    private var textNodes: [TextSlot: SKShapeNode] = [:]
    private var textLayouts: [TextSlot: TextLayout] = [:]
    private var renderedGraphicsSet: OriginalGraphicsSet?

    init() {
        node.zPosition = 10
        node.addChild(content)

        configureIcon(lifeIcon)
        content.addChild(lifeIcon)
        installTextNode(for: .lives)
        configureIcon(bombIcon)
        content.addChild(bombIcon)
        installTextNode(for: .bombs)
        installTextNode(for: .score)
        installTextNode(for: .highScore)
        installTextNode(for: .multiplier)
        installTextNode(for: .debug)
        installTextNode(for: .status)
        installTextNode(for: .message)
    }

    func render(
        session: GameSession,
        highScore: Int,
        playerY: CGFloat,
        simulationFrame: Int,
        debugEnabled: Bool,
        message: SKLabelNode,
        getReadyFrame: Int,
        playerColor: ParticleColor,
        scoreColor: ParticleColor,
        size: CGSize
    ) {
        updateIconTexturesIfNeeded()

        let topAlpha = playerY < 80
            ? 0.5 + playerY / 400
            : 0.8
        let playerSKColor = skColor(playerColor)
        updateIcon(
            lifeIcon,
            visible: session.lives > 1,
            x: size.width / 2 - 16,
            y: 19,
            alpha: topAlpha,
            size: size
        )
        if session.lives > 2 {
            updateText(
                .lives,
                "\(session.lives - 1)",
                x: size.width / 2 - 48,
                y: 10,
                scale: 3,
                color: playerSKColor,
                alpha: topAlpha,
                size: size
            )
        } else {
            hideText(.lives)
        }

        updateIcon(
            bombIcon,
            visible: session.bombs > 0,
            x: size.width / 2 + 16,
            y: 19,
            alpha: topAlpha,
            size: size
        )
        if session.bombs > 1 {
            updateText(
                .bombs,
                "\(session.bombs)",
                x: size.width / 2 + 32,
                y: 10,
                scale: 3,
                color: playerSKColor,
                alpha: topAlpha,
                size: size
            )
        } else {
            hideText(.bombs)
        }

        let scoreSKColor = skColor(scoreColor)
        updateText(
            .score,
            "SCORE: \(session.score)",
            x: 10,
            y: 10,
            scale: 3,
            color: scoreSKColor,
            alpha: topAlpha,
            size: size
        )
        updateText(
            .highScore,
            "HISCORE: \(max(highScore, session.score))",
            x: size.width - 260,
            y: 10,
            scale: 3,
            color: scoreSKColor,
            alpha: topAlpha,
            size: size
        )
        updateText(
            .multiplier,
            "\(session.multiplier)X",
            x: 240,
            y: 10,
            scale: 2.5,
            color: scoreSKColor,
            alpha: topAlpha,
            size: size
        )
        if debugEnabled {
            updateText(
                .debug,
                "\(simulationFrame)",
                x: 300,
                y: 10,
                scale: 3,
                color: scoreSKColor,
                alpha: topAlpha,
                size: size
            )
        } else {
            hideText(.debug)
        }

        if let status = session.powerUpStatusMessage {
            let bottomAlpha = playerY > size.height - 80
                ? 1 - (playerY - (size.height - 80)) / 400
                : 0.8
            updateText(
                .status,
                status.text,
                x: size.width / 2 - CGFloat(status.text.count * 7) + 1,
                y: size.height - 25,
                scale: 2.8,
                color: SKColor(
                    red: CGFloat(status.red) / 255,
                    green: CGFloat(status.green) / 255,
                    blue: CGFloat(status.blue) / 255,
                    alpha: 1
                ),
                alpha: bottomAlpha,
                size: size
            )
        } else {
            hideText(.status)
        }

        renderMessage(message, getReadyFrame: getReadyFrame, size: size)
    }

    private func renderMessage(_ label: SKLabelNode, getReadyFrame: Int, size: CGSize) {
        guard !label.isHidden, let text = label.text, !text.isEmpty else {
            hideText(.message)
            return
        }
        let color = label.fontColor ?? .white
        if text == "GET READY", (0..<60).contains(getReadyFrame) {
            let pulse = abs(sin(CGFloat(getReadyFrame) * .pi / 180))
            let scale = max(0.01, pulse * 20)
            updateText(
                .message,
                text,
                x: size.width / 2 - pulse * 19 * 5 * 9 * 0.5,
                y: size.height / 2 - pulse * 100,
                scale: scale,
                color: color,
                alpha: 1,
                size: size
            )
            return
        }

        let scale = max(0.01, 3 * label.xScale)
        let width = CGFloat(text.count) * 5 * scale
        updateText(
            .message,
            text,
            x: label.position.x - width / 2,
            y: size.height - label.position.y,
            scale: scale,
            color: color,
            alpha: 1,
            size: size
        )
    }

    private func configureIcon(_ sprite: SKSpriteNode) {
        sprite.blendMode = .add
        sprite.isHidden = true
    }

    private func updateIconTexturesIfNeeded() {
        let set = OriginalGraphicsSet(index: graphicsSetIndex)
        guard renderedGraphicsSet != set else { return }
        renderedGraphicsSet = set

        lifeIcon.texture = OriginalGraphics.frameTexture(
            sheet: "icons",
            frame: 0,
            columns: 1,
            rows: 2,
            setIndex: set.rawValue
        )
        bombIcon.texture = OriginalGraphics.frameTexture(
            sheet: "icons",
            frame: 1,
            columns: 1,
            rows: 2,
            setIndex: set.rawValue
        )
        lifeIcon.size = set.iconFrameSize
        bombIcon.size = set.iconFrameSize
    }

    private func updateIcon(
        _ sprite: SKSpriteNode,
        visible: Bool,
        x: CGFloat,
        y: CGFloat,
        alpha: CGFloat,
        size: CGSize
    ) {
        sprite.isHidden = !visible
        guard visible else { return }
        sprite.position = CGPoint(x: x, y: size.height - y)
        sprite.alpha = alpha
    }

    private func installTextNode(for slot: TextSlot) {
        let textNode = SKShapeNode()
        textNode.strokeColor = .white
        textNode.fillColor = .clear
        textNode.lineWidth = 2
        textNode.lineCap = .butt
        textNode.lineJoin = .miter
        textNode.isAntialiased = false
        textNode.blendMode = .add
        textNode.isHidden = true
        textNodes[slot] = textNode
        content.addChild(textNode)
    }

    private func hideText(_ slot: TextSlot) {
        textNodes[slot]?.isHidden = true
    }

    private func updateText(
        _ slot: TextSlot,
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        scale: CGFloat,
        color: SKColor,
        alpha: CGFloat,
        size: CGSize
    ) {
        guard let textNode = textNodes[slot] else { return }
        let layout = TextLayout(
            text: text,
            x: x,
            y: y,
            scale: scale,
            arenaHeight: size.height
        )
        if textLayouts[slot] != layout {
            textNode.path = font.makePath(
                text,
                x: x,
                yFromTop: y,
                scale: scale,
                arenaHeight: size.height
            )
            textLayouts[slot] = layout
        }
        textNode.strokeColor = color
        textNode.alpha = alpha
        textNode.isHidden = false
    }

    private func skColor(_ color: ParticleColor) -> SKColor {
        SKColor(
            red: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: 1
        )
    }
}
