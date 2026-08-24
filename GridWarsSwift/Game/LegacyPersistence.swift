import CoreGraphics
import Foundation

enum LegacyDataError: Error, Equatable {
    case invalidColours
    case invalidHighScores
}

enum LegacyConfigCodec {
    static func decode(_ text: String, defaults: OriginalRuntimeSettings = .init()) -> OriginalRuntimeSettings {
        var settings = defaults
        var currentJoyPort: Int?
        let lines = normalizedLines(text)
        var index = 0
        while index + 1 < lines.count {
            let label = lines[index]
            let value = lines[index + 1]
            index += 2

            if label == "[Joy Port]" {
                let port = int(value)
                currentJoyPort = (0..<4).contains(port) ? port : nil
                continue
            }
            if let port = currentJoyPort, applyJoyValue(label, value: value, port: port, to: &settings) {
                continue
            }

            switch label {
            case "[Windowed]": settings.windowed = value.uppercased() == "TRUE"
            case "[Control Type]":
                if let type = OriginalControllerType.allCases.first(where: {
                    $0.title.caseInsensitiveCompare(value) == .orderedSame
                }) {
                    settings.controllerType = type
                }
            case "[Hybrid Config]": settings.hybridConfiguration = int(value)
            case "[Joypad Config]": settings.joypadConfiguration = int(value)
            case "[Joypad Left]": settings.joypadButtons[0] = int(value)
            case "[Joypad Up]": settings.joypadButtons[1] = int(value)
            case "[Joypad Right]": settings.joypadButtons[2] = int(value)
            case "[Joypad Down]": settings.joypadButtons[3] = int(value)
            case "[Joypad Option]": settings.joypadOptionButton = int(value)
            case "[Joypad Bomb]": settings.joypadBombButton = int(value)
            case "[Autofire]": settings.autoFire = int(value) != 0
            case "[Key Bomb]": settings.keyBomb = int(value)
            case "[Key Move Left]": settings.keyMoveLeft = int(value)
            case "[Key Move Right]": settings.keyMoveRight = int(value)
            case "[Key Move Up]": settings.keyMoveUp = int(value)
            case "[Key Move Down]": settings.keyMoveDown = int(value)
            case "[Key Fire Left]": settings.keyFireLeft = int(value)
            case "[Key Fire Right]": settings.keyFireRight = int(value)
            case "[Key Fire Up]": settings.keyFireUp = int(value)
            case "[Key Fire Down]": settings.keyFireDown = int(value)
            case "[SFX Volume]": settings.soundEffectsVolume = CGFloat(double(value)) / 100
            case "[Music Volume]": settings.musicVolume = CGFloat(double(value)) / 100
            case "[Sound Set]":
                let soundSet = int(value)
                settings.soundSetIndex = (0...1).contains(soundSet) ? soundSet : 0
            case "[Grid Style]": settings.gridStyle = int(value)
            case "[Grid Red]": settings.gridRed = int(value)
            case "[Grid Green]": settings.gridGreen = int(value)
            case "[Grid Blue]": settings.gridBlue = int(value)
            case "[Grid Opacity]":
                settings.gridOpacity = CGFloat(double(value)) / 100
                settings.gridBrightness = Int(settings.gridOpacity * 120)
            case "[Grid Spacing]": settings.gridSpacing = int(value)
            case "[Full Grid]":
                let fullGrid = int(value)
                settings.fullGrid = (0...1).contains(fullGrid) ? fullGrid != 0 : false
            case "[Gfx Set]":
                let graphicsSet = int(value)
                settings.graphicsSetIndex = (0...4).contains(graphicsSet) ? graphicsSet : 0
            case "[Show Stars]": settings.starCount = int(value)
            case "[Scroll]": settings.scroll = int(value) != 0
            case "[Playfield Width]": settings.playfieldWidth = int(value)
            case "[Playfield Height]": settings.playfieldHeight = int(value)
            case "[Screen Width]": settings.screenWidth = int(value)
            case "[Screen Height]": settings.screenHeight = int(value)
            case "[Particle Count]": settings.particleCount = min(50_000, int(value))
            case "[Particle Life]": settings.particleLife = min(500, int(value))
            case "[Particle Gravity]": settings.particleGravity = int(value) != 0
            case "[Particle Decay]": settings.particleDecay = min(0.9999, max(0.01, CGFloat(double(value))))
            case "[Particle Style]": settings.particleStyle = int(value)
            case "[Mouse Sensitivity]": settings.mouseSensitivity = CGFloat(double(value)) / 100
            case "[Mouse Fire]": settings.mouseFireButton = int(value)
            case "[Mouse Bomb]": settings.mouseBombButton = int(value)
            case "[Difficulty]": settings.difficulty = GameDifficulty(rawValue: int(value)) ?? settings.difficulty
            case "[Inertia]": settings.inertia = CGFloat(double(value)) / 100
            case "[Used Port]": settings.dualAnalogPort = int(value)
            default: break
            }
        }

        if let playfieldIndex = OriginalRuntimeSettings.playfieldSizes.firstIndex(where: {
            Int($0.width) == settings.playfieldWidth && Int($0.height) == settings.playfieldHeight
        }) {
            settings.playfieldSizeIndex = playfieldIndex
        }
        return settings
    }

    static func encode(_ settings: OriginalRuntimeSettings) -> String {
        var lines: [String] = []
        func pair(_ label: String, _ value: String) {
            lines.append(label)
            lines.append(value)
        }
        func number(_ value: Bool) -> String { value ? "1" : "0" }

        pair("[Windowed]", settings.windowed ? "True" : "False")
        pair("[Control Type]", settings.controllerType.title)
        pair("[Hybrid Config]", String(settings.hybridConfiguration))
        pair("[Joypad Config]", String(settings.joypadConfiguration))
        pair("[Joypad Left]", String(settings.joypadButtons[0]))
        pair("[Joypad Up]", String(settings.joypadButtons[1]))
        pair("[Joypad Right]", String(settings.joypadButtons[2]))
        pair("[Joypad Down]", String(settings.joypadButtons[3]))
        pair("[Joypad Option]", String(settings.joypadOptionButton))
        pair("[Joypad Bomb]", String(settings.joypadBombButton))
        pair("[Autofire]", number(settings.autoFire))
        pair("[Key Bomb]", String(settings.keyBomb))
        pair("[Key Move Left]", String(settings.keyMoveLeft))
        pair("[Key Move Right]", String(settings.keyMoveRight))
        pair("[Key Move Up]", String(settings.keyMoveUp))
        pair("[Key Move Down]", String(settings.keyMoveDown))
        pair("[Key Fire Left]", String(settings.keyFireLeft))
        pair("[Key Fire Right]", String(settings.keyFireRight))
        pair("[Key Fire Up]", String(settings.keyFireUp))
        pair("[Key Fire Down]", String(settings.keyFireDown))
        pair("[SFX Volume]", String(Int(settings.soundEffectsVolume * 100)))
        pair("[Music Volume]", String(Int(settings.musicVolume * 100)))
        pair("[Sound Set]", String(settings.soundSetIndex))
        pair("[Grid Style]", String(settings.gridStyle))
        pair("[Grid Red]", String(settings.gridRed))
        pair("[Grid Green]", String(settings.gridGreen))
        pair("[Grid Blue]", String(settings.gridBlue))
        pair("[Grid Opacity]", String(Int(settings.gridOpacity * 100)))
        pair("[Grid Spacing]", String(settings.gridSpacing))
        pair("[Full Grid]", number(settings.fullGrid))
        pair("[Gfx Set]", String(settings.graphicsSetIndex))
        pair("[Show Stars]", String(settings.starCount))
        pair("[Scroll]", number(settings.scroll))
        pair("[Playfield Width]", String(settings.playfieldWidth))
        pair("[Playfield Height]", String(settings.playfieldHeight))
        pair("[Screen Width]", String(settings.screenWidth))
        pair("[Screen Height]", String(settings.screenHeight))
        pair("[Particle Count]", String(settings.particleCount))
        pair("[Particle Life]", String(settings.particleLife))
        pair("[Particle Gravity]", number(settings.particleGravity))
        pair("[Particle Decay]", String(Double(settings.particleDecay)))
        pair("[Particle Style]", String(settings.particleStyle))
        pair("[Mouse Sensitivity]", String(Int(settings.mouseSensitivity * 100)))
        pair("[Mouse Fire]", String(settings.mouseFireButton))
        pair("[Mouse Bomb]", String(settings.mouseBombButton))
        pair("[Difficulty]", String(settings.difficulty.rawValue))
        pair("[Inertia]", String(Int(settings.inertia * 100)))
        pair("[Used Port]", String(settings.dualAnalogPort))

        for port in 0..<4 {
            let joy = settings.joyPorts[port]
            pair("[Joy Port]", String(port))
            pair("[Joy Move X]", String(joy.axes[0]))
            pair("[Joy Move Y]", String(joy.axes[1]))
            pair("[Joy Fire X]", String(joy.axes[2]))
            pair("[Joy Fire Y]", String(joy.axes[3]))
            pair("[Joy Move X Inverted]", String(joy.inversion[0]))
            pair("[Joy Move Y Inverted]", String(joy.inversion[1]))
            pair("[Joy Fire X Inverted]", String(joy.inversion[2]))
            pair("[Joy Fire Y Inverted]", String(joy.inversion[3]))
            pair("[Joy Move X Scale]", String(Int(joy.scale[0])))
            pair("[Joy Move Y Scale]", String(Int(joy.scale[1])))
            pair("[Joy Fire X Scale]", String(Int(joy.scale[2])))
            pair("[Joy Fire Y Scale]", String(Int(joy.scale[3])))
            pair("[Joy Move X Center]", legacyFloat(joy.center[0]))
            pair("[Joy Move Y Center]", legacyFloat(joy.center[1]))
            pair("[Joy Fire X Center]", legacyFloat(joy.center[2]))
            pair("[Joy Fire Y Center]", legacyFloat(joy.center[3]))
            pair("[Joy Move X Dead Zone]", legacyFloat(joy.deadZone[0]))
            pair("[Joy Move Y Dead Zone]", legacyFloat(joy.deadZone[1]))
            pair("[Joy Fire X Dead Zone]", legacyFloat(joy.deadZone[2]))
            pair("[Joy Fire Y Dead Zone]", legacyFloat(joy.deadZone[3]))
            pair("[Joy Option]", String(joy.optionButton))
            pair("[Joy Bomb]", String(joy.bombButton))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func applyJoyValue(
        _ label: String,
        value: String,
        port: Int,
        to settings: inout OriginalRuntimeSettings
    ) -> Bool {
        switch label {
        case "[Joy Move X]": settings.joyPorts[port].axes[0] = int(value)
        case "[Joy Move Y]": settings.joyPorts[port].axes[1] = int(value)
        case "[Joy Fire X]": settings.joyPorts[port].axes[2] = int(value)
        case "[Joy Fire Y]": settings.joyPorts[port].axes[3] = int(value)
        case "[Joy Move X Inverted]": settings.joyPorts[port].inversion[0] = inversion(value)
        case "[Joy Move Y Inverted]": settings.joyPorts[port].inversion[1] = inversion(value)
        case "[Joy Fire X Inverted]": settings.joyPorts[port].inversion[2] = inversion(value)
        case "[Joy Fire Y Inverted]": settings.joyPorts[port].inversion[3] = inversion(value)
        case "[Joy Move X Scale]": settings.joyPorts[port].scale[0] = scale(value)
        case "[Joy Move Y Scale]": settings.joyPorts[port].scale[1] = scale(value)
        case "[Joy Fire X Scale]": settings.joyPorts[port].scale[2] = scale(value)
        case "[Joy Fire Y Scale]": settings.joyPorts[port].scale[3] = scale(value)
        case "[Joy Move X Center]": settings.joyPorts[port].center[0] = boundedFloat(value)
        case "[Joy Move Y Center]": settings.joyPorts[port].center[1] = boundedFloat(value)
        case "[Joy Fire X Center]": settings.joyPorts[port].center[2] = boundedFloat(value)
        case "[Joy Fire Y Center]": settings.joyPorts[port].center[3] = boundedFloat(value)
        case "[Joy Move X Dead Zone]": settings.joyPorts[port].deadZone[0] = boundedFloat(value)
        case "[Joy Move Y Dead Zone]": settings.joyPorts[port].deadZone[1] = boundedFloat(value)
        case "[Joy Fire X Dead Zone]": settings.joyPorts[port].deadZone[2] = boundedFloat(value)
        case "[Joy Fire Y Dead Zone]": settings.joyPorts[port].deadZone[3] = boundedFloat(value)
        case "[Joy Option]": settings.joyPorts[port].optionButton = int(value)
        case "[Joy Bomb]": settings.joyPorts[port].bombButton = int(value)
        default: return false
        }
        return true
    }

    private static func inversion(_ value: String) -> Int {
        let parsed = int(value)
        return abs(parsed) == 1 ? parsed : 1
    }

    private static func scale(_ value: String) -> CGFloat {
        let parsed = int(value)
        return CGFloat(parsed == 0 ? 1 : parsed)
    }

    private static func boundedFloat(_ value: String) -> CGFloat {
        let parsed = CGFloat(double(value))
        return abs(parsed) > 1 ? 0 : parsed
    }

    private static func int(_ value: String) -> Int {
        Int(value.trimmingCharacters(in: .whitespaces))
            ?? Int(double(value))
    }

    private static func double(_ value: String) -> Double {
        Double(value.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private static func legacyFloat(_ value: CGFloat) -> String {
        String(Double(value))
    }

    private static func normalizedLines(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }
}

enum OriginalColorRole: String, CaseIterable, Codable {
    case square = "squares"
    case pinwheel = "pinwheels"
    case diamond = "diamonds"
    case cube = "cubes"
    case seeker = "circles"
    case butterfly = "butterflies"
    case blackHole = "blackholes"
    case interceptor = "clone"
    case snake = "snake head"
    case snakeTail = "snake tail"
    case triangle = "triangles"
    case player = "player"
    case shot = "shots"
    case superShot = "super shots"
    case bouncyShot = "bouncy shots"
    case bomb = "bomb"
    case score = "scores"
    case powerUp = "powerups"
    case trail = "trail"
}

struct OriginalColorPalette: Equatable, Codable {
    private var values: [OriginalColorRole: ParticleColor]

    init(values: [OriginalColorRole: ParticleColor] = [:]) {
        self.values = Self.defaults.merging(values) { _, replacement in replacement }
    }

    subscript(role: OriginalColorRole) -> ParticleColor {
        get { values[role] ?? Self.defaults[role] ?? ParticleColor(red: 255, green: 255, blue: 255) }
        set { values[role] = newValue }
    }

    private static let defaults: [OriginalColorRole: ParticleColor] = [
        .square: .init(red: 32, green: 255, blue: 32),
        .pinwheel: .init(red: 200, green: 64, blue: 255),
        .diamond: .init(red: 32, green: 255, blue: 255),
        .cube: .init(red: 255, green: 32, blue: 255),
        .seeker: .init(red: 32, green: 64, blue: 255),
        .butterfly: .init(red: 128, green: 32, blue: 255),
        .blackHole: .init(red: 255, green: 32, blue: 32),
        .interceptor: .init(red: 255, green: 32, blue: 32),
        .snake: .init(red: 190, green: 32, blue: 255),
        .snakeTail: .init(red: 255, green: 180, blue: 96),
        .triangle: .init(red: 255, green: 128, blue: 32),
        .player: .init(red: 255, green: 255, blue: 200),
        .shot: .init(red: 200, green: 200, blue: 128),
        .superShot: .init(red: 200, green: 32, blue: 32),
        .bouncyShot: .init(red: 32, green: 200, blue: 32),
        .bomb: .init(red: 255, green: 255, blue: 255),
        .score: .init(red: 32, green: 255, blue: 32),
        .powerUp: .init(red: 255, green: 255, blue: 32),
        .trail: .init(red: 240, green: 240, blue: 100),
    ]
}

enum LegacyColoursCodec {
    static func decode(_ text: String) throws -> OriginalColorPalette {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        guard lines.count >= OriginalColorRole.allCases.count * 4 else {
            throw LegacyDataError.invalidColours
        }
        var palette = OriginalColorPalette()
        for (index, role) in OriginalColorRole.allCases.enumerated() {
            let start = index * 4
            guard let red = Int(lines[start + 1]),
                  let green = Int(lines[start + 2]),
                  let blue = Int(lines[start + 3]) else {
                throw LegacyDataError.invalidColours
            }
            palette[role] = ParticleColor(red: red, green: green, blue: blue)
        }
        return palette
    }

    static func encode(_ palette: OriginalColorPalette) -> String {
        var lines: [String] = []
        for role in OriginalColorRole.allCases {
            let color = palette[role]
            lines += [role.rawValue, String(color.red), String(color.green), String(color.blue)]
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

struct LegacyHighScoreEntry: Equatable, Codable {
    var score: Int
    var playTime: String
    var name: String
    var settings: String
    var checksum: Int

    init(score: Int, playTime: String, name: String, settings: String, checksum: Int? = nil) {
        self.score = score
        self.playTime = playTime
        self.name = name
        self.settings = settings
        self.checksum = checksum ?? Self.calculateChecksum(
            score: score,
            playTime: playTime,
            name: name,
            settings: settings
        )
    }

    var isChecksumValid: Bool {
        checksum == Self.calculateChecksum(
            score: score,
            playTime: playTime,
            name: name,
            settings: settings
        )
    }

    static func calculateChecksum(score: Int, playTime: String, name: String, settings: String) -> Int {
        let source = String(score) + name + playTime + settings
        return source.utf8.reduce(0) { $0 + Int($1) }
    }
}

struct LegacyHighScoreTable: Equatable, Codable {
    private(set) var difficulties: [[LegacyHighScoreEntry]]

    init(difficulties: [[LegacyHighScoreEntry]] = Self.defaultDifficulties) {
        self.difficulties = difficulties
    }

    subscript(difficulty: GameDifficulty) -> [LegacyHighScoreEntry] {
        difficulties[difficulty.rawValue]
    }

    static func decode(_ text: String) throws -> LegacyHighScoreTable {
        var lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        while lines.last == "" { lines.removeLast() }
        guard lines.count >= 150 else { throw LegacyDataError.invalidHighScores }

        var result: [[LegacyHighScoreEntry]] = []
        var index = 0
        for _ in 0..<3 {
            var entries: [LegacyHighScoreEntry] = []
            for _ in 0..<10 {
                guard let score = Int(lines[index]), let checksum = Int(lines[index + 4]) else {
                    throw LegacyDataError.invalidHighScores
                }
                let entry = LegacyHighScoreEntry(
                    score: score,
                    playTime: lines[index + 1],
                    name: lines[index + 2],
                    settings: lines[index + 3],
                    checksum: checksum
                )
                guard entry.isChecksumValid else { throw LegacyDataError.invalidHighScores }
                entries.append(entry)
                index += 5
            }
            result.append(entries)
        }
        return LegacyHighScoreTable(difficulties: result)
    }

    static func decodeOrDefault(_ text: String) -> LegacyHighScoreTable {
        (try? decode(text)) ?? LegacyHighScoreTable()
    }

    func encode() -> String {
        difficulties.flatMap { $0 }.flatMap { entry in
            [
                String(entry.score),
                entry.playTime,
                entry.name,
                entry.settings,
                String(entry.checksum),
            ]
        }.joined(separator: "\n") + "\n"
    }

    func qualifies(score: Int, difficulty: GameDifficulty) -> Bool {
        guard let last = difficulties[difficulty.rawValue].last else { return true }
        return score > last.score
    }

    @discardableResult
    mutating func insert(
        score: Int,
        playTime: String,
        name: String,
        settings: String,
        difficulty: GameDifficulty
    ) -> Int? {
        var entries = difficulties[difficulty.rawValue]
        guard let position = entries.firstIndex(where: { score > $0.score }) else { return nil }
        entries.insert(LegacyHighScoreEntry(
            score: score,
            playTime: playTime,
            name: Self.normalizedName(name),
            settings: settings
        ), at: position)
        difficulties[difficulty.rawValue] = Array(entries.prefix(10))
        return position
    }

    static func playTime(frames: Int) -> String {
        let seconds = frames / 50
        let minutes = seconds / 60
        let hours = minutes / 60
        var result = ""
        if hours > 0 {
            result += "\(hours) hr"
            result += hours > 1 ? "s, " : ", "
        }
        if minutes > 0 {
            result += "\(minutes % 60) mn"
            result += minutes > 1 ? "s, " : ", "
        }
        if seconds > 0 {
            result += "\(seconds % 60) sec"
            if seconds > 1 { result += "s" }
        }
        return result
    }

    static func normalizedName(_ name: String) -> String {
        let ascii = name.unicodeScalars.map { scalar -> Character in
            (32...126).contains(Int(scalar.value)) ? Character(String(scalar)) : "?"
        }
        return String((ascii + Array(repeating: " ", count: 8)).prefix(8))
    }

    private static let defaultDifficulties: [[LegacyHighScoreEntry]] = {
        (0..<3).map { difficulty in
            (0..<10).map { row in
                let score: Int = switch difficulty {
                case 0: 200_000 - row * 19_000
                case 1: 100_000 - row * 9_000
                default: 50_000 - row * 4_900
                }
                return LegacyHighScoreEntry(
                    score: score,
                    playTime: playTime(frames: 50 * 60 * 11 - row * 50 * 40 - difficulty * 50 * 60 * 2),
                    name: "Mark Inc",
                    settings: "0,0,0,0,0,0,0,0,0,0"
                )
            }
        }
    }()
}

struct OriginalHighScoreNameEntry: Equatable {
    private(set) var characters = Array(repeating: 32, count: 8)
    private(set) var selectedIndex = 0

    var name: String {
        String(characters.compactMap(UnicodeScalar.init).map(Character.init))
    }

    mutating func moveSelection(by direction: Int) {
        selectedIndex = (selectedIndex + direction) % 8
        if selectedIndex < 0 { selectedIndex += 8 }
    }

    mutating func setASCII(_ value: Int) {
        guard (32...126).contains(value) else { return }
        characters[selectedIndex] = value
        moveSelection(by: 1)
    }

    mutating func toggleCase() {
        let value = characters[selectedIndex]
        if (65...90).contains(value) {
            characters[selectedIndex] = value + 32
        } else if (97...122).contains(value) {
            characters[selectedIndex] = value - 32
        }
    }

    mutating func cycleCharacter(by direction: Int) {
        guard direction != 0 else { return }
        if direction < 0 {
            characters[selectedIndex] -= 1
            switch characters[selectedIndex] {
            case 32: characters[selectedIndex] = 126
            case 64: characters[selectedIndex] = 32
            case ..<32: characters[selectedIndex] = 64
            case 96: characters[selectedIndex] = 32
            case 122: characters[selectedIndex] = 96
            default: break
            }
        } else {
            characters[selectedIndex] += 1
            switch characters[selectedIndex] {
            case 127...: characters[selectedIndex] = 33
            case 65: characters[selectedIndex] = 32
            case 33: characters[selectedIndex] = 65
            case 123: characters[selectedIndex] = 91
            case 97: characters[selectedIndex] = 123
            default: break
            }
        }
    }
}

extension OriginalRuntimeSettings {
    func highScoreSettingsString(gameVersion: String = "5.4") -> String {
        var control = controllerType.title
        if controllerType == .joypad { control += "-\(joypadConfiguration)" }
        if controllerType == .hybrid { control += "-\(hybridConfiguration)" }
        return [
            gameVersion,
            "\(screenWidth)X\(screenHeight)",
            "\(playfieldWidth)X\(playfieldHeight)",
            control,
            scroll ? "1" : "0",
            String(graphicsSetIndex),
            String(gridStyle),
            autoFire ? "1" : "0",
            String(Int(inertia * 100)),
        ].joined(separator: ",")
    }
}

struct GridWarsPersistentState: Equatable {
    var settings: OriginalRuntimeSettings
    var colours: OriginalColorPalette
    var highScores: LegacyHighScoreTable
}

struct GridWarsPersistenceStore {
    static let configFileName = "Config.txt"
    static let coloursFileName = "Colours.txt"
    static let scoresFileName = "hiscores.dat"

    let directoryURL: URL
    let legacyDirectoryURL: URL
    private let fileManager: FileManager

    init(
        directoryURL: URL,
        legacyDirectoryURL: URL,
        fileManager: FileManager = .default
    ) {
        self.directoryURL = directoryURL
        self.legacyDirectoryURL = legacyDirectoryURL
        self.fileManager = fileManager
    }

    static func applicationDefault(fileManager: FileManager = .default) -> GridWarsPersistenceStore? {
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        #if os(macOS)
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        #else
        let homeDirectory = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        #endif
        let legacy = homeDirectory.appendingPathComponent(".config/gridwars", isDirectory: true)
        return GridWarsPersistenceStore(
            directoryURL: applicationSupport.appendingPathComponent("GridWars", isDirectory: true),
            legacyDirectoryURL: legacy,
            fileManager: fileManager
        )
    }

    func load() throws -> GridWarsPersistentState {
        try prepareDirectoryAndImportLegacyFiles()
        let settings = read(Self.configFileName).map { LegacyConfigCodec.decode($0) }
            ?? OriginalRuntimeSettings()
        let colours = read(Self.coloursFileName).flatMap { try? LegacyColoursCodec.decode($0) }
            ?? OriginalColorPalette()
        let highScores = read(Self.scoresFileName).map(LegacyHighScoreTable.decodeOrDefault)
            ?? LegacyHighScoreTable()
        return GridWarsPersistentState(settings: settings, colours: colours, highScores: highScores)
    }

    func save(_ state: GridWarsPersistentState) throws {
        try prepareDirectoryAndImportLegacyFiles()
        try write(LegacyConfigCodec.encode(state.settings), named: Self.configFileName)
        try write(LegacyColoursCodec.encode(state.colours), named: Self.coloursFileName)
        try write(state.highScores.encode(), named: Self.scoresFileName)
    }

    private func prepareDirectoryAndImportLegacyFiles() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        for name in [Self.configFileName, Self.coloursFileName, Self.scoresFileName] {
            let destination = directoryURL.appendingPathComponent(name)
            let legacy = legacyDirectoryURL.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: destination.path),
               fileManager.fileExists(atPath: legacy.path) {
                try fileManager.copyItem(at: legacy, to: destination)
            }
        }
    }

    private func read(_ name: String) -> String? {
        try? String(contentsOf: directoryURL.appendingPathComponent(name), encoding: .utf8)
    }

    private func write(_ text: String, named name: String) throws {
        try text.write(
            to: directoryURL.appendingPathComponent(name),
            atomically: true,
            encoding: .utf8
        )
    }
}
