import CoreGraphics
import Foundation

enum OriginalAttractPage: Int, CaseIterable, Equatable {
    case title
    case scores
    case friends
    case enemies

    var durationFrames: Int {
        switch self {
        case .title, .friends, .enemies: 900
        case .scores: 750
        }
    }

    var next: OriginalAttractPage {
        switch self {
        case .title: .scores
        case .scores: .friends
        case .friends: .enemies
        case .enemies: .title
        }
    }
}

enum OriginalRunPhase: Equatable {
    case attract(OriginalAttractPage)
    case playing
    case gameOver
}

enum OriginalMenuCapture: String, CaseIterable, Equatable {
    case options
    case optionsGame = "options-game"
    case confirmExit = "confirm-exit"
    case confirmEndGame = "confirm-end-game"
    case confirmKeepVideo = "confirm-keep-video"
    case confirmKeepGame = "confirm-keep-game"
    case settings
    case video
    case game
    case audio
    case controller
    case hybrid
    case mouse
    case keyboard
    case joypad
    case dualAnalog = "dual-analog"
}

enum OriginalCaptureSubject: Equatable {
    case attract(OriginalAttractPage, frame: Int)
    case gameplay
    case enemy(OriginalEnemyKind)
    case generator(OriginalEnemyKind)
    case powerUp(PowerUpKind)
    case grid(Int)
    case particleStyle(Int)
    case graphicsSet(OriginalGraphicsSet)
    case getReady(frame: Int)
    case death
    case gameOver(frame: Int)
    case highScoreEntry
    case hudDefault
    case hudUpgraded
    case powerUpMessage
    case menu(OriginalMenuCapture)

    var hidesArenaBorder: Bool {
        switch self {
        case .grid, .particleStyle: true
        default: false
        }
    }
}

struct OriginalCaptureScenario: Equatable {
    let name: String
    let subject: OriginalCaptureSubject

    init?(name: String) {
        guard let scenario = Self.all.first(where: { $0.name == name.lowercased() }) else {
            return nil
        }
        self = scenario
    }

    private init(_ name: String, _ subject: OriginalCaptureSubject) {
        self.name = name
        self.subject = subject
    }

    static let all: [OriginalCaptureScenario] = {
        var scenarios: [OriginalCaptureScenario] = [
            .init("title", .attract(.title, frame: 600)),
            .init("scores", .attract(.scores, frame: 600)),
            .init("friends", .attract(.friends, frame: 600)),
            .init("enemies", .attract(.enemies, frame: 600)),
            .init("gameplay", .gameplay),
            .init("get-ready-title", .getReady(frame: 29)),
            .init("get-ready-rings", .getReady(frame: 79)),
            .init("death", .death),
            .init("game-over", .gameOver(frame: 89)),
            .init("high-score-entry", .highScoreEntry),
            .init("hud-default", .hudDefault),
            .init("hud-upgraded", .hudUpgraded),
            .init("power-up-message", .powerUpMessage),
        ]

        let enemies: [(String, OriginalEnemyKind)] = [
            ("pinwheel", .pinwheel), ("diamond", .diamond),
            ("green-square", .greenSquare), ("cube", .cube),
            ("seeker", .seeker), ("black-hole", .blackHole),
            ("triangle", .triangle), ("snake", .snake),
            ("interceptor", .interceptor), ("butterfly", .butterfly),
        ]
        scenarios += enemies.map { .init("enemy-\($0.0)", .enemy($0.1)) }
        scenarios += enemies.map { .init("generator-\($0.0)", .generator($0.1)) }

        let powerUps: [(String, PowerUpKind)] = [
            ("reverse", .reverseShooter), ("side", .sideShooters),
            ("cannon", .extraCannon), ("faster", .fasterShots),
            ("player", .extraPlayer), ("bomb", .extraBomb),
            ("shield", .shield), ("super", .superShots),
            ("bouncy", .bouncyShots),
        ]
        scenarios += powerUps.map { .init("powerup-\($0.0)", .powerUp($0.1)) }
        scenarios += (0..<21).map {
            .init(String(format: "grid-%02d", $0), .grid($0))
        }
        scenarios += (0...3).map { .init("particle-\($0)", .particleStyle($0)) }

        let graphicsSets: [(String, OriginalGraphicsSet)] = [
            ("solid", .solid), ("low", .low), ("medium", .medium),
            ("high", .high), ("user", .user),
        ]
        scenarios += graphicsSets.map { .init("graphics-\($0.0)", .graphicsSet($0.1)) }
        scenarios += OriginalMenuCapture.allCases.map { .init($0.rawValue, .menu($0)) }
        return scenarios
    }()
}

struct OriginalScreenFlow: Equatable {
    private(set) var phase: OriginalRunPhase = .attract(.title)
    private(set) var frame = 0
    private(set) var persistentTitleFrame = 0

    @discardableResult
    mutating func advance() -> Bool {
        switch phase {
        case let .attract(page):
            frame += 1
            if page == .title {
                persistentTitleFrame = min(600, persistentTitleFrame + 1)
            }
            guard frame >= page.durationFrames else { return false }
            phase = .attract(page.next)
            frame = 0
            return true
        case .gameOver:
            frame += 1
            guard frame >= 179 else { return false }
            phase = .attract(.scores)
            frame = 0
            return true
        case .playing:
            return false
        }
    }

    mutating func startGame() {
        phase = .playing
        frame = 0
    }

    mutating func showGameOver() {
        phase = .gameOver
        frame = 0
    }

    mutating func skipGameOver() {
        guard phase == .gameOver else { return }
        phase = .attract(.scores)
        frame = 0
    }

    mutating func returnToTitle() {
        phase = .attract(.title)
        frame = 0
    }

    mutating func configureCapture(
        page: OriginalAttractPage,
        frame: Int,
        persistentTitleFrame: Int = 600
    ) {
        phase = .attract(page)
        self.frame = max(0, frame)
        self.persistentTitleFrame = min(600, max(0, persistentTitleFrame))
    }
}

enum OriginalControllerType: Int, CaseIterable, Codable {
    case dualAnalog
    case mouse
    case keyboard
    case joypad
    case hybrid

    var title: String {
        switch self {
        case .dualAnalog: "Dual Analog"
        case .mouse: "Mouse"
        case .keyboard: "Keyboard"
        case .joypad: "Joypad"
        case .hybrid: "Hybrid"
        }
    }
}

struct OriginalJoyPortSettings: Equatable, Codable {
    var axes = [1, 2, 4, 3]
    var inversion = [1, 1, 1, 1]
    var scale: [CGFloat] = [1, 1, 1, 1]
    var center: [CGFloat] = [0, 0, 0, 0]
    var deadZone: [CGFloat] = [0, 0, 0, 0]
    var optionButton = 1
    var bombButton = 2
}

struct OriginalRuntimeSettings: Equatable, Codable {
    struct ScreenMode: Equatable {
        let description: String
        let size: CGSize
    }

    static let maximumStars = 10_000
    static let playfieldSizes: [CGSize] = [
        CGSize(width: 1_024, height: 768),
        CGSize(width: 512, height: 384),
        CGSize(width: 640, height: 480),
        CGSize(width: 720, height: 400),
        CGSize(width: 720, height: 480),
        CGSize(width: 720, height: 576),
        CGSize(width: 800, height: 600),
        CGSize(width: 1_024, height: 720),
        CGSize(width: 1_024, height: 768),
        CGSize(width: 1_152, height: 864),
        CGSize(width: 1_152, height: 870),
        CGSize(width: 1_280, height: 720),
        CGSize(width: 1_280, height: 768),
        CGSize(width: 1_280, height: 800),
        CGSize(width: 1_280, height: 854),
        CGSize(width: 1_280, height: 960),
        CGSize(width: 1_280, height: 1_024),
        CGSize(width: 1_440, height: 900),
        CGSize(width: 1_400, height: 1_050),
        CGSize(width: 1_600, height: 1_024),
        CGSize(width: 1_600, height: 1_200),
        CGSize(width: 1_600, height: 1_280),
        CGSize(width: 1_680, height: 1_050),
        CGSize(width: 1_800, height: 1_440),
        CGSize(width: 1_920, height: 1_080),
        CGSize(width: 1_920, height: 1_200),
        CGSize(width: 2_048, height: 768),
        CGSize(width: 2_048, height: 1_536),
        CGSize(width: 2_560, height: 1_024),
        CGSize(width: 2_560, height: 1_600),
        CGSize(width: 2_560, height: 2_048),
        CGSize(width: 3_200, height: 2_048),
        CGSize(width: 3_200, height: 2_400),
        CGSize(width: 3_840, height: 2_400),
        CGSize(width: 5_120, height: 4_096),
    ]

    static let screenModes: [ScreenMode] = zip([
        "USER", "BWMac", "VGA", "????", "NTSCDVD", "PALDVD", "SVGA",
        "XGA-", "XGA", "XGA+", "XGA++", "720p", "WXGA", "WXGA+",
        "WXGA++", "WXGA+++", "SXGA", "WSXGA", "SXGA+", "WSXGA",
        "UXGA", "UXGA+", "WSXGA+", "?????", "1080p", "WUXGA", "DUALW",
        "QXGA", "DUALW+", "WQXGA", "QSXGA", "WQSXGA", "QUXGA", "WQUXGA",
        "HSXGA",
    ], playfieldSizes).map {
        ScreenMode(description: $0.0, size: $0.1)
    }

    var scroll = false
    var screenSizeIndex = 8
    var playfieldSizeIndex = 0
    var screenWidth = 1_024
    var screenHeight = 768
    var playfieldWidth = 1_024
    var playfieldHeight = 768
    var graphicsSetIndex = 0
    var windowed = false
    var gridStyle = 0
    var starCount = 300
    var particleStyle = 0
    var gridColorPosition = 0
    var gridRed = 32
    var gridGreen = 80
    var gridBlue = 200
    var gridBrightness = 102
    var gridOpacity: CGFloat = 0.85
    var gridSpacing = 2
    var fullGrid = true
    var particleCount = 2_048
    var particleLife = 40
    var particleGravity = true
    var particleDecay: CGFloat = 0.95

    var difficulty = GameDifficulty.medium
    var extraLifeScores = [75_000, 100_000, 200_000]
    var extraBombScores = [100_000, 150_000, 250_000]
    var autoFire = false
    var inertia: CGFloat = 0

    var soundEffectsVolume: CGFloat = 0.5
    var musicVolume: CGFloat = 0.5
    var soundSetIndex = 0

    var controllerType = OriginalControllerType.dualAnalog
    var hybridConfiguration = 0
    var mouseFireButton = 1
    var mouseBombButton = 2
    var mouseSensitivity: CGFloat = 0.5
    var joypadConfiguration = 0
    var joypadButtons = [0, 1, 2, 3]
    var joypadBombButton = 4
    var joypadOptionButton = 0
    var keyBomb = 32
    var keyMoveLeft = 83
    var keyMoveRight = 68
    var keyMoveUp = 69
    var keyMoveDown = 88
    var keyFireLeft = 37
    var keyFireRight = 39
    var keyFireUp = 38
    var keyFireDown = 40
    var dualAnalogPort = 0
    var joyPorts = Array(repeating: OriginalJoyPortSettings(), count: 4)

    var dualAnalogAxes: [Int] {
        get { joyPorts[activeJoyPortIndex].axes }
        set { joyPorts[activeJoyPortIndex].axes = newValue }
    }

    var dualAnalogInverted: [Bool] {
        get { joyPorts[activeJoyPortIndex].inversion.map { $0 == -1 } }
        set { joyPorts[activeJoyPortIndex].inversion = newValue.map { $0 ? -1 : 1 } }
    }

    var dualAnalogScale: [CGFloat] {
        get { joyPorts[activeJoyPortIndex].scale }
        set { joyPorts[activeJoyPortIndex].scale = newValue }
    }

    var dualAnalogCenter: [CGFloat] {
        get { joyPorts[activeJoyPortIndex].center }
        set { joyPorts[activeJoyPortIndex].center = newValue }
    }

    var dualAnalogDeadZone: [CGFloat] {
        get { joyPorts[activeJoyPortIndex].deadZone }
        set { joyPorts[activeJoyPortIndex].deadZone = newValue }
    }

    var dualAnalogOptionButton: Int {
        get { joyPorts[activeJoyPortIndex].optionButton }
        set { joyPorts[activeJoyPortIndex].optionButton = newValue }
    }

    var dualAnalogBombButton: Int {
        get { joyPorts[activeJoyPortIndex].bombButton }
        set { joyPorts[activeJoyPortIndex].bombButton = newValue }
    }

    mutating func cycleGridStyle(by direction: Int = 1) {
        gridStyle = wrappedValue(gridStyle + direction, count: 21)
    }

    mutating func cycleStars(by direction: Int = 1) {
        starCount += direction * 100
        if starCount > Self.maximumStars {
            starCount = 0
        } else if starCount < 0 {
            starCount = Self.maximumStars
        }
    }

    mutating func cycleParticleStyle(by direction: Int = 1) {
        particleStyle = wrappedValue(particleStyle + direction, count: 4)
    }

    private func wrappedValue(_ value: Int, count: Int) -> Int {
        (value % count + count) % count
    }

    private var activeJoyPortIndex: Int {
        min(3, max(0, dualAnalogPort))
    }
}

enum OriginalMenuPage: Equatable {
    case options
    case confirmExit
    case confirmEndGame
    case confirmKeepVideo
    case confirmKeepGame
    case settings
    case video
    case game
    case audio
    case controller
    case hybrid
    case mouse
    case keyboard
    case joypad
    case dualAnalog
}

enum OriginalMenuOutcome: Equatable {
    case none
    case close
    case endGame
    case exitApplication
}

struct OriginalMenuModel: Equatable {
    private(set) var page = OriginalMenuPage.options
    private(set) var selection = 0
    private(set) var openedDuringGame = false
    private(set) var isOpen = false
    private(set) var awaitingKeyboardBinding = false
    private var pageStack: [OriginalMenuPage] = []
    private var settingsSnapshot: OriginalRuntimeSettings?
    var settings = OriginalRuntimeSettings()

    var runtimeSettings: OriginalRuntimeSettings {
        guard let snapshot = settingsSnapshot,
              page == .video || page == .confirmKeepVideo else { return settings }
        var result = settings
        result.scroll = snapshot.scroll
        result.playfieldSizeIndex = snapshot.playfieldSizeIndex
        result.playfieldWidth = snapshot.playfieldWidth
        result.playfieldHeight = snapshot.playfieldHeight
        result.graphicsSetIndex = snapshot.graphicsSetIndex
        result.windowed = snapshot.windowed
        return result
    }

    var isVideoTransactionPending: Bool {
        settingsSnapshot != nil && (page == .video || page == .confirmKeepVideo)
    }

    mutating func open(duringGame: Bool) {
        page = .options
        openedDuringGame = duringGame
        selection = duringGame ? 3 : 2
        isOpen = true
        awaitingKeyboardBinding = false
        pageStack = []
        settingsSnapshot = nil
    }

    mutating func close() {
        isOpen = false
        awaitingKeyboardBinding = false
        pageStack = []
        settingsSnapshot = nil
    }

    mutating func moveSelection(by delta: Int) {
        guard !awaitingKeyboardBinding else { return }
        let count = lines.count
        guard count > 0 else { return }
        selection = (selection + delta) % count
        if selection < 0 { selection += count }
    }

    mutating func select(_ index: Int) {
        guard lines.indices.contains(index) else { return }
        selection = index
    }

    mutating func adjust(by direction: Int) -> OriginalMenuOutcome {
        guard !awaitingKeyboardBinding else { return .none }
        guard direction != 0 else { return .none }
        switch page {
        case .options, .confirmExit, .confirmEndGame, .confirmKeepVideo,
             .confirmKeepGame, .settings:
            return activate()
        case .controller:
            if selection == 0 {
                settings.controllerType = cycled(settings.controllerType, by: direction)
                return .none
            }
            return activate()
        case .video:
            adjustVideo(by: direction)
        case .game:
            adjustGame(by: direction)
        case .audio:
            adjustAudio(by: direction)
        case .hybrid:
            adjustHybrid(by: direction)
        case .mouse:
            adjustMouse(by: direction)
        case .keyboard:
            if selection == 9 { return navigateBack() }
            awaitingKeyboardBinding = true
        case .joypad:
            adjustJoypad(by: direction)
        case .dualAnalog:
            adjustDualAnalog(by: direction)
        }
        return .none
    }

    mutating func activate() -> OriginalMenuOutcome {
        switch page {
        case .options:
            if selection == 0 { return navigate(to: .confirmExit) }
            if selection == 1 { return navigate(to: .settings) }
            if openedDuringGame, selection == 2 { return navigate(to: .confirmEndGame) }
            close()
            return .close
        case .confirmExit:
            if selection == 0 { return .exitApplication }
            return navigateBack()
        case .confirmEndGame:
            if selection == 0 { return .endGame }
            return navigateBack()
        case .confirmKeepVideo:
            return resolveVideoConfirmation(keepChanges: selection == 0)
        case .confirmKeepGame:
            return resolveGameConfirmation(keepChanges: selection == 0)
        case .settings:
            switch selection {
            case 0: return navigate(to: .audio)
            case 1: return navigate(to: .video)
            case 2: return navigate(to: .controller)
            case 3: return navigate(to: .game)
            default: return navigateBack()
            }
        case .controller:
            if selection == 0 {
                settings.controllerType = cycled(settings.controllerType, by: 1)
                return .none
            }
            if selection == 1 {
                let target: OriginalMenuPage = switch settings.controllerType {
                case .dualAnalog: .dualAnalog
                case .mouse: .mouse
                case .keyboard: .keyboard
                case .joypad: .joypad
                case .hybrid: .hybrid
                }
                return navigate(to: target)
            }
            return navigateBack()
        case .video:
            if selection == 10 { return finishVideoSettings() }
            return adjust(by: 1)
        case .game:
            if selection == 5 { return finishGameSettings() }
            return adjust(by: 1)
        case .audio:
            if selection == 3 { return navigateBack() }
            return adjust(by: 1)
        case .hybrid:
            if selection == 4 { return navigateBack() }
            return adjust(by: 1)
        case .mouse:
            if selection == 3 { return navigateBack() }
            return adjust(by: 1)
        case .keyboard:
            if selection == 9 { return navigateBack() }
            awaitingKeyboardBinding = true
            return .none
        case .joypad:
            if selection == 7 { return navigateBack() }
            return adjust(by: 1)
        case .dualAnalog:
            if selection == lines.count - 1 { return navigateBack() }
            return adjust(by: 1)
        }
    }

    mutating func back() -> OriginalMenuOutcome {
        if awaitingKeyboardBinding {
            awaitingKeyboardBinding = false
            return .none
        }
        if page == .options {
            close()
            return .close
        }
        if page == .confirmKeepVideo {
            return resolveVideoConfirmation(keepChanges: false)
        }
        if page == .confirmKeepGame {
            return resolveGameConfirmation(keepChanges: false)
        }
        if page == .video { return finishVideoSettings() }
        if page == .game { return finishGameSettings() }
        return navigateBack()
    }

    @discardableResult
    mutating func captureKeyboardKey(_ key: Int) -> Bool {
        guard page == .keyboard, awaitingKeyboardBinding, (8...255).contains(key) else {
            return false
        }
        switch selection {
        case 0: settings.keyMoveLeft = key
        case 1: settings.keyMoveRight = key
        case 2: settings.keyMoveUp = key
        case 3: settings.keyMoveDown = key
        case 4: settings.keyFireLeft = key
        case 5: settings.keyFireRight = key
        case 6: settings.keyFireUp = key
        case 7: settings.keyFireDown = key
        case 8: settings.keyBomb = key
        default: return false
        }
        awaitingKeyboardBinding = false
        return true
    }

    @discardableResult
    mutating func captureControllerButton(_ button: Int) -> Bool {
        guard (0...15).contains(button) else { return false }
        switch page {
        case .joypad:
            switch selection {
            case 1: settings.joypadBombButton = button
            case 2: settings.joypadOptionButton = button
            case 3...6:
                settings.joypadButtons[[3, 0, 2, 1][selection - 3]] = button
            default: return false
            }
        case .dualAnalog:
            if selection == 21 {
                settings.dualAnalogOptionButton = button
            } else if selection == 22 {
                settings.dualAnalogBombButton = button
            } else {
                return false
            }
        default:
            return false
        }
        return true
    }

    var title: String {
        switch page {
        case .options: "Options"
        case .confirmExit: "Sure?"
        case .confirmEndGame: "End Game?"
        case .confirmKeepVideo, .confirmKeepGame: "Keep Changes?"
        case .settings: "Settings"
        case .video: "Video Settings"
        case .game: "Game Settings"
        case .audio: "Audio Settings"
        case .controller: "Controller Selection"
        case .hybrid: "Hybrid Control"
        case .mouse: "Mouse Control"
        case .keyboard: "Keyboard Control"
        case .joypad: "Joypad Control"
        case .dualAnalog: "Dual Stick Configuration"
        }
    }

    var lines: [String] {
        switch page {
        case .options:
            return openedDuringGame
                ? ["Exit Program", "Settings", "End Game", "Continue"]
                : ["Exit Program", "Settings", "Continue"]
        case .confirmExit, .confirmEndGame, .confirmKeepVideo, .confirmKeepGame:
            return ["Yes", "No"]
        case .settings:
            return ["Audio", "Video", "Controls", "Game", "Done"]
        case .video:
            let screenModeIndex = min(
                max(0, settings.screenSizeIndex),
                OriginalRuntimeSettings.screenModes.count - 1
            )
            let screenMode = OriginalRuntimeSettings.screenModes[screenModeIndex]
            let playfield = Self.sizeText(
                OriginalRuntimeSettings.playfieldSizes[settings.playfieldSizeIndex]
            )
            return [
                "Scroll: \(onOff(settings.scroll))",
                "Screen Size: \(screenModeIndex + 1)/\(OriginalRuntimeSettings.screenModes.count - 1) \(screenMode.description) (\(Self.sizeText(screenMode.size)))",
                "Playfield Size: \(settings.playfieldSizeIndex + 1)/\(OriginalRuntimeSettings.playfieldSizes.count - 1) \(playfield)",
                "Gfx Set: \(["Solid", "Low", "Med", "High", "User"][settings.graphicsSetIndex])",
                "Windowed: \(onOff(settings.windowed))",
                "Grid Style: \(settings.gridStyle)",
                "Number of Stars: \(settings.starCount)",
                "Particle Style: \(settings.particleStyle)",
                "Grid Colour: \(settings.gridColorPosition)",
                "Grid Bright: \(Int(settings.gridOpacity * 100))",
                "Done",
            ]
        case .game:
            let difficulty = settings.difficulty.rawValue
            return [
                "Starting Level: \(settings.difficulty.title)",
                "Free Player: \(settings.extraLifeScores[difficulty])",
                "Free Bomb: \(settings.extraBombScores[difficulty])",
                "AutoFire: \(onOff(settings.autoFire))",
                "Inertia:",
                "Done",
            ]
        case .audio:
            return [
                "SFX Volume:",
                "Music Volume:",
                "Sound Set: \(settings.soundSetIndex == 0 ? "Original" : "User")",
                "Done",
            ]
        case .controller:
            return ["Type: \(settings.controllerType.title)", "Configure Controls", "Done"]
        case .hybrid:
            let mode = [
                "Move: Keys* - Aim: Mouse Relative",
                "Move: Mouse - Fire: Keys*",
                "Move: Keys* - Aim: Mouse Centered",
            ][settings.hybridConfiguration]
            return [
                mode,
                "Fire: \(mouseButton(settings.mouseFireButton)) Mouse Button",
                "Bomb: \(mouseButton(settings.mouseBombButton)) Mouse Button",
                "Mouse Sensitivity:",
                "Done",
            ]
        case .mouse:
            return [
                "Fire: \(mouseButton(settings.mouseFireButton)) Mouse Button",
                "Bomb: \(mouseButton(settings.mouseBombButton)) Mouse Button",
                "Mouse Sensitivity:",
                "Done",
            ]
        case .keyboard:
            return [
                keyboardLine("Move Left ", key: settings.keyMoveLeft, index: 0),
                keyboardLine("Move Right", key: settings.keyMoveRight, index: 1),
                keyboardLine("Move Up   ", key: settings.keyMoveUp, index: 2),
                keyboardLine("Move Down ", key: settings.keyMoveDown, index: 3),
                keyboardLine("Fire Left ", key: settings.keyFireLeft, index: 4),
                keyboardLine("Fire Right", key: settings.keyFireRight, index: 5),
                keyboardLine("Fire Up   ", key: settings.keyFireUp, index: 6),
                keyboardLine("Fire Down ", key: settings.keyFireDown, index: 7),
                keyboardLine("Bomb", key: settings.keyBomb, index: 8),
                "Done",
            ]
        case .joypad:
            let mapping = settings.joypadConfiguration == 0
                ? "Move: D Pad  Fire: 4-Buttons"
                : "Move: 4-Buttons  Fire: D Pad"
            return [
                mapping,
                "Bomb: Button [\(settings.joypadBombButton + 1)]",
                "Option: Button [\(settings.joypadOptionButton + 1)]",
                "Up: Button [\(settings.joypadButtons[3] + 1)]",
                "Left: Button [\(settings.joypadButtons[0] + 1)]",
                "Right: Button [\(settings.joypadButtons[2] + 1)]",
                "Down: Button [\(settings.joypadButtons[1] + 1)]",
                "Done",
            ]
        case .dualAnalog:
            let axes = settings.dualAnalogAxes
            let inversion = settings.dualAnalogInverted
            let scale = settings.dualAnalogScale
            let center = settings.dualAnalogCenter
            let deadZone = settings.dualAnalogDeadZone
            return [
                "Controller: \(settings.dualAnalogPort)",
                "Stick 1 X axis: \(axisTitle(axes[0]))",
                "Stick 1 Y axis: \(axisTitle(axes[1]))",
                "Stick 2 X axis: \(axisTitle(axes[2]))",
                "Stick 2 Y axis: \(axisTitle(axes[3]))",
                "Stick 1 X invert: \(onOff(inversion[0]))",
                "Stick 1 Y invert: \(onOff(inversion[1]))",
                "Stick 2 X invert: \(onOff(inversion[2]))",
                "Stick 2 Y invert: \(onOff(inversion[3]))",
                "Stick 1 X scale: \(Int(scale[0]))",
                "Stick 1 Y scale: \(Int(scale[1]))",
                "Stick 2 X scale: \(Int(scale[2]))",
                "Stick 2 Y scale: \(Int(scale[3]))",
                "Stick 1 X center: \(formattedAxisValue(center[0]))",
                "Stick 1 Y center: \(formattedAxisValue(center[1]))",
                "Stick 2 X center: \(formattedAxisValue(center[2]))",
                "Stick 2 Y center: \(formattedAxisValue(center[3]))",
                "Stick 1 X dead zone: \(formattedAxisValue(deadZone[0]))",
                "Stick 1 Y dead zone: \(formattedAxisValue(deadZone[1]))",
                "Stick 2 X dead zone: \(formattedAxisValue(deadZone[2]))",
                "Stick 2 Y dead zone: \(formattedAxisValue(deadZone[3]))",
                "Option = \(settings.dualAnalogOptionButton + 1)",
                "Bomb = \(settings.dualAnalogBombButton + 1)",
                "Done",
            ]
        }
    }

    private mutating func navigate(to target: OriginalMenuPage) -> OriginalMenuOutcome {
        pageStack.append(page)
        if target == .video || target == .game {
            settingsSnapshot = settings
        }
        page = target
        selection = defaultSelection(for: target)
        awaitingKeyboardBinding = false
        return .none
    }

    private mutating func navigateBack() -> OriginalMenuOutcome {
        guard let previous = pageStack.popLast() else {
            close()
            return .close
        }
        page = previous
        selection = defaultSelection(for: previous)
        awaitingKeyboardBinding = false
        return .none
    }

    private func defaultSelection(for page: OriginalMenuPage) -> Int {
        switch page {
        case .options: openedDuringGame ? 3 : 2
        case .confirmExit, .confirmEndGame, .confirmKeepVideo, .confirmKeepGame: 1
        case .settings: 4
        case .video: 10
        case .game: 5
        case .audio: 3
        case .controller: 2
        case .hybrid: 4
        case .mouse: 3
        case .keyboard: 9
        case .joypad: 7
        case .dualAnalog: 23
        }
    }

    private mutating func finishVideoSettings() -> OriginalMenuOutcome {
        guard let snapshot = settingsSnapshot else { return navigateBack() }
        let requiresConfirmation = snapshot.scroll != settings.scroll
            || snapshot.playfieldSizeIndex != settings.playfieldSizeIndex
            || snapshot.playfieldWidth != settings.playfieldWidth
            || snapshot.playfieldHeight != settings.playfieldHeight
            || snapshot.graphicsSetIndex != settings.graphicsSetIndex
            || snapshot.windowed != settings.windowed
        guard requiresConfirmation else {
            settingsSnapshot = nil
            return navigateBack()
        }
        page = .confirmKeepVideo
        selection = 1
        awaitingKeyboardBinding = false
        return .none
    }

    private mutating func finishGameSettings() -> OriginalMenuOutcome {
        guard let snapshot = settingsSnapshot else { return navigateBack() }
        let oldDifficulty = snapshot.difficulty.rawValue
        let currentDifficulty = settings.difficulty.rawValue
        let requiresConfirmation = snapshot.difficulty != settings.difficulty
            || snapshot.extraLifeScores[oldDifficulty] != settings.extraLifeScores[currentDifficulty]
            || snapshot.extraBombScores[oldDifficulty] != settings.extraBombScores[currentDifficulty]
            || snapshot.autoFire != settings.autoFire
            || snapshot.inertia != settings.inertia
        guard requiresConfirmation else {
            settingsSnapshot = nil
            return navigateBack()
        }
        page = .confirmKeepGame
        selection = 1
        awaitingKeyboardBinding = false
        return .none
    }

    private mutating func resolveVideoConfirmation(keepChanges: Bool) -> OriginalMenuOutcome {
        if !keepChanges, let snapshot = settingsSnapshot {
            settings.scroll = snapshot.scroll
            settings.playfieldSizeIndex = snapshot.playfieldSizeIndex
            settings.playfieldWidth = snapshot.playfieldWidth
            settings.playfieldHeight = snapshot.playfieldHeight
            settings.graphicsSetIndex = snapshot.graphicsSetIndex
            settings.windowed = snapshot.windowed
        }
        settingsSnapshot = nil
        if keepChanges, openedDuringGame { return .endGame }
        return navigateBack()
    }

    private mutating func resolveGameConfirmation(keepChanges: Bool) -> OriginalMenuOutcome {
        if !keepChanges, let snapshot = settingsSnapshot {
            let oldDifficulty = snapshot.difficulty.rawValue
            settings.difficulty = snapshot.difficulty
            settings.extraLifeScores[oldDifficulty] = snapshot.extraLifeScores[oldDifficulty]
            settings.extraBombScores[oldDifficulty] = snapshot.extraBombScores[oldDifficulty]
            settings.autoFire = snapshot.autoFire
            settings.inertia = snapshot.inertia
        }
        settingsSnapshot = nil
        if keepChanges, openedDuringGame { return .endGame }
        return navigateBack()
    }

    private mutating func adjustVideo(by direction: Int) {
        switch selection {
        case 0: settings.scroll.toggle()
        case 1:
            settings.screenSizeIndex = wrapped(
                settings.screenSizeIndex + direction,
                count: OriginalRuntimeSettings.screenModes.count
            )
            let mode = OriginalRuntimeSettings.screenModes[settings.screenSizeIndex]
            settings.screenWidth = Int(mode.size.width)
            settings.screenHeight = Int(mode.size.height)
        case 2:
            settings.playfieldSizeIndex = wrapped(
                settings.playfieldSizeIndex + direction,
                count: OriginalRuntimeSettings.playfieldSizes.count
            )
            let size = OriginalRuntimeSettings.playfieldSizes[settings.playfieldSizeIndex]
            settings.playfieldWidth = Int(size.width)
            settings.playfieldHeight = Int(size.height)
        case 3: settings.graphicsSetIndex = wrapped(settings.graphicsSetIndex + direction, count: 5)
        case 4: settings.windowed.toggle()
        case 5: settings.cycleGridStyle(by: direction)
        case 6: settings.cycleStars(by: direction)
        case 7: settings.cycleParticleStyle(by: direction)
        case 8: settings.gridColorPosition = min(119, max(0, settings.gridColorPosition + direction))
        case 9:
            settings.gridBrightness = min(119, max(0, settings.gridBrightness + direction))
            settings.gridOpacity = CGFloat(settings.gridBrightness) / 119
        default: break
        }
    }

    private mutating func adjustGame(by direction: Int) {
        switch selection {
        case 0: settings.difficulty = cycled(settings.difficulty, by: direction)
        case 1:
            let index = settings.difficulty.rawValue
            settings.extraLifeScores[index] = min(300_000, max(25_000, settings.extraLifeScores[index] + direction * 25_000))
        case 2:
            let index = settings.difficulty.rawValue
            settings.extraBombScores[index] = min(300_000, max(25_000, settings.extraBombScores[index] + direction * 25_000))
        case 3: settings.autoFire.toggle()
        case 4: settings.inertia = clamped(settings.inertia + CGFloat(direction) * 0.05)
        default: break
        }
    }

    private mutating func adjustAudio(by direction: Int) {
        switch selection {
        case 0: settings.soundEffectsVolume = clamped(settings.soundEffectsVolume + CGFloat(direction) * 0.05)
        case 1: settings.musicVolume = clamped(settings.musicVolume + CGFloat(direction) * 0.05)
        case 2: settings.soundSetIndex = wrapped(settings.soundSetIndex + direction, count: 2)
        default: break
        }
    }

    private mutating func adjustHybrid(by direction: Int) {
        switch selection {
        case 0: settings.hybridConfiguration = wrapped(settings.hybridConfiguration + direction, count: 3)
        case 1: settings.mouseFireButton = wrappedMouseButton(settings.mouseFireButton + direction)
        case 2: settings.mouseBombButton = wrappedMouseButton(settings.mouseBombButton + direction)
        case 3: settings.mouseSensitivity = clamped(settings.mouseSensitivity + CGFloat(direction) * 0.05)
        default: break
        }
    }

    private mutating func adjustMouse(by direction: Int) {
        switch selection {
        case 0: settings.mouseFireButton = wrappedMouseButton(settings.mouseFireButton + direction)
        case 1: settings.mouseBombButton = wrappedMouseButton(settings.mouseBombButton + direction)
        case 2: settings.mouseSensitivity = clamped(settings.mouseSensitivity + CGFloat(direction) * 0.05)
        default: break
        }
    }

    private mutating func adjustJoypad(by direction: Int) {
        switch selection {
        case 0: settings.joypadConfiguration = 1 - settings.joypadConfiguration
        case 1: settings.joypadBombButton = min(15, max(0, settings.joypadBombButton + direction))
        case 2: settings.joypadOptionButton = min(15, max(0, settings.joypadOptionButton + direction))
        case 3...6:
            let index = [3, 0, 2, 1][selection - 3]
            settings.joypadButtons[index] = min(15, max(0, settings.joypadButtons[index] + direction))
        default: break
        }
    }

    private mutating func adjustDualAnalog(by direction: Int) {
        switch selection {
        case 0: settings.dualAnalogPort = min(3, max(0, settings.dualAnalogPort + direction))
        case 1...4:
            let index = selection - 1
            settings.dualAnalogAxes[index] = wrapped(settings.dualAnalogAxes[index] + direction - 1, count: 15) + 1
        case 5...8:
            let index = selection - 5
            settings.dualAnalogInverted[index].toggle()
        case 9...12:
            let index = selection - 9
            let values: [CGFloat] = [1, 128, 255]
            let oldIndex = values.firstIndex(of: settings.dualAnalogScale[index]) ?? 0
            settings.dualAnalogScale[index] = values[wrapped(oldIndex + direction, count: values.count)]
        case 13...16:
            let index = selection - 13
            settings.dualAnalogCenter[index] = min(
                0.9,
                max(-0.9, settings.dualAnalogCenter[index] + CGFloat(direction) * 0.01)
            )
        case 17...20:
            let index = selection - 17
            settings.dualAnalogDeadZone[index] = min(
                index < 2 ? 0.5 : 0.9,
                max(0, settings.dualAnalogDeadZone[index] + CGFloat(direction) * 0.01)
            )
        case 21: settings.dualAnalogOptionButton = min(15, max(0, settings.dualAnalogOptionButton + direction))
        case 22: settings.dualAnalogBombButton = min(15, max(0, settings.dualAnalogBombButton + direction))
        default: break
        }
    }

    private func keyboardLine(_ label: String, key: Int, index: Int) -> String {
        let value = awaitingKeyboardBinding && selection == index
            ? "Press a key"
            : OriginalKeyName.displayName(for: key)
        return "\(label): \(value)"
    }

    private func formattedAxisValue(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }

    private func onOff(_ value: Bool) -> String { value ? "On" : "Off" }

    private func mouseButton(_ value: Int) -> String {
        ["None", "Left", "Right", "Middle"][min(3, max(0, value))]
    }

    private func axisTitle(_ value: Int) -> String {
        let labels = [
            "null", "JoyX()", "JoyY()", "JoyZ()", "JoyR()", "JoyU()", "JoyV()",
            "JoyYaw()", "JoyPitch()", "JoyRoll()", "JoyHat()", "JoyWheel()",
            "JoyAxis12()", "JoyAxis13()", "JoyAxis14()", "JoyAxis15()",
        ]
        return labels[min(15, max(0, value))]
    }

    private func wrappedMouseButton(_ value: Int) -> Int {
        value < 1 ? 3 : (value > 3 ? 1 : value)
    }

    private func wrapped(_ value: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let remainder = value % count
        return remainder < 0 ? remainder + count : remainder
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(1, max(0, value))
    }

    private func cycled<T>(_ value: T, by direction: Int) -> T where T: CaseIterable & RawRepresentable, T.RawValue == Int {
        let values = Array(T.allCases)
        let index = values.firstIndex { $0.rawValue == value.rawValue } ?? 0
        return values[wrapped(index + direction, count: values.count)]
    }

    private static func sizeText(_ size: CGSize) -> String {
        "\(Int(size.width))X\(Int(size.height))"
    }
}
