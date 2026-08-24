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

    var scroll = false
    var screenSizeIndex = 0
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
    var settings = OriginalRuntimeSettings()

    mutating func open(duringGame: Bool) {
        page = .options
        openedDuringGame = duringGame
        selection = duringGame ? 3 : 2
        isOpen = true
        awaitingKeyboardBinding = false
        pageStack = []
    }

    mutating func close() {
        isOpen = false
        awaitingKeyboardBinding = false
        pageStack = []
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
        case .options, .confirmExit, .confirmEndGame, .settings, .controller:
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
            if selection == 10 { return navigateBack() }
            return adjust(by: 1)
        case .game:
            if selection == 5 { return navigateBack() }
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
        case .confirmExit: "Exit Program?"
        case .confirmEndGame: "End Game?"
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
        case .confirmExit, .confirmEndGame:
            return ["Yes", "No"]
        case .settings:
            return ["Audio", "Video", "Controls", "Game", "Done"]
        case .video:
            let playfield = Self.sizeText(
                OriginalRuntimeSettings.playfieldSizes[settings.playfieldSizeIndex]
            )
            return [
                "Scroll: \(onOff(settings.scroll))",
                "Screen Size: 1/1 \(Self.sizeText(CGSize(width: 1_024, height: 768)))",
                "Playfield Size: \(settings.playfieldSizeIndex + 1)/\(OriginalRuntimeSettings.playfieldSizes.count) \(playfield)",
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
                "Inertia: \(Int(settings.inertia * 100))",
                "Done",
            ]
        case .audio:
            return [
                "SFX Volume: \(Int(settings.soundEffectsVolume * 100))",
                "Music Volume: \(Int(settings.musicVolume * 100))",
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
                "Mouse Sensitivity: \(Int(settings.mouseSensitivity * 100))",
                "Done",
            ]
        case .mouse:
            return [
                "Fire: \(mouseButton(settings.mouseFireButton)) Mouse Button",
                "Bomb: \(mouseButton(settings.mouseBombButton)) Mouse Button",
                "Mouse Sensitivity: \(Int(settings.mouseSensitivity * 100))",
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
                keyboardLine("Bomb      ", key: settings.keyBomb, index: 8),
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
        case .confirmExit, .confirmEndGame: 1
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

    private mutating func adjustVideo(by direction: Int) {
        switch selection {
        case 0: settings.scroll.toggle()
        case 1: break
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
            let values: [CGFloat] = [1, 180, 255]
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
