@preconcurrency import SpriteKit

@MainActor
final class OriginalScreenRenderer {
    let node = SKNode()
    var graphicsSetIndex = 0

    private let font = OriginalVectorFont()
    private let background = SKShapeNode()
    private let content = SKNode()
    private var scoreTrailColors = Array(repeating: SKColor.white, count: 10)
    private var scoreTrailFrame = -1
    private var friendTrailColors = Array(repeating: SKColor.white, count: 8)
    private var friendTrailFrame = -1
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
        cyclingColor: SKColor,
        colours: OriginalColorPalette,
        highScores: LegacyHighScoreTable,
        scorePageDifficulty: GameDifficulty?,
        highlightedScorePosition: Int?,
        unrankedEntry: LegacyHighScoreEntry?,
        showScoreSettings: Bool
    ) {
        prepare(size: size, backgroundAlpha: 1)
        switch page {
        case .title:
            renderTitle(frame: frame, titleFrame: persistentTitleFrame, size: size, color: cyclingColor)
        case .scores:
            renderScores(
                frame: frame,
                size: size,
                color: cyclingColor,
                highScores: highScores,
                fixedDifficulty: scorePageDifficulty,
                highlightedPosition: highlightedScorePosition,
                unrankedEntry: unrankedEntry,
                showSettings: showScoreSettings
            )
        case .friends:
            renderFriends(frame: frame, size: size, color: cyclingColor, colours: colours)
        case .enemies:
            renderEnemies(frame: frame, size: size, colours: colours)
        }
        if page != .title, frame % 50 > 25 {
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

    func renderHighScoreEntry(
        _ entry: OriginalHighScoreNameEntry,
        score: Int,
        playTime: String,
        difficulty: GameDifficulty,
        size: CGSize
    ) {
        prepare(size: size, backgroundAlpha: 1)
        addText("Congratulations!", x: size.width / 2 - 250, y: size.height / 2 - 240, scale: 3, color: .white, size: size)
        addText("You are in the top 10.", x: size.width / 2 - 250, y: size.height / 2 - 200, scale: 3, color: .white, size: size)
        addText("Difficulty Level: \(difficulty.title)", x: size.width / 2 - 250, y: size.height / 2 - 160, scale: 3, color: .white, size: size)
        let green = SKColor(red: 0, green: 1, blue: 0, alpha: 1)
        addText("Score: \(score)", x: size.width / 2 - 200, y: size.height / 2 - 80, scale: 3, color: green, size: size)
        addText("Time:  \(playTime)", x: size.width / 2 - 200, y: size.height / 2 - 40, scale: 3, color: green, size: size)
        addText("Name:  \(entry.name)", x: size.width / 2 - 200, y: size.height / 2, scale: 3, color: green, size: size)
        for index in 0..<8 {
            let underline = SKShapeNode(rect: CGRect(
                x: size.width / 2 - 95 + CGFloat(index * 15),
                y: size.height / 2 - 24,
                width: 12,
                height: 2
            ))
            underline.fillColor = index == entry.selectedIndex ? .yellow : green
            underline.strokeColor = .clear
            content.addChild(underline)
        }
        addText("Up and Down to select letter,", x: size.width / 2 - 250, y: size.height / 2 + 80, scale: 3, color: .white, size: size)
        addText("Left and Right to select position.", x: size.width / 2 - 250, y: size.height / 2 + 120, scale: 3, color: .white, size: size)
        addText("Press Enter when done.", x: size.width / 2 - 250, y: size.height / 2 + 160, scale: 3, color: .white, size: size)
        #if os(iOS)
        addText("LEFT   RIGHT   UP   DOWN   DONE", centeredAtY: size.height - 42, scale: 2.5, color: .yellow, size: size)
        #endif
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

        let creditColor = SKColor(red: 64 / 255, green: 180 / 255, blue: 64 / 255, alpha: 1)
        addText("Programmed In Blitzmax", x: size.width / 2 - CGFloat(22 / 2) * 5 * 3.2 * shrink, y: size.height - 280, scale: 3.2 * shrink, color: creditColor, size: size)
        addText("By Mark Incitti", x: size.width / 2 - CGFloat(15 / 2) * 5 * 3.2 * shrink, y: size.height - 240, scale: 3.2 * shrink, color: creditColor, size: size)
        let detail = frame % 200 > 99
            ? "Version 5.4 - Apr 19, 2006"
            : "Visit www.incitti.com for more games."
        let detailScale: CGFloat = frame % 200 > 99 ? 3 : 3.1
        let detailLength = frame % 200 > 99 ? 25 : 36
        addText(detail, x: size.width / 2 - CGFloat(detailLength / 2) * 5 * detailScale * shrink, y: size.height - 200, scale: detailScale * shrink, color: creditColor, size: size)
        addText("Special Thanks To", x: size.width / 2 - CGFloat(17 / 2) * 5 * 3.2 * shrink, y: size.height - 160, scale: 3.2 * shrink, color: SKColor(red: 240 / 255, green: 32 / 255, blue: 200 / 255, alpha: 1), size: size)
        addText("Svrman, taumel - Gfx & Effects, Swith - Music, RiK - Mac", x: size.width / 2 - CGFloat(56 / 2) * 5 * 3.2 * shrink, y: size.height - 120, scale: 3.2 * shrink, color: SKColor(red: 200 / 255, green: 32 / 255, blue: 240 / 255, alpha: 1), size: size)
        if frame % 60 > 29 {
            addText("Press BOMB Button to Start", x: size.width / 2 - CGFloat(26 / 2) * 5 * 4 * shrink, y: size.height - 32, scale: 4 * shrink, color: .yellow, size: size)
        }

    }

    private func renderScores(
        frame: Int,
        size: CGSize,
        color: SKColor,
        highScores: LegacyHighScoreTable,
        fixedDifficulty: GameDifficulty?,
        highlightedPosition: Int?,
        unrankedEntry: LegacyHighScoreEntry?,
        showSettings: Bool
    ) {
        updateScoreTrail(frame: frame, color: color)
        let difficulty = fixedDifficulty ?? GameDifficulty(rawValue: min(2, frame / 250)) ?? .easy
        addText("TOP SCORES - \(difficulty.title)", x: size.width / 2 - 200, y: size.height / 2 - 220, scale: 4, color: SKColor(red: 0, green: 0, blue: 240 / 255, alpha: 1), size: size)
        let headerColor = SKColor(red: 64 / 255, green: 240 / 255, blue: 64 / 255, alpha: 1)
        addText("SCORE", x: size.width / 2 - 250, y: size.height / 2 - 180, scale: 3, color: headerColor, size: size)
        addText("NAME", x: size.width / 2 - 100, y: size.height / 2 - 180, scale: 3, color: headerColor, size: size)
        addText("TIME", x: size.width / 2 + 130, y: size.height / 2 - 180, scale: 3, color: headerColor, size: size)
        for (row, entry) in highScores[difficulty].enumerated() {
            let spacing = showSettings ? 32 : 30
            let y = size.height / 2 - 150 + CGFloat(row * spacing)
            let rowColor = row == highlightedPosition ? SKColor.yellow : scoreTrailColors[9 - row]
            let scale: CGFloat = showSettings ? 2 : 3
            let score = String(entry.score)
            let scoreX = size.width / 2 - 180 - CGFloat(score.count * 14)
            addText(score, x: scoreX, y: y, scale: scale, color: rowColor, size: size)
            addText(entry.name, x: size.width / 2 - 120, y: y, scale: scale, color: rowColor, size: size)
            addText(entry.playTime, x: size.width / 2 + 64, y: y, scale: scale, color: rowColor, size: size)
            if showSettings {
                addText(entry.settings, x: scoreX, y: y + 16, scale: 2, color: rowColor, size: size)
            }
        }
        if let unrankedEntry {
            let y = size.height / 2 - 150 + CGFloat(11 * 30)
            let score = String(unrankedEntry.score)
            addText(score, x: size.width / 2 - 180 + 32 - CGFloat(score.count * 14), y: y, scale: 3, color: .red, size: size)
            addText(unrankedEntry.playTime, x: size.width / 2 + 32, y: y, scale: 3, color: .red, size: size)
        }
    }

    private func renderFriends(
        frame: Int,
        size: CGSize,
        color: SKColor,
        colours: OriginalColorPalette
    ) {
        updateFriendTrail(frame: frame, color: color)
        addText("Know Your Friends", x: size.width / 2 - 4.5 * 5 * 18 / 2 - 32, y: 10, scale: 4.5, color: .yellow, size: size)
        let entries: [(Int, String, String?, Int, ParticleColor)] = [
            (50, "Your Ship", "whiteplayer", -1, colours[.player]),
            (100, "Temporary Back Shooter", nil, 2, colours[.diamond]),
            (150, "Temporary Side Shooters", nil, 3, colours[.player]),
            (200, "Extra Front Shooter", nil, 0, colours[.diamond]),
            (250, "Extra Shot Speed", nil, 5, colours[.player]),
            (300, "Extra Player", nil, 6, colours[.diamond]),
            (350, "Extra Bomb", nil, 8, colours[.player]),
            (400, "Temporary Shield", nil, 9, colours[.diamond]),
            (450, "Super Shots", nil, 7, colours[.player]),
            (500, "Bouncy Shots", nil, 10, colours[.diamond]),
        ]
        for (index, entry) in entries.enumerated() where frame > entry.0 {
            let y = size.height / 2 - 200 + CGFloat(index * 50)
            let x = size.width / 2 - 200
            let sprite: SKSpriteNode
            if let textureName = entry.2 {
                sprite = makeSprite(textureName, atTopLeftPosition: CGPoint(x: x, y: y), size: size)
                sprite.zRotation = CGFloat(frame) * .pi / 180
            } else {
                sprite = SKSpriteNode(texture: powerUpTexture(frame: entry.3))
                sprite.position = CGPoint(x: x, y: size.height - y)
                sprite.size = CGSize(width: 64, height: 64)
                sprite.blendMode = .add
            }
            content.addChild(sprite)
            if entry.2 == nil {
                let star = makeSprite("whitestar", atTopLeftPosition: CGPoint(x: x, y: y), size: size)
                star.zRotation = CGFloat(frame * 6 + (index == 2 ? 45 : 0)) * .pi / 180
                let trailIndex = min(7, max(0, index - 1))
                star.color = friendTrailColors[trailIndex]
                star.colorBlendFactor = 1
                content.addChild(star)
            }
            addText(entry.1, x: size.width / 2 - 100, y: y - 10, scale: 3, color: skColor(entry.4), size: size)
        }
    }

    private func renderEnemies(frame: Int, size: CGSize, colours: OriginalColorPalette) {
        addText("Know Your Enemies", x: size.width / 2 - 4.5 * 5 * 18 / 2 - 32, y: 10, scale: 4.5, color: .red, size: size)
        let entries: [(Int, String, String, ParticleColor)] = [
            (50, "Paul the Pinwheel (25 pts)", "pinkpinwheel", colours[.pinwheel]),
            (100, "Dimmy the Diamond (50 pts)", "bluediamond", colours[.diamond]),
            (150, "Shy the Square (100 pts)", "greensquare", colours[.square]),
            (200, "Cubie the Cube (50/100 pts)", "purplesquare1", colours[.cube]),
            (250, "Sammy the Seeker (10 pts)", "bluecircle", colours[.seeker]),
            (300, "Dwight the Black Hole (150 pts)", "redcircle", colours[.blackHole]),
            (350, "Selena the Snake (100 pts)", "snakehead", colours[.snake]),
            (400, "Ivan the Interceptor (100 pts)", "redclone", colours[.interceptor]),
            (450, "Trish the Triangle (150 pts)", "orangetriangle", colours[.triangle]),
            (500, "Indy the Butterfly (10 pts)", "indigotriangle", colours[.butterfly]),
        ]
        for (index, entry) in entries.enumerated() where frame > entry.0 {
            let y = size.height / 2 - 200 + CGFloat(index * 50)
            if index == 6 {
                addDisplaySnake(frame: frame, center: CGPoint(x: size.width / 2 - 155, y: y), size: size)
            } else {
                let sprite = makeSprite(entry.2, atTopLeftPosition: CGPoint(x: size.width / 2 - 200, y: y), size: size)
                switch index {
                case 0: sprite.zRotation = CGFloat(frame * 4) * .pi / 180
                case 1:
                    let phase = frame % 256
                    let scaleY = phase > 127 ? CGFloat(phase > 190 ? 255 - phase : phase - 127) : 0
                    let scaleX = phase <= 127 ? CGFloat(phase > 63 ? 127 - phase : phase) : 0
                    sprite.xScale = 1 + scaleX / 80
                    sprite.yScale = 1 + scaleY / 80
                case 2: sprite.zRotation = CGFloat(frame * 2) * .pi / 180
                case 3: sprite.zRotation = (-CGFloat(frame) * 2.5 + 90) * .pi / 180
                case 5:
                    let pulse = 0.75 + sin(CGFloat(frame * 8) * .pi / 180) * 0.25
                    sprite.setScale(pulse)
                case 7: sprite.zRotation = CGFloat(frame) * .pi / 180
                case 8: sprite.zRotation = -CGFloat(frame * 3) * .pi / 180
                case 9: sprite.zRotation = CGFloat(frame * 4) * .pi / 180
                default: break
                }
                content.addChild(sprite)
            }
            addText(entry.1, x: size.width / 2 - 120, y: y - 10, scale: 3, color: skColor(entry.3), size: size)
        }
    }

    private func addDisplaySnake(frame: Int, center: CGPoint, size: CGSize) {
        for segment in 0..<24 {
            let y = center.y + sin(CGFloat(segment * 30 + frame) * .pi / 180) * 16
            let texture = if segment == 0 {
                OriginalGraphics.texture(named: "snakehead", setIndex: graphicsSetIndex)
            } else {
                OriginalGraphics.frameTexture(
                    sheet: "snaketail",
                    frame: 24 - segment,
                    columns: 8,
                    rows: 3,
                    setIndex: graphicsSetIndex
                )
            }
            let sprite = SKSpriteNode(texture: texture)
            sprite.position = CGPoint(x: center.x - CGFloat(segment * 13), y: size.height - y)
            sprite.blendMode = .add
            sprite.zRotation = (90 - cos(CGFloat(segment * 30 + frame) * .pi / 180) * 20) * .pi / 180
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
        let sprite = SKSpriteNode(texture: OriginalGraphics.texture(
            named: name,
            setIndex: graphicsSetIndex
        ))
        sprite.position = CGPoint(x: position.x, y: size.height - position.y)
        sprite.blendMode = .add
        return sprite
    }

    private func powerUpTexture(frame: Int) -> SKTexture {
        OriginalGraphics.frameTexture(
            sheet: "powerups",
            frame: frame,
            columns: 2,
            rows: 8,
            setIndex: graphicsSetIndex
        )
    }

    private func updateScoreTrail(frame: Int, color: SKColor) {
        guard frame != scoreTrailFrame else { return }
        if scoreTrailFrame < 0 || frame != scoreTrailFrame + 1 {
            scoreTrailColors = Array(repeating: color, count: 10)
        }
        scoreTrailColors[9] = color
        if frame.isMultiple(of: 4) {
            for index in 1..<scoreTrailColors.count {
                scoreTrailColors[index - 1] = scoreTrailColors[index]
            }
        }
        scoreTrailFrame = frame
    }

    private func updateFriendTrail(frame: Int, color: SKColor) {
        guard frame != friendTrailFrame else { return }
        if friendTrailFrame < 0 || frame != friendTrailFrame + 1 {
            friendTrailColors = Array(repeating: color, count: 8)
        }
        friendTrailColors[7] = color
        if frame.isMultiple(of: 4) {
            for index in 1..<friendTrailColors.count {
                friendTrailColors[index - 1] = friendTrailColors[index]
            }
        }
        friendTrailFrame = frame
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
