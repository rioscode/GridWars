@preconcurrency import SpriteKit

@MainActor
final class OriginalHUDRenderer {
    let node = SKNode()
    var graphicsSetIndex = 0

    private let font = OriginalVectorFont()
    private let content = SKNode()

    init() {
        node.zPosition = 10
        node.addChild(content)
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
        content.removeAllChildren()

        let topAlpha = playerY < 80
            ? 0.5 + playerY / 400
            : 0.8
        let playerSKColor = skColor(playerColor)
        if session.lives > 1 {
            addIcon(frame: 0, x: size.width / 2 - 16, y: 19, alpha: topAlpha, size: size)
            if session.lives > 2 {
                addText(
                    "\(session.lives - 1)",
                    x: size.width / 2 - 48,
                    y: 10,
                    scale: 3,
                    color: playerSKColor,
                    alpha: topAlpha,
                    size: size
                )
            }
        }
        if session.bombs > 0 {
            addIcon(frame: 1, x: size.width / 2 + 16, y: 19, alpha: topAlpha, size: size)
            if session.bombs > 1 {
                addText(
                    "\(session.bombs)",
                    x: size.width / 2 + 32,
                    y: 10,
                    scale: 3,
                    color: playerSKColor,
                    alpha: topAlpha,
                    size: size
                )
            }
        }

        let scoreSKColor = skColor(scoreColor)
        addText(
            "SCORE: \(session.score)",
            x: 10,
            y: 10,
            scale: 3,
            color: scoreSKColor,
            alpha: topAlpha,
            size: size
        )
        addText(
            "HISCORE: \(max(highScore, session.score))",
            x: size.width - 260,
            y: 10,
            scale: 3,
            color: scoreSKColor,
            alpha: topAlpha,
            size: size
        )
        addText(
            "\(session.multiplier)X",
            x: 240,
            y: 10,
            scale: 2.5,
            color: scoreSKColor,
            alpha: topAlpha,
            size: size
        )
        if debugEnabled {
            addText(
                "\(simulationFrame)",
                x: 300,
                y: 10,
                scale: 3,
                color: scoreSKColor,
                alpha: topAlpha,
                size: size
            )
        }

        if let status = session.powerUpStatusMessage {
            let bottomAlpha = playerY > size.height - 80
                ? 1 - (playerY - (size.height - 80)) / 400
                : 0.8
            addText(
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
        }

        renderMessage(message, getReadyFrame: getReadyFrame, size: size)
    }

    private func renderMessage(_ label: SKLabelNode, getReadyFrame: Int, size: CGSize) {
        guard !label.isHidden, let text = label.text, !text.isEmpty else { return }
        let color = label.fontColor ?? .white
        if text == "GET READY", (0..<60).contains(getReadyFrame) {
            let pulse = abs(sin(CGFloat(getReadyFrame) * .pi / 180))
            let scale = max(0.01, pulse * 20)
            addText(
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
        addText(
            text,
            x: label.position.x - width / 2,
            y: size.height - label.position.y,
            scale: scale,
            color: color,
            alpha: 1,
            size: size
        )
    }

    private func addIcon(
        frame: Int,
        x: CGFloat,
        y: CGFloat,
        alpha: CGFloat,
        size: CGSize
    ) {
        let texture = OriginalGraphics.frameTexture(
            sheet: "icons",
            frame: frame,
            columns: 1,
            rows: 2,
            setIndex: graphicsSetIndex
        )
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = OriginalGraphicsSet(index: graphicsSetIndex).iconFrameSize
        sprite.position = CGPoint(x: x, y: size.height - y)
        sprite.alpha = alpha
        sprite.blendMode = .add
        content.addChild(sprite)
    }

    private func addText(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        scale: CGFloat,
        color: SKColor,
        alpha: CGFloat,
        size: CGSize
    ) {
        let textNode = font.makeNode(
            text,
            x: x,
            yFromTop: y,
            scale: scale,
            arenaHeight: size.height,
            color: color
        )
        textNode.alpha = alpha
        content.addChild(textNode)
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
