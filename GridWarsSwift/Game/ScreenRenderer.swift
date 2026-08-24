@preconcurrency import SpriteKit

@MainActor
final class OriginalScreenRenderer {
    private struct MenuLayout {
        let titleY: CGFloat
        let lineYs: [CGFloat]
    }

    let node = SKNode()
    var graphicsSetIndex = 0

    private let font = OriginalVectorFont()
    private let background = SKShapeNode()
    private let content = SKNode()
    private var scoreTrailColors = Array(repeating: SKColor.white, count: 10)
    private var scoreTrailFrame = -1
    private var friendTrailColors = Array(repeating: SKColor.white, count: 8)
    private var friendTrailFrame = -1
    private var menuBackgroundTexture: SKTexture?
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

    func captureMenuBackground(from scene: SKScene, view: SKView) {
        menuBackgroundTexture = view.texture(from: scene)
    }

    func clearMenuBackground() {
        menuBackgroundTexture = nil
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

    func resetAttractTrails() {
        scoreTrailColors = Array(repeating: .white, count: 10)
        scoreTrailFrame = -1
        friendTrailColors = Array(repeating: .white, count: 8)
        friendTrailFrame = -1
    }

    func seedScoreTrail(_ colors: [SKColor]) {
        guard colors.count == scoreTrailColors.count else { return }
        scoreTrailColors = colors
        scoreTrailFrame = -2
    }

    func recordAttractTrail(page: OriginalAttractPage, frame: Int, color: SKColor) {
        switch page {
        case .scores:
            updateScoreTrail(frame: frame, color: color)
        case .friends:
            updateFriendTrail(frame: frame, color: color)
        case .title, .enemies:
            break
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

    func renderMenu(_ menu: OriginalMenuModel, frame: Int, size: CGSize) {
        prepare(size: size, backgroundAlpha: 1)
        renderCapturedMenuBackground(for: menu, size: size)
        if menu.page == .dualAnalog {
            renderDualAnalogMenu(menu, frame: frame, size: size)
            return
        }

        let layout = menuLayout(for: menu, size: size)
        addText(
            menu.title,
            x: size.width / 2 - 280,
            y: layout.titleY,
            scale: 6,
            color: .red,
            size: size
        )

        menuHitFrames = []
        if menu.page == .joypad {
            renderJoypadMenu(menu, frame: frame, lineYs: layout.lineYs, size: size)
            return
        }

        for (index, line) in menu.lines.enumerated() {
            let y = layout.lineYs[index]
            let selected = index == menu.selection
            let color = menuColor(selected: selected, frame: frame)
            let visibleLine: String
            if menu.page == .keyboard,
               menu.awaitingKeyboardBinding,
               selected,
               (frame * 8) % 30 < 15,
               let colon = line.lastIndex(of: ":") {
                visibleLine = String(line[...colon])
            } else {
                visibleLine = line
            }
            addText(
                visibleLine,
                x: size.width / 2 - 280,
                y: y,
                scale: 4,
                color: color,
                size: size
            )
            menuHitFrames.append(menuRowHitFrame(yFromTop: y, size: size))
        }
        if menu.page == .hybrid {
            addText(
                "* configure in Keys Control",
                x: size.width / 2 - 280,
                y: size.height / 2 + 160,
                scale: 4,
                color: SKColor(red: 0, green: 200 / 255, blue: 0, alpha: 1),
                size: size
            )
        }
        renderMenuMeters(menu, lineYs: layout.lineYs, frame: frame, size: size)
        let targetY = layout.lineYs[menu.selection] + 20
        addTarget(
            at: CGPoint(x: size.width / 2 - 300, y: size.height - targetY),
            frame: frame,
            size: 4
        )
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

    private func renderCapturedMenuBackground(for menu: OriginalMenuModel, size: CGSize) {
        guard menu.openedDuringGame,
              menu.page != .dualAnalog,
              let menuBackgroundTexture else { return }
        let originalScale: CGFloat = switch menu.page {
        case .options: 0.9
        case .confirmExit, .confirmEndGame, .confirmKeepVideo, .confirmKeepGame,
             .settings: 0.8
        case .video, .game, .audio, .controller: 0.7
        case .hybrid, .mouse, .keyboard, .joypad: 0.6
        case .dualAnalog: 1
        }
        let sprite = SKSpriteNode(texture: menuBackgroundTexture)
        sprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sprite.size = CGSize(width: size.width * originalScale, height: size.height * originalScale)
        sprite.color = SKColor(red: 64 / 255, green: 64 / 255, blue: 128 / 255, alpha: 1)
        sprite.colorBlendFactor = 1
        sprite.blendMode = .replace
        sprite.zPosition = -1
        content.addChild(sprite)
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

    private func menuLayout(for menu: OriginalMenuModel, size: CGSize) -> MenuLayout {
        let center = size.height / 2
        let spacing: CGFloat = switch menu.page {
        case .video where size.height <= 480: 32
        case .keyboard where size.height < 600: 32
        default: 40
        }
        let titleOffset: CGFloat
        let lineMultipliers: [CGFloat]
        switch menu.page {
        case .options:
            titleOffset = -3
            lineMultipliers = menu.openedDuringGame ? [-1, 0, 1, 2] : [-1, 0, 1]
        case .confirmExit, .confirmEndGame, .confirmKeepVideo, .confirmKeepGame:
            titleOffset = -2
            lineMultipliers = [0, 1]
        case .settings:
            titleOffset = -3
            lineMultipliers = [-1, 0, 1, 2, 3]
        case .video:
            titleOffset = -6
            lineMultipliers = Array(-4...6).map(CGFloat.init)
        case .game:
            titleOffset = -4
            lineMultipliers = Array(-2...3).map(CGFloat.init)
        case .audio:
            titleOffset = -2
            lineMultipliers = Array(0...3).map(CGFloat.init)
        case .controller:
            titleOffset = -2
            lineMultipliers = Array(0...2).map(CGFloat.init)
        case .hybrid:
            titleOffset = -3
            lineMultipliers = Array(-1...3).map(CGFloat.init)
        case .mouse:
            titleOffset = -3
            lineMultipliers = Array(-1...2).map(CGFloat.init)
        case .keyboard:
            titleOffset = -6
            lineMultipliers = Array(-4...5).map(CGFloat.init)
        case .joypad:
            titleOffset = -4
            lineMultipliers = [-2, -1, 0, 1, 2, 2, 3, 4]
        case .dualAnalog:
            titleOffset = 0
            lineMultipliers = []
        }
        return MenuLayout(
            titleY: center + titleOffset * spacing,
            lineYs: lineMultipliers.map { center + $0 * spacing }
        )
    }

    private func menuColor(selected: Bool, frame: Int) -> SKColor {
        selected
            ? SKColor(red: 1, green: 1, blue: CGFloat((frame * 8) % 255) / 255, alpha: 1)
            : SKColor(red: 0, green: 200 / 255, blue: 0, alpha: 1)
    }

    private func menuRowHitFrame(yFromTop: CGFloat, size: CGSize) -> CGRect {
        CGRect(x: 0, y: size.height - yFromTop - 20, width: size.width, height: 20)
    }

    private func renderJoypadMenu(
        _ menu: OriginalMenuModel,
        frame: Int,
        lineYs: [CGFloat],
        size: CGSize
    ) {
        for index in 0...2 {
            addText(
                menu.lines[index],
                x: size.width / 2 - 280,
                y: lineYs[index],
                scale: 4,
                color: menuColor(selected: menu.selection == index, frame: frame),
                size: size
            )
        }

        let buttonValues = [
            menu.settings.joypadButtons[3],
            menu.settings.joypadButtons[0],
            menu.settings.joypadButtons[2],
            menu.settings.joypadButtons[1],
        ]
        let buttonFrames = [
            CGRect(x: size.width / 2 + 64, y: size.height / 2 + 40, width: 40, height: 30),
            CGRect(x: size.width / 2, y: size.height / 2 + 80, width: 40, height: 30),
            CGRect(x: size.width / 2 + 128, y: size.height / 2 + 80, width: 40, height: 30),
            CGRect(x: size.width / 2 + 64, y: size.height / 2 + 120, width: 40, height: 30),
        ]
        for offset in 0..<4 {
            let index = offset + 3
            let box = buttonFrames[offset]
            let color = menuColor(selected: menu.selection == index, frame: frame)
            addRectangle(
                x: box.minX,
                yFromTop: box.minY,
                width: box.width,
                height: box.height,
                color: color,
                filled: false,
                size: size
            )
            addText(
                String(buttonValues[offset] + 1),
                x: box.minX + 8,
                y: box.minY + 8,
                scale: 3,
                color: color,
                size: size
            )
        }
        addText(
            menu.lines[7],
            x: size.width / 2 - 280,
            y: lineYs[7],
            scale: 4,
            color: menuColor(selected: menu.selection == 7, frame: frame),
            size: size
        )

        menuHitFrames = [
            menuRowHitFrame(yFromTop: lineYs[0], size: size),
            menuRowHitFrame(yFromTop: lineYs[1], size: size),
            menuRowHitFrame(yFromTop: lineYs[2], size: size),
        ] + buttonFrames.map {
            CGRect(x: $0.minX, y: size.height - $0.minY - $0.height, width: $0.width, height: $0.height)
        } + [menuRowHitFrame(yFromTop: lineYs[7], size: size)]

        let targetPosition: CGPoint
        switch menu.selection {
        case 3...6:
            let box = buttonFrames[menu.selection - 3]
            targetPosition = CGPoint(x: box.minX - 20, y: size.height - box.minY - 20)
        default:
            let y = lineYs[menu.selection] + 20
            targetPosition = CGPoint(x: size.width / 2 - 300, y: size.height - y)
        }
        addTarget(at: targetPosition, frame: frame, size: 4)
    }

    private func renderVideoPickers(
        _ menu: OriginalMenuModel,
        lineYs: [CGFloat],
        size: CGSize
    ) {
        let centerX = size.width / 2 + 74
        for (index, frame) in [(8, 1), (9, 0)] {
            let sprite = SKSpriteNode(texture: OriginalGraphics.commonFrameTexture(
                sheet: "colourpick",
                frame: frame,
                columns: 1,
                rows: 3
            ))
            sprite.position = CGPoint(x: centerX, y: size.height - lineYs[index] - 14)
            sprite.setScale(2)
            content.addChild(sprite)
            if menu.selection == index {
                let overlay = SKSpriteNode(texture: OriginalGraphics.commonFrameTexture(
                    sheet: "colourpick",
                    frame: 2,
                    columns: 1,
                    rows: 3
                ))
                overlay.position = sprite.position
                overlay.setScale(2)
                content.addChild(overlay)
            }
        }
        let markerColor = SKColor(red: 100 / 255, green: 1, blue: 100 / 255, alpha: 1)
        addRectangle(
            x: size.width / 2 - 46 + CGFloat(menu.settings.gridColorPosition * 2),
            yFromTop: lineYs[8] + 20,
            width: 2,
            height: 8,
            color: markerColor,
            filled: true,
            size: size
        )
        addRectangle(
            x: size.width / 2 - 46 + CGFloat(menu.settings.gridBrightness * 2),
            yFromTop: lineYs[9] + 20,
            width: 2,
            height: 8,
            color: markerColor,
            filled: true,
            size: size
        )
    }

    private func renderDualAnalogMenu(
        _ menu: OriginalMenuModel,
        frame: Int,
        size: CGSize
    ) {
        background.alpha = 1
        let originX = (size.width - 640) / 2
        let originY = (size.height - 480) / 2
        let white = SKColor.white
        let gray = SKColor(white: 0.5, alpha: 1)
        let darkBlue = SKColor(red: 35 / 255, green: 65 / 255, blue: 115 / 255, alpha: 1)
        let borderBlue = SKColor(red: 0, green: 0, blue: 100 / 255, alpha: 1)

        func textLine(_ text: String, _ x: CGFloat, _ y: CGFloat, color: SKColor = .white, scale: CGFloat = 1.35) {
            addText(text, x: originX + x, y: originY + y, scale: scale, color: color, size: size)
        }
        func rectangle(
            _ x: CGFloat,
            _ y: CGFloat,
            _ width: CGFloat,
            _ height: CGFloat,
            color: SKColor,
            filled: Bool = false,
            lineWidth: CGFloat = 1
        ) {
            addRectangle(
                x: originX + x,
                yFromTop: originY + y,
                width: width,
                height: height,
                color: color,
                filled: filled,
                size: size,
                lineWidth: lineWidth
            )
        }
        func sceneFrame(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(
                x: originX + x,
                y: size.height - originY - y - height,
                width: width,
                height: height
            )
        }

        textLine("Dual Stick Configuration", 170, 10, scale: 1.5)
        rectangle(10, 32, 600, 130, color: gray)
        let instructions = [
            "Select controller port (0 for  single joypad)",
            "others are only needed for multiple joypads.",
            "Assign controls by clicking AXIS WIZARD or individually",
            "cycle through available controls by left clicking on the axis box.",
            "Right click on a box to toggle invert On or Off.",
            "Blue box is normal, Orange box indicates an inverted axis.",
            "Click on Stick 1/2 boxes and use cursor keys to adjust centering and",
            "Dead Zone.  Make sure the red dot is in the green square when at rest.",
            "If it drifts, press SHIFT+Cursor Keys to adjust Dead Zone.",
        ]
        for (index, instruction) in instructions.enumerated() {
            textLine(instruction, 15, 35 + CGFloat(index * 12), scale: 1.15)
        }

        for port in 0..<4 {
            let x = CGFloat(110 + port * 50)
            if menu.settings.dualAnalogPort == port {
                rectangle(x, 175, 45, 25, color: darkBlue, filled: true)
            }
            rectangle(x, 175, 45, 25, color: borderBlue)
            textLine(String(port), x + 17, 183, scale: 1.2)
        }
        textLine("Controller:", 10, 180, scale: 1.2)

        rectangle(10, 225, 135, 25, color: white)
        textLine("AXIS WIZARD", 25, 230, scale: 1.2)
        rectangle(180, 225, 100, 25, color: white)
        textLine("OPTION = \(menu.settings.dualAnalogOptionButton + 1)", 190, 230, scale: 1.05)
        rectangle(320, 225, 100, 25, color: white)
        textLine("BOMB = \(menu.settings.dualAnalogBombButton + 1)", 330, 230, scale: 1.05)

        let axes = menu.settings.dualAnalogAxes
        let inverted = menu.settings.dualAnalogInverted
        let axisBoxes = [
            CGRect(x: 10, y: 395, width: 175, height: 14),
            CGRect(x: 10, y: 415, width: 175, height: 14),
            CGRect(x: 250, y: 395, width: 175, height: 14),
            CGRect(x: 250, y: 415, width: 175, height: 14),
        ]
        let axisLabels = ["X axis", "Y axis", "X axis", "Y axis"]
        let joyLabels = [
            "null", "JoyX()", "JoyY()", "JoyZ()", "JoyR()", "JoyU()", "JoyV()",
            "JoyYaw()", "JoyPitch()", "JoyRoll()", "JoyHat()", "JoyWheel()",
            "JoyAxis12()", "JoyAxis13()", "JoyAxis14()", "JoyAxis15()",
        ]
        textLine("Stick 1", 10, 380, scale: 1.2)
        textLine("Stick 2", 250, 380, scale: 1.2)
        for index in 0..<4 {
            let box = axisBoxes[index]
            let axisColor = inverted[index]
                ? SKColor(red: 1, green: 128 / 255, blue: 0, alpha: 1)
                : SKColor(red: 50 / 255, green: 65 / 255, blue: 220 / 255, alpha: 1)
            rectangle(box.minX, box.minY, box.width, box.height, color: axisColor, filled: true)
            let axis = min(15, max(0, axes[index]))
            textLine("\(axisLabels[index]): \(joyLabels[axis])", box.minX + 10, box.minY + 1, scale: 1.05)
        }

        let centers = menu.settings.dualAnalogCenter
        let deadZones = menu.settings.dualAnalogDeadZone
        for stick in 0..<2 {
            let boxX = CGFloat(stick == 0 ? 10 : 250)
            let valueX = stick * 2
            rectangle(boxX + 42, 317, 16, 16, color: .green)
            rectangle(boxX, 275, 100, 100, color: white)
            rectangle(
                boxX + 45 - centers[valueX] * 50,
                320 - centers[valueX + 1] * 50,
                10,
                10,
                color: SKColor(red: 185 / 255, green: 0, blue: 0, alpha: 1),
                filled: true
            )
            let valueXPosition = stick == 0 ? CGFloat(120) : 360
            textLine("DZ \(stick + 1)", valueXPosition, 270, color: .red, scale: 1.1)
            textLine("X: \(String(format: "%.2f", Double(deadZones[valueX])))", valueXPosition, 290, color: .blue, scale: 1.0)
            textLine("Y: \(String(format: "%.2f", Double(deadZones[valueX + 1])))", valueXPosition, 305, color: .blue, scale: 1.0)
            textLine("C \(stick + 1)", valueXPosition, 330, color: .red, scale: 1.1)
            textLine("X: \(String(format: "%.2f", Double(centers[valueX])))", valueXPosition, 350, color: .blue, scale: 1.0)
            textLine("Y: \(String(format: "%.2f", Double(centers[valueX + 1])))", valueXPosition, 365, color: .blue, scale: 1.0)
        }

        let scaleValues = menu.settings.dualAnalogScale
        for axis in 0..<4 {
            let rightStick = axis >= 2
            let xBase: CGFloat = rightStick ? 250 : 10
            let y: CGFloat = axis % 2 == 0 ? 455 : 495
            textLine(axis % 2 == 0 ? "X Scaling Factor" : "Y Scaling Factor", xBase, y - 15, scale: 1.1)
            let choices: [CGFloat] = [1, 180, 255]
            for choice in 0..<3 {
                let x = xBase + CGFloat(choice * 50)
                if scaleValues[axis] == choices[choice] {
                    rectangle(x, y, 45, 20, color: darkBlue, filled: true)
                }
                rectangle(x, y, 45, 20, color: borderBlue)
                textLine(["1", "180", "255"][choice], x + CGFloat(choice == 0 ? 17 : 10), y + 5, scale: 1.0)
            }
        }

        let commandLabels = ["(D)ebug", "(S)ave Config", "(L)oad Config", "(E)xit"]
        for (index, label) in commandLabels.enumerated() {
            rectangle(490, 315 + CGFloat(index * 25), 110, 20, color: SKColor(white: 0.25, alpha: 1), filled: true)
            textLine(label, 493, 317 + CGFloat(index * 25), scale: 1.05)
        }

        menuHitFrames = Array(repeating: .null, count: menu.lines.count)
        menuHitFrames[0] = sceneFrame(110, 175, 195, 25)
        for index in 0..<4 {
            let box = axisBoxes[index]
            menuHitFrames[index + 1] = sceneFrame(box.minX, box.minY, box.width, box.height)
        }
        menuHitFrames[9] = sceneFrame(10, 455, 145, 20)
        menuHitFrames[10] = sceneFrame(10, 495, 145, 20)
        menuHitFrames[11] = sceneFrame(250, 455, 145, 20)
        menuHitFrames[12] = sceneFrame(250, 495, 145, 20)
        menuHitFrames[13] = sceneFrame(10, 275, 100, 100)
        menuHitFrames[15] = sceneFrame(250, 275, 100, 100)
        menuHitFrames[21] = sceneFrame(180, 225, 100, 25)
        menuHitFrames[22] = sceneFrame(320, 225, 100, 25)
        menuHitFrames[23] = sceneFrame(490, 390, 110, 20)

        let highlightFrame: CGRect = switch menu.selection {
        case 0: sceneFrame(110, 175, 195, 25)
        case 1...4: sceneFrame(
            axisBoxes[menu.selection - 1].minX,
            axisBoxes[menu.selection - 1].minY,
            axisBoxes[menu.selection - 1].width,
            axisBoxes[menu.selection - 1].height
        )
        case 5...8: sceneFrame(
            axisBoxes[menu.selection - 5].minX,
            axisBoxes[menu.selection - 5].minY,
            axisBoxes[menu.selection - 5].width,
            axisBoxes[menu.selection - 5].height
        )
        case 9: sceneFrame(10, 455, 145, 20)
        case 10: sceneFrame(10, 495, 145, 20)
        case 11: sceneFrame(250, 455, 145, 20)
        case 12: sceneFrame(250, 495, 145, 20)
        case 13, 14, 17, 18: sceneFrame(10, 275, 100, 100)
        case 15, 16, 19, 20: sceneFrame(250, 275, 100, 100)
        case 21: sceneFrame(180, 225, 100, 25)
        case 22: sceneFrame(320, 225, 100, 25)
        default: sceneFrame(490, 390, 110, 20)
        }
        let highlight = SKShapeNode(rect: highlightFrame.insetBy(dx: -2, dy: -2))
        highlight.strokeColor = menuColor(selected: true, frame: frame)
        highlight.lineWidth = 2
        highlight.fillColor = .clear
        content.addChild(highlight)
        addTarget(
            at: CGPoint(x: highlightFrame.minX - 8, y: highlightFrame.midY),
            frame: frame,
            size: 4
        )
    }

    private func addRectangle(
        x: CGFloat,
        yFromTop: CGFloat,
        width: CGFloat,
        height: CGFloat,
        color: SKColor,
        filled: Bool,
        size: CGSize,
        lineWidth: CGFloat = 1
    ) {
        let rectangle = SKShapeNode(rect: CGRect(
            x: x,
            y: size.height - yFromTop - height,
            width: width,
            height: height
        ))
        rectangle.fillColor = filled ? color : .clear
        rectangle.strokeColor = filled ? .clear : color
        rectangle.lineWidth = lineWidth
        content.addChild(rectangle)
    }

    private func renderMenuMeters(
        _ menu: OriginalMenuModel,
        lineYs: [CGFloat],
        frame: Int,
        size: CGSize
    ) {
        let meters: [(index: Int, value: CGFloat, x: CGFloat, width: CGFloat)]
        switch menu.page {
        case .audio:
            meters = [
                (0, menu.settings.soundEffectsVolume, size.width / 2, 202),
                (1, menu.settings.musicVolume, size.width / 2, 202),
            ]
        case .game:
            meters = [(4, menu.settings.inertia, size.width / 2 - 120, 302)]
        case .hybrid:
            meters = [(3, menu.settings.mouseSensitivity, size.width / 2 + 100, 202)]
        case .mouse:
            meters = [(2, menu.settings.mouseSensitivity, size.width / 2 + 100, 202)]
        default:
            meters = []
        }
        for meter in meters {
            let y = lineYs[meter.index]
            let selected = menu.selection == meter.index
            let fillColor = SKColor(
                red: 0,
                green: selected ? 200 / 255 : 100 / 255,
                blue: 0,
                alpha: 1
            )
            addRectangle(
                x: meter.x + 1,
                yFromTop: y + 1,
                width: max(0, min(1, meter.value)) * (meter.width - 2),
                height: 22,
                color: fillColor,
                filled: true,
                size: size
            )
            addRectangle(
                x: meter.x,
                yFromTop: y,
                width: meter.width,
                height: 24,
                color: menuColor(selected: selected, frame: frame),
                filled: false,
                size: size
            )
        }
        if menu.page == .video {
            renderVideoPickers(menu, lineYs: lineYs, size: size)
        }
    }

    private func addTarget(at position: CGPoint, frame: Int, size targetSize: CGFloat) {
        let path = CGMutablePath()
        let radius = targetSize * sqrt(2)
        for angleOffset in stride(from: 0, to: 180, by: 45) {
            let angle = CGFloat(frame * 8 + angleOffset + 45) * .pi / 180
            let dx = cos(angle) * radius
            let dy = sin(angle) * radius
            path.move(to: CGPoint(x: position.x - dx, y: position.y - dy))
            path.addLine(to: CGPoint(x: position.x + dx, y: position.y + dy))
        }
        let target = SKShapeNode(path: path)
        target.strokeColor = frame % 30 > 14
            ? SKColor(red: 1, green: 1, blue: 32 / 255, alpha: 1)
            : SKColor(red: 1, green: 32 / 255, blue: 32 / 255, alpha: 1)
        target.lineWidth = 2
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
        if scoreTrailFrame == -1 || (scoreTrailFrame >= 0 && frame != scoreTrailFrame + 1) {
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
