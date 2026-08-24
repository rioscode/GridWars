@preconcurrency import SpriteKit

struct HighScoreDisplayEntry: Equatable {
    let score: Int
    let name: String
    let playTime: String
    let settings: String
}

@MainActor
final class OriginalScreenRenderer {
    let node = SKNode()

    private let font = OriginalVectorFont()
    private let background = SKShapeNode()
    private let content = SKNode()
    private(set) var menuHitFrames: [CGRect] = []

    init() {
        background.fillColor = .black
        background.strokeColor = .clear
        node.addChild(background)
        content.zPosition = 2
        node.addChild(content)
    }

    func hide() {
        node.isHidden = true
        menuHitFrames = []
    }

    func renderAttract(
        page: OriginalAttractPage,
        frame: Int,
        persistentTitleFrame: Int,
        size: CGSize,
        cyclingColor: SKColor
    ) {
        prepare(size: size, backgroundAlpha: 1)
        switch page {
        case .title:
            renderTitle(frame: frame, titleFrame: persistentTitleFrame, size: size, color: cyclingColor)
        case .scores:
            renderScores(frame: frame, size: size, color: cyclingColor)
        case .friends:
            renderFriends(frame: frame, size: size, color: cyclingColor)
        case .enemies:
            renderEnemies(frame: frame, size: size)
        }
        if frame % (page == .title ? 60 : 50) > (page == .title ? 29 : 25) {
            addText(
                "Press BOMB Button to Start",
                x: size.width / 2 - 250,
                y: size.height - 32,
                scale: 4,
                color: .yellow,
                size: size
            )
        }
    }

    func renderGameOver(counter: Int, size: CGSize) {
        prepare(size: size, backgroundAlpha: 0)
        let pulse = abs(sin(CGFloat(counter) / 2 * .pi / 180))
        addText(
            "GAME OVER",
            x: size.width / 2 - pulse * 19 * 5 * 9 * 0.5,
            y: size.height / 2 - pulse * 100,
            scale: max(0.01, pulse * 20),
            color: SKColor(red: 0, green: (55 + pulse * 200) / 255, blue: 0, alpha: 1),
            size: size
        )
    }

    func renderPause(size: CGSize) {
        prepare(size: size, backgroundAlpha: 0.72)
        addText(
            "PAUSED",
            centeredAtY: size.height / 2 - 60,
            scale: 10,
            color: .yellow,
            size: size
        )
        addText(
            "Release P to continue - O steps one frame",
            centeredAtY: size.height / 2 + 45,
            scale: 3,
            color: SKColor(red: 0.25, green: 0.9, blue: 0.35, alpha: 1),
            size: size
        )
    }

    func renderMenu(_ menu: OriginalMenuModel, size: CGSize) {
        prepare(size: size, backgroundAlpha: menu.openedDuringGame ? 0.82 : 1)
        addText(
            menu.title,
            x: size.width / 2 - 280,
            y: size.height / 2 - 200,
            scale: 6,
            color: .red,
            size: size
        )

        menuHitFrames = []
        let lineSpacing: CGFloat = menu.lines.count > 10 ? 32 : 40
        let totalHeight = CGFloat(max(0, menu.lines.count - 1)) * lineSpacing
        let firstY = size.height / 2 - totalHeight / 2
        for (index, line) in menu.lines.enumerated() {
            let y = firstY + CGFloat(index) * lineSpacing
            let selected = index == menu.selection
            let color = selected
                ? SKColor(red: 1, green: 1, blue: CGFloat((menu.selection * 37 + Int(y)) % 255) / 255, alpha: 1)
                : SKColor(red: 0, green: 200 / 255, blue: 0, alpha: 1)
            addText(
                line,
                x: size.width / 2 - 280,
                y: y,
                scale: menu.lines.count > 10 ? 3 : 4,
                color: color,
                size: size
            )
            let spriteY = size.height - y - 18
            menuHitFrames.append(CGRect(x: 0, y: spriteY - 14, width: size.width, height: 32))
            if selected {
                addTarget(
                    at: CGPoint(x: size.width / 2 - 300, y: spriteY),
                    phase: CGFloat(menu.selection * 8 + Int(y))
                )
            }
        }
        renderMenuMeters(menu, firstY: firstY, lineSpacing: lineSpacing, size: size)
    }

    func menuIndex(at point: CGPoint) -> Int? {
        menuHitFrames.firstIndex { $0.contains(point) }
    }

    private func prepare(size: CGSize, backgroundAlpha: CGFloat) {
        node.isHidden = false
        content.removeAllChildren()
        menuHitFrames = []
        background.path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
        background.alpha = backgroundAlpha
    }

    private func renderTitle(
        frame: Int,
        titleFrame: Int,
        size: CGSize,
        color: SKColor
    ) {
        let shrink = size.width / 1_024
        let title = "GridWars 2"
        let length = CGFloat(title.count - 1)
        let scale = min(20, CGFloat(titleFrame) / 24) * shrink
        if scale > 0 {
            for ring in 0...max(0, titleFrame / 25) {
                let angle = CGFloat(ring * 20 + frame * 2) * .pi / 180
                let x = (size.width - length * scale * 5.5) / 2
                    + cos(angle) * (2 + CGFloat(titleFrame) / 60)
                let y = (size.height - 18 * scale) / 2 - 50
                    + sin(angle) * (2 + CGFloat(titleFrame) / 60)
                    + 600 / 8 - CGFloat(titleFrame) / 8
                addText(title, x: x, y: y, scale: scale, color: color, size: size)
            }
        }

        addText("Programmed In Blitzmax", centeredAtY: size.height - 280, scale: 3.2 * shrink, color: SKColor(red: 64 / 255, green: 180 / 255, blue: 64 / 255, alpha: 1), size: size)
        addText("By Mark Incitti", centeredAtY: size.height - 240, scale: 3.2 * shrink, color: SKColor(red: 64 / 255, green: 180 / 255, blue: 64 / 255, alpha: 1), size: size)
        let detail = frame % 200 > 99
            ? "Version 5.4 - Apr 19, 2006"
            : "Visit www.incitti.com for more games."
        addText(detail, centeredAtY: size.height - 200, scale: 3 * shrink, color: SKColor(red: 64 / 255, green: 180 / 255, blue: 64 / 255, alpha: 1), size: size)
        addText("Special Thanks To", centeredAtY: size.height - 160, scale: 3.2 * shrink, color: SKColor(red: 240 / 255, green: 32 / 255, blue: 200 / 255, alpha: 1), size: size)
        addText("Svrman, taumel - Gfx & Effects, Swith - Music, RiK - Mac", centeredAtY: size.height - 120, scale: 3.2 * shrink, color: SKColor(red: 200 / 255, green: 32 / 255, blue: 240 / 255, alpha: 1), size: size)

        for index in 0..<2 {
            let sprite = makeSprite("redcircle", atTopLeftPosition: CGPoint(
                x: size.width / 2 + (index == 0 ? -72 : 68),
                y: size.height / 2 + (index == 0 ? -30 : 34)
            ), size: size)
            let pulse = 0.35 + 0.18 * sin(CGFloat(frame * (index + 2)) * .pi / 180)
            sprite.setScale(pulse)
            sprite.alpha = 0.7
            content.addChild(sprite)
        }
    }

    private func renderScores(frame: Int, size: CGSize, color: SKColor) {
        let difficulty = min(2, frame / 250)
        let titles = ["Easy", "Medium", "Hard"]
        addText("TOP SCORES - \(titles[difficulty])", x: size.width / 2 - 200, y: size.height / 2 - 220, scale: 4, color: SKColor(red: 0, green: 0, blue: 240 / 255, alpha: 1), size: size)
        let headerColor = SKColor(red: 64 / 255, green: 240 / 255, blue: 64 / 255, alpha: 1)
        addText("SCORE", x: size.width / 2 - 250, y: size.height / 2 - 180, scale: 3, color: headerColor, size: size)
        addText("NAME", x: size.width / 2 - 100, y: size.height / 2 - 180, scale: 3, color: headerColor, size: size)
        addText("TIME", x: size.width / 2 + 130, y: size.height / 2 - 180, scale: 3, color: headerColor, size: size)
        for (row, entry) in defaultScores(for: difficulty).enumerated() {
            let y = size.height / 2 - 150 + CGFloat(row * 30)
            addText(String(entry.score), x: size.width / 2 - 250, y: y, scale: 3, color: shifted(color, by: CGFloat(row) * 0.07), size: size)
            addText(entry.name, x: size.width / 2 - 120, y: y, scale: 3, color: shifted(color, by: CGFloat(row) * 0.07), size: size)
            addText(entry.playTime, x: size.width / 2 + 64, y: y, scale: 3, color: shifted(color, by: CGFloat(row) * 0.07), size: size)
        }
    }

    private func renderFriends(frame: Int, size: CGSize, color: SKColor) {
        addText("Know Your Friends", centeredAtY: 10, scale: 4.5, color: .yellow, size: size)
        let entries: [(Int, String, String?, Int, ParticleColor)] = [
            (50, "Your Ship", "whiteplayer", -1, OriginalParticleColor.player),
            (100, "Temporary Back Shooter", nil, 2, OriginalParticleColor.diamond),
            (150, "Temporary Side Shooters", nil, 3, OriginalParticleColor.player),
            (200, "Extra Front Shooter", nil, 0, OriginalParticleColor.diamond),
            (250, "Extra Shot Speed", nil, 5, OriginalParticleColor.player),
            (300, "Extra Player", nil, 6, OriginalParticleColor.diamond),
            (350, "Extra Bomb", nil, 8, OriginalParticleColor.player),
            (400, "Temporary Shield", nil, 9, OriginalParticleColor.diamond),
            (450, "Super Shots", nil, 7, OriginalParticleColor.player),
            (500, "Bouncy Shots", nil, 10, OriginalParticleColor.diamond),
        ]
        for (index, entry) in entries.enumerated() where frame > entry.0 {
            let y = size.height / 2 - 200 + CGFloat(index * 50)
            let x = size.width / 2 - 200
            let sprite: SKSpriteNode
            if let textureName = entry.2 {
                sprite = makeSprite(textureName, atTopLeftPosition: CGPoint(x: x, y: y), size: size)
            } else {
                sprite = SKSpriteNode(texture: powerUpTexture(frame: entry.3))
                sprite.position = CGPoint(x: x, y: size.height - y)
                sprite.size = CGSize(width: 64, height: 64)
                sprite.blendMode = .add
            }
            sprite.zRotation = CGFloat(frame * (index.isMultiple(of: 2) ? 1 : -1)) * .pi / 180
            content.addChild(sprite)
            let star = makeSprite("whitestar", atTopLeftPosition: CGPoint(x: x, y: y), size: size)
            star.zRotation = CGFloat(frame * 6 + index * 45) * .pi / 180
            star.color = shifted(color, by: CGFloat(index) * 0.08)
            star.colorBlendFactor = 1
            content.addChild(star)
            addText(entry.1, x: size.width / 2 - 100, y: y - 10, scale: 3, color: skColor(entry.4), size: size)
        }
    }

    private func renderEnemies(frame: Int, size: CGSize) {
        addText("Know Your Enemies", centeredAtY: 10, scale: 4.5, color: .red, size: size)
        let entries: [(Int, String, String, ParticleColor)] = [
            (50, "Paul the Pinwheel (25 pts)", "pinkpinwheel", OriginalParticleColor.pinwheel),
            (100, "Dimmy the Diamond (50 pts)", "bluediamond", OriginalParticleColor.diamond),
            (150, "Shy the Square (100 pts)", "greensquare", OriginalParticleColor.greenSquare),
            (200, "Cubie the Cube (50/100 pts)", "purplesquare1", OriginalParticleColor.cube),
            (250, "Sammy the Seeker (10 pts)", "bluecircle", OriginalParticleColor.seeker),
            (300, "Dwight the Black Hole (150 pts)", "redcircle", OriginalParticleColor.blackHole),
            (350, "Selena the Snake (100 pts)", "snakehead", OriginalParticleColor.snake),
            (400, "Ivan the Interceptor (100 pts)", "redclone", OriginalParticleColor.interceptor),
            (450, "Trish the Triangle (150 pts)", "orangetriangle", OriginalParticleColor.triangle),
            (500, "Indy the Butterfly (10 pts)", "indigotriangle", OriginalParticleColor.butterfly),
        ]
        for (index, entry) in entries.enumerated() where frame > entry.0 {
            let y = size.height / 2 - 200 + CGFloat(index * 50)
            if index == 6 {
                addDisplaySnake(frame: frame, center: CGPoint(x: size.width / 2 - 155, y: y), size: size)
            } else {
                let sprite = makeSprite(entry.2, atTopLeftPosition: CGPoint(x: size.width / 2 - 200, y: y), size: size)
                sprite.zRotation = CGFloat(frame * (index.isMultiple(of: 2) ? 2 : -3)) * .pi / 180
                if index == 5 {
                    let pulse = 0.75 + sin(CGFloat(frame * 8) * .pi / 180) * 0.25
                    sprite.setScale(pulse)
                }
                content.addChild(sprite)
            }
            addText(entry.1, x: size.width / 2 - 120, y: y - 10, scale: 3, color: skColor(entry.3), size: size)
        }
    }

    private func addDisplaySnake(frame: Int, center: CGPoint, size: CGSize) {
        for segment in 0..<24 {
            let name = segment == 0 ? "snakehead" : "snaketail"
            let y = center.y + sin(CGFloat(segment * 30 + frame) * .pi / 180) * 16
            let sprite = makeSprite(name, atTopLeftPosition: CGPoint(x: center.x - CGFloat(segment * 13), y: y), size: size)
            sprite.zRotation = (90 - cos(CGFloat(segment * 30 + frame) * .pi / 180) * 20) * .pi / 180
            sprite.setScale(segment == 0 ? 1 : max(0.18, 1 - CGFloat(segment) / 28))
            content.addChild(sprite)
        }
    }

    private func renderMenuMeters(
        _ menu: OriginalMenuModel,
        firstY: CGFloat,
        lineSpacing: CGFloat,
        size: CGSize
    ) {
        let meters: [(Int, CGFloat)]
        switch menu.page {
        case .audio:
            meters = [(0, menu.settings.soundEffectsVolume), (1, menu.settings.musicVolume)]
        case .game:
            meters = [(4, menu.settings.inertia)]
        case .hybrid:
            meters = [(3, menu.settings.mouseSensitivity)]
        case .mouse:
            meters = [(2, menu.settings.mouseSensitivity)]
        case .video:
            meters = [(8, CGFloat(menu.settings.gridColorPosition) / 120), (9, menu.settings.gridOpacity)]
        default:
            meters = []
        }
        for (index, value) in meters {
            let yFromTop = firstY + CGFloat(index) * lineSpacing
            let outline = SKShapeNode(rect: CGRect(x: size.width / 2 + 85, y: size.height - yFromTop - 26, width: 202, height: 24))
            outline.strokeColor = .yellow
            outline.fillColor = .clear
            outline.lineWidth = 1
            content.addChild(outline)
            let fill = SKShapeNode(rect: CGRect(x: size.width / 2 + 86, y: size.height - yFromTop - 25, width: max(0, min(1, value)) * 200, height: 22))
            fill.fillColor = SKColor(red: 0, green: 0.55, blue: 0, alpha: 1)
            fill.strokeColor = .clear
            content.addChild(fill)
        }
    }

    private func addTarget(at position: CGPoint, phase: CGFloat) {
        let path = CGMutablePath()
        for index in 0..<4 {
            let angle = (phase + CGFloat(index * 90)) * .pi / 180
            path.move(to: CGPoint(x: position.x + cos(angle) * 7, y: position.y + sin(angle) * 7))
            path.addLine(to: CGPoint(x: position.x + cos(angle) * 14, y: position.y + sin(angle) * 14))
        }
        let target = SKShapeNode(path: path)
        target.strokeColor = .yellow
        target.lineWidth = 2
        target.blendMode = .add
        content.addChild(target)
    }

    private func addText(
        _ text: String,
        centeredAtY y: CGFloat,
        scale: CGFloat,
        color: SKColor,
        size: CGSize
    ) {
        let width = CGFloat(text.count) * 5 * scale
        addText(text, x: (size.width - width) / 2, y: y, scale: scale, color: color, size: size)
    }

    private func addText(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        scale: CGFloat,
        color: SKColor,
        size: CGSize
    ) {
        content.addChild(font.makeNode(
            text,
            x: x,
            yFromTop: y,
            scale: scale,
            arenaHeight: size.height,
            color: color
        ))
    }

    private func makeSprite(
        _ name: String,
        atTopLeftPosition position: CGPoint,
        size: CGSize
    ) -> SKSpriteNode {
        let sprite = SKSpriteNode(imageNamed: name)
        sprite.position = CGPoint(x: position.x, y: size.height - position.y)
        sprite.size = name == "redcircle" ? CGSize(width: 128, height: 128) : CGSize(width: 64, height: 64)
        sprite.blendMode = .add
        return sprite
    }

    private func powerUpTexture(frame: Int) -> SKTexture {
        let sheet = SKTexture(imageNamed: "powerups")
        let column = frame % 2
        let rowFromTop = frame / 2
        return SKTexture(
            rect: CGRect(
                x: CGFloat(column) / 2,
                y: CGFloat(7 - rowFromTop) / 8,
                width: 0.5,
                height: 0.125
            ),
            in: sheet
        )
    }

    private func defaultScores(for difficulty: Int) -> [HighScoreDisplayEntry] {
        (0..<10).map { row in
            let score: Int = switch difficulty {
            case 0: 200_000 - row * 19_000
            case 1: 100_000 - row * 9_000
            default: 50_000 - row * 4_900
            }
            let frames = 50 * 60 * 11 - row * 50 * 40 - difficulty * 50 * 60 * 2
            return HighScoreDisplayEntry(
                score: score,
                name: "Mark Inc",
                playTime: Self.playTime(frames: frames),
                settings: "0,0,0,0,0,0,0,0,0,0"
            )
        }
    }

    private static func playTime(frames: Int) -> String {
        let seconds = frames / 50
        let minutes = seconds / 60
        let hours = minutes / 60
        var result = ""
        if hours > 0 { result += "\(hours) hr\(hours > 1 ? "s" : ""), " }
        if minutes > 0 { result += "\(minutes % 60) mn\(minutes > 1 ? "s" : ""), " }
        if seconds > 0 { result += "\(seconds % 60) sec\(seconds > 1 ? "s" : "")" }
        return result
    }

    private func shifted(_ color: SKColor, by shift: CGFloat) -> SKColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return SKColor(
            hue: (hue + shift).truncatingRemainder(dividingBy: 1),
            saturation: max(0.6, saturation),
            brightness: max(0.75, brightness),
            alpha: alpha
        )
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
