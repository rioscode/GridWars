@preconcurrency import SpriteKit
@preconcurrency import ImageIO
@preconcurrency import GameController

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class GameScene: SKScene, SKPhysicsContactDelegate {
    private struct FloatingScoreEffect {
        var state: OriginalFloatingScoreState
        let node: SKNode
    }

    private struct CaptureRequest {
        let scenario: OriginalCaptureScenario
        let outputPath: String

        static var commandLine: CaptureRequest? {
            let arguments = ProcessInfo.processInfo.arguments
            guard let screenFlag = arguments.firstIndex(of: "--capture-screen"),
                  arguments.indices.contains(screenFlag + 1),
                  let outputFlag = arguments.firstIndex(of: "--capture-output"),
                  arguments.indices.contains(outputFlag + 1) else { return nil }
            guard let scenario = OriginalCaptureScenario(
                name: arguments[screenFlag + 1]
            ) else { return nil }
            return CaptureRequest(scenario: scenario, outputPath: arguments[outputFlag + 1])
        }
    }

    private struct AttractDisplayEffect {
        var position: CGPoint
        var velocity: CGVector
        var rotation: CGFloat
        let size: CGFloat
    }

    private struct PendingHighScore {
        let score: Int
        let playTime: String
        let difficulty: GameDifficulty
        let settings: String
    }

    private enum Category {
        static let player: UInt32 = 1 << 0
        static let projectile: UInt32 = 1 << 1
        static let enemy: UInt32 = 1 << 2
    }

    private enum EnemyKind: String, CaseIterable {
        case pinwheel
        case diamond
        case greenSquare
        case cube
        case seeker
        case blackHole
        case triangle
        case snake
        case interceptor
        case butterfly

        init(_ original: OriginalEnemyKind) {
            self = EnemyKind(rawValue: String(describing: original)) ?? .pinwheel
        }

        var textureName: String {
            switch self {
            case .pinwheel: "pinkpinwheel"
            case .diamond: "bluediamond"
            case .greenSquare: "greensquare"
            case .cube: "purplesquare1"
            case .seeker: "bluecircle"
            case .blackHole: "redcircle"
            case .triangle: "orangetriangle"
            case .snake: "snakehead"
            case .interceptor: "redclone"
            case .butterfly: "indigotriangle"
            }
        }

        var size: CGSize {
            switch self {
            case .blackHole: CGSize(width: 128, height: 128)
            default: CGSize(width: 64, height: 64)
            }
        }

        var health: Int {
            switch self {
            case .pinwheel, .diamond, .greenSquare, .cube, .seeker,
                 .blackHole, .triangle, .snake, .interceptor, .butterfly:
                1
            }
        }

        var score: Int {
            switch self {
            case .pinwheel: 25
            case .diamond: 50
            case .greenSquare, .cube, .snake, .interceptor: 100
            case .seeker, .butterfly: 10
            case .blackHole, .triangle: 150
            }
        }

        var original: OriginalEnemyKind {
            OriginalEnemyKind(rawValue: EnemyKind.allCases.firstIndex(of: self) ?? 0) ?? .pinwheel
        }
    }

    private let worldLayer = SKNode()
    private let gridLayer = SKNode()
    private let trailLayer = SKNode()
    private let gridRenderer = GridRenderer()
    private let particleRenderer = ParticleRenderer()
    private let screenRenderer = OriginalScreenRenderer()
    private let hudRenderer = OriginalHUDRenderer()
    private let vectorFont = OriginalVectorFont()
    private let enemyLayer = SKNode()
    private let projectileLayer = SKNode()
    private let pickupLayer = SKNode()
    private let effectLayer = SKNode()
    private let hudLayer = SKNode()

    private let player = SKSpriteNode()
    private let messageLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let readyMessageNode = SKNode()
    private let bombButton = SKShapeNode(circleOfRadius: 38)
    private let optionsButton = SKShapeNode(circleOfRadius: 30)
    private let movementStick = VirtualStickNode()
    private let aimingStick = VirtualStickNode()
    private let playerShield = SKShapeNode(path: PlayerVisualRule.shieldPath())
    private let readyRings = (0..<3).map { _ in SKShapeNode(circleOfRadius: 1) }

    private var session = GameSession()
    private var configured = false
    private var pressedKeys = Set<UInt16>()
    private var pressedOriginalKeys = Set<Int>()
    private var pointerLocation = CGPoint(x: 512, y: 600)
    private var hasPointerLocation = false
    private var mouseButtons = Set<Int>()
    private var relativeMouseMovement = CGVector.zero
    private var touchMovement = CGVector.zero
    private var touchAim = CGVector.zero
    private var currentAim = CGVector(dx: 0, dy: 1)
    private var inputResolver = OriginalInputResolver()
    private var frameInput = OriginalResolvedInput()
    private var controllerAxes = Array(repeating: CGFloat.zero, count: 15)
    private var controllerDPad = CGVector.zero
    private var joypadDPad = CGVector.zero
    private var controllerButtons = Set<Int>()
    private var previousControllerButtons = Set<Int>()
    private var controllerHorizontalIsLatched = false
    private var controllerVerticalIsLatched = false
    private var highScoreFireAxisIsLatched = false
    private var playerMotion = PlayerMotionState()
    private var gridSimulation = GridSimulation(arenaSize: CGSize(width: 1_024, height: 768))
    private var particleSimulation = ParticleSimulation(arenaSize: CGSize(width: 1_024, height: 768))
    private var gridStyle = GridStyle.pointsSolid
    private var screenFlow = OriginalScreenFlow()
    private var menuModel = OriginalMenuModel()
    private var menuPresentationPage = OriginalMenuPage.options
    private var menuPresentationFrame = 0
    private var gameplayPaused = false
    private var cheatMode = false
    private var godMode = false
    private var particleGravityEnabled = true
    private var debugEnabled = false
    private var starStates: [OriginalStarState] = []
    private var starNodes: [SKShapeNode] = []
    private var initialStarRandom = BlitzMaxRandomNumberGenerator()
    private var appliedGridColorPosition = 0
    private var appliedGraphicsSetIndex = -1
    private var cameraOffset = CGPoint.zero
    private let persistenceStore = GridWarsPersistenceStore.applicationDefault()
    private let audio = OriginalAudioEngine()
    private var colorPalette = OriginalColorPalette()
    private var highScores = LegacyHighScoreTable()
    private var highScoreNameEntry: OriginalHighScoreNameEntry?
    private var retainedHighScoreNameCharacters = Array(repeating: 32, count: 8)
    private var pendingHighScore: PendingHighScore?
    private var scorePageDifficulty: GameDifficulty?
    private var highlightedScorePosition: Int?
    private var unrankedScoreEntry: LegacyHighScoreEntry?
    private let captureRequest = CaptureRequest.commandLine
    private var captureWasWritten = false

    private var lastUpdateTime: TimeInterval = 0
    private var shotTimerFrames = 0
    private var deathFramesRemaining = 0
    private var getReadyFrame = -1
    private var destroyedEnemyCount = 0
    private var fixedTimeAccumulator: TimeInterval = 0
    private var simulationFrame = GameDifficulty.medium.initialFrame
    private var bombCooldownFrames = 20
    private var spawnDirector = SpawnDirector()
    private var spawnRandom = BlitzMaxRandomNumberGenerator(
        seed: Int(ProcessInfo.processInfo.systemUptime * 1_000)
    )
    private var captureRandom: BlitzMaxRandomNumberGenerator?
    private var floatingScores: [FloatingScoreEffect] = []
    private var attractDisplayEffects: [AttractDisplayEffect] = []
    private var cyclingRed = 250
    private var cyclingGreen = 20
    private var cyclingBlue = 30
    private var cyclingRedDelta: CGFloat = -3
    private var cyclingGreenDelta: CGFloat = 5
    private var cyclingBlueDelta: CGFloat = 7

    private var playfieldSize: CGSize {
        let settings = menuModel.runtimeSettings
        return CGSize(
            width: CGFloat(max(32, settings.playfieldWidth)),
            height: CGFloat(max(32, settings.playfieldHeight))
        )
    }

    private var activeGraphicsSetIndex: Int {
        menuModel.runtimeSettings.graphicsSetIndex
    }

    private var configuredGridSpacing: CGFloat {
        let values: [CGFloat] = [4, 8, 16, 32]
        return values[min(3, max(0, menuModel.settings.gridSpacing))]
    }

    #if os(iOS)
    private var movementTouch: UITouch?
    private var aimingTouch: UITouch?
    private var movementTouchOrigin = CGPoint.zero
    private var aimingTouchOrigin = CGPoint.zero
    #endif

    override init(size: CGSize) {
        super.init(size: size)
        gridSimulation = GridSimulation(arenaSize: size)
        particleSimulation = ParticleSimulation(arenaSize: size)
        scaleMode = .aspectFit
        backgroundColor = .black
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        gridSimulation = GridSimulation(arenaSize: size)
        particleSimulation = ParticleSimulation(arenaSize: size)
        scaleMode = .aspectFit
        backgroundColor = .black
    }

    override func didMove(to view: SKView) {
        guard !configured else { return }
        configured = true

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = nil
        if captureRequest == nil {
            loadPersistentState()
        }
        audio.configure(settings: menuModel.settings)
        setupLayers()
        setupArena()
        setupPlayer()
        setupHUD()
        applyRuntimeSettings()
        prepareAttractMode()
        configureCaptureIfRequested(in: view)
    }

    private func loadPersistentState() {
        guard let persistenceStore, let state = try? persistenceStore.load() else { return }
        menuModel.settings = state.settings
        colorPalette = state.colours
        highScores = state.highScores
        particleGravityEnabled = state.settings.particleGravity
        particleSimulation = ParticleSimulation(
            arenaSize: playfieldSize,
            capacity: max(0, min(50_000, state.settings.particleCount)),
            particleLife: state.settings.particleLife,
            decay: state.settings.particleDecay
        )
    }

    func persistState() {
        guard captureRequest == nil, let persistenceStore else { return }
        let state = GridWarsPersistentState(
            settings: menuModel.settings,
            colours: colorPalette,
            highScores: highScores
        )
        try? persistenceStore.save(state)
    }

    private func setupLayers() {
        addChild(worldLayer)
        worldLayer.addChild(gridLayer)
        worldLayer.addChild(trailLayer)
        worldLayer.addChild(particleRenderer.node)
        worldLayer.addChild(enemyLayer)
        worldLayer.addChild(projectileLayer)
        worldLayer.addChild(pickupLayer)
        worldLayer.addChild(effectLayer)
        addChild(hudLayer)
        addChild(screenRenderer.node)

        gridLayer.zPosition = -10
        gridLayer.addChild(gridRenderer.node)
        trailLayer.zPosition = 4
        particleRenderer.node.zPosition = 5
        enemyLayer.zPosition = 10
        projectileLayer.zPosition = 20
        pickupLayer.zPosition = 15
        effectLayer.zPosition = 30
        hudLayer.zPosition = 100
        screenRenderer.node.zPosition = 200
    }

    private func setupArena() {
        gridSimulation = GridSimulation(
            arenaSize: playfieldSize,
            spacing: configuredGridSpacing
        )
        renderGrid()
        starStates = OriginalStarRule.create(
            maximumIndex: OriginalRuntimeSettings.maximumStars,
            playfieldSize: playfieldSize,
            screenSize: size,
            using: &initialStarRandom
        )
        ensureStarCapacity(through: 300)
        rebuildArenaBorder()
    }

    private func rebuildArenaBorder() {
        gridLayer.childNode(withName: "arenaBorder")?.removeFromParent()
        let border = SKNode()
        border.name = "arenaBorder"
        border.zPosition = 31
        for segment in OriginalArenaBorderRule.sceneSegments(playfieldSize: playfieldSize) {
            let path = CGMutablePath()
            path.move(to: OriginalLineRasterRule.scenePixelCenter(segment.start))
            path.addLine(to: OriginalLineRasterRule.scenePixelCenter(segment.end))
            let line = SKShapeNode(path: path)
            line.lineWidth = 2
            line.lineCap = .butt
            line.lineJoin = .miter
            line.isAntialiased = false
            line.blendMode = .add
            border.addChild(line)
        }
        gridLayer.addChild(border)
        updateArenaBorderAppearance()
    }

    private func updateArenaBorderAppearance() {
        let color = SKColor(
            red: CGFloat(menuModel.settings.gridRed) / 255,
            green: CGFloat(menuModel.settings.gridGreen) / 255,
            blue: CGFloat(menuModel.settings.gridBlue) / 255,
            alpha: 1
        )
        for case let line as SKShapeNode in gridLayer
            .childNode(withName: "arenaBorder")?.children ?? [] {
            line.strokeColor = color
        }
    }

    private func setupPlayer() {
        playerShield.name = "playerShield"
        playerShield.fillColor = SKColor(red: 0.4, green: 0.8, blue: 1, alpha: 1)
        playerShield.strokeColor = .clear
        playerShield.alpha = 0.48
        playerShield.zPosition = 18
        playerShield.isHidden = true
        worldLayer.addChild(playerShield)

        player.name = "player"
        player.texture = OriginalGraphics.texture(
            named: "whiteplayer",
            setIndex: activeGraphicsSetIndex
        )
        player.size = player.texture?.size() ?? CGSize(width: 64, height: 64)
        player.blendMode = .add
        player.color = .white
        player.colorBlendFactor = 0
        player.zPosition = 19
        player.physicsBody = SKPhysicsBody(circleOfRadius: 15)
        player.physicsBody?.affectedByGravity = false
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.categoryBitMask = Category.player
        player.physicsBody?.collisionBitMask = 0
        player.physicsBody?.contactTestBitMask = Category.enemy
        worldLayer.addChild(player)

        for ring in readyRings {
            ring.name = "readyRing"
            ring.fillColor = .white
            ring.strokeColor = .clear
            ring.lineWidth = 0
            ring.glowWidth = 0
            ring.isAntialiased = false
            ring.zPosition = 3
            ring.isHidden = true
            worldLayer.addChild(ring)
        }
    }

    private func setupHUD() {
        hudLayer.addChild(hudRenderer.node)
        // DrawAll emits the fixed HUD after power-ups but before the player,
        // shield, shots, and arena border. The controls stay above gameplay.
        hudRenderer.node.zPosition = -83

        messageLabel.fontSize = 40
        messageLabel.numberOfLines = 3
        messageLabel.preferredMaxLayoutWidth = 800
        messageLabel.horizontalAlignmentMode = .center
        messageLabel.verticalAlignmentMode = .center
        messageLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        messageLabel.fontColor = .white
        messageLabel.alpha = 0
        messageLabel.zPosition = 20
        messageLabel.isHidden = true
        hudLayer.addChild(messageLabel)

        readyMessageNode.zPosition = 20
        readyMessageNode.isHidden = true
        hudLayer.addChild(readyMessageNode)

        bombButton.position = CGPoint(x: size.width - 62, y: 72)
        bombButton.fillColor = SKColor(red: 0.1, green: 0.2, blue: 0.55, alpha: 0.65)
        bombButton.strokeColor = SKColor(red: 0.35, green: 0.75, blue: 1, alpha: 1)
        bombButton.lineWidth = 2
        bombButton.glowWidth = 2
        #if os(macOS)
        bombButton.isHidden = true
        #endif

        let bombText = SKLabelNode(fontNamed: "Menlo-Bold")
        bombText.text = "BOMB"
        bombText.fontSize = 12
        bombText.verticalAlignmentMode = .center
        bombText.fontColor = .white
        bombButton.addChild(bombText)
        hudLayer.addChild(bombButton)

        optionsButton.position = CGPoint(x: 48, y: size.height - 52)
        optionsButton.fillColor = SKColor(red: 0.08, green: 0.25, blue: 0.18, alpha: 0.7)
        optionsButton.strokeColor = SKColor(red: 0.3, green: 1, blue: 0.6, alpha: 1)
        optionsButton.lineWidth = 2
        #if os(macOS)
        optionsButton.isHidden = true
        #endif
        let optionsText = SKLabelNode(fontNamed: "Menlo-Bold")
        optionsText.text = "OPT"
        optionsText.fontSize = 11
        optionsText.verticalAlignmentMode = .center
        optionsText.fontColor = .white
        optionsButton.addChild(optionsText)
        hudLayer.addChild(optionsButton)

        hudLayer.addChild(movementStick)
        hudLayer.addChild(aimingStick)
    }

    private func showAttractTouchControls() {
        #if os(iOS)
        let showsButtons = highScoreNameEntry == nil
        hudLayer.isHidden = !showsButtons
        hudLayer.zPosition = 300
        hudRenderer.node.isHidden = true
        messageLabel.isHidden = true
        movementStick.isHidden = true
        aimingStick.isHidden = true
        bombButton.isHidden = !showsButtons
        optionsButton.isHidden = !showsButtons
        #else
        hudLayer.isHidden = true
        #endif
    }

    private func showGameplayTouchControls() {
        hudLayer.isHidden = false
        hudLayer.zPosition = 100
        hudRenderer.node.isHidden = false
        #if os(iOS)
        movementStick.isHidden = false
        aimingStick.isHidden = false
        bombButton.isHidden = false
        optionsButton.isHidden = false
        #endif
    }

    private func restartGame() {
        enemyLayer.removeAllChildren()
        projectileLayer.removeAllChildren()
        pickupLayer.removeAllChildren()
        trailLayer.removeAllChildren()
        effectLayer.removeAllChildren()
        floatingScores.removeAll()

        session.restart(difficulty: menuModel.settings.difficulty)
        if cheatMode {
            session.invalidateScore()
        } else {
            godMode = false
        }
        spawnDirector.reset()
        destroyedEnemyCount = 0
        lastUpdateTime = 0
        shotTimerFrames = 0
        deathFramesRemaining = 0
        getReadyFrame = -1
        fixedTimeAccumulator = 0
        simulationFrame = session.difficulty.initialFrame
        bombCooldownFrames = 20
        gameplayPaused = false
        player.removeAllActions()
        player.alpha = 1
        centerPlayerAndCamera()
        playerMotion.reset()
        inputResolver.reset()
        frameInput = OriginalResolvedInput()
        gridSimulation.reset()
        gridRenderer.resetAnimation()
        particleSimulation.reset()
        playerShield.isHidden = true
        playerShield.position = player.position
        readyRings.forEach { $0.isHidden = true }
        messageLabel.isHidden = true
        touchMovement = .zero
        touchAim = .zero
        relativeMouseMovement = .zero
        mouseButtons.removeAll()
        currentAim = CGVector(dx: 0, dy: 1)
        updateHUD()
        startGetReadySequence()
    }

    private func centerPlayerAndCamera() {
        let arena = playfieldSize
        player.position = CGPoint(x: arena.width / 2, y: arena.height / 2)
        cameraOffset = OriginalCameraRule.centeredOffset(playfield: arena, viewport: size)
        updateWorldTransformAndStars()
    }

    private func prepareAttractMode() {
        enemyLayer.removeAllChildren()
        projectileLayer.removeAllChildren()
        pickupLayer.removeAllChildren()
        trailLayer.removeAllChildren()
        effectLayer.removeAllChildren()
        floatingScores.removeAll()
        particleSimulation.reset()
        audio.stopAllBlackHoleLoops()
        audio.startMusic(.intro)
        screenFlow.returnToTitle()
        attractDisplayEffects.removeAll(keepingCapacity: true)
        createAttractDisplayEffects()
        clearScorePresentation()
        gameplayPaused = false
        cameraOffset = .zero
        updateWorldTransformAndStars()
        gridLayer.isHidden = true
        trailLayer.isHidden = true
        enemyLayer.isHidden = true
        projectileLayer.isHidden = true
        pickupLayer.isHidden = true
        effectLayer.isHidden = true
        showAttractTouchControls()
        player.isHidden = true
        playerShield.isHidden = true
        readyRings.forEach { $0.isHidden = true }
        particleRenderer.node.zPosition = 201
        renderPresentation()
    }

    private func configureCaptureIfRequested(in view: SKView) {
        guard let captureRequest else { return }
        audio.stopMusic()
        particleSimulation.reset()
        gridRenderer.resetAnimation()
        spawnRandom = BlitzMaxRandomNumberGenerator(seed: 1)
        captureRandom = BlitzMaxRandomNumberGenerator(seed: 1)

        let preparesOriginalState: Bool = switch captureRequest.scenario.subject {
        case .gameplay, .enemy, .enemyMotion, .blackHole, .snake, .interceptor,
             .triangle, .player, .projectile,
             .generator, .powerUp, .powerUpCollection, .powerUpLifecycle,
             .grid, .particleStyle,
             .graphicsSet, .getReady, .death, .gameOver, .highScoreEntry,
             .hudDefault, .hudUpgraded, .hudOverlap, .cameraScroll,
             .powerUpMessage:
            true
        case let .menu(menu):
            menu == .optionsGame || menu == .confirmEndGame
        case .attract:
            false
        }
        if preparesOriginalState {
            prepareOriginalCaptureStars()
        }

        switch captureRequest.scenario.subject {
        case let .attract(page, frame):
            screenFlow.configureCapture(
                page: page,
                frame: 0,
                persistentTitleFrame: page == .title ? 0 : 600
            )
            prepareAttractCaptureRandomState(page: page)
            for _ in 0...frame {
                advanceAttractFrame()
            }
            screenFlow.configureCapture(
                page: page,
                frame: frame,
                persistentTitleFrame: page == .title ? min(600, frame) : 600
            )
        case .gameplay:
            prepareGameplayCapture(includeSamples: true)
        case let .enemy(kind):
            prepareGameplayCapture()
            configureEnemyCapture(kind)
        case let .enemyMotion(kind):
            prepareGameplayCapture()
            configureBasicEnemyMotionCapture(kind)
        case let .blackHole(capture):
            prepareGameplayCapture()
            configureBlackHoleCapture(capture)
        case let .snake(capture):
            prepareGameplayCapture()
            configureSnakeCapture(capture)
        case let .interceptor(capture):
            prepareGameplayCapture()
            configureInterceptorCapture(capture)
        case let .triangle(capture):
            prepareGameplayCapture()
            configureTriangleCapture(capture)
        case let .player(capture):
            prepareGameplayCapture()
            configurePlayerCapture(capture)
        case let .projectile(capture):
            prepareGameplayCapture()
            configureProjectileCapture(capture)
        case let .generator(kind):
            prepareGameplayCapture()
            spawnGenerator(
                kind: EnemyKind(kind),
                at: CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2),
                freezeFrames: 0,
                rate: 60,
                generatorSize: 24
            )
        case let .powerUp(kind):
            prepareGameplayCapture()
            spawnPowerUp(
                at: CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2),
                kind: kind,
                freezeFrames: 0,
                pushesGrid: false
            )
        case let .powerUpCollection(kind):
            prepareGameplayCapture()
            configurePowerUpCollectionCapture(kind)
        case let .powerUpLifecycle(capture):
            prepareGameplayCapture()
            configurePowerUpLifecycleCapture(capture)
        case let .grid(style):
            prepareGameplayCapture()
            gridLayer.childNode(withName: "arenaBorder")?.isHidden = true
            menuModel.settings.gridStyle = style
            menuModel.settings.starCount = 0
            applyRuntimeSettings()
            player.isHidden = true
            hudLayer.isHidden = true
            gridSimulation.pull(
                at: CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2),
                radiusInPoints: 18,
                amount: 28
            )
            for _ in 0..<12 { gridSimulation.update() }
        case let .particleStyle(style):
            prepareGameplayCapture()
            gridLayer.childNode(withName: "arenaBorder")?.isHidden = true
            menuModel.settings.gridStyle = GridStyle.none.rawValue
            menuModel.settings.starCount = 0
            menuModel.settings.particleStyle = style
            applyRuntimeSettings()
            player.isHidden = true
            hudLayer.isHidden = true
            for index in 0..<192 {
                emitParticles(
                    count: 1,
                    at: CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2),
                    kind: .radialBomb,
                    color: ParticleColor(red: 255, green: 180, blue: 32),
                    rotation: { _ in CGFloat(index) * 360 / 192 }
                )
            }
            for _ in 0..<5 { particleSimulation.update() }
        case let .graphicsSet(set):
            menuModel.settings.graphicsSetIndex = set.rawValue
            applyRuntimeSettings()
            prepareGameplayCapture(includeSamples: true)
        case let .getReady(frame):
            prepareGameplayCapture()
            startGetReadySequence()
            for sourceFrame in 0...frame {
                if sourceFrame == OriginalGetReadyRule.ringPullFrame {
                    gridSimulation.pull(at: player.position, radiusInPoints: 20, amount: 20)
                }
                for _ in 0..<OriginalGetReadyRule.gridUpdatesPerFrame {
                    gridSimulation.update()
                }
            }
            getReadyFrame = frame
            advanceGetReadySequence(updatesGrid: false)
        case .death:
            prepareGameplayCapture()
            _ = hitPlayer()
            cycleColors()
            cycleColors()
            gridSimulation.update()
            particleSimulation.update()
        case let .gameOver(frame):
            prepareGameplayCapture()
            player.isHidden = true
            messageLabel.isHidden = true
            screenFlow.showGameOver()
            for _ in 0...frame {
                cycleColors()
                cycleColors()
                gridSimulation.update()
                particleSimulation.update()
            }
            for _ in 0..<frame { _ = screenFlow.advance() }
        case .highScoreEntry:
            screenFlow.configureCapture(page: .scores, frame: 600)
            pendingHighScore = PendingHighScore(
                score: 123_456,
                playTime: LegacyHighScoreTable.playTime(frames: 10_050),
                difficulty: .medium,
                settings: "0,0,0,0,0,0,0,0,0,0"
            )
            beginHighScoreNameEntry()
        case .hudDefault:
            prepareGameplayCapture()
        case .hudUpgraded:
            prepareGameplayCapture()
            session.grantCheatCannon()
            session.grantCheatCannon()
            session.grantCheatShotSpeed()
            session.grantCheatShotSpeed()
            for kind in [
                PowerUpKind.reverseShooter,
                .sideShooters,
                .extraPlayer,
                .extraBomb,
                .shield,
                .superShots,
                .bouncyShots,
            ] {
                _ = session.collectPowerUp(kind)
            }
            _ = session.registerScore(baseScore: 123_456)
            updatePlayerShield()
            updateHUD()
        case .hudOverlap:
            prepareGameplayCapture()
            player.position = sourcePoint(CGPoint(x: playfieldSize.width / 2, y: 19))
            updateHUD()
        case .cameraScroll:
            prepareGameplayCapture()
            menuModel.settings.playfieldWidth = 1_280
            menuModel.settings.playfieldHeight = 960
            menuModel.settings.starCount = 0
            menuModel.settings.scroll = true
            applyRuntimeSettings()
            player.position = sourcePoint(CGPoint(x: 16, y: 16))
            cameraOffset = CGPoint(x: -80, y: 272)
            updateWorldTransformAndStars()
            let samplePosition = sourcePoint(CGPoint(x: 160, y: 160))
            _ = spawnEnemy(
                kind: .pinwheel,
                at: samplePosition,
                freezeFrames: 0,
                closeToPlayer: true,
                playBornSound: false
            )
            showFloatingScore(baseScore: 25, at: samplePosition)
            updateHUD()
        case .powerUpMessage:
            prepareGameplayCapture()
            session.restart(difficulty: session.difficulty)
            session.advancePowerUpStatusMessageFrame()
            updateHUD()
        case let .menu(menu):
            configureMenuCapture(menu)
            menuPresentationPage = menuModel.page
            menuPresentationFrame = 20
        }

        renderPresentation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self, weak view] in
            guard let self, let view else { return }
            self.writeCapture(from: view, to: captureRequest.outputPath, attempt: 0)
        }
    }

    private func prepareGameplayCapture(includeSamples: Bool = false) {
        beginGame()
        audio.stopMusic()
        session.clearPowerUpStatusMessage()
        getReadyFrame = -1
        deathFramesRemaining = 0
        player.removeAllActions()
        player.isHidden = false
        player.alpha = 1
        player.position = CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2)
        playerShield.isHidden = true
        readyRings.forEach { $0.isHidden = true }
        messageLabel.removeAllActions()
        messageLabel.isHidden = true
        if includeSamples {
            let samples: [(EnemyKind, CGPoint)] = [
                (.pinwheel, CGPoint(x: 180, y: 180)),
                (.diamond, CGPoint(x: 330, y: 560)),
                (.greenSquare, CGPoint(x: 790, y: 570)),
                (.seeker, CGPoint(x: 840, y: 230)),
                (.triangle, CGPoint(x: 650, y: 180)),
            ]
            for sample in samples {
                _ = spawnEnemy(
                    kind: sample.0,
                    at: sample.1,
                    freezeFrames: 0,
                    playBornSound: false
                )
            }
            spawnPowerUp(
                at: CGPoint(x: 360, y: 260),
                kind: .shield,
                freezeFrames: 0,
                pushesGrid: false
            )
        }
    }

    private func prepareOriginalCaptureStars() {
        guard var random = captureRandom else { return }
        starStates = OriginalStarRule.create(
            maximumIndex: OriginalRuntimeSettings.maximumStars,
            playfieldSize: playfieldSize,
            screenSize: size,
            using: &random
        )
        ensureStarCapacity(through: menuModel.settings.starCount)
        for index in starNodes.indices {
            configureStarNode(starNodes[index], index: index)
        }
        captureRandom = random
    }

    private func configureEnemyCapture(_ originalKind: OriginalEnemyKind) {
        let kind = EnemyKind(originalKind)
        player.position = sourcePoint(CGPoint(x: playfieldSize.width / 2, y: 100))
        let center = CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2)
        if kind == .triangle {
            let first = spawnEnemy(
                kind: kind,
                at: CGPoint(x: center.x - 55, y: center.y),
                freezeFrames: 0,
                closeToPlayer: true,
                playBornSound: false
            )
            let second = spawnEnemy(
                kind: kind,
                at: CGPoint(x: center.x + 55, y: center.y),
                freezeFrames: 0,
                closeToPlayer: true,
                playBornSound: false
            )
            if let first, let second {
                attachTriangles(first, second)
                updateEnemyVisual(
                    first,
                    kind: .triangle,
                    rotation: (first.userData?["rotation"] as? NSNumber)?.intValue ?? 0
                )
                updateEnemyVisual(
                    second,
                    kind: .triangle,
                    rotation: (second.userData?["rotation"] as? NSNumber)?.intValue ?? 0
                )
                updateTrianglePairsAndBonds()
            }
            return
        }
        guard let enemy = spawnEnemy(
            kind: kind,
            at: center,
            freezeFrames: 0,
            closeToPlayer: true,
            playBornSound: false
        ) else { return }
        if kind == .blackHole {
            enemy.userData?["blackHoleSize"] = 36.0
            enemy.userData?["blackHoleActive"] = true
            var velocity = CGVector.zero
            updateBlackHole(
                enemy,
                velocity: &velocity,
                maximumSpeed: 1,
                rotation: (enemy.userData?["rotation"] as? NSNumber)?.intValue ?? 0
            )
        } else if kind == .snake {
            layoutSnakeForCapture(enemy)
        }
    }

    private func configureBasicEnemyMotionCapture(_ originalKind: OriginalEnemyKind) {
        let kind = EnemyKind(originalKind)
        player.position = sourcePoint(CGPoint(x: playfieldSize.width / 2, y: 100))
        let center = CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2)
        for xOffset in [-9, 9] {
            _ = spawnEnemy(
                kind: kind,
                at: CGPoint(x: center.x + CGFloat(xOffset), y: center.y),
                freezeFrames: 0,
                closeToPlayer: true,
                playBornSound: false
            )
        }
        for _ in 0..<30 {
            updateEnemies(kinds: [kind])
        }
    }

    private func configureBlackHoleCapture(_ capture: OriginalBlackHoleCapture) {
        player.position = sourcePoint(CGPoint(x: playfieldSize.width / 2, y: 100))
        let center = CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2)

        switch capture {
        case .motion:
            let first = spawnEnemy(
                kind: .blackHole,
                at: CGPoint(x: center.x - 18, y: center.y),
                freezeFrames: 0,
                closeToPlayer: true,
                playBornSound: false
            )
            let second = spawnEnemy(
                kind: .blackHole,
                at: CGPoint(x: center.x + 18, y: center.y),
                freezeFrames: 0,
                closeToPlayer: true,
                playBornSound: false
            )
            first?.userData?["blackHoleSize"] = 36.0
            first?.userData?["blackHoleActive"] = true
            second?.userData?["blackHoleSize"] = 28.0
            second?.userData?["blackHoleActive"] = true
            for _ in 0..<30 {
                updateEnemies(kinds: [.blackHole])
            }
        case .shrink:
            guard let blackHole = spawnEnemy(
                kind: .blackHole,
                at: center,
                freezeFrames: 0,
                closeToPlayer: true,
                playBornSound: false
            ) else { return }
            blackHole.userData?["blackHoleSize"] = 4.5
            blackHole.userData?["blackHoleActive"] = true
            blackHole.userData?["absorbCount"] = 5
            let projectile = SKNode()
            projectile.userData = NSMutableDictionary(dictionary: ["dx": 0.0, "dy": 0.0])
            damageEnemy(blackHole, projectile: projectile)
        case .explosion:
            guard let blackHole = spawnEnemy(
                kind: .blackHole,
                at: center,
                freezeFrames: 0,
                closeToPlayer: true,
                playBornSound: false
            ) else { return }
            blackHole.userData?["blackHoleSize"] = 64.5
            blackHole.userData?["blackHoleActive"] = true
            growBlackHole(blackHole, amount: 1)
        case .particles:
            guard let blackHole = spawnEnemy(
                kind: .blackHole,
                at: center,
                freezeFrames: 0,
                closeToPlayer: true,
                playBornSound: false
            ) else { return }
            blackHole.userData?["blackHoleSize"] = 20.0
            blackHole.userData?["blackHoleActive"] = true
            blackHole.userData?["rotation"] = 59
            updateEnemies(kinds: [.blackHole])
        }
    }

    private func configureSnakeCapture(_ capture: OriginalSnakeCapture) {
        player.position = sourcePoint(CGPoint(x: playfieldSize.width / 2, y: 100))
        let center = CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2)
        guard let head = spawnEnemy(
            kind: .snake,
            at: center,
            freezeFrames: 0,
            closeToPlayer: true,
            playBornSound: false
        ) else { return }

        switch capture {
        case .motion:
            for _ in 0..<30 {
                updateEnemies(kinds: [.snake])
            }
        case .tailHit:
            layoutSnakeForCapture(head)
            guard let segment = snakeSegments(for: head).first(where: {
                (($0.userData?["originalFrame"] as? NSNumber)?.intValue ?? -1) == 16
            }) else { return }
            let projectile = SKNode()
            projectile.userData = NSMutableDictionary(dictionary: ["dx": 0.0, "dy": 0.0])
            damageEnemy(segment, projectile: projectile)
        case .cascade:
            layoutSnakeForCapture(head)
            let projectile = SKNode()
            projectile.userData = NSMutableDictionary(dictionary: ["dx": 0.0, "dy": 0.0])
            damageEnemy(head, projectile: projectile)
            for _ in 0..<8 {
                updateEnemies(kinds: [.snake])
            }
        }
    }

    private func layoutSnakeForCapture(_ head: SKNode) {
        guard let headID = head.userData?["enemyID"] as? String else { return }
        let center = CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2)
        for segment in enemyLayer.children where
            segment.name == "snakeTail"
                && segment.userData?["snakeHeadID"] as? String == headID {
            let index = (segment.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0
            let sourceIndex = index + 1
            segment.position = sourcePoint(CGPoint(
                x: center.x - CGFloat(sourceIndex) * 13,
                y: center.y + sin(CGFloat(sourceIndex * 20) * .pi / 180) * 22
            ))
        }
    }

    private func snakeSegments(for head: SKNode) -> [SKNode] {
        guard let headID = head.userData?["enemyID"] as? String else { return [] }
        return enemyLayer.children.filter {
            $0.name == "snakeTail" && $0.userData?["snakeHeadID"] as? String == headID
        }
    }

    private func configureInterceptorCapture(_ capture: OriginalInterceptorCapture) {
        player.position = sourcePoint(CGPoint(x: playfieldSize.width / 2, y: 100))
        let center = CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2)
        guard let interceptor = spawnEnemy(
            kind: .interceptor,
            at: center,
            freezeFrames: 0,
            closeToPlayer: true,
            playBornSound: false
        ) else { return }

        switch capture {
        case .motion:
            for _ in 0..<30 {
                updateEnemies(kinds: [.interceptor])
                cacheInterceptorShieldCollisionGeometry()
            }
        case .shield, .block:
            interceptor.userData?["dx"] = 4.0
            interceptor.userData?["dy"] = 0.0
            interceptor.userData?["rotation"] = 180
            interceptor.userData?["interceptorHeading"] = 0.0
            interceptor.userData?["interceptorTurnRemaining"] = 0
            updateEnemyVisual(interceptor, kind: .interceptor, rotation: 180)
            updateInterceptorShieldVisual(interceptor)
            cacheInterceptorShieldCollisionGeometry()
            if capture == .block {
                let projectile = SKSpriteNode(texture: OriginalGraphics.texture(
                    named: "yellowshot",
                    setIndex: activeGraphicsSetIndex
                ))
                projectile.name = "projectile"
                projectile.blendMode = .add
                projectile.position = CGPoint(x: center.x + 30, y: center.y)
                projectile.userData = NSMutableDictionary(dictionary: [
                    "dx": 10.0,
                    "dy": 0.0,
                    "speed": 10.0,
                ])
                projectileLayer.addChild(projectile)
                updateProjectiles()
            }
        }
    }

    private func configureTriangleCapture(_ capture: OriginalTriangleCapture) {
        player.position = sourcePoint(CGPoint(x: playfieldSize.width / 2, y: 100))
        let center = CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2)

        if capture == .motion {
            _ = spawnEnemy(
                kind: .triangle,
                at: center,
                freezeFrames: 0,
                closeToPlayer: true,
                playBornSound: false
            )
            for _ in 0..<30 {
                updateEnemies(kinds: [.triangle])
            }
            updateTrianglePairsAndBonds()
            return
        }

        let halfDistance: CGFloat = capture == .bond ? 90 : (capture == .blackHole ? 50 : 55)
        guard let first = spawnEnemy(
            kind: .triangle,
            at: CGPoint(x: center.x - halfDistance, y: center.y),
            freezeFrames: 0,
            closeToPlayer: true,
            playBornSound: false
        ), let second = spawnEnemy(
            kind: .triangle,
            at: CGPoint(x: center.x + halfDistance, y: center.y),
            freezeFrames: 0,
            closeToPlayer: true,
            playBornSound: false
        ) else { return }

        for triangle in [first, second] {
            triangle.userData?["dx"] = 0.0
            triangle.userData?["dy"] = 0.0
            triangle.userData?["rotation"] = 0
            updateEnemyVisual(triangle, kind: .triangle, rotation: 0)
        }
        attachTriangles(first, second)
        updateEnemyVisual(first, kind: .triangle, rotation: 0)
        updateEnemyVisual(second, kind: .triangle, rotation: 0)

        switch capture {
        case .motion:
            break
        case .bond:
            for _ in 0..<30 {
                updateEnemies(kinds: [.triangle])
            }
        case .hit:
            let projectile = SKNode()
            projectile.userData = NSMutableDictionary(dictionary: [
                "dx": 10.0,
                "dy": 0.0,
            ])
            damageEnemy(first, projectile: projectile)
        case .blackHole:
            second.userData?["triangleStrength"] = 0.25
            guard let blackHole = spawnEnemy(
                kind: .blackHole,
                at: first.position,
                freezeFrames: 0,
                closeToPlayer: true,
                playBornSound: false
            ) else { return }
            blackHole.userData?["dx"] = 0.0
            blackHole.userData?["dy"] = 0.0
            blackHole.userData?["rotation"] = 45
            blackHole.userData?["blackHoleSize"] = 20.0
            blackHole.userData?["blackHoleActive"] = false
            // Reproduce the live frame order: bond visuals already exist when
            // the later enemy update snaps the bond.
            updateTrianglePairsAndBonds()
            updateEnemies(kinds: [.triangle])
            updateEnemyVisual(blackHole, kind: .blackHole, rotation: 45)
            return
        }
        updateTrianglePairsAndBonds()
    }

    private func configurePlayerCapture(_ capture: OriginalPlayerCapture) {
        switch capture {
        case .motion:
            player.position = sourcePoint(CGPoint(x: 360, y: playfieldSize.height / 2))
            playerMotion.reset()
            for frame in 0..<24 {
                let input = frame < 12
                    ? CGVector(dx: 1, dy: 0)
                    : CGVector(dx: 0, dy: 1)
                advanceCapturedPlayer(input: input)
            }
        case .boundary:
            player.position = sourcePoint(CGPoint(x: 17, y: playfieldSize.height / 2))
            playerMotion.reset()
            advanceCapturedPlayer(input: CGVector(dx: -1, dy: 0))
        case .shield:
            _ = session.collectPowerUp(.shield)
            updatePlayerShield()
        case .cannon1, .cannon2, .cannon3, .cannon4, .reverseSide:
            let cannons: Int = switch capture {
            case .cannon1, .reverseSide: 1
            case .cannon2: 2
            case .cannon3: 3
            case .cannon4: 4
            default: 1
            }
            let aim = CGVector(dx: 1, dy: 0)
            player.zRotation = PlayerVisualRule.sceneRotation(forMovement: aim)
            let launches = PlayerWeaponRule.launches(
                aim: aim,
                cannons: cannons,
                shotSpeed: 3,
                reverseShooter: capture == .reverseSide,
                sideShooters: capture == .reverseSide
            )
            for launch in launches {
                spawnProjectile(
                    direction: launch.direction,
                    speed: launch.speed,
                    offset: launch.offset
                )
            }
            for _ in 0..<6 { updateProjectiles() }
        }
    }

    private func configureProjectileCapture(_ capture: OriginalProjectileCapture) {
        player.position = sourcePoint(CGPoint(x: playfieldSize.width / 2, y: 100))
        let center = CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2)

        switch capture {
        case .superPierce:
            _ = session.collectPowerUp(.superShots)
            for xOffset in [0, 20] {
                _ = spawnEnemy(
                    kind: .pinwheel,
                    at: CGPoint(x: center.x + CGFloat(xOffset), y: center.y),
                    freezeFrames: 0,
                    closeToPlayer: true,
                    playBornSound: false
                )
            }
            let projectile = spawnProjectile(direction: CGVector(dx: 1, dy: 0), speed: 40)
            projectile?.position = CGPoint(x: center.x - 20, y: center.y)
            updateProjectiles()

        case .bouncyWall:
            _ = session.collectPowerUp(.bouncyShots)
            let projectile = spawnProjectile(direction: CGVector(dx: 0, dy: 1), speed: 2)
            projectile?.position = sourcePoint(CGPoint(x: center.x, y: 1))
            updateProjectiles()

        case .bouncyHit:
            _ = session.collectPowerUp(.bouncyShots)
            _ = spawnEnemy(
                kind: .pinwheel,
                at: center,
                freezeFrames: 0,
                closeToPlayer: true,
                playBornSound: false
            )
            let projectile = spawnProjectile(direction: CGVector(dx: 1, dy: 0), speed: 40)
            projectile?.position = CGPoint(x: center.x - 20, y: center.y)
            updateProjectiles()

        case .superBlackHole, .bouncyBlackHole:
            _ = session.collectPowerUp(
                capture == .superBlackHole ? .superShots : .bouncyShots
            )
            guard let blackHole = spawnEnemy(
                kind: .blackHole,
                at: center,
                freezeFrames: 0,
                closeToPlayer: true,
                playBornSound: false
            ) else { return }
            blackHole.userData?["blackHoleSize"] = 20.0
            blackHole.userData?["blackHoleActive"] = true
            updateEnemyVisual(
                blackHole,
                kind: .blackHole,
                rotation: (blackHole.userData?["rotation"] as? NSNumber)?.intValue ?? 0
            )
            let projectile = spawnProjectile(direction: CGVector(dx: 1, dy: 0), speed: 10)
            projectile?.position = CGPoint(x: center.x - 60, y: center.y)
            updateProjectiles()
        }
    }

    private func configurePowerUpCollectionCapture(_ kind: PowerUpKind) {
        let powerUp = spawnPowerUp(
            at: CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2),
            kind: kind,
            freezeFrames: 0,
            pushesGrid: false
        )
        applyPowerUpCollection(powerUp)
        powerUp.removeFromParent()
    }

    private func configurePowerUpLifecycleCapture(_ capture: OriginalPowerUpLifecycleCapture) {
        player.position = sourcePoint(CGPoint(x: playfieldSize.width / 2, y: 100))
        let center = CGPoint(x: playfieldSize.width / 2, y: playfieldSize.height / 2)

        switch capture {
        case .aged:
            let powerUp = spawnPowerUp(
                at: center,
                kind: .extraCannon,
                freezeFrames: 0,
                pushesGrid: false
            )
            powerUp.userData?["lifeFrames"] = 361
            updatePowerUpVisual(powerUp, lifeFrames: 361)
        case .merge:
            let first = spawnPowerUp(
                at: CGPoint(x: center.x - 8, y: center.y),
                kind: .extraCannon,
                freezeFrames: 0,
                pushesGrid: false
            )
            let second = spawnPowerUp(
                at: CGPoint(x: center.x + 8, y: center.y),
                kind: .fasterShots,
                freezeFrames: 0,
                pushesGrid: false
            )
            for powerUp in [first, second] {
                powerUp.userData?["lifeFrames"] = 200
                powerUp.userData?["dx"] = 0.0
                powerUp.userData?["dy"] = 0.0
            }
            updatePowerUps()
        case .expire:
            let powerUp = spawnPowerUp(
                at: center,
                kind: .reverseShooter,
                freezeFrames: 0,
                pushesGrid: false
            )
            powerUp.userData?["lifeFrames"] = 400
            powerUp.userData?["dx"] = 0.0
            powerUp.userData?["dy"] = 0.0
            updatePowerUps()
        case .blackHole:
            guard let blackHole = spawnEnemy(
                kind: .blackHole,
                at: center,
                freezeFrames: 0,
                closeToPlayer: true,
                playBornSound: false
            ) else { return }
            blackHole.userData?["blackHoleSize"] = 20.0
            blackHole.userData?["blackHoleActive"] = true
            let powerUp = spawnPowerUp(
                at: CGPoint(x: center.x + 20, y: center.y),
                kind: .extraCannon,
                freezeFrames: 0,
                pushesGrid: false
            )
            powerUp.userData?["lifeFrames"] = 10
            powerUp.userData?["rotation"] = 37
            powerUp.userData?["dx"] = 0.0
            powerUp.userData?["dy"] = 0.0
            updatePowerUps()
            updateEnemyVisual(
                blackHole,
                kind: .blackHole,
                rotation: (blackHole.userData?["rotation"] as? NSNumber)?.intValue ?? 0
            )
        }
    }

    private func advanceCapturedPlayer(input: CGVector) {
        let result = playerMotion.advance(
            from: player.position,
            input: input,
            arenaSize: playfieldSize,
            inertia: 0.5
        )
        player.position = result.position
        if result.movement.length > 0 {
            player.zRotation = PlayerVisualRule.sceneRotation(forMovement: result.movement)
        }
        if abs(result.movement.dx) > 0.1 || abs(result.movement.dy) > 0.1 {
            createPlayerTrail(movement: result.movement)
        }
        updatePlayerTrails()
        simulationFrame += 1
    }

    private func configureMenuCapture(_ capture: OriginalMenuCapture) {
        menuModel.settings.windowed = true
        menuModel.settings.screenSizeIndex = 8
        menuModel.settings.screenWidth = 1_024
        menuModel.settings.screenHeight = 768
        let duringGame = capture == .optionsGame || capture == .confirmEndGame
        if duringGame {
            prepareGameplayCapture(includeSamples: true)
        }
        menuModel.open(duringGame: duringGame)
        menuPresentationPage = .options
        menuPresentationFrame = 20
        if capture == .options || capture == .optionsGame { return }
        if capture == .confirmExit {
            menuModel.select(0)
            _ = menuModel.activate()
            return
        }
        if capture == .confirmEndGame {
            menuModel.select(2)
            _ = menuModel.activate()
            return
        }

        menuModel.select(1)
        _ = menuModel.activate()
        if capture == .settings { return }
        let settingsIndex: Int
        switch capture {
        case .audio: settingsIndex = 0
        case .video, .confirmKeepVideo: settingsIndex = 1
        case .controller, .hybrid, .mouse, .keyboard, .joypad, .dualAnalog:
            settingsIndex = 2
        case .game, .confirmKeepGame: settingsIndex = 3
        default: return
        }
        menuModel.select(settingsIndex)
        _ = menuModel.activate()
        if capture == .confirmKeepVideo {
            menuModel.select(0)
            _ = menuModel.adjust(by: 1)
            menuModel.select(10)
            _ = menuModel.activate()
            return
        }
        if capture == .confirmKeepGame {
            menuModel.select(0)
            _ = menuModel.adjust(by: 1)
            menuModel.select(5)
            _ = menuModel.activate()
            return
        }
        if capture == .audio || capture == .video || capture == .game || capture == .controller {
            return
        }

        menuModel.settings.controllerType = switch capture {
        case .hybrid: .hybrid
        case .mouse: .mouse
        case .keyboard: .keyboard
        case .joypad: .joypad
        default: .dualAnalog
        }
        menuModel.select(1)
        _ = menuModel.activate()
    }

    private func writeCapture(
        from view: SKView,
        to outputPath: String,
        attempt: Int
    ) {
        #if os(macOS)
        guard !captureWasWritten else { return }
        guard let texture = view.texture(from: self) else {
            guard attempt < 20 else {
                fputs("GridWars capture failed: rendered texture unavailable\n", stderr)
                NSApplication.shared.terminate(nil)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak view] in
                guard let self, let view else { return }
                self.writeCapture(from: view, to: outputPath, attempt: attempt + 1)
            }
            return
        }
        let image = texture.cgImage()
        let url = URL(fileURLWithPath: outputPath)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let normalizedImage = normalizedCaptureImage(image) else {
            fputs("GridWars capture failed: image normalization unavailable\n", stderr)
            NSApplication.shared.terminate(nil)
            return
        }
        let bitmap = NSBitmapImageRep(cgImage: normalizedImage)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            fputs("GridWars capture failed: PNG encoding unavailable\n", stderr)
            NSApplication.shared.terminate(nil)
            return
        }
        do {
            try png.write(to: url, options: .atomic)
            captureWasWritten = true
            fputs("GridWars capture written: \(outputPath)\n", stderr)
        } catch {
            fputs("GridWars capture failed: \(error)\n", stderr)
        }
        NSApplication.shared.terminate(nil)
        #endif
    }

    #if os(macOS)
    private func normalizedCaptureImage(_ image: CGImage) -> CGImage? {
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        guard width > 0, height > 0,
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
    #endif

    private func beginGame() {
        clearScorePresentation()
        menuModel.close()
        audio.stopMusic()
        audio.stopAllBlackHoleLoops()
        screenFlow.startGame()
        screenRenderer.hide()
        particleSimulation.reset()
        particleRenderer.node.zPosition = 5
        gridLayer.isHidden = false
        trailLayer.isHidden = false
        enemyLayer.isHidden = false
        projectileLayer.isHidden = false
        pickupLayer.isHidden = false
        effectLayer.isHidden = false
        showGameplayTouchControls()
        applyRuntimeSettings()
        restartGame()
    }

    override func update(_ currentTime: TimeInterval) {
        if captureRequest != nil {
            renderPresentation()
            return
        }
        pollController()
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            renderPresentation()
            return
        }

        let deltaTime = min(
            OriginalTimingRule.maximumAccumulatedTime,
            currentTime - lastUpdateTime
        )
        lastUpdateTime = currentTime
        fixedTimeAccumulator += deltaTime
        while fixedTimeAccumulator >= OriginalTimingRule.fixedStep {
            let gridIsAnimating = menuModel.page == .video && menuModel.isOpen
                || (!menuModel.isOpen && !gameplayPaused && {
                    switch screenFlow.phase {
                    case .playing, .gameOver: true
                    case .attract: false
                    }
                }())
            if gridIsAnimating {
                gridRenderer.advanceAnimation()
            }
            if highScoreNameEntry != nil {
                cycleColors()
                if originalRandomInt(0...100) > 90 {
                    emitFirework(style: 2)
                }
                particleSimulation.update()
            } else if menuModel.isOpen {
                menuPresentationFrame += 1
                if menuModel.page == .video {
                    if menuPresentationFrame % 60 == 0,
                       [5, 7, 8, 9].contains(menuModel.selection) {
                        gridSimulation.pull(
                            at: CGPoint(
                                x: CGFloat(originalRandomInt(0...20) * 16),
                                y: CGFloat(originalRandomInt(0...20) * 16)
                            ),
                            radiusInPoints: 8,
                            amount: 24
                        )
                    }
                    cycleColors()
                    gridSimulation.update()
                    if menuModel.selection == 7,
                       originalRandomInt(0...100) > 94 {
                        emitFirework(style: 2)
                    }
                    particleSimulation.updateWide(screenSize: size)
                }
            } else if !menuModel.isOpen, !gameplayPaused {
                switch screenFlow.phase {
                case .attract:
                    advanceAttractFrame()
                case .playing:
                    simulateFrame()
                case .gameOver:
                    advanceGameOverFrame()
                }
            }
            fixedTimeAccumulator -= OriginalTimingRule.fixedStep
        }
        renderPresentation()
    }

    private func advanceAttractFrame() {
        if case let .attract(page) = screenFlow.phase {
            switch page {
            case .title:
                cycleColors()
                emitAttractFireworkIfNeeded(page: page, chance: 90, cutoff: 850)
                if screenFlow.persistentTitleFrame > 350 {
                    particleSimulation.updateWide(screenSize: size)
                    for effect in attractDisplayEffects {
                        particleSimulation.applyBlackHole(
                            at: sourcePoint(effect.position),
                            size: effect.size,
                            frame: screenFlow.frame + 1
                        )
                    }
                    updateAttractDisplayEffects()
                }
            case .scores:
                cycleColors()
                cycleColors()
                recordAttractTrail(page: page)
                emitAttractFireworkIfNeeded(page: page, chance: 90, cutoff: 700)
                particleSimulation.updateWide(screenSize: size)
            case .friends:
                emitAttractFireworkIfNeeded(page: page, chance: 94, cutoff: 850)
                particleSimulation.updateWide(screenSize: size)
                for effect in attractDisplayEffects {
                    particleSimulation.applyBlackHole(
                        at: sourcePoint(effect.position),
                        size: effect.size,
                        frame: screenFlow.persistentTitleFrame + screenFlow.frame + 1
                    )
                }
                updateAttractDisplayEffects()
                cycleColors()
                cycleColors()
                recordAttractTrail(page: page)
            case .enemies:
                emitAttractFireworkIfNeeded(page: page, chance: 94, cutoff: 850)
                particleSimulation.updateWide(screenSize: size)
            }
        }
        let wasScorePage = screenFlow.phase == .attract(.scores)
        let returnsToTitleAfterScores = wasScorePage && scorePageDifficulty != nil
        let wasEnemyPage = screenFlow.phase == .attract(.enemies)
        let advancedPage = returnsToTitleAfterScores
            ? screenFlow.advancePostGameScorePage()
            : screenFlow.advance()
        if advancedPage {
            if wasScorePage {
                clearScorePresentation()
                audio.startMusic(.intro)
                if returnsToTitleAfterScores {
                    createAttractDisplayEffects()
                }
            }
            if wasEnemyPage {
                createAttractDisplayEffects()
            }
        }
    }

    private func emitAttractFireworkIfNeeded(
        page: OriginalAttractPage,
        chance: Int,
        cutoff: Int
    ) {
        guard screenFlow.frame < cutoff,
              page != .title || screenFlow.persistentTitleFrame > 350,
              originalRandomInt(0...100) > chance else { return }
        emitFirework(style: page == .title ? 0 : 1)
    }

    private func recordAttractTrail(page: OriginalAttractPage) {
        guard captureRequest != nil else { return }
        screenRenderer.recordAttractTrail(
            page: page,
            frame: screenFlow.frame,
            color: SKColor(
                red: CGFloat(cyclingRed) / 255,
                green: CGFloat(cyclingGreen) / 255,
                blue: CGFloat(cyclingBlue) / 255,
                alpha: 1
            )
        )
    }

    private func advanceGameOverFrame() {
        updateParticleSimulation()
        gridSimulation.update()
        session.advancePowerUpStatusMessageFrame()
        if screenFlow.advance() {
            presentPostGameResult()
        }
    }

    private func skipGameOverToScores() {
        guard screenFlow.phase == .gameOver else { return }
        screenFlow.skipGameOver()
        presentPostGameResult()
    }

    private func presentPostGameResult() {
        screenFlow.showPostGameScores()
        preparePostGameScores()
        attractDisplayEffects.removeAll(keepingCapacity: true)
        if session.score <= 0 {
            clearScorePresentation()
            screenFlow.returnToTitle()
            createAttractDisplayEffects()
        }
        enterAttractPresentation()
    }

    private func preparePostGameScores() {
        particleSimulation.reset()
        gridSimulation.reset()
        let score = session.score
        let qualifies = highScores.qualifies(score: score, difficulty: session.difficulty)
        let route = OriginalPostGameScoreRule.route(
            score: score,
            isValid: session.isScoreValid,
            qualifies: qualifies
        )
        guard route != .noScore else { audio.startMusic(.intro); return }

        let playTime = LegacyHighScoreTable.playTime(frames: simulationFrame)
        scorePageDifficulty = session.difficulty
        highlightedScorePosition = nil
        unrankedScoreEntry = nil

        switch route {
        case .nameEntry:
            audio.startMusic(.highScore)
            audio.play(.highScore)
            pendingHighScore = PendingHighScore(
                score: score,
                playTime: playTime,
                difficulty: session.difficulty,
                settings: menuModel.settings.highScoreSettingsString()
            )
            beginHighScoreNameEntry()
        case let .unranked(useHighScoreMusic):
            audio.startMusic(useHighScoreMusic ? .highScore : .intro)
            unrankedScoreEntry = LegacyHighScoreEntry(
                score: score,
                playTime: playTime,
                name: "        ",
                settings: menuModel.settings.highScoreSettingsString()
            )
        case .noScore:
            break
        }
    }

    private func beginHighScoreNameEntry() {
        highScoreNameEntry = OriginalHighScoreNameEntry(
            characters: retainedHighScoreNameCharacters
        )
        controllerHorizontalIsLatched = false
        controllerVerticalIsLatched = false
        highScoreFireAxisIsLatched = false
    }

    private func finishHighScoreNameEntry() {
        guard let entry = highScoreNameEntry, let pending = pendingHighScore else { return }
        retainedHighScoreNameCharacters = entry.characters
        highlightedScorePosition = highScores.insert(
            score: pending.score,
            playTime: pending.playTime,
            name: entry.name,
            settings: pending.settings,
            difficulty: pending.difficulty
        )
        highScoreNameEntry = nil
        pendingHighScore = nil
        showAttractTouchControls()
        persistState()
    }

    private func clearScorePresentation() {
        highScoreNameEntry = nil
        pendingHighScore = nil
        scorePageDifficulty = nil
        highlightedScorePosition = nil
        unrankedScoreEntry = nil
        controllerHorizontalIsLatched = false
        controllerVerticalIsLatched = false
        highScoreFireAxisIsLatched = false
    }

    private func renderPresentation() {
        applyGraphicsSetIfNeeded()
        let cyclingColor = SKColor(
            red: CGFloat(cyclingRed) / 255,
            green: CGFloat(cyclingGreen) / 255,
            blue: CGFloat(cyclingBlue) / 255,
            alpha: 1
        )
        if let highScoreNameEntry, let pendingHighScore {
            particleRenderer.node.zPosition = 201
            screenRenderer.renderHighScoreEntry(
                highScoreNameEntry,
                score: pendingHighScore.score,
                playTime: pendingHighScore.playTime,
                difficulty: pendingHighScore.difficulty,
                size: size
            )
            particleRenderer.render(particleSimulation, style: menuModel.settings.particleStyle)
            return
        }
        if menuModel.isOpen {
            if menuPresentationPage != menuModel.page {
                menuPresentationPage = menuModel.page
                menuPresentationFrame = 0
            }
            let showsVideoPreview = menuModel.page == .video
            gridLayer.zPosition = showsVideoPreview ? 201 : -10
            gridLayer.isHidden = !showsVideoPreview && screenFlow.phase != .playing && screenFlow.phase != .gameOver
            particleRenderer.node.zPosition = showsVideoPreview ? 201 : 5
            gridLayer.childNode(withName: "arenaBorder")?.isHidden = showsVideoPreview
            for (index, star) in starNodes.enumerated() {
                star.isHidden = showsVideoPreview
                    || menuModel.settings.starCount == 0
                    || index > menuModel.settings.starCount
            }
            screenRenderer.renderMenu(
                menuModel,
                frame: menuPresentationFrame,
                size: size,
                capturePointerYFromTop: captureRequest == nil ? nil : 0
            )
            if showsVideoPreview {
                renderGrid()
                particleRenderer.render(particleSimulation, style: menuModel.settings.particleStyle)
            }
            return
        }

        gridLayer.zPosition = -10
        let isolatedRendererCapture = captureRequest?.scenario.subject.hidesArenaBorder ?? false
        gridLayer.childNode(withName: "arenaBorder")?.isHidden = isolatedRendererCapture
        for (index, star) in starNodes.enumerated() {
            star.isHidden = menuModel.settings.starCount == 0 || index > menuModel.settings.starCount
        }
        if case .attract = screenFlow.phase {
            gridLayer.isHidden = true
        } else {
            gridLayer.isHidden = false
        }

        switch screenFlow.phase {
        case let .attract(page):
            particleRenderer.node.zPosition = 201
            screenRenderer.renderAttract(
                page: page,
                frame: screenFlow.frame,
                persistentTitleFrame: screenFlow.persistentTitleFrame,
                size: size,
                cyclingColor: cyclingColor,
                colours: colorPalette,
                highScores: highScores,
                scorePageDifficulty: scorePageDifficulty,
                highlightedScorePosition: highlightedScorePosition,
                unrankedEntry: unrankedScoreEntry,
                showScoreSettings: pressedKeys.contains(35)
            )
            particleRenderer.render(particleSimulation, style: menuModel.settings.particleStyle)
        case .playing:
            particleRenderer.node.zPosition = 5
            screenRenderer.hide()
            renderGrid()
            particleRenderer.render(particleSimulation, style: menuModel.settings.particleStyle)
            renderHUD()
        case .gameOver:
            particleRenderer.node.zPosition = 5
            renderGrid()
            particleRenderer.render(particleSimulation, style: menuModel.settings.particleStyle)
            renderHUD()
            screenRenderer.renderGameOver(counter: 2 + screenFlow.frame * 2, size: size)
        }
    }

    private func enterAttractPresentation() {
        audio.stopAllBlackHoleLoops()
        enemyLayer.removeAllChildren()
        projectileLayer.removeAllChildren()
        pickupLayer.removeAllChildren()
        trailLayer.removeAllChildren()
        effectLayer.removeAllChildren()
        floatingScores.removeAll()
        cameraOffset = .zero
        updateWorldTransformAndStars()
        gridLayer.isHidden = true
        trailLayer.isHidden = true
        enemyLayer.isHidden = true
        projectileLayer.isHidden = true
        pickupLayer.isHidden = true
        effectLayer.isHidden = true
        showAttractTouchControls()
        player.isHidden = true
        playerShield.isHidden = true
        readyRings.forEach { $0.isHidden = true }
        particleRenderer.node.zPosition = 201
    }

    private func emitFirework(style: Int) {
        let firework: OriginalFireworkState
        if var random = captureRandom {
            firework = OriginalFireworkRule.make(
                style: style,
                screenSize: size,
                using: &random
            )
            captureRandom = random
        } else {
            firework = OriginalFireworkRule.make(
                style: style,
                screenSize: size,
                using: &spawnRandom
            )
        }
        emitParticles(
            count: 64,
            at: sourcePoint(firework.sourcePosition),
            kind: .random,
            color: firework.color
        )
    }

    private func prepareAttractCaptureRandomState(page: OriginalAttractPage) {
        attractDisplayEffects.removeAll(keepingCapacity: true)
        screenRenderer.resetAttractTrails()
        if page == .scores {
            var colors = Array(repeating: SKColor.white, count: 10)
            for index in stride(from: 9, through: 0, by: -1) {
                cycleColors()
                cycleColors()
                colors[index] = SKColor(
                    red: CGFloat(cyclingRed) / 255,
                    green: CGFloat(cyclingGreen) / 255,
                    blue: CGFloat(cyclingBlue) / 255,
                    alpha: 1
                )
            }
            screenRenderer.seedScoreTrail(colors)
        }
        guard page == .title else { return }

        createAttractDisplayEffects()
    }

    private func createAttractDisplayEffects() {
        for _ in 0..<2 {
            let position = CGPoint(
                x: size.width / 2 + CGFloat(originalRandomInt(-100...100)),
                y: size.height / 2 + CGFloat(originalRandomInt(-100...100))
            )
            let effectSize = CGFloat(originalRandomInt(12...50))
            let rotation = CGFloat(originalRandomInt(0...359))
            let direction = CGFloat(originalRandomInt(0...359)) * .pi / 180
            let magnitude = CGFloat(originalRandomDouble(1..<4))
            attractDisplayEffects.append(AttractDisplayEffect(
                position: position,
                velocity: CGVector(
                    dx: cos(direction) * magnitude,
                    dy: sin(direction) * magnitude
                ),
                rotation: rotation,
                size: effectSize
            ))
        }
    }

    private func updateAttractDisplayEffects() {
        for index in attractDisplayEffects.indices {
            var effect = attractDisplayEffects[index]
            effect.rotation += 1
            effect.position.x += effect.velocity.dx
            effect.position.y += effect.velocity.dy
            if effect.position.x < 32 {
                effect.velocity.dx = abs(effect.velocity.dx)
                effect.position.x += effect.velocity.dx
            } else if effect.position.x > size.width - 32 {
                effect.velocity.dx = -abs(effect.velocity.dx)
                effect.position.x += effect.velocity.dx
            }
            if effect.position.y < 32 {
                effect.velocity.dy = abs(effect.velocity.dy)
                effect.position.y += effect.velocity.dy
            } else if effect.position.y > size.height - 32 {
                effect.velocity.dy = -abs(effect.velocity.dy)
                effect.position.y += effect.velocity.dy
            }
            attractDisplayEffects[index] = effect

            guard Int(effect.rotation).isMultiple(of: 25) else { continue }
            let rotation = effect.rotation * .pi / 180
            for particleIndex in 0..<8 {
                let radial = CGFloat(particleIndex * 45) * .pi / 180
                let position = CGPoint(
                    x: effect.position.x + sin(rotation) * effect.size * 1.25
                        + sin(radial) * 8,
                    y: effect.position.y + cos(rotation) * effect.size * 1.25
                        + cos(radial) * 8
                )
                emitParticles(
                    count: 1,
                    at: sourcePoint(position),
                    kind: .slowDirected,
                    color: ParticleColor(
                        red: cyclingRed,
                        green: cyclingGreen,
                        blue: cyclingBlue
                    )
                )
            }
        }
    }

    private func sourcePoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: size.height - point.y)
    }

    private func originalRandomInt(_ range: ClosedRange<Int>) -> Int {
        if var random = captureRandom {
            let value = random.rand(range.lowerBound, range.upperBound)
            captureRandom = random
            return value
        }
        return spawnRandom.rand(range.lowerBound, range.upperBound)
    }

    private func originalRandomDouble(_ range: Range<Double>) -> Double {
        if var random = captureRandom {
            let value = random.rnd(range.lowerBound, range.upperBound)
            captureRandom = random
            return value
        }
        return spawnRandom.rnd(range.lowerBound, range.upperBound)
    }

    private func originalEnemySpawnState(for kind: EnemyKind) -> OriginalEnemySpawnState {
        if var random = captureRandom {
            let state = OriginalEnemySpawnState.make(kind: kind.original, using: &random)
            captureRandom = random
            return state
        }
        return OriginalEnemySpawnState.make(kind: kind.original, using: &spawnRandom)
    }

    private func originalPowerUpSpawnState() -> OriginalPowerUpSpawnState {
        if var random = captureRandom {
            let state = OriginalPowerUpSpawnState.make(using: &random)
            captureRandom = random
            return state
        }
        return OriginalPowerUpSpawnState.make(using: &spawnRandom)
    }

    private func originalPowerUpPosition() -> CGPoint {
        if var random = captureRandom {
            let position = OriginalPowerUpRule.sceneSpawnPosition(
                arenaSize: playfieldSize,
                using: &random
            )
            captureRandom = random
            return position
        }
        return OriginalPowerUpRule.sceneSpawnPosition(
            arenaSize: playfieldSize,
            using: &spawnRandom
        )
    }

    private func consumeOriginalDiamondJitter() {
        if var random = captureRandom {
            OriginalDiamondRandomRule.consumeIntegerJitter(using: &random)
            captureRandom = random
        } else {
            OriginalDiamondRandomRule.consumeIntegerJitter(using: &spawnRandom)
        }
    }

    private func originalCubeSplitOffset() -> CGVector {
        if var random = captureRandom {
            let offset = OriginalCubeSplitRule.sceneOffset(using: &random)
            captureRandom = random
            return offset
        }
        return OriginalCubeSplitRule.sceneOffset(using: &spawnRandom)
    }

    private func simulateFrame() {
        updateParticleSimulation()
        cycleColors()
        cycleColors()
        updateFloatingScores()
        gridSimulation.update()
        if deathFramesRemaining > 0 {
            session.advancePowerUpStatusMessageFrame()
            advanceDeathSequence()
            return
        }
        if getReadyFrame >= 0 {
            session.advancePowerUpStatusMessageFrame()
            advanceGetReadySequence()
            return
        }

        defer { session.advancePowerUpStatusMessageFrame() }

        let spawnResult = spawnDirector.advance(
            frame: simulationFrame,
            spawningIsBlocked: bombCooldownFrames > 0,
            using: &spawnRandom
        )
        if spawnResult.shouldIncreaseEnemySpeeds {
            session.increaseEnemySpeeds()
        }
        for command in spawnResult.commands {
            execute(command)
        }

        session.tick()
        bombCooldownFrames = max(0, bombCooldownFrames - 1)
        resolveFrameInput()
        if bombCooldownFrames == 0, frameInput.bombIsHeld {
            triggerBomb()
        }
        updatePlayer()
        updateCamera()
        updatePlayerTrails()
        updateAim()
        updatePlayerShield()
        fireIfNeeded()
        pullPlayerTowardBlackHoles()
        checkTriangleBondPlayerCollision()
        if stopGameplayFrameForDeath() { return }
        updateGenerators()
        if stopGameplayFrameForDeath() { return }
        updateEnemies(kinds: [
            .greenSquare, .pinwheel, .diamond, .cube, .seeker,
            .snake, .interceptor, .butterfly, .triangle,
        ])
        if stopGameplayFrameForDeath() { return }
        updateTrianglePairsAndBonds()
        updatePowerUps()
        updateEnemies(kinds: [.blackHole])
        if stopGameplayFrameForDeath() { return }
        updateProjectiles()
        cacheInterceptorShieldCollisionGeometry()
        simulationFrame += 1
    }

    private func stopGameplayFrameForDeath() -> Bool {
        guard deathFramesRemaining > 0 else { return false }
        simulationFrame += 1
        return true
    }

    private func resolveFrameInput() {
        let playerOnScreen = CGPoint(
            x: player.position.x - cameraOffset.x,
            y: player.position.y - cameraOffset.y
        )
        var snapshot = OriginalInputSnapshot(
            pressedKeys: pressedOriginalKeys,
            mouseButtons: mouseButtons,
            mouseDelta: relativeMouseMovement,
            pointerFromPlayer: hasPointerLocation
                ? CGVector(
                    dx: pointerLocation.x - playerOnScreen.x,
                    dy: pointerLocation.y - playerOnScreen.y
                )
                : .zero,
            pointerFromCenter: hasPointerLocation
                ? CGVector(
                    dx: pointerLocation.x - size.width / 2,
                    dy: pointerLocation.y - size.height / 2
                )
                : .zero,
            controllerAxes: controllerAxes,
            // Joypad mode calls JoyX()/JoyY() without a port in the original.
            controllerDPad: joypadDPad,
            controllerButtons: controllerButtons,
            touchMovement: touchMovement,
            touchAim: touchAim
        )
        #if os(iOS)
        snapshot.touchIsActive = movementTouch != nil || aimingTouch != nil
        #endif
        frameInput = inputResolver.resolve(settings: menuModel.settings, snapshot: snapshot)
        relativeMouseMovement = .zero
    }

    private func pollController() {
        let state = captureControllerState()
        controllerAxes = state.axes
        controllerDPad = state.dPad
        controllerButtons = state.buttons
        joypadDPad = captureDPad(from: GCController.controllers().first)
        let newlyPressed = controllerButtons.subtracting(previousControllerButtons)
        previousControllerButtons = controllerButtons

        if highScoreNameEntry != nil {
            handleHighScoreController(newlyPressedButtons: newlyPressed)
            return
        }
        if menuModel.isOpen {
            handleControllerMenuNavigation(newlyPressedButtons: newlyPressed)
            return
        }
        releaseControllerNavigationLatchesIfNeeded()

        guard !newlyPressed.isEmpty else { return }
        let settings = menuModel.settings
        let bombButton: Int? = switch settings.controllerType {
        case .dualAnalog: settings.dualAnalogBombButton
        case .joypad: settings.joypadBombButton
        case .mouse, .keyboard, .hybrid: nil
        }
        let optionButton: Int? = switch settings.controllerType {
        case .dualAnalog: settings.dualAnalogOptionButton
        case .joypad: settings.joypadOptionButton
        case .mouse, .keyboard, .hybrid: nil
        }
        switch screenFlow.phase {
        case .attract:
            if let optionButton, newlyPressed.contains(optionButton) {
                openOptions()
            } else if let bombButton, newlyPressed.contains(bombButton) {
                beginGame()
            }
            return
        case .gameOver:
            if let optionButton, newlyPressed.contains(optionButton) {
                openOptions()
            } else if let bombButton, newlyPressed.contains(bombButton) {
                skipGameOverToScores()
            }
            return
        case .playing:
            break
        }

        if let optionButton, newlyPressed.contains(optionButton) {
            openOptions()
            return
        }

        if let bombButton, newlyPressed.contains(bombButton) {
            triggerBomb()
        }
    }

    private func handleHighScoreController(newlyPressedButtons: Set<Int>) {
        guard var entry = highScoreNameEntry else { return }
        let input = OriginalHighScoreControllerRule.resolve(
            settings: menuModel.settings,
            controllerAxes: controllerAxes,
            pressedButtons: newlyPressedButtons
        )
        var changed = false

        if abs(input.fireY) < 0.3 {
            highScoreFireAxisIsLatched = false
        } else if !highScoreFireAxisIsLatched {
            entry.toggleCase()
            highScoreFireAxisIsLatched = true
            audio.play(.enemyHit)
            changed = true
        }

        if abs(input.moveY) < 0.3 {
            controllerVerticalIsLatched = false
        } else if !controllerVerticalIsLatched {
            entry.cycleCharacter(by: input.moveY < 0 ? -1 : 1)
            controllerVerticalIsLatched = true
            audio.play(.enemyHit)
            changed = true
        }

        if abs(input.moveX) < 0.3 {
            controllerHorizontalIsLatched = false
        } else if !controllerHorizontalIsLatched {
            entry.moveSelection(by: input.moveX < 0 ? -1 : 1)
            controllerHorizontalIsLatched = true
            audio.play(.enemyHit)
            changed = true
        }

        highScoreNameEntry = entry
        if input.finishIsPressed {
            finishHighScoreNameEntry()
            renderPresentation()
        } else if changed {
            renderPresentation()
        }
    }

    private func handleControllerMenuNavigation(newlyPressedButtons: Set<Int>) {
        if let button = newlyPressedButtons.min(),
           menuModel.captureControllerButton(button) {
            applyRuntimeSettings()
            renderPresentation()
            return
        }
        let navigation = controllerMenuNavigationVector()
        var changed = false
        if abs(navigation.dy) < 0.35 {
            controllerVerticalIsLatched = false
        } else if !controllerVerticalIsLatched, abs(navigation.dy) > 0.6 {
            menuModel.moveSelection(by: navigation.dy > 0 ? 1 : -1)
            controllerVerticalIsLatched = true
            changed = true
        }
        if abs(navigation.dx) < 0.35 {
            controllerHorizontalIsLatched = false
        } else if !controllerHorizontalIsLatched, abs(navigation.dx) > 0.6 {
            handleMenuOutcome(menuModel.adjust(by: navigation.dx > 0 ? 1 : -1))
            controllerHorizontalIsLatched = true
            changed = true
        }

        if !newlyPressedButtons.isEmpty {
            handleMenuOutcome(menuModel.activate())
            changed = true
        }
        if changed {
            applyRuntimeSettings()
            renderPresentation()
        }
    }

    private func releaseControllerNavigationLatchesIfNeeded() {
        let navigation = controllerMenuNavigationVector()
        if abs(navigation.dx) < 0.35 { controllerHorizontalIsLatched = false }
        if abs(navigation.dy) < 0.35 { controllerVerticalIsLatched = false }
    }

    private func controllerMenuNavigationVector() -> CGVector {
        if abs(controllerDPad.dx) > 0.1 || abs(controllerDPad.dy) > 0.1 {
            return controllerDPad
        }
        return CGVector(dx: controllerAxes[0], dy: controllerAxes[1])
    }

    private func captureControllerState() -> (
        axes: [CGFloat],
        dPad: CGVector,
        buttons: Set<Int>
    ) {
        let controllers = GCController.controllers()
        let port = min(3, max(0, menuModel.settings.dualAnalogPort))
        guard controllers.indices.contains(port) else {
            return (Array(repeating: 0, count: 15), .zero, [])
        }

        var axes = Array(repeating: CGFloat.zero, count: 15)
        var dPad = CGVector.zero
        var buttons = Set<Int>()
        func record(_ button: GCControllerButtonInput?, as index: Int) {
            if button?.isPressed == true { buttons.insert(index) }
        }

        if let gamepad = controllers[port].extendedGamepad {
            axes[0] = CGFloat(gamepad.leftThumbstick.xAxis.value)
            axes[1] = -CGFloat(gamepad.leftThumbstick.yAxis.value)
            axes[2] = -CGFloat(gamepad.rightThumbstick.yAxis.value)
            axes[3] = CGFloat(gamepad.rightThumbstick.xAxis.value)
            axes[4] = CGFloat(gamepad.leftTrigger.value)
            axes[5] = CGFloat(gamepad.rightTrigger.value)
            axes[6] = CGFloat(gamepad.dpad.xAxis.value)
            axes[7] = -CGFloat(gamepad.dpad.yAxis.value)
            axes[9] = CGFloat(gamepad.dpad.xAxis.value)
            dPad = CGVector(
                dx: CGFloat(gamepad.dpad.xAxis.value),
                dy: -CGFloat(gamepad.dpad.yAxis.value)
            )

            record(gamepad.buttonA, as: 0)
            record(gamepad.buttonB, as: 1)
            record(gamepad.buttonX, as: 2)
            record(gamepad.buttonY, as: 3)
            record(gamepad.leftShoulder, as: 4)
            record(gamepad.rightShoulder, as: 5)
            record(gamepad.leftTrigger, as: 6)
            record(gamepad.rightTrigger, as: 7)
            record(gamepad.buttonMenu, as: 8)
            record(gamepad.leftThumbstickButton, as: 9)
            record(gamepad.rightThumbstickButton, as: 10)
            record(gamepad.dpad.up, as: 11)
            record(gamepad.dpad.down, as: 12)
            record(gamepad.dpad.left, as: 13)
            record(gamepad.dpad.right, as: 14)
            record(gamepad.buttonOptions ?? gamepad.buttonHome, as: 15)
        } else if let gamepad = controllers[port].microGamepad {
            dPad = CGVector(
                dx: CGFloat(gamepad.dpad.xAxis.value),
                dy: -CGFloat(gamepad.dpad.yAxis.value)
            )
            axes[0] = dPad.dx
            axes[1] = dPad.dy
            record(gamepad.buttonA, as: 0)
            record(gamepad.buttonX, as: 2)
            record(gamepad.buttonMenu, as: 8)
        }
        return (axes, dPad, buttons)
    }

    private func captureDPad(from controller: GCController?) -> CGVector {
        if let dPad = controller?.extendedGamepad?.dpad {
            return CGVector(
                dx: CGFloat(dPad.xAxis.value),
                dy: -CGFloat(dPad.yAxis.value)
            )
        }
        if let dPad = controller?.microGamepad?.dpad {
            return CGVector(
                dx: CGFloat(dPad.xAxis.value),
                dy: -CGFloat(dPad.yAxis.value)
            )
        }
        return .zero
    }

    private func renderGrid() {
        let simulation: GridSimulation
        if menuModel.isOpen, menuModel.page == .video {
            let sourceOffset = CGPoint(x: size.width / 8, y: size.height / 8)
            let columns = Int(sourceOffset.x / gridSimulation.spacing) * 6
            let rows = Int(sourceOffset.y / gridSimulation.spacing) * 6
            let sceneOffset = CGPoint(
                x: sourceOffset.x,
                y: size.height - sourceOffset.y
                    - CGFloat(max(0, rows - 1)) * gridSimulation.spacing
            )
            simulation = gridSimulation.renderWindow(
                canvasSize: size,
                columns: columns,
                rows: rows,
                offset: sceneOffset
            )
        } else {
            simulation = gridSimulation
        }
        gridRenderer.render(
            simulation: simulation,
            style: gridStyle,
            solidColor: SKColor(
                red: CGFloat(menuModel.settings.gridRed) / 255,
                green: CGFloat(menuModel.settings.gridGreen) / 255,
                blue: CGFloat(menuModel.settings.gridBlue) / 255,
                alpha: 1
            ),
            cyclingColor: SKColor(
                red: CGFloat(cyclingRed) / 255,
                green: CGFloat(cyclingGreen) / 255,
                blue: CGFloat(cyclingBlue) / 255,
                alpha: 1
            ),
            opacity: menuModel.settings.gridOpacity
        )
    }

    private func applyRuntimeSettings() {
        configurePlayfieldIfNeeded()
        audio.configure(settings: menuModel.settings)
        applyGraphicsSetIfNeeded()
        for blackHole in enemies(of: .blackHole)
            where (blackHole.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false {
            guard let id = blackHole.userData?["enemyID"] as? String else { continue }
            let blackHoleSize = CGFloat(
                (blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20
            )
            audio.startBlackHoleLoop(
                id: id,
                at: blackHole.position,
                listener: player.position,
                playfieldSize: playfieldSize,
                size: blackHoleSize
            )
        }
        gridStyle = GridStyle(rawValue: menuModel.settings.gridStyle) ?? .pointsSolid
        particleGravityEnabled = menuModel.settings.particleGravity
        particleSimulation.particleLife = menuModel.settings.particleLife
        particleSimulation.decay = menuModel.settings.particleDecay
        ensureStarCapacity(through: menuModel.settings.starCount)
        for (index, star) in starNodes.enumerated() {
            star.isHidden = menuModel.settings.starCount == 0 || index > menuModel.settings.starCount
        }
        if appliedGridColorPosition != menuModel.settings.gridColorPosition {
            appliedGridColorPosition = menuModel.settings.gridColorPosition
            if let color = originalGridColor(at: appliedGridColorPosition) {
                menuModel.settings.gridRed = color.red
                menuModel.settings.gridGreen = color.green
                menuModel.settings.gridBlue = color.blue
            }
        }
        updateArenaBorderAppearance()
    }

    private func configurePlayfieldIfNeeded() {
        let arena = playfieldSize
        let spacing = configuredGridSpacing
        let gridNeedsRebuild = gridSimulation.arenaSize != arena
            || gridSimulation.spacing != spacing
        let particleCapacity = max(0, min(50_000, menuModel.settings.particleCount))
        let particlesNeedRebuild = particleSimulation.arenaSize != arena
            || particleSimulation.capacity != particleCapacity

        if !menuModel.isVideoTransactionPending,
           arena.width > size.width || arena.height > size.height {
            menuModel.settings.scroll = true
        }
        if gridNeedsRebuild {
            gridSimulation = GridSimulation(arenaSize: arena, spacing: spacing)
            rebuildArenaBorder()
            for star in starNodes { star.removeFromParent() }
            starNodes.removeAll(keepingCapacity: true)
            starStates = OriginalStarRule.create(
                maximumIndex: OriginalRuntimeSettings.maximumStars,
                playfieldSize: arena,
                screenSize: size,
                using: &spawnRandom
            )
            ensureStarCapacity(through: menuModel.settings.starCount)
            centerPlayerAndCamera()
        }
        if particlesNeedRebuild {
            particleSimulation = ParticleSimulation(
                arenaSize: arena,
                capacity: particleCapacity,
                particleLife: menuModel.settings.particleLife,
                decay: menuModel.settings.particleDecay
            )
        }
        updateWorldTransformAndStars()
    }

    private func applyGraphicsSetIfNeeded() {
        let setIndex = activeGraphicsSetIndex
        guard setIndex != appliedGraphicsSetIndex else { return }
        appliedGraphicsSetIndex = setIndex
        screenRenderer.graphicsSetIndex = setIndex
        hudRenderer.graphicsSetIndex = setIndex
        particleRenderer.setGraphicsSet(setIndex)

        player.texture = OriginalGraphics.texture(named: "whiteplayer", setIndex: setIndex)
        player.size = player.texture?.size() ?? player.size

        for case let sprite as SKSpriteNode in projectileLayer.children {
            sprite.texture = OriginalGraphics.texture(named: "yellowshot", setIndex: setIndex)
            sprite.size = sprite.texture?.size() ?? sprite.size
        }
        for case let sprite as SKSpriteNode in trailLayer.children where sprite.name == "playerTrail" {
            sprite.texture = OriginalGraphics.texture(named: "particle", setIndex: setIndex)
            let textureSize = sprite.texture?.size() ?? CGSize(width: 15, height: 15)
            sprite.size = CGSize(
                width: textureSize.width * PlayerTrailState.sourceScale,
                height: textureSize.height * PlayerTrailState.sourceScale
            )
        }
        for case let sprite as SKSpriteNode in enemyLayer.children {
            if sprite.name == "snakeTail" {
                let frame = (sprite.userData?["originalFrame"] as? NSNumber)?.intValue ?? 0
                sprite.texture = snakeTailTexture(frame: frame)
                sprite.size = OriginalGraphicsSet(index: setIndex).snakeFrameSize
                continue
            }
            guard sprite.name == "enemy",
                  let rawKind = sprite.userData?["kind"] as? String,
                  let kind = EnemyKind(rawValue: rawKind) else { continue }
            let cubeTier = (sprite.userData?["cubeTier"] as? NSNumber)?.intValue ?? 0
            let textureName = kind == .cube && cubeTier > 0 ? "purplesquare2" : kind.textureName
            sprite.texture = OriginalGraphics.texture(named: textureName, setIndex: setIndex)
            sprite.size = sprite.texture?.size() ?? sprite.size
            if let twin = sprite.childNode(withName: "triangleTwin") as? SKSpriteNode {
                twin.texture = OriginalGraphics.texture(
                    named: kind.textureName,
                    setIndex: setIndex
                )
                twin.size = twin.texture?.size() ?? twin.size
            }
        }
        for powerUp in pickupLayer.children where powerUp.name == "powerUp" {
            let rawKind = (powerUp.userData?["kind"] as? NSNumber)?.intValue ?? 0
            if let kind = PowerUpKind(rawValue: rawKind) {
                (powerUp.childNode(withName: "powerUpIcon") as? SKSpriteNode)?.texture =
                    powerUpTexture(for: kind)
            }
            (powerUp.childNode(withName: "powerUpStar") as? SKSpriteNode)?.texture =
                OriginalGraphics.texture(named: "whitestar", setIndex: setIndex)
            if let star = powerUp.childNode(withName: "powerUpStar") as? SKSpriteNode {
                star.size = star.texture?.size() ?? star.size
            }
        }
    }

    private func ensureStarCapacity(through requestedIndex: Int) {
        let finalIndex = min(OriginalRuntimeSettings.maximumStars, max(0, requestedIndex))
        guard starStates.count > finalIndex else { return }
        guard starNodes.count <= finalIndex else { return }
        for index in starNodes.count...finalIndex {
            let star = SKShapeNode(rect: OriginalDrawRectRule.sceneRect(
                at: .zero,
                width: 2,
                height: 2
            ))
            star.strokeColor = .clear
            star.alpha = OriginalBlendRule.spriteKitAdditiveNodeAlpha(sourceAlpha: 0.8)
            star.blendMode = .add
            star.isAntialiased = false
            star.name = "star"
            configureStarNode(star, index: index)
            starNodes.append(star)
            gridLayer.addChild(star)
        }
        updateWorldTransformAndStars()
    }

    private func configureStarNode(_ star: SKShapeNode, index: Int) {
        guard index < starStates.count else { return }
        let state = starStates[index]
        let basePosition = state.sceneBasePosition(
            playfieldSize: playfieldSize,
            screenSize: size
        )
        star.fillColor = SKColor(
            white: CGFloat(state.brightnessChannel) / 255,
            alpha: 1
        )
        star.position = basePosition
        star.userData = NSMutableDictionary(dictionary: [
            "baseX": basePosition.x,
            "baseY": basePosition.y,
            "depth": state.depth,
        ])
    }

    private func updateWorldTransformAndStars() {
        worldLayer.position = CGPoint(x: -cameraOffset.x, y: -cameraOffset.y)
        for star in starNodes {
            guard let data = star.userData else { continue }
            let baseX = CGFloat((data["baseX"] as? NSNumber)?.doubleValue ?? Double(star.position.x))
            let baseY = CGFloat((data["baseY"] as? NSNumber)?.doubleValue ?? Double(star.position.y))
            let depth = max(1, CGFloat((data["depth"] as? NSNumber)?.doubleValue ?? 2))
            star.position = CGPoint(
                x: baseX + cameraOffset.x * (1 - 1 / depth),
                y: baseY + cameraOffset.y * (1 - 1 / depth)
            )
        }
    }

    private func updateCamera() {
        cameraOffset = OriginalCameraRule.advance(
            offset: cameraOffset,
            player: player.position,
            playfield: playfieldSize,
            viewport: size,
            scrolling: menuModel.runtimeSettings.scroll
        )
        updateWorldTransformAndStars()
    }

    private func originalGridColor(at position: Int) -> (red: Int, green: Int, blue: Int)? {
        guard let url = Bundle.main.url(forResource: "colourpick", withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = image.width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
            | CGImageAlphaInfo.noneSkipLast.rawValue
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo
            ) else { return false }
            context.interpolationQuality = .none
            context.draw(
                image,
                in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
            )
            return true
        }
        guard rendered else { return nil }

        // colourpick.png contains three 122x9 frames. SetGridColours locks frame 1
        // and samples (1 + index, 2), using Max2D's top-left pixmap origin.
        let x = min(120, max(1, 1 + position))
        let topY = 9 + 2
        let row = image.height - 1 - topY
        let offset = row * bytesPerRow + x * bytesPerPixel
        guard pixels.indices.contains(offset + 2) else { return nil }
        return (Int(pixels[offset]), Int(pixels[offset + 1]), Int(pixels[offset + 2]))
    }

    private func setParticleGravityEnabled(_ enabled: Bool) {
        particleGravityEnabled = enabled
        menuModel.settings.particleGravity = enabled
        showStatusMessage("Particle Gravity \(enabled ? "ON" : "OFF")")
    }

    private func showStatusMessage(_ message: String) {
        messageLabel.removeAllActions()
        messageLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        messageLabel.setScale(1)
        messageLabel.fontColor = .white
        messageLabel.text = message
        messageLabel.isHidden = false
        messageLabel.run(.sequence([.wait(forDuration: 0.9), .hide()]))
    }

    private func randomPowerUpPosition() -> CGPoint {
        originalPowerUpPosition()
    }

    private func handleRuntimeKey(_ keyCode: UInt16) -> Bool {
        guard screenFlow.phase == .playing else { return false }
        switch keyCode {
        case 99: // F3
            menuModel.settings.cycleGridStyle()
            applyRuntimeSettings()
            showStatusMessage("Grid Style =\(menuModel.settings.gridStyle)")
        case 118: // F4
            menuModel.settings.cycleStars()
            applyRuntimeSettings()
            showStatusMessage("Number of Stars =\(menuModel.settings.starCount)")
        case 96: // F5
            setParticleGravityEnabled(!particleGravityEnabled)
        case 97: // F6
            menuModel.settings.cycleParticleStyle()
            showStatusMessage("Particle - Style \(menuModel.settings.particleStyle)")
        case 98: // F7
            debugEnabled.toggle()
            showStatusMessage("Debug \(debugEnabled ? "ON" : "OFF")")
        case 122: // F1
            session.invalidateScore()
            cheatMode.toggle()
            showStatusMessage("Cheatmode \(cheatMode ? "ON" : "OFF")")
        case 18 where cheatMode:
            session.grantCheatUpgrade(.reverseShooter)
        case 19 where cheatMode:
            session.grantCheatUpgrade(.sideShooters)
        case 20 where cheatMode:
            session.grantCheatUpgrade(.superShots)
        case 21 where cheatMode:
            session.grantCheatUpgrade(.bouncyShots)
        case 7 where cheatMode:
            session.grantCheatCannon()
        case 6 where cheatMode:
            session.grantCheatShotSpeed()
        case 1 where cheatMode:
            spawnPowerUp(at: randomPowerUpPosition(), kind: .shield)
        case 120 where cheatMode: // F2
            godMode.toggle()
            showStatusMessage("God Mode \(godMode ? "ON" : "OFF")")
        default:
            return false
        }
        updateHUD()
        return true
    }

    private func updateParticleSimulation() {
        for blackHole in enemies(of: .blackHole)
            where particleGravityEnabled
            && ((blackHole.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false) {
            let blackHoleSize = CGFloat(
                (blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20
            )
            particleSimulation.applyBlackHole(
                at: blackHole.position,
                size: blackHoleSize,
                frame: simulationFrame
            )
        }

        if deathFramesRemaining > 0 {
            let deathFrame = 100 - deathFramesRemaining
            guard deathFrame.isMultiple(of: 2) else { return }
        }
        particleSimulation.update()
    }

    private func updatePlayer() {
        let result = playerMotion.advance(
            from: player.position,
            input: frameInput.movement,
            arenaSize: playfieldSize,
            inertia: menuModel.settings.inertia,
            movementLimit: frameInput.movementLimit
        )
        player.position = result.position
        if result.movement.length > 0 {
            player.zRotation = PlayerVisualRule.sceneRotation(forMovement: result.movement)
        }
        if abs(result.movement.dx) > 0.1 || abs(result.movement.dy) > 0.1 {
            createPlayerTrail(movement: result.movement)
        }
    }

    private func createPlayerTrail(movement: CGVector) {
        let trailColor = colorPalette[.trail]
        for index in 0..<3 {
            let state = PlayerTrailState(
                playerPosition: player.position,
                movement: movement,
                frame: simulationFrame,
                index: index,
                color: trailColor
            )
            let trail = SKSpriteNode(texture: OriginalGraphics.texture(
                named: "particle",
                setIndex: activeGraphicsSetIndex
            ))
            trail.name = "playerTrail"
            trail.colorBlendFactor = 1
            trail.blendMode = .add
            trail.alpha = OriginalBlendRule.spriteKitAdditiveNodeAlpha(
                sourceAlpha: PlayerTrailState.sourceAlpha
            )
            let textureSize = trail.texture?.size() ?? CGSize(width: 15, height: 15)
            trail.size = CGSize(
                width: textureSize.width * PlayerTrailState.sourceScale,
                height: textureSize.height * PlayerTrailState.sourceScale
            )
            trail.position = state.position

            let point = SKShapeNode(rectOf: CGSize(
                width: PlayerTrailState.sourceScale,
                height: PlayerTrailState.sourceScale
            ))
            point.name = "playerTrailPoint"
            point.strokeColor = .clear
            point.blendMode = .add
            point.isAntialiased = false
            point.zPosition = -1
            trail.addChild(point)

            trail.userData = NSMutableDictionary(dictionary: [
                "trailActive": state.framesRemaining,
                "trailDX": state.velocity.dx,
                "trailDY": state.velocity.dy,
                "trailR": state.color.red,
                "trailG": state.color.green,
                "trailB": state.color.blue,
            ])
            applyPlayerTrailColor(state.color, to: trail)
            trailLayer.addChild(trail)
        }
    }

    private func updatePlayerTrails() {
        for case let trail as SKSpriteNode in trailLayer.children where trail.name == "playerTrail" {
            var state = PlayerTrailState(
                position: trail.position,
                velocity: CGVector(
                    dx: CGFloat((trail.userData?["trailDX"] as? NSNumber)?.doubleValue ?? 0),
                    dy: CGFloat((trail.userData?["trailDY"] as? NSNumber)?.doubleValue ?? 0)
                ),
                color: ParticleColor(
                    red: (trail.userData?["trailR"] as? NSNumber)?.intValue ?? 0,
                    green: (trail.userData?["trailG"] as? NSNumber)?.intValue ?? 0,
                    blue: (trail.userData?["trailB"] as? NSNumber)?.intValue ?? 0
                ),
                framesRemaining: (trail.userData?["trailActive"] as? NSNumber)?.intValue ?? 0
            )

            guard state.advance() else {
                trail.removeFromParent()
                continue
            }
            trail.position = state.position
            trail.userData?["trailActive"] = state.framesRemaining
            trail.userData?["trailDX"] = state.velocity.dx
            trail.userData?["trailDY"] = state.velocity.dy
            trail.userData?["trailR"] = state.color.red
            trail.userData?["trailG"] = state.color.green
            trail.userData?["trailB"] = state.color.blue
            applyPlayerTrailColor(state.color, to: trail)
        }
    }

    private func applyPlayerTrailColor(_ color: ParticleColor, to trail: SKSpriteNode) {
        let resolved = skColor(color)
        trail.color = resolved
        (trail.childNode(withName: "playerTrailPoint") as? SKShapeNode)?.fillColor = resolved
    }

    private func updatePlayerShield() {
        playerShield.position = player.position
        let frames = session.shieldFrames
        if frames == 100 || frames == 70 || frames == 40 {
            audio.play(.shieldWarning)
        }
        playerShield.isHidden = !PlayerVisualRule.shieldIsVisible(frames: frames)
        playerShield.setScale(PlayerVisualRule.shieldScale(frames: frames))
        playerShield.fillColor = SKColor(
            red: CGFloat(cyclingRed) / 255,
            green: CGFloat(cyclingGreen) / 255,
            blue: CGFloat(cyclingBlue) / 255,
            alpha: 1
        )
    }

    private func cycleColors() {
        cycleColor(value: &cyclingRed, delta: &cyclingRedDelta)
        cycleColor(value: &cyclingGreen, delta: &cyclingGreenDelta)
        cycleColor(value: &cyclingBlue, delta: &cyclingBlueDelta)
    }

    private func cycleColor(value: inout Int, delta: inout CGFloat) {
        value = Int(CGFloat(value) + delta)
        if value < 0 {
            value = 0
            delta = CGFloat(originalRandomDouble(1..<10))
        } else if value > 255 {
            value = 255
            delta = -CGFloat(originalRandomDouble(1..<10))
        }
    }

    private func updateAim() {
        if frameInput.aim.length > 0 {
            currentAim = frameInput.aim.normalized
        }
    }

    private func fireIfNeeded() {
        shotTimerFrames = max(0, shotTimerFrames - 1)
        guard shotTimerFrames == 0 else { return }
        shotTimerFrames = debugEnabled
            ? PlayerWeaponRule.debugTimerFrames(cannons: session.cannons)
            : PlayerWeaponRule.timerFrames(cannons: session.cannons)
        guard frameInput.isFiring else { return }

        let launches = if debugEnabled {
            PlayerWeaponRule.debugLaunches(
                aim: currentAim,
                cannons: session.cannons,
                shotSpeed: session.shotSpeed,
                reverseShooter: session.reverseShooterFrames > 0,
                sideShooters: session.sideShooterFrames > 0
            )
        } else {
            PlayerWeaponRule.launches(
                aim: currentAim,
                cannons: session.cannons,
                shotSpeed: session.shotSpeed,
                reverseShooter: session.reverseShooterFrames > 0,
                sideShooters: session.sideShooterFrames > 0
            )
        }
        for launch in launches {
            spawnProjectile(
                direction: launch.direction,
                speed: launch.speed,
                offset: launch.offset
            )
        }
        audio.play(.shotBorn)
    }

    @discardableResult
    private func spawnProjectile(
        direction: CGVector,
        speed: CGFloat,
        offset: CGVector = .zero
    ) -> SKSpriteNode? {
        guard projectileLayer.children.count < 500 else { return nil }
        let projectile = SKSpriteNode(texture: OriginalGraphics.texture(
            named: "yellowshot",
            setIndex: activeGraphicsSetIndex
        ))
        projectile.name = "projectile"
        projectile.blendMode = .add
        projectile.color = projectileColor
        projectile.colorBlendFactor = 1
        projectile.position = CGPoint(
            x: player.position.x + offset.dx,
            y: player.position.y + offset.dy
        )
        projectile.zRotation = PlayerVisualRule.projectileSceneRotation(forDirection: direction)
        let velocity = direction * speed
        projectile.userData = NSMutableDictionary(dictionary: [
            "dx": velocity.dx,
            "dy": velocity.dy,
            "speed": speed,
        ])
        projectileLayer.addChild(projectile)
        return projectile
    }

    @discardableResult
    private func spawnEnemy(
        kind: EnemyKind,
        at position: CGPoint,
        freezeFrames: Int,
        closeToPlayer: Bool = false,
        playBornSound: Bool = true
    ) -> SKNode? {
        let matchingEnemyCount = enemyLayer.children.filter {
            $0.name == "enemy" && $0.userData?["kind"] as? String == kind.rawValue
        }.count
        let resolvedPosition = safePosition(
            position,
            minimumPlayerDistance: closeToPlayer ? 40 : 160
        )
        switch kind {
        case .cube where matchingEnemyCount > 100:
            return nil
        case .blackHole where matchingEnemyCount > 3:
            return nil
        case .snake:
            let snakeNodeCount = matchingEnemyCount + enemyLayer.children.filter {
                $0.name == "snakeTail"
            }.count
            if snakeNodeCount > 16 * 24 { return nil }
        case .interceptor:
            if matchingEnemyCount > 3, originalRandomInt(0...100) > 50 {
                return nil
            }
            if matchingEnemyCount > 7 { return nil }
        default:
            break
        }

        let enemy = SKSpriteNode(texture: OriginalGraphics.texture(
            named: kind.textureName,
            setIndex: activeGraphicsSetIndex
        ))
        enemy.name = "enemy"
        enemy.blendMode = .add
        enemy.color = .white
        enemy.colorBlendFactor = 0
        enemy.position = resolvedPosition
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: min(kind.size.width, kind.size.height) * 0.38)
        enemy.physicsBody?.affectedByGravity = false
        enemy.physicsBody?.allowsRotation = false
        enemy.physicsBody?.categoryBitMask = Category.enemy
        enemy.physicsBody?.collisionBitMask = 0
        enemy.physicsBody?.contactTestBitMask = Category.player | Category.projectile
        let enemyID = UUID().uuidString
        let initialState = originalEnemySpawnState(for: kind)
        let initialRotation = initialState.rotation
        let initialAngle = CGFloat(initialState.direction) * .pi / 180
        let initialVelocity = CGVector(
            dx: cos(initialAngle) * initialState.magnitude,
            dy: -sin(initialAngle) * initialState.magnitude
        )
        let interceptorTurn = InterceptorRule.sourceTurnToFace(
            sceneVelocity: initialVelocity,
            sceneTarget: CGVector(
                dx: playfieldSize.width / 2 - enemy.position.x,
                dy: playfieldSize.height / 2 - enemy.position.y
            )
        )
        enemy.userData = NSMutableDictionary(dictionary: [
            "enemyID": enemyID,
            "kind": kind.rawValue,
            "health": kind.health,
            "score": kind.score,
            "freezeFrames": freezeFrames,
            "rotation": initialRotation,
            "dx": initialVelocity.dx,
            "dy": initialVelocity.dy,
            "cubeTier": 0,
            "blackHoleSize": kind == .blackHole ? 20.0 : 0.0,
            "blackHoleActive": false,
            "absorbCount": 0,
            "snakeHeading": Double(initialRotation),
            "snakeTurnDirection": initialState.snakeTurnDirection,
            "interceptorHeading": Double(initialRotation),
            "interceptorTurnRemaining": InterceptorRule.initialTurnRemaining(
                interceptorTurn
            ),
            "interceptorLastPlayed": 0,
            "interceptorShieldRightX": 0.0,
            "interceptorShieldRightY": 0.0,
            "interceptorShieldLeftX": 0.0,
            "interceptorShieldLeftY": 0.0,
            "seekerMean": 0,
            "triangleResist": false,
        ])
        if kind != .snake, kind != .interceptor {
            let aura = SKShapeNode(path: enemyAuraPath(kind: kind, rotation: initialRotation, cubeTier: 0))
            aura.name = "spawnAura"
            aura.fillColor = generatorColor(for: kind)
            aura.strokeColor = .clear
            aura.blendMode = .alpha
            aura.zPosition = -1
            aura.zRotation = enemyAuraRotation(for: kind)
            enemy.addChild(aura)
        }
        enemyLayer.addChild(enemy)
        if playBornSound {
            playSpatial(enemyBornSound(for: kind), at: enemy.position)
        }
        if kind == .snake {
            spawnSnakeSegments(for: enemy, freezeFrames: freezeFrames)
        }
        updateEnemyVisual(enemy, kind: kind, rotation: initialRotation)
        return enemy
    }

    private func execute(_ command: SpawnCommand) {
        switch command {
        case let .enemy(kind, freezeFrames, corner):
            spawnEnemy(
                kind: EnemyKind(kind),
                at: position(for: corner),
                freezeFrames: freezeFrames
            )
        case let .generator(kind, freezeFrames, corner, rate, generatorSize):
            spawnGenerator(
                kind: EnemyKind(kind),
                at: position(for: corner),
                freezeFrames: freezeFrames,
                rate: rate,
                generatorSize: generatorSize
            )
        }
    }

    private func position(for corner: SpawnCorner) -> CGPoint {
        let arena = playfieldSize
        let resolved: SpawnCorner
        switch corner {
        case .anyCorner:
            resolved = SpawnCorner(rawValue: originalRandomInt(1...4)) ?? .topLeft
        case .topCorners:
            resolved = originalRandomInt(1...10) > 5 ? .topLeft : .topRight
        case .rightCorners:
            resolved = originalRandomInt(1...10) > 5 ? .topRight : .bottomRight
        case .bottomCorners:
            resolved = originalRandomInt(1...10) > 5 ? .bottomRight : .bottomLeft
        case .diagonalTopLeftBottomRight:
            resolved = originalRandomInt(1...10) > 5 ? .topLeft : .bottomRight
        case .leftCorners:
            resolved = originalRandomInt(1...10) > 5 ? .topLeft : .bottomLeft
        case .diagonalTopRightBottomLeft:
            resolved = originalRandomInt(1...10) > 5 ? .topRight : .bottomLeft
        default:
            resolved = corner
        }

        switch resolved {
        case .topLeft:
            return CGPoint(
                x: randomCoordinate(30...80),
                y: arena.height - randomCoordinate(30...80)
            )
        case .topRight:
            return CGPoint(
                x: randomCoordinate((Int(arena.width) - 80)...(Int(arena.width) - 30)),
                y: arena.height - randomCoordinate(30...80)
            )
        case .bottomRight:
            return CGPoint(
                x: randomCoordinate((Int(arena.width) - 80)...(Int(arena.width) - 30)),
                y: arena.height - randomCoordinate(
                    (Int(arena.height) - 80)...(Int(arena.height) - 30)
                )
            )
        case .bottomLeft:
            return CGPoint(
                x: randomCoordinate(30...80),
                y: arena.height - randomCoordinate(
                    (Int(arena.height) - 80)...(Int(arena.height) - 30)
                )
            )
        case .nearPlayer:
            let angle = CGFloat(originalRandomInt(0...360)) * .pi / 180
            return CGPoint(
                x: player.position.x + cos(angle) * 240,
                y: player.position.y - sin(angle) * 240
            )
        default:
            let sourceX = randomCoordinate(inset: 30, length: arena.width)
            let sourceY = randomCoordinate(
                30...max(30, Int(arena.height) - 30)
            )
            return CGPoint(
                x: sourceX,
                y: arena.height - sourceY
            )
        }
    }

    private func randomCoordinate(_ range: ClosedRange<Int>) -> CGFloat {
        CGFloat(originalRandomInt(range))
    }

    private func randomCoordinate(inset: Int, length: CGFloat) -> CGFloat {
        let midpoint = max(0, Int(length) / 2)
        let lowerBound = min(inset, midpoint)
        let upperBound = max(lowerBound, Int(length) - inset)
        return randomCoordinate(lowerBound...upperBound)
    }

    private func safePosition(_ proposed: CGPoint, minimumPlayerDistance: CGFloat) -> CGPoint {
        let arena = playfieldSize
        let sourcePlayer = CGPoint(
            x: player.position.x,
            y: arena.height - player.position.y
        )
        var result = CGPoint(
            x: min(arena.width - 20, max(20, proposed.x)),
            y: min(arena.height - 20, max(20, arena.height - proposed.y))
        )
        var fromSpawnToPlayer = CGVector(
            dx: sourcePlayer.x - result.x,
            dy: sourcePlayer.y - result.y
        )

        if minimumPlayerDistance == 40 {
            var distance = fromSpawnToPlayer.length + 0.001
            while distance < minimumPlayerDistance {
                if distance < 0.001 {
                    result = CGPoint(
                        x: sourcePlayer.x + CGFloat(originalRandomInt(10...20))
                            * (originalRandomInt(1...10) > 5 ? -1 : 1),
                        y: sourcePlayer.y + CGFloat(originalRandomInt(10...20))
                            * (originalRandomInt(1...10) > 5 ? -1 : 1)
                    )
                } else {
                    result.x -= fromSpawnToPlayer.dx / distance * 10
                    result.y -= fromSpawnToPlayer.dy / distance * 10
                }
                fromSpawnToPlayer = CGVector(
                    dx: sourcePlayer.x - result.x,
                    dy: sourcePlayer.y - result.y
                )
                distance = fromSpawnToPlayer.length
            }
        } else {
            while fromSpawnToPlayer.dx * fromSpawnToPlayer.dx
                    + fromSpawnToPlayer.dy * fromSpawnToPlayer.dy
                    < minimumPlayerDistance * minimumPlayerDistance {
                let angle = CGFloat(originalRandomInt(0...(360 * 8))) / 8 * .pi / 180
                result = CGPoint(
                    x: sourcePlayer.x + sin(angle) * minimumPlayerDistance,
                    y: sourcePlayer.y + cos(angle) * minimumPlayerDistance
                )
                result.x = min(arena.width - 20, max(20, result.x))
                result.y = min(arena.height - 20, max(20, result.y))
                fromSpawnToPlayer = CGVector(
                    dx: sourcePlayer.x - result.x,
                    dy: sourcePlayer.y - result.y
                )
            }
        }
        return CGPoint(x: result.x, y: arena.height - result.y)
    }

    private func spawnGenerator(
        kind: EnemyKind,
        at position: CGPoint,
        freezeFrames: Int,
        rate: Int,
        generatorSize: Int
    ) {
        let resolvedPosition = safePosition(position, minimumPlayerDistance: 160)
        let rotation = originalRandomInt(0...359)
        let warning = OriginalGeneratorRule.isWarningFrame(
            rotation: rotation,
            rate: rate,
            health: generatorSize
        )
        let color = warning ? SKColor.white : generatorColor(for: kind)
        let generator = SKShapeNode(path: generatorFillPath(kind: kind, health: generatorSize))
        generator.name = "generator"
        generator.position = resolvedPosition
        generator.fillColor = color.withAlphaComponent(OriginalGeneratorRule.fillAlpha(
            kind: kind.original,
            health: generatorSize
        ))
        generator.strokeColor = .clear
        generator.blendMode = .add
        generator.physicsBody = SKPhysicsBody(circleOfRadius: 12 + CGFloat(generatorSize) / 2)
        generator.physicsBody?.affectedByGravity = false
        generator.physicsBody?.allowsRotation = false
        generator.physicsBody?.categoryBitMask = Category.enemy
        generator.physicsBody?.collisionBitMask = 0
        generator.physicsBody?.contactTestBitMask = Category.player | Category.projectile
        generator.userData = NSMutableDictionary(dictionary: [
            "kind": kind.rawValue,
            "health": generatorSize,
            "score": 200,
            "freezeFrames": freezeFrames,
            "rate": rate,
            "rotation": rotation,
            "generatorSize": generatorSize,
        ])
        let outline = SKShapeNode(path: generatorOutlinePath(kind: kind, health: generatorSize))
        outline.name = "generatorOutline"
        outline.strokeColor = color
        outline.fillColor = .clear
        outline.lineWidth = 2
        outline.blendMode = .add
        generator.addChild(outline)
        enemyLayer.addChild(generator)
        playSpatial(.generatorBorn, at: generator.position)
    }

    private func generatorFillPath(kind: EnemyKind, health: Int) -> CGPath {
        let path = CGMutablePath()
        let size = CGFloat(health)
        switch kind {
        case .pinwheel, .diamond:
            let radius = 12 * size / 14
            path.move(to: CGPoint(x: 0, y: radius))
            path.addLine(to: CGPoint(x: radius, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -radius))
            path.addLine(to: CGPoint(x: -radius, y: 0))
            path.closeSubpath()
        case .greenSquare, .cube, .interceptor:
            let halfWidth = 12 * size / 16
            path.addRect(CGRect(
                x: -halfWidth,
                y: -halfWidth,
                width: halfWidth * 2,
                height: halfWidth * 2
            ))
        case .triangle, .butterfly:
            let scale = size / 8
            path.move(to: CGPoint(x: 0, y: -8 * scale))
            path.addLine(to: CGPoint(x: 6 * scale, y: 4 * scale))
            path.addLine(to: CGPoint(x: -6 * scale, y: 4 * scale))
            path.closeSubpath()
        case .seeker, .blackHole, .snake:
            appendCircle(to: path, radius: size)
        }
        return path
    }

    private func generatorOutlinePath(kind: EnemyKind, health: Int) -> CGPath {
        let path = CGMutablePath()
        let size = CGFloat(health)
        switch kind {
        case .pinwheel, .diamond:
            appendDiamond(to: path, radius: 12 + size / 4)
            appendDiamond(to: path, radius: 8)
        case .greenSquare, .cube, .interceptor:
            appendSquare(to: path, halfWidth: 8 + size / 4)
            appendSquare(to: path, halfWidth: 8)
        case .seeker, .blackHole, .snake:
            appendCircle(to: path, radius: (8 + size / 2) / 1.1)
            appendCircle(to: path, radius: 8)
        case .triangle, .butterfly:
            appendGeneratorTriangle(to: path, expansion: size / 4)
            appendGeneratorTriangle(to: path, expansion: 0)
        }
        return path
    }

    private func appendDiamond(to path: CGMutablePath, radius: CGFloat) {
        path.move(to: CGPoint(x: 0, y: radius))
        path.addLine(to: CGPoint(x: radius, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -radius))
        path.addLine(to: CGPoint(x: -radius, y: 0))
        path.closeSubpath()
    }

    private func appendSquare(to path: CGMutablePath, halfWidth: CGFloat) {
        path.addRect(CGRect(
            x: -halfWidth,
            y: -halfWidth,
            width: halfWidth * 2,
            height: halfWidth * 2
        ))
    }

    private func appendCircle(to path: CGMutablePath, radius: CGFloat) {
        for index in 0..<18 {
            let angle = CGFloat(index * 20) * .pi / 180
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
    }

    private func appendGeneratorTriangle(to path: CGMutablePath, expansion: CGFloat) {
        path.move(to: CGPoint(x: 0, y: -12 - expansion))
        path.addLine(to: CGPoint(x: 9 + expansion, y: 4 + expansion))
        path.addLine(to: CGPoint(x: -9 - expansion, y: 4 + expansion))
        path.closeSubpath()
    }

    private func enemyAuraPath(kind: EnemyKind, rotation: Int, cubeTier: Int) -> CGPath {
        let path = CGMutablePath()
        switch kind {
        case .greenSquare, .pinwheel, .cube:
            let radius = 12 - CGFloat(cubeTier)
            path.move(to: CGPoint(x: 0, y: radius))
            path.addLine(to: CGPoint(x: radius, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -radius))
            path.addLine(to: CGPoint(x: -radius, y: 0))
            path.closeSubpath()
        case .diamond:
            let phase = rotation % 256
            let stretchX: CGFloat
            let stretchY: CGFloat
            if phase > 127 {
                stretchY = CGFloat(phase > 190 ? 255 - phase : phase - 127)
                stretchX = 0
            } else {
                stretchX = CGFloat(phase > 63 ? 127 - phase : phase)
                stretchY = 0
            }
            path.move(to: CGPoint(x: 0, y: 12 + stretchY / 32))
            path.addLine(to: CGPoint(x: 12 + stretchX / 32, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -12 - stretchY / 32))
            path.addLine(to: CGPoint(x: -12 - stretchX / 32, y: 0))
            path.closeSubpath()
        case .seeker, .blackHole:
            for index in 0..<18 {
                let angle = CGFloat(index * 20) * .pi / 180
                let point = CGPoint(x: cos(angle) * 8, y: sin(angle) * 8)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
        case .triangle, .butterfly:
            path.move(to: CGPoint(x: 0, y: 10))
            path.addLine(to: CGPoint(x: 8, y: -6))
            path.addLine(to: CGPoint(x: -8, y: -6))
            path.closeSubpath()
        case .snake, .interceptor:
            break
        }
        return path
    }

    private func enemyAuraRotation(for kind: EnemyKind) -> CGFloat {
        switch kind {
        case .greenSquare, .pinwheel, .cube:
            OriginalSourceTransform.sceneRadians(sourceDegrees: 45)
        default: 0
        }
    }

    private func generatorColor(for kind: EnemyKind) -> SKColor {
        skColor(particleColor(for: kind))
    }

    private func updateGenerators() {
        for generator in enemyLayer.children where generator.name == "generator" {
            var freezeFrames = (generator.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0
            if freezeFrames > 0 {
                freezeFrames -= 1
                generator.userData?["freezeFrames"] = freezeFrames
                continue
            }

            var rotation = (generator.userData?["rotation"] as? NSNumber)?.intValue ?? 0
            rotation += 1
            generator.userData?["rotation"] = rotation
            let rate = (generator.userData?["rate"] as? NSNumber)?.intValue ?? 100
            let health = (generator.userData?["health"] as? NSNumber)?.intValue ?? 1
            let kind = EnemyKind(rawValue: generator.userData?["kind"] as? String ?? "") ?? .pinwheel
            if let shape = generator as? SKShapeNode {
                let warning = OriginalGeneratorRule.isWarningFrame(
                    rotation: rotation,
                    rate: rate,
                    health: health
                )
                let color = warning ? SKColor.white : generatorColor(for: kind)
                shape.fillColor = color.withAlphaComponent(OriginalGeneratorRule.fillAlpha(
                    kind: kind.original,
                    health: health
                ))
                (shape.childNode(withName: "generatorOutline") as? SKShapeNode)?.strokeColor = color
            }
            let collisionRadiusSquared = pow(12 + CGFloat(health) / 2, 2) + 12 * 12
            if squaredDistance(generator.position, player.position) < collisionRadiusSquared,
               hitPlayer(killer: generator) {
                continue
            }
            guard rotation.isMultiple(of: OriginalGeneratorRule.birthPeriod(
                rate: rate,
                health: health
            )) else { continue }
            gridSimulation.push(at: generator.position, radiusInPoints: 6, amount: 0.9)
            let offset = CGPoint(
                x: generator.position.x + randomCoordinate(-10...10),
                y: generator.position.y + randomCoordinate(-10...10)
            )
            let born = spawnEnemy(
                kind: kind,
                at: offset,
                freezeFrames: 5,
                closeToPlayer: OriginalGeneratorRule.childUsesCloseSafePosition(
                    kind: kind.original
                )
            )
            if kind == .blackHole {
                born?.userData?["blackHoleSize"] = 10.0
                if let born {
                    updateEnemyVisual(born, kind: .blackHole, rotation: 0)
                }
            }
        }
    }

    private func updateEnemies(kinds: [EnemyKind]) {
        for requestedKind in kinds {
            if requestedKind == .snake {
                updateDyingSnakeSegments(maximumSpeed: session.enemySpeeds[.snake])
                if deathFramesRemaining > 0 { return }
            }
            let enemies = enemyLayer.children.filter {
                $0.name == "enemy" && $0.userData?["kind"] as? String == requestedKind.rawValue
            }
            for enemy in enemies {
            guard enemy.parent != nil else { continue }
            let baseSpeed = session.enemySpeeds[requestedKind.original]
            let cubeTier = (enemy.userData?["cubeTier"] as? NSNumber)?.intValue ?? 0
            let seekerMean = (enemy.userData?["seekerMean"] as? NSNumber)?.intValue ?? 0
            let maximumSpeed = OriginalBasicEnemyRule.maximumSpeed(
                for: requestedKind.original,
                baseSpeed: baseSpeed,
                cubeTier: cubeTier,
                seekerMean: seekerMean
            )
            if requestedKind == .snake {
                updateSnakeSegments(for: enemy, maximumSpeed: maximumSpeed)
                if deathFramesRemaining > 0 { continue }
            }
            var freezeFrames = (enemy.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0
            if freezeFrames > 0 {
                freezeFrames -= 1
                enemy.userData?["freezeFrames"] = freezeFrames
                updateEnemyVisual(enemy, kind: requestedKind, rotation: (enemy.userData?["rotation"] as? NSNumber)?.intValue ?? 0)
                continue
            }

            let kind = EnemyKind(rawValue: enemy.userData?["kind"] as? String ?? "") ?? .pinwheel
            var velocity = CGVector(
                dx: CGFloat((enemy.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                dy: CGFloat((enemy.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
            )
            var rotation = (enemy.userData?["rotation"] as? NSNumber)?.intValue ?? 0
            rotation = switch kind {
            case .interceptor: (rotation + 16) % 360
            case .triangle: rotation + 2
            default: rotation + 1
            }

            let movesBeforeSteering: Bool = switch kind {
            case .pinwheel, .diamond, .greenSquare, .cube, .seeker, .blackHole, .butterfly:
                true
            case .triangle, .snake, .interceptor:
                false
            }
            if movesBeforeSteering {
                enemy.position.x += velocity.dx
                enemy.position.y += velocity.dy
                let margin: CGFloat = switch kind {
                case .greenSquare, .pinwheel, .diamond, .cube, .seeker, .butterfly:
                    OriginalBasicEnemyRule.boundaryMargin(for: kind.original)
                case .blackHole: 16
                default: 8
                }
                bounce(enemy, velocity: &velocity, margin: margin)
            }

            let playerDifference = CGVector(
                dx: player.position.x - enemy.position.x,
                dy: player.position.y - enemy.position.y
            )
            let towardPlayer = playerDifference / (playerDifference.length + 0.001)

            if kind == .triangle {
                pairEligibleTriangle(enemy)
            }

            switch kind {
            case .pinwheel:
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
            case .diamond:
                consumeOriginalDiamondJitter()
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
                velocity = velocity + towardPlayer
                    * OriginalBasicEnemyRule.homingAcceleration(for: kind.original)
            case .greenSquare:
                velocity = velocity + towardPlayer
                    * OriginalBasicEnemyRule.homingAcceleration(for: kind.original)
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
            case .cube:
                velocity = velocity + towardPlayer
                    * OriginalBasicEnemyRule.homingAcceleration(for: kind.original)
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
            case .seeker:
                velocity = velocity + towardPlayer
                    * OriginalBasicEnemyRule.homingAcceleration(for: kind.original)
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
            case .blackHole:
                updateBlackHole(
                    enemy,
                    velocity: &velocity,
                    maximumSpeed: maximumSpeed,
                    rotation: rotation
                )
            case .triangle:
                updateTriangleVelocity(enemy, towardPlayer: towardPlayer, velocity: &velocity)
            case .snake:
                var heading = CGFloat((enemy.userData?["snakeHeading"] as? NSNumber)?.doubleValue ?? 0)
                var turnDirection = (enemy.userData?["snakeTurnDirection"] as? NSNumber)?.intValue ?? 0
                velocity = velocity + SnakeHeadRule.sceneSteeringAcceleration(
                    sourceHeading: heading,
                    maximumSpeed: maximumSpeed
                )
                heading = SnakeHeadRule.sourceHeadingAfterTurn(
                    heading,
                    turnDirection: turnDirection
                )
                turnDirection = SnakeHeadRule.turnDirectionAfterRoll(
                    turnDirection,
                    roll: originalRandomInt(1...100)
                )
                enemy.userData?["snakeHeading"] = heading
                enemy.userData?["snakeTurnDirection"] = turnDirection
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
            case .interceptor:
                var heading = CGFloat((enemy.userData?["interceptorHeading"] as? NSNumber)?.doubleValue ?? 0)
                var turnRemaining = (enemy.userData?["interceptorTurnRemaining"] as? NSNumber)?.intValue ?? 0
                if InterceptorRule.shouldRetarget(
                    roll: originalRandomInt(1...100),
                    maximumSpeed: maximumSpeed
                ) {
                    turnRemaining = InterceptorRule.sourceTurnToFace(
                        sceneVelocity: velocity,
                        sceneTarget: CGVector(
                            dx: player.position.x - enemy.position.x,
                            dy: player.position.y - enemy.position.y
                        )
                    )
                }
                InterceptorRule.advanceTurn(
                    sourceHeading: &heading,
                    turnRemaining: &turnRemaining
                )
                var lastPlayed = (enemy.userData?["interceptorLastPlayed"] as? NSNumber)?.intValue ?? 0
                if turnRemaining == 0, lastPlayed == 0 {
                    lastPlayed = 60
                    playSpatial(.interceptorShield, at: enemy.position)
                }
                if lastPlayed > 0 { lastPlayed -= 1 }
                velocity = InterceptorRule.steeredVelocity(
                    velocity,
                    sourceHeading: heading,
                    turnRemaining: turnRemaining,
                    maximumSpeed: maximumSpeed
                )
                if abs(turnRemaining) < 20 {
                    gridSimulation.push(
                        at: CGPoint(
                            x: enemy.position.x + velocity.dx * 8,
                            y: enemy.position.y + velocity.dy * 8
                        ),
                        radiusInPoints: 4,
                        amount: 0.1
                    )
                }
                enemy.userData?["interceptorHeading"] = heading
                enemy.userData?["interceptorTurnRemaining"] = turnRemaining
                enemy.userData?["interceptorLastPlayed"] = lastPlayed
            case .butterfly:
                velocity = velocity + towardPlayer
                    * OriginalBasicEnemyRule.homingAcceleration(for: kind.original)
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
            }

            guard enemy.parent != nil else { continue }

            if kind == .interceptor {
                enemy.position.x += velocity.dx
                enemy.position.y += velocity.dy
                if enemy.position.x < InterceptorRule.boundaryMargin
                    || enemy.position.x > playfieldSize.width - InterceptorRule.boundaryMargin {
                    enemy.position.x -= velocity.dx
                    enemy.position.y -= velocity.dy
                }
                if enemy.position.y < InterceptorRule.boundaryMargin
                    || enemy.position.y > playfieldSize.height - InterceptorRule.boundaryMargin {
                    enemy.position.x -= velocity.dx
                    enemy.position.y -= velocity.dy
                }
                _ = applyBlackHoleInfluence(to: enemy, kind: kind, velocity: &velocity)
                guard enemy.parent != nil else { continue }
            }

            applySeparation(to: enemy, kind: kind, velocity: &velocity)
            if velocity.length > maximumSpeed {
                velocity = velocity.normalized * maximumSpeed
            }

            if !movesBeforeSteering, kind != .interceptor {
                enemy.position.x += velocity.dx
                enemy.position.y += velocity.dy
                if kind == .snake {
                    var heading = CGFloat(
                        (enemy.userData?["snakeHeading"] as? NSNumber)?.doubleValue ?? 0
                    )
                    SnakeHeadRule.bounce(
                        position: &enemy.position,
                        velocity: &velocity,
                        sourceHeading: &heading,
                        arenaSize: playfieldSize
                    )
                    enemy.userData?["snakeHeading"] = heading
                } else {
                    bounce(enemy, velocity: &velocity, margin: 8)
                }
            }

            if kind == .cube {
                let orbit = OriginalBasicEnemyRule.cubeSceneOrbit(
                    rotation: rotation,
                    tier: cubeTier
                )
                enemy.position.x += orbit.dx
                enemy.position.y += orbit.dy
            }

            if checkPlayerCollision(with: enemy, kind: kind) {
                continue
            }

            enemy.userData?["dx"] = velocity.dx
            enemy.userData?["dy"] = velocity.dy
            enemy.userData?["rotation"] = rotation
            updateEnemyVisual(enemy, kind: kind, rotation: rotation)
            if kind == .interceptor { updateInterceptorShieldVisual(enemy) }
        }
        }
    }

    private func updateEnemyVisual(_ enemy: SKNode, kind: EnemyKind, rotation: Int) {
        switch kind {
        case .pinwheel:
            enemy.zRotation = OriginalSourceTransform.sceneRadians(
                sourceDegrees: CGFloat(rotation * 4)
            )
        case .diamond:
            let phase = rotation % 256
            let scaleX: CGFloat
            let scaleY: CGFloat
            if phase > 127 {
                scaleY = CGFloat(phase > 190 ? 255 - phase : phase - 127)
                scaleX = 0
            } else {
                scaleX = CGFloat(phase > 63 ? 127 - phase : phase)
                scaleY = 0
            }
            enemy.xScale = 1 + scaleX / 80
            enemy.yScale = 1 + scaleY / 80
        case .greenSquare, .cube:
            enemy.zRotation = OriginalSourceTransform.sceneRadians(
                sourceDegrees: CGFloat(rotation)
            )
        case .seeker:
            enemy.zRotation = 0
        case .blackHole:
            var scale = 0.25 + CGFloat((enemy.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20) / 64
            if (enemy.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false {
                var pulse = CGFloat((enemy.userData?["blackHolePulse"] as? NSNumber)?.doubleValue ?? 0)
                pulse += CGFloat((enemy.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20) / 2
                enemy.userData?["blackHolePulse"] = pulse
                scale += cos(pulse * .pi / 180) / 6
            }
            enemy.setScale(scale)
            enemy.zRotation = 0
        case .triangle:
            enemy.zRotation = OriginalSourceTransform.sceneRadians(
                sourceDegrees: CGFloat(rotation * 2)
            )
            let attached = trianglePartner(of: enemy) != nil
            var second = enemy.childNode(withName: "triangleTwin") as? SKSpriteNode
            if attached, second == nil {
                let twin = SKSpriteNode(texture: OriginalGraphics.texture(
                    named: EnemyKind.triangle.textureName,
                    setIndex: activeGraphicsSetIndex
                ))
                twin.name = "triangleTwin"
                twin.blendMode = .add
                enemy.addChild(twin)
                second = twin
            }
            second?.isHidden = !attached
            second?.zRotation = OriginalSourceTransform.sceneRadians(
                sourceDegrees: CGFloat(rotation * 2 + 180)
            )
        case .snake:
            let velocity = CGVector(
                dx: CGFloat((enemy.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                dy: CGFloat((enemy.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
            )
            enemy.zRotation = atan2(velocity.dy, velocity.dx) + .pi / 2
        case .interceptor:
            let heading = CGFloat((enemy.userData?["interceptorHeading"] as? NSNumber)?.doubleValue ?? 0)
            enemy.zRotation = OriginalSourceTransform.sceneRadians(
                sourceDegrees: heading + 90
            )
        case .butterfly:
            enemy.zRotation = OriginalSourceTransform.sceneRadians(
                sourceDegrees: CGFloat(rotation * 8)
            )
        }
        updateEnemyAura(enemy, kind: kind, rotation: rotation)
    }

    private func updateEnemyAura(_ enemy: SKNode, kind: EnemyKind, rotation: Int) {
        guard let aura = enemy.childNode(withName: "spawnAura") as? SKShapeNode else { return }
        let freezeFrames = (enemy.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0
        let cubeTier = (enemy.userData?["cubeTier"] as? NSNumber)?.intValue ?? 0
        aura.path = enemyAuraPath(kind: kind, rotation: rotation, cubeTier: cubeTier)
        aura.zRotation = enemyAuraRotation(for: kind)

        let desiredScaleX: CGFloat
        let desiredScaleY: CGFloat
        if freezeFrames > 0 {
            let base = CGFloat(freezeFrames) / 5
            desiredScaleX = kind == .diamond ? 1 + base : base
            desiredScaleY = kind == .diamond ? 1 + base : base
            aura.alpha = CGFloat(freezeFrames) / 40
        } else {
            let pulse = CGFloat((rotation / 16) % 8) + 0.5
            aura.alpha = max(0, 0.5 - pulse / 8)
            if kind == .diamond {
                let phase = rotation % 256
                let stretchX: CGFloat
                let stretchY: CGFloat
                if phase > 127 {
                    stretchY = CGFloat(phase > 190 ? 255 - phase : phase - 127)
                    stretchX = 0
                } else {
                    stretchX = CGFloat(phase > 63 ? 127 - phase : phase)
                    stretchY = 0
                }
                desiredScaleX = 1.5 + stretchX / 16
                desiredScaleY = 1.5 + stretchY / 16
            } else if kind == .blackHole {
                let blackHoleSize = CGFloat(
                    (enemy.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20
                )
                desiredScaleX = pulse + blackHoleSize / 16
                desiredScaleY = desiredScaleX
            } else {
                desiredScaleX = pulse
                desiredScaleY = pulse
            }
        }

        // The original draws the aura and image with independent SetScale calls.
        // Counter the parent sprite's current scale to preserve that separation.
        let parentScaleX = max(0.001, abs(enemy.xScale))
        let parentScaleY = max(0.001, abs(enemy.yScale))
        aura.xScale = desiredScaleX / parentScaleX
        aura.yScale = desiredScaleY / parentScaleY
    }

    private func spawnSnakeSegments(for head: SKNode, freezeFrames: Int) {
        guard let headID = head.userData?["enemyID"] as? String else { return }
        for index in 0..<SnakeSegmentRule.tailSegmentCount {
            let originalFrame = SnakeSegmentRule.originalFrame(segmentIndex: index)
            let segment = SKSpriteNode(texture: snakeTailTexture(frame: originalFrame))
            segment.name = "snakeTail"
            segment.size = OriginalGraphicsSet(
                index: activeGraphicsSetIndex
            ).snakeFrameSize
            segment.blendMode = .add
            segment.color = .white
            segment.colorBlendFactor = 0
            segment.position = head.position
            segment.zRotation = SnakeSegmentRule.zeroVelocityDrawRotation
            segment.physicsBody = SKPhysicsBody(circleOfRadius: sqrt(CGFloat(81 + originalFrame)))
            segment.physicsBody?.affectedByGravity = false
            segment.physicsBody?.allowsRotation = false
            segment.physicsBody?.categoryBitMask = Category.enemy
            segment.physicsBody?.collisionBitMask = 0
            segment.physicsBody?.contactTestBitMask = Category.player | Category.projectile
            segment.userData = NSMutableDictionary(dictionary: [
                "snakeHeadID": headID,
                "segmentIndex": index,
                "originalFrame": originalFrame,
                "freezeFrames": freezeFrames,
                "dx": 0.0,
                "dy": 0.0,
            ])
            enemyLayer.addChild(segment)
        }
    }

    private func snakeTailTexture(frame: Int) -> SKTexture {
        return OriginalGraphics.frameTexture(
            sheet: "snaketail",
            frame: frame,
            columns: 8,
            rows: 3,
            setIndex: activeGraphicsSetIndex
        )
    }

    private func updateSnakeSegments(for head: SKNode, maximumSpeed: CGFloat) {
        guard let headID = head.userData?["enemyID"] as? String else { return }
        let segments = enemyLayer.children.compactMap { $0 as? SKSpriteNode }
            .filter {
                $0.name == "snakeTail" && $0.userData?["snakeHeadID"] as? String == headID
            }
        let segmentsByIndex = Dictionary(uniqueKeysWithValues: segments.map {
            ((($0.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0), $0)
        })
        let orderedSegments = segments.sorted {
            (($0.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0)
                > (($1.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0)
        }

        for segment in orderedSegments {
            let index = (segment.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0
            let precedingPosition = index == 0
                ? head.position
                : segmentsByIndex[index - 1]?.position ?? head.position
            var freezeFrames = (segment.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0
            if freezeFrames > 0 {
                freezeFrames -= 1
                segment.userData?["freezeFrames"] = freezeFrames
                continue
            }

            var velocity = SnakeSegmentRule.velocity(
                from: segment.position,
                toward: precedingPosition,
                maximumSpeed: maximumSpeed
            )
            segment.position.x += velocity.dx
            segment.position.y += velocity.dy
            bounce(segment, velocity: &velocity, margin: SnakeSegmentRule.boundaryMargin)
            segment.userData?["dx"] = velocity.dx
            segment.userData?["dy"] = velocity.dy
            segment.zRotation = atan2(velocity.dy, velocity.dx) + .pi / 2
            if squaredDistance(segment.position, player.position)
                < SnakeSegmentRule.playerCollisionThresholdSquared,
               hitPlayer(killer: segment) {
                return
            }
        }
    }

    private func scheduleSnakeTailExplosion(for head: SKNode, awardPoints: Bool) {
        guard let headID = head.userData?["enemyID"] as? String else { return }
        let segments = enemyLayer.children.filter {
            $0.name == "snakeTail" && $0.userData?["snakeHeadID"] as? String == headID
        }
        let nearest = segments.min {
            (($0.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0)
                < (($1.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0)
        }
        nearest?.userData?["snakeDyingMove"] = SnakeSegmentRule.cascadeStartFrame(
            awardsPoints: awardPoints
        )
    }

    private func updateDyingSnakeSegments(maximumSpeed: CGFloat) {
        let allSegments = enemyLayer.children.compactMap { $0 as? SKSpriteNode }
            .filter { $0.name == "snakeTail" }
        let dyingHeadIDs = Set(allSegments.compactMap { segment -> String? in
            guard segment.userData?["snakeDyingMove"] != nil else { return nil }
            return segment.userData?["snakeHeadID"] as? String
        })
        let chains = Dictionary(grouping: allSegments.filter {
            dyingHeadIDs.contains($0.userData?["snakeHeadID"] as? String ?? "")
        }) {
            $0.userData?["snakeHeadID"] as? String ?? ""
        }

        for chain in chains.values {
            let byIndex = Dictionary(uniqueKeysWithValues: chain.map {
                ((($0.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0), $0)
            })
            let ordered = chain.sorted {
                (($0.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0)
                    > (($1.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0)
            }
            for segment in ordered {
                let index = (segment.userData?["segmentIndex"] as? NSNumber)?.intValue ?? 0
                if let dyingMove = (segment.userData?["snakeDyingMove"] as? NSNumber)?.intValue {
                    let nextMove = dyingMove - 1
                    byIndex[index + 1]?.userData?["snakeDyingMove"] = nextMove
                    let position = segment.position
                    segment.removeFromParent()
                    emitParticles(
                        count: 8,
                        at: position,
                        kind: .random,
                        color: colorPalette[.snakeTail]
                    )
                    if nextMove < 50 {
                        playSpatial(.snakeTailExplode, at: position)
                    }
                    continue
                }

                var freezeFrames = (segment.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0
                if freezeFrames > 0 {
                    freezeFrames -= 1
                    segment.userData?["freezeFrames"] = freezeFrames
                    continue
                }
                guard let preceding = byIndex[index - 1] else { continue }
                var velocity = SnakeSegmentRule.velocity(
                    from: segment.position,
                    toward: preceding.position,
                    maximumSpeed: maximumSpeed
                )
                segment.position.x += velocity.dx
                segment.position.y += velocity.dy
                bounce(segment, velocity: &velocity, margin: SnakeSegmentRule.boundaryMargin)
                segment.userData?["dx"] = velocity.dx
                segment.userData?["dy"] = velocity.dy
                segment.zRotation = atan2(velocity.dy, velocity.dx) + .pi / 2
                if squaredDistance(segment.position, player.position)
                    < SnakeSegmentRule.playerCollisionThresholdSquared,
                   hitPlayer(killer: segment) {
                    return
                }
            }
        }
    }

    private func updateTriangleVelocity(
        _ triangle: SKNode,
        towardPlayer: CGVector,
        velocity: inout CGVector
    ) {
        guard let partner = trianglePartner(of: triangle) else {
            triangle.userData?["trianglePartnerID"] = nil
            let distance = CGVector(
                dx: player.position.x - triangle.position.x,
                dy: player.position.y - triangle.position.y
            ).length + 0.001
            if distance < TriangleRule.playerHomingRange {
                velocity = velocity + towardPlayer
            }
            _ = applyBlackHoleInfluence(to: triangle, kind: .triangle, velocity: &velocity)
            return
        }

        let difference = CGVector(
            dx: partner.position.x - triangle.position.x,
            dy: partner.position.y - triangle.position.y
        )
        let distance = difference.length + 0.001
        if distance > TriangleRule.partnerFarDistance {
            velocity = velocity + difference / distance * TriangleRule.partnerAcceleration
        } else if distance < TriangleRule.partnerNearDistance {
            velocity = velocity - difference / distance * TriangleRule.partnerAcceleration
        }
        _ = applyBlackHoleInfluence(to: triangle, kind: .triangle, velocity: &velocity)
    }

    private func updateTrianglePairsAndBonds() {
        for bond in enemyLayer.children where bond.name == "triangleBond" {
            bond.removeFromParent()
        }

        let triangles = enemyLayer.children.filter {
            $0.name == "enemy"
                && $0.userData?["kind"] as? String == EnemyKind.triangle.rawValue
                && (($0.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0) == 0
        }
        for triangle in triangles {
            guard let partner = trianglePartner(of: triangle),
                  let triangleID = triangle.userData?["enemyID"] as? String,
                  let partnerID = partner.userData?["enemyID"] as? String else { continue }

            let strength = CGFloat((triangle.userData?["triangleStrength"] as? NSNumber)?.doubleValue
                                   ?? Double(TriangleBondState.initialStrength))
            let path = CGMutablePath()
            path.move(to: triangle.position)
            path.addLine(to: partner.position)
            let bond = SKShapeNode(path: path)
            bond.name = "triangleBond"
            bond.strokeColor = SKColor(
                red: min(1, (20 + strength * 8) / 255),
                green: min(1, (220 - strength * 8) / 255),
                blue: 0,
                alpha: 1
            )
            bond.lineWidth = 2
            bond.glowWidth = 0
            bond.blendMode = .add
            bond.lineCap = .butt
            bond.lineJoin = .miter
            bond.zPosition = 1
            bond.userData = NSMutableDictionary(dictionary: [
                "triangleFirstID": triangleID,
                "triangleSecondID": partnerID,
            ])
            enemyLayer.addChild(bond)

        }
    }

    private func pairEligibleTriangle(_ triangle: SKNode) {
        guard trianglePartner(of: triangle) == nil else { return }
        for candidate in enemyLayer.children where candidate !== triangle {
            guard candidate.name == "enemy",
                  candidate.userData?["kind"] as? String == EnemyKind.triangle.rawValue,
                  trianglePartner(of: candidate) == nil,
                  squaredDistance(triangle.position, candidate.position)
                    < TriangleRule.pairDistanceSquared else { continue }
            attachTriangles(triangle, candidate)
            return
        }
    }

    private func checkTriangleBondPlayerCollision() {
        var checkedPairs = Set<String>()
        for triangle in enemies(of: .triangle) {
            guard let partner = trianglePartner(of: triangle),
                  let firstID = triangle.userData?["enemyID"] as? String,
                  let secondID = partner.userData?["enemyID"] as? String else { continue }
            let pairID = [firstID, secondID].sorted().joined(separator: "-")
            guard checkedPairs.insert(pairID).inserted else { continue }
            if distanceFromPoint(
                player.position,
                toLineFrom: triangle.position,
                to: partner.position
            ) <= TriangleRule.bondPlayerCollisionRadius {
                _ = hitPlayer()
                return
            }
        }
    }

    private func pullPlayerTowardBlackHoles() {
        for blackHole in enemies(of: .blackHole) {
            let blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            player.position = BlackHoleRule.pulledPlayerPosition(
                player: player.position,
                blackHole: blackHole.position,
                size: blackHoleSize
            )
        }
    }

    private func attachTriangles(_ first: SKNode, _ second: SKNode) {
        guard let firstID = first.userData?["enemyID"] as? String,
              let secondID = second.userData?["enemyID"] as? String else { return }
        first.userData?["trianglePartnerID"] = secondID
        first.userData?["triangleStrength"] = TriangleBondState.initialStrength
        first.userData?["triangleResist"] = false
        second.userData?["trianglePartnerID"] = firstID
        second.userData?["triangleStrength"] = TriangleBondState.initialStrength
        second.userData?["triangleResist"] = false
    }

    private func trianglePartner(of triangle: SKNode) -> SKNode? {
        guard let partnerID = triangle.userData?["trianglePartnerID"] as? String else { return nil }
        return enemyLayer.children.first {
            $0.parent != nil && $0.userData?["enemyID"] as? String == partnerID
        }
    }

    private func detachTriangle(_ triangle: SKNode) {
        if let triangleID = triangle.userData?["enemyID"] as? String {
            removeTriangleBondVisuals(involving: triangleID)
        }
        if let partner = trianglePartner(of: triangle) {
            partner.userData?["trianglePartnerID"] = nil
            partner.userData?["triangleStrength"] = 0
            partner.userData?["triangleResist"] = false
            partner.childNode(withName: "triangleTwin")?.isHidden = true
        }
        triangle.userData?["trianglePartnerID"] = nil
        triangle.userData?["triangleStrength"] = 0
        triangle.userData?["triangleResist"] = false
        triangle.childNode(withName: "triangleTwin")?.isHidden = true
    }

    private func removeTriangleBondVisuals(involving triangleID: String) {
        for bond in enemyLayer.children where bond.name == "triangleBond" {
            let firstID = bond.userData?["triangleFirstID"] as? String
            let secondID = bond.userData?["triangleSecondID"] as? String
            if firstID == triangleID || secondID == triangleID {
                bond.removeFromParent()
            }
        }
    }

    private func updateInterceptorShieldVisual(_ interceptor: SKNode) {
        interceptor.childNode(withName: "interceptorShield")?.removeFromParent()
        let turnRemaining = (interceptor.userData?["interceptorTurnRemaining"] as? NSNumber)?.intValue ?? 0
        guard InterceptorRule.shieldIsActive(turnRemaining: turnRemaining) else { return }

        let path = CGMutablePath()
        let rotation = CGFloat((interceptor.userData?["rotation"] as? NSNumber)?.intValue ?? 0)
        let phase = rotation / 360
        for index in 0...2 {
            let t = 1.5 + phase + CGFloat(index)
            let forward = 12 + 12 * t
            let halfWidth = abs(12 - 9 * t)
            path.move(to: CGPoint(x: forward, y: -halfWidth))
            path.addLine(to: CGPoint(x: forward, y: halfWidth))
        }
        let shield = SKShapeNode(path: path)
        shield.name = "interceptorShield"
        shield.strokeColor = SKColor(red: 1, green: 32 / 255, blue: 32 / 255, alpha: 1)
        shield.lineWidth = 1
        shield.glowWidth = 0
        shield.blendMode = .add
        shield.zPosition = 1
        // The source rotates its points by `rot + 270` in a Y-down space.
        // The sprite parent already contributes `-(rot + 90)` in SpriteKit,
        // so a +90-degree child rotation leaves the shield at `-rot`.
        shield.zRotation = .pi / 2
        interceptor.addChild(shield)
    }

    private func cacheInterceptorShieldCollisionGeometry() {
        for interceptor in enemies(of: .interceptor) {
            let velocity = CGVector(
                dx: CGFloat((interceptor.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                dy: CGFloat((interceptor.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
            )
            let geometry = InterceptorShieldGeometry(
                center: interceptor.position,
                velocity: velocity
            )
            interceptor.userData?["interceptorShieldRightX"] = geometry.right.x
            interceptor.userData?["interceptorShieldRightY"] = geometry.right.y
            interceptor.userData?["interceptorShieldLeftX"] = geometry.left.x
            interceptor.userData?["interceptorShieldLeftY"] = geometry.left.y
        }
    }

    private func cachedInterceptorShieldGeometry(_ interceptor: SKNode) -> InterceptorShieldGeometry {
        InterceptorShieldGeometry(
            center: interceptor.position,
            right: CGPoint(
                x: CGFloat(
                    (interceptor.userData?["interceptorShieldRightX"] as? NSNumber)?.doubleValue ?? 0
                ),
                y: CGFloat(
                    (interceptor.userData?["interceptorShieldRightY"] as? NSNumber)?.doubleValue ?? 0
                )
            ),
            left: CGPoint(
                x: CGFloat(
                    (interceptor.userData?["interceptorShieldLeftX"] as? NSNumber)?.doubleValue ?? 0
                ),
                y: CGFloat(
                    (interceptor.userData?["interceptorShieldLeftY"] as? NSNumber)?.doubleValue ?? 0
                )
            )
        )
    }

    private func blockProjectilesWithInterceptorShields() {
        let interceptors = enemyLayer.children.filter {
            $0.name == "enemy"
                && $0.userData?["kind"] as? String == EnemyKind.interceptor.rawValue
                && InterceptorRule.shieldIsActive(
                    turnRemaining: ($0.userData?["interceptorTurnRemaining"] as? NSNumber)?.intValue ?? 0
                )
        }
        for projectile in projectileLayer.children where projectile.parent != nil {
            guard session.superShotFrames == 0 else { continue }
            for interceptor in interceptors {
                let geometry = cachedInterceptorShieldGeometry(interceptor)
                if geometry.contains(
                    projectile.position,
                    projectileVelocity: projectileVelocity(projectile)
                ) {
                    let position = projectile.position
                    projectile.removeFromParent()
                    emitParticles(
                        count: 4,
                        at: position,
                        kind: .random,
                        color: projectileParticleColor
                    )
                    break
                }
            }
        }
    }

    private func applySeparation(to enemy: SKNode, kind: EnemyKind, velocity: inout CGVector) {
        let cubeTier = (enemy.userData?["cubeTier"] as? NSNumber)?.intValue ?? 0
        let rule: OriginalEnemySeparationRule
        if let basicRule = OriginalBasicEnemyRule.separation(
            for: kind.original,
            cubeTier: cubeTier
        ) {
            rule = basicRule
        } else if kind == .interceptor {
            rule = OriginalEnemySeparationRule(
                thresholdSquared: 20 * 20 + 20 * 20,
                force: 1
            )
        } else {
            return
        }

        for other in enemyLayer.children where other !== enemy && other.name == "enemy" {
            guard other.userData?["kind"] as? String == kind.rawValue else { continue }
            let difference = CGVector(
                dx: other.position.x - enemy.position.x,
                dy: other.position.y - enemy.position.y
            )
            let distanceSquared = difference.dx * difference.dx + difference.dy * difference.dy
            if distanceSquared < rule.thresholdSquared {
                velocity.dx -= difference.dx == 0 ? 0 : copysign(rule.force, difference.dx)
                velocity.dy -= difference.dy == 0 ? 0 : copysign(rule.force, difference.dy)
            }
        }
    }

    private func bounce(_ enemy: SKNode, velocity: inout CGVector, margin: CGFloat) {
        OriginalBoundaryRule.bounce(
            position: &enemy.position,
            velocity: &velocity,
            arenaSize: playfieldSize,
            margin: margin
        )
    }

    @discardableResult
    private func applyBlackHoleInfluence(
        to enemy: SKNode,
        kind: EnemyKind,
        velocity: inout CGVector
    ) -> Bool {
        if kind == .triangle,
           let partner = trianglePartner(of: enemy) {
            let resists = (enemy.userData?["triangleResist"] as? NSNumber)?.boolValue ?? false
            guard !resists else { return false }
            for blackHole in enemies(of: .blackHole) {
                // BlackHole2 designates the opposite endpoint as the resistant
                // spinner as soon as it visits any Black Hole, active or not.
                partner.userData?["triangleResist"] = true
                let blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
                let difference = CGVector(
                    dx: blackHole.position.x - enemy.position.x,
                    dy: blackHole.position.y - enemy.position.y
                )
                let distance = difference.length + 0.001
                if distance < 100 + blackHoleSize * 10 {
                    velocity = velocity + difference / distance
                }
                let distanceSquared = difference.dx * difference.dx
                    + difference.dy * difference.dy
                if distanceSquared
                    < TriangleRule.bondBlackHoleCollisionThresholdSquared(size: blackHoleSize) {
                    let rotation = CGFloat((blackHole.userData?["rotation"] as? NSNumber)?.doubleValue ?? 0)
                    var partnerVelocity = CGVector(
                        dx: CGFloat((partner.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                        dy: CGFloat((partner.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
                    )
                    partnerVelocity = partnerVelocity
                        + TriangleRule.sceneBlackHoleSpinImpulse(sourceRotation: rotation)
                    partner.userData?["dx"] = partnerVelocity.dx
                    partner.userData?["dy"] = partnerVelocity.dy
                    let strength = CGFloat((partner.userData?["triangleStrength"] as? NSNumber)?.doubleValue
                                           ?? Double(TriangleBondState.initialStrength))
                    var bond = TriangleBondState(strength: strength)
                    bond.registerBlackHoleSpin()
                    partner.userData?["triangleStrength"] = bond.strength
                    if bond.isBroken {
                        detachTriangle(enemy)
                        // BlackHole2 removes the swallowed endpoint directly;
                        // unlike le.Kill(False), it emits no particles, score,
                        // shockwave, or killed sound.
                        enemy.removeFromParent()
                        growBlackHole(blackHole, amount: 1)
                        return true
                    }
                }
            }
            return false
        }

        for blackHole in enemies(of: .blackHole) {
            guard (blackHole.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false else { continue }
            let blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            let difference = CGVector(
                dx: blackHole.position.x - enemy.position.x,
                dy: blackHole.position.y - enemy.position.y
            )
            let distance = difference.length + 0.001
            let pullRange: CGFloat
            let pullStrength: CGFloat
            let absorbDistance: CGFloat
            switch kind {
            case .pinwheel, .diamond, .greenSquare, .cube:
                pullRange = 75 + blackHoleSize * 8
                pullStrength = (1_200 - distance) / 512
                absorbDistance = 12 + blackHoleSize / 2
            case .seeker:
                pullRange = 75 + blackHoleSize * 6
                pullStrength = (700 - distance) / 1_024
                absorbDistance = blackHoleSize / 2
            case .butterfly:
                pullRange = 75 + blackHoleSize * 5
                pullStrength = (500 - distance) / 2_048
                absorbDistance = 12 + blackHoleSize
            case .snake:
                pullRange = 75 + blackHoleSize * 5
                pullStrength = (1_200 - distance) / 1_024
                absorbDistance = 12 + blackHoleSize / 2
            case .interceptor:
                pullRange = 75 + blackHoleSize * 8
                pullStrength = (1_200 - distance) / 512
                absorbDistance = 16 + blackHoleSize / 2
            case .triangle:
                pullRange = 25 + blackHoleSize * 5
                pullStrength = (500 - distance) / 1_024
                absorbDistance = blackHoleSize / 2
            case .blackHole:
                continue
            }
            guard distance < pullRange else { continue }
            velocity = velocity + difference / distance * pullStrength
            if distance < absorbDistance {
                destroyEnemy(enemy, playSound: false, awardPoints: false)
                growBlackHole(blackHole, amount: 1)
                return true
            }
        }
        return false
    }

    private func updateBlackHole(
        _ blackHole: SKNode,
        velocity: inout CGVector,
        maximumSpeed: CGFloat,
        rotation: Int
    ) {
        let blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
        blackHole.setScale(max(0.25, 0.25 + blackHoleSize / 64))
        if (blackHole.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false {
            gridSimulation.pull(
                at: blackHole.position,
                radiusInPoints: 5 + Int(blackHoleSize / 2),
                amount: 4
            )
            if rotation.isMultiple(of: 25),
               let id = blackHole.userData?["enemyID"] as? String {
                audio.updateBlackHoleLoop(
                    id: id,
                    at: blackHole.position,
                    listener: player.position,
                    playfieldSize: playfieldSize,
                    size: blackHoleSize
                )
            }
        }

        for otherBlackHole in enemyLayer.children where otherBlackHole !== blackHole
            && otherBlackHole.name == "enemy"
            && otherBlackHole.userData?["kind"] as? String == EnemyKind.blackHole.rawValue {
            let otherSize = CGFloat((otherBlackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            let difference = CGVector(
                dx: otherBlackHole.position.x - blackHole.position.x,
                dy: otherBlackHole.position.y - blackHole.position.y
            )
            velocity = BlackHoleRule.mutuallyDeflectedVelocity(
                velocity: velocity,
                differenceToOther: difference,
                ownSize: blackHoleSize,
                otherSize: otherSize,
                maximumSpeed: maximumSpeed
            )
        }

        if (blackHole.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false,
           rotation.isMultiple(of: OriginalBlackHoleParticleRule.cadence) {
            let color = ParticleColor(
                red: cyclingRed,
                green: cyclingGreen,
                blue: cyclingBlue
            )
            for index in 0..<OriginalBlackHoleParticleRule.count {
                emitParticles(
                    count: 1,
                    at: OriginalBlackHoleParticleRule.scenePosition(
                        center: blackHole.position,
                        size: blackHoleSize,
                        sourceRotation: rotation,
                        index: index
                    ),
                    kind: .slowDirected,
                    color: color,
                    rotation: { _ in
                        OriginalBlackHoleParticleRule.sourceDirection(
                            sourceRotation: rotation,
                            index: index
                        )
                    }
                )
            }
        }
    }

    private func growBlackHole(_ blackHole: SKNode, amount: CGFloat) {
        var blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
        let speedUp = BlackHoleRule.growthSpeedUp(frame: simulationFrame)
        blackHoleSize += amount * speedUp
        blackHole.userData?["blackHoleSize"] = blackHoleSize
        let wasActive = (blackHole.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false
        blackHole.userData?["blackHoleActive"] = true
        if !wasActive {
            gridSimulation.push(
                at: blackHole.position,
                radiusInPoints: BlackHoleRule.activationPushRadius,
                amount: 1
            )
        }
        if let id = blackHole.userData?["enemyID"] as? String {
            audio.startBlackHoleLoop(
                id: id,
                at: blackHole.position,
                listener: player.position,
                playfieldSize: playfieldSize,
                size: blackHoleSize
            )
        }
        let absorbed = (blackHole.userData?["absorbCount"] as? NSNumber)?.intValue ?? 0
        blackHole.userData?["absorbCount"] = absorbed + 1

        if blackHoleSize > BlackHoleRule.maximumSize {
            let position = blackHole.position
            if let id = blackHole.userData?["enemyID"] as? String {
                audio.stopBlackHoleLoop(id: id)
            }
            blackHole.removeFromParent()
            for index in 0..<16 {
                let seeker = spawnEnemy(
                    kind: .seeker,
                    at: BlackHoleRule.explosionChildPosition(
                        sceneCenter: position,
                        arenaHeight: playfieldSize.height,
                        index: index,
                        angleStep: 22.5,
                        radius: 20
                    ),
                    freezeFrames: 4,
                    closeToPlayer: true
                )
                seeker?.userData?["seekerMean"] = 1
            }
            for index in 0..<18 {
                spawnEnemy(
                    kind: .butterfly,
                    at: BlackHoleRule.explosionChildPosition(
                        sceneCenter: position,
                        arenaHeight: playfieldSize.height,
                        index: index,
                        angleStep: 20,
                        radius: 30
                    ),
                    freezeFrames: 4,
                    closeToPlayer: true
                )
            }
            emitParticles(
                count: 36,
                at: position,
                kind: .random,
                color: colorPalette[.blackHole],
                positionForIndex: { index in
                    BlackHoleRule.explosionParticlePosition(
                        sceneCenter: position,
                        index: index
                    )
                }
            )
            playSpatial(.blackHoleExplode, at: position)
        } else {
            playSpatial(.blackHoleGrow, at: blackHole.position)
        }
    }

    private func updateProjectiles() {
        let arena = playfieldSize
        for projectile in projectileLayer.children {
            guard projectile.parent != nil else { continue }
            if let sprite = projectile as? SKSpriteNode {
                sprite.color = projectileColor
                sprite.colorBlendFactor = 1
            }
            var velocity = projectileVelocity(projectile)
            let originalSpeed = CGFloat((projectile.userData?["speed"] as? NSNumber)?.doubleValue
                                        ?? Double(velocity.length))
            var shouldRemove = false

            for _ in 0..<2 {
                projectile.position.x += velocity.dx / 2
                projectile.position.y += velocity.dy / 2

                let boundary = ProjectileUpdateRule.resolveBoundary(
                    positionAfterHalfStep: projectile.position,
                    velocity: velocity,
                    arenaSize: arena,
                    isBouncy: session.bouncyShotFrames > 0
                )
                projectile.position = boundary.position
                velocity = boundary.velocity
                shouldRemove = boundary.shouldRemove

                projectile.userData?["dx"] = velocity.dx
                projectile.userData?["dy"] = velocity.dy
                if !shouldRemove {
                    let collided = checkProjectileCollisions(projectile)
                    shouldRemove = ProjectileUpgradeRule.collisionRemovesProjectile(
                        collided: collided,
                        superShotFrames: session.superShotFrames
                    )
                }
                if !shouldRemove {
                    applyBlackHoles(toProjectile: projectile, velocity: &velocity)
                }

                velocity = ProjectileUpdateRule.enforceSourceMinimumSpeed(
                    velocity: velocity,
                    originalSpeed: originalSpeed
                )
                if shouldRemove {
                    let position = projectile.position
                    projectile.removeFromParent()
                    createProjectileImpact(at: position)
                    break
                } else {
                    gridSimulation.push(
                        at: CGPoint(
                            x: projectile.position.x + velocity.dx * 2,
                            y: projectile.position.y + velocity.dy * 2
                        ),
                        radiusInPoints: 3,
                        amount: 0.025
                    )
                }
            }

            if projectile.parent != nil {
                projectile.userData?["dx"] = velocity.dx
                projectile.userData?["dy"] = velocity.dy
                projectile.zRotation = PlayerVisualRule.projectileSceneRotation(
                    forDirection: velocity
                )
            }
        }
    }

    private var projectileColor: SKColor {
        skColor(colorPalette[projectileColorRole])
    }

    private var projectileParticleColor: ParticleColor {
        colorPalette[projectileColorRole]
    }

    private var projectileColorRole: OriginalColorRole {
        ProjectileUpgradeRule.colorRole(
            superShotFrames: session.superShotFrames,
            bouncyShotFrames: session.bouncyShotFrames
        )
    }

    private func createProjectileImpact(at position: CGPoint) {
        emitParticles(
            count: 4,
            at: position,
            kind: .random,
            color: projectileParticleColor
        )
        playSpatial(.shotWall, at: position)
    }

    private func projectileVelocity(_ projectile: SKNode) -> CGVector {
        CGVector(
            dx: CGFloat((projectile.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
            dy: CGFloat((projectile.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
        )
    }

    private func checkProjectileCollisions(_ projectile: SKNode) -> Bool {
        let position = projectile.position

        for blackHole in enemies(of: .blackHole) {
            let blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            if squaredDistance(position, blackHole.position) < pow(12 + blackHoleSize / 2, 2) {
                damageEnemy(blackHole, projectile: projectile)
                return true
            }
        }
        for square in enemies(of: .greenSquare) {
            if squaredDistance(position, square.position) < 16 * 16 + 2 * 2 {
                damageEnemy(square, projectile: projectile)
                return true
            }
            runGreenSquare(square, awayFrom: projectile)
        }
        for pinwheel in enemies(of: .pinwheel) where squaredDistance(position, pinwheel.position) < 16 * 16 + 2 * 2 {
            damageEnemy(pinwheel, projectile: projectile)
            return true
        }
        for diamond in enemies(of: .diamond) where squaredDistance(position, diamond.position) < 18 * 18 + 3 * 3 {
            damageEnemy(diamond, projectile: projectile)
            return true
        }
        for cube in enemies(of: .cube) {
            let tier = (cube.userData?["cubeTier"] as? NSNumber)?.intValue ?? 0
            if squaredDistance(position, cube.position) < CGFloat(16 * 16 + 3 * 3 - tier * 3) {
                damageEnemy(cube, projectile: projectile)
                return true
            }
        }
        for seeker in enemies(of: .seeker) where squaredDistance(position, seeker.position) < 12 * 12 + 2 * 2 {
            damageEnemy(seeker, projectile: projectile)
            return true
        }
        for triangle in enemies(of: .triangle) where
            squaredDistance(position, triangle.position)
                < TriangleRule.projectileCollisionThresholdSquared {
            damageEnemy(triangle, projectile: projectile)
            return true
        }
        for generator in enemyLayer.children where generator.name == "generator" {
            let generatorSize = CGFloat((generator.userData?["health"] as? NSNumber)?.doubleValue ?? 0)
            if squaredDistance(position, generator.position) < 12 * 12 + generatorSize {
                damageEnemy(generator, projectile: projectile)
                return true
            }
        }

        let snakeNodes = enemyLayer.children.filter {
            $0.name == "snakeTail"
                || ($0.name == "enemy" && $0.userData?["kind"] as? String == EnemyKind.snake.rawValue)
        }
        for snakeNode in snakeNodes {
            let frame = snakeNode.name == "snakeTail"
                ? ((snakeNode.userData?["originalFrame"] as? NSNumber)?.intValue ?? 0)
                : 24
            if squaredDistance(position, snakeNode.position)
                < SnakeSegmentRule.projectileCollisionThresholdSquared(originalFrame: frame) {
                damageEnemy(snakeNode, projectile: projectile)
                return true
            }
        }

        for interceptor in enemies(of: .interceptor) {
            let distance = squaredDistance(position, interceptor.position)
            guard distance < InterceptorRule.shieldRangeSquared else { continue }
            let turnRemaining = (interceptor.userData?["interceptorTurnRemaining"] as? NSNumber)?.intValue ?? 0
            if !InterceptorRule.shieldIsActive(turnRemaining: turnRemaining) {
                if distance < InterceptorRule.bodyProjectileThresholdSquared {
                    damageEnemy(interceptor, projectile: projectile)
                    return true
                }
            } else {
                if cachedInterceptorShieldGeometry(interceptor).contains(
                    position,
                    projectileVelocity: projectileVelocity(projectile)
                ) {
                    return true
                }
                if distance < InterceptorRule.bodyProjectileThresholdSquared {
                    damageEnemy(interceptor, projectile: projectile)
                    return true
                }
            }
        }
        for butterfly in enemies(of: .butterfly) where squaredDistance(position, butterfly.position) < 10 * 10 + 2 * 2 {
            damageEnemy(butterfly, projectile: projectile)
            return true
        }
        return false
    }

    private func enemies(of kind: EnemyKind) -> [SKNode] {
        enemyLayer.children.filter {
            $0.name == "enemy" && $0.userData?["kind"] as? String == kind.rawValue
        }
    }

    private func squaredDistance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return dx * dx + dy * dy
    }

    private func checkPlayerCollision(with enemy: SKNode, kind: EnemyKind) -> Bool {
        let radiusSquared: CGFloat
        switch kind {
        case .greenSquare, .pinwheel, .diamond, .cube, .seeker, .butterfly:
            let cubeTier = (enemy.userData?["cubeTier"] as? NSNumber)?.intValue ?? 0
            guard let threshold = OriginalBasicEnemyRule.playerCollisionThresholdSquared(
                for: kind.original,
                cubeTier: cubeTier
            ) else { return false }
            radiusSquared = threshold
        case .snake:
            radiusSquared = SnakeSegmentRule.playerCollisionThresholdSquared
        case .interceptor:
            radiusSquared = InterceptorRule.playerCollisionThresholdSquared
        case .triangle:
            radiusSquared = TriangleRule.playerCollisionThresholdSquared
        case .blackHole:
            let blackHoleSize = CGFloat((enemy.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            radiusSquared = BlackHoleRule.playerCollisionThresholdSquared(size: blackHoleSize)
        }
        guard squaredDistance(enemy.position, player.position) < radiusSquared,
              hitPlayer(killer: enemy) else { return false }
        return true
    }

    private func runGreenSquare(_ square: SKNode, awayFrom projectile: SKNode) {
        let squareVelocity = CGVector(
            dx: CGFloat((square.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
            dy: CGFloat((square.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
        )
        let shotVelocity = projectileVelocity(projectile)
        let maximumSpeed = session.enemySpeeds[.greenSquare] * 1.1
        let avoidingVelocity = OriginalGreenSquareRule.velocityAvoidingProjectile(
            squarePosition: square.position,
            squareVelocity: squareVelocity,
            projectilePosition: projectile.position,
            projectileVelocity: shotVelocity,
            maximumSpeed: maximumSpeed
        )
        square.userData?["dx"] = avoidingVelocity.dx
        square.userData?["dy"] = avoidingVelocity.dy
    }

    private func applyBlackHoles(toProjectile projectile: SKNode, velocity: inout CGVector) {
        for blackHole in enemies(of: .blackHole) {
            guard (blackHole.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false else { continue }
            let blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            velocity = BlackHoleRule.deflectProjectile(
                position: projectile.position,
                velocity: velocity,
                blackHolePosition: blackHole.position,
                blackHoleSize: blackHoleSize
            )
            projectile.userData?["dx"] = velocity.dx
            projectile.userData?["dy"] = velocity.dy
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        handleContact(contact)
    }

    private func handleContact(_ contact: SKPhysicsContact) {
        let first = contact.bodyA.categoryBitMask <= contact.bodyB.categoryBitMask
            ? contact.bodyA.node
            : contact.bodyB.node
        let second = contact.bodyA.categoryBitMask <= contact.bodyB.categoryBitMask
            ? contact.bodyB.node
            : contact.bodyA.node

        guard let first, let second else { return }
        let categories = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if categories == Category.projectile | Category.enemy {
            let projectile = first.physicsBody?.categoryBitMask == Category.projectile ? first : second
            let enemy = first.physicsBody?.categoryBitMask == Category.enemy ? first : second
            if session.superShotFrames == 0 { projectile.removeFromParent() }
            damageEnemy(enemy, projectile: projectile)
        } else if categories == Category.player | Category.enemy {
            let enemy = first.physicsBody?.categoryBitMask == Category.enemy ? first : second
            _ = hitPlayer(killer: enemy)
        }
    }

    private func damageEnemy(_ enemy: SKNode, projectile: SKNode) {
        guard enemy.parent != nil else { return }
        if enemy.name == "snakeTail" {
            emitParticles(
                count: 8,
                at: enemy.position,
                kind: .random,
                color: colorPalette[.snakeTail]
            )
            playSpatial(.snakeTailHit, at: enemy.position)
            return
        }
        guard enemy.name == "enemy" || enemy.name == "generator" else { return }
        let kind = EnemyKind(rawValue: enemy.userData?["kind"] as? String ?? "") ?? .pinwheel
        if kind == .interceptor, enemy.name == "enemy" {
            let turnRemaining = (enemy.userData?["interceptorTurnRemaining"] as? NSNumber)?.intValue ?? 0
            if InterceptorRule.shieldIsActive(turnRemaining: turnRemaining),
               cachedInterceptorShieldGeometry(enemy).contains(
                   projectile.position,
                   projectileVelocity: projectileVelocity(projectile)
               ) {
                emitParticles(
                    count: 4,
                    at: projectile.position,
                    kind: .random,
                    color: projectileParticleColor
                )
                return
            }
        }
        var trianglePreHitParticlesEmitted = false
        if kind == .triangle, enemy.name == "enemy" {
            let strength = CGFloat((enemy.userData?["triangleStrength"] as? NSNumber)?.doubleValue
                                   ?? Double(TriangleBondState.initialStrength))
            emitParticles(
                count: 4,
                at: enemy.position,
                kind: .threeDirections,
                color: ParticleColor(
                    red: 20 + Int(strength * 4),
                    green: 220 - Int(strength * 4),
                    blue: 0
                ),
                rotation: { _ in
                    CGFloat((enemy.userData?["rotation"] as? NSNumber)?.intValue ?? 0)
                }
            )
            trianglePreHitParticlesEmitted = true
            if trianglePartner(of: enemy) != nil {
                var bond = TriangleBondState(strength: strength)
                let shotVelocity = projectileVelocity(projectile)
                let impulse = bond.registerProjectileHit(projectileVelocityPerFrame: shotVelocity)
                var velocity = CGVector(
                    dx: CGFloat((enemy.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                    dy: CGFloat((enemy.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
                )
                velocity = velocity + impulse
                enemy.userData?["dx"] = velocity.dx
                enemy.userData?["dy"] = velocity.dy
                enemy.userData?["triangleStrength"] = bond.strength
                if bond.isBroken { detachTriangle(enemy) }
                playSpatial(.triangleHit, at: enemy.position)
                return
            }
        }
        if kind == .blackHole, enemy.name == "enemy" {
            emitParticles(
                count: 4,
                at: enemy.position,
                kind: .random,
                color: colorPalette[.blackHole]
            )
            var blackHoleSize = CGFloat((enemy.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            let wasActive = (enemy.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false
            enemy.userData?["blackHoleActive"] = true
            if !wasActive {
                gridSimulation.push(
                    at: enemy.position,
                    radiusInPoints: BlackHoleRule.activationPushRadius,
                    amount: 1
                )
            }
            blackHoleSize = BlackHoleRule.sizeAfterHit(size: blackHoleSize)
            enemy.userData?["blackHoleSize"] = blackHoleSize
            if let id = enemy.userData?["enemyID"] as? String {
                audio.startBlackHoleLoop(
                    id: id,
                    at: enemy.position,
                    listener: player.position,
                    playfieldSize: playfieldSize,
                    size: blackHoleSize
                )
            }
            if blackHoleSize < BlackHoleRule.minimumSize {
                gridSimulation.push(
                    at: enemy.position,
                    radiusInPoints: BlackHoleRule.finalPushRadius,
                    amount: 2
                )
                let absorbed = (enemy.userData?["absorbCount"] as? NSNumber)?.intValue ?? 0
                enemy.userData?["score"] = BlackHoleRule.destructionScore(absorbedEnemies: absorbed)
                destroyEnemy(enemy, preHitParticlesEmitted: true)
            } else {
                let rate = BlackHoleRule.shrinkSoundRate(size: blackHoleSize)
                playSpatial(.blackHoleShrink, at: enemy.position, rate: rate)
            }
            return
        }

        let health = (enemy.userData?["health"] as? NSNumber)?.intValue ?? 1
        if health > 1 {
            let newHealth = health - 1
            enemy.userData?["health"] = newHealth
            if enemy.name == "generator" {
                emitParticles(
                    count: 4,
                    at: enemy.position,
                    kind: .random,
                    color: particleColor(for: kind)
                )
                for event in session.registerScore(baseScore: 1) {
                    handleProgressionEvent(event)
                }
                updateGeneratorAppearance(enemy, kind: kind, health: newHealth)
                updateHUD()
            }
            enemy.run(.sequence([
                .fadeAlpha(to: 0.25, duration: 0.035),
                .fadeAlpha(to: 1, duration: 0.07),
            ]))
            if enemy.name == "generator" {
                playSpatial(
                    .generatorHit,
                    at: enemy.position,
                    rate: 1 + CGFloat(newHealth) / 64
                )
            }
        } else {
            destroyEnemy(enemy, preHitParticlesEmitted: trianglePreHitParticlesEmitted)
        }
    }

    private func updateGeneratorAppearance(_ generator: SKNode, kind: EnemyKind, health: Int) {
        guard let shape = generator as? SKShapeNode else { return }
        let rotation = (generator.userData?["rotation"] as? NSNumber)?.intValue ?? 0
        let rate = (generator.userData?["rate"] as? NSNumber)?.intValue ?? 100
        let warning = OriginalGeneratorRule.isWarningFrame(
            rotation: rotation,
            rate: rate,
            health: health
        )
        let color = warning ? SKColor.white : generatorColor(for: kind)
        shape.path = generatorFillPath(kind: kind, health: health)
        shape.fillColor = color.withAlphaComponent(OriginalGeneratorRule.fillAlpha(
            kind: kind.original,
            health: health
        ))
        if let outline = shape.childNode(withName: "generatorOutline") as? SKShapeNode {
            outline.path = generatorOutlinePath(kind: kind, health: health)
            outline.strokeColor = color
        }
        shape.physicsBody = SKPhysicsBody(circleOfRadius: 12 + CGFloat(health) / 2)
        shape.physicsBody?.affectedByGravity = false
        shape.physicsBody?.allowsRotation = false
        shape.physicsBody?.categoryBitMask = Category.enemy
        shape.physicsBody?.collisionBitMask = 0
        shape.physicsBody?.contactTestBitMask = Category.player | Category.projectile
    }

    private func destroyEnemy(
        _ enemy: SKNode,
        playSound: Bool = true,
        awardPoints: Bool = true,
        preHitParticlesEmitted: Bool = false
    ) {
        guard enemy.parent != nil, enemy.name == "enemy" || enemy.name == "generator" else { return }
        let originalName = enemy.name
        let kind = EnemyKind(rawValue: enemy.userData?["kind"] as? String ?? "") ?? .pinwheel
        let cubeTier = (enemy.userData?["cubeTier"] as? NSNumber)?.intValue ?? 0
        if kind == .triangle, originalName == "enemy" {
            destroyTriangle(
                enemy,
                awardPoints: awardPoints,
                preHitParticlesEmitted: preHitParticlesEmitted
            )
            return
        }
        if kind == .blackHole,
           let id = enemy.userData?["enemyID"] as? String {
            audio.stopBlackHoleLoop(id: id)
        }
        enemy.name = "destroying"
        enemy.physicsBody?.categoryBitMask = 0
        let score = (enemy.userData?["score"] as? NSNumber)?.intValue ?? 100
        let position = enemy.position

        if originalName == "generator" {
            // ge.Kill emits its final particles before sound and score.
            emitEnemyDestructionParticles(
                for: enemy,
                kind: kind,
                originalName: originalName,
                preHitParticlesEmitted: preHitParticlesEmitted
            )
            if playSound {
                playEnemyDestroyedSound(
                    kind: kind,
                    originalName: originalName,
                    cubeTier: cubeTier,
                    at: position
                )
            }
            if awardPoints {
                showFloatingScore(baseScore: score, at: position)
                for event in session.registerEnemyDestroyed(baseScore: score) {
                    handleProgressionEvent(event)
                }
                destroyedEnemyCount += 1
            }
            enemy.removeFromParent()
        } else if kind == .blackHole {
            // nme5 removes itself, emits 32 final particles, then awards score.
            enemy.removeFromParent()
            emitEnemyDestructionParticles(
                for: enemy,
                kind: kind,
                originalName: originalName,
                preHitParticlesEmitted: preHitParticlesEmitted
            )
            if awardPoints {
                showFloatingScore(baseScore: score, at: position)
                for event in session.registerEnemyDestroyed(baseScore: score) {
                    handleProgressionEvent(event)
                }
                destroyedEnemyCount += 1
            }
            if playSound {
                playEnemyDestroyedSound(
                    kind: kind,
                    originalName: originalName,
                    cubeTier: cubeTier,
                    at: position
                )
            }
        } else {
            // Ordinary enemy Kill methods score first. Any threshold power-up
            // therefore consumes BRL.Random before kill particles and Cube splits.
            if awardPoints {
                showFloatingScore(baseScore: score, at: position)
                for event in session.registerEnemyDestroyed(baseScore: score) {
                    handleProgressionEvent(event)
                }
                destroyedEnemyCount += 1
            }
            if playSound {
                playEnemyDestroyedSound(
                    kind: kind,
                    originalName: originalName,
                    cubeTier: cubeTier,
                    at: position
                )
            }
            if awardPoints, kind == .cube, cubeTier == 0 {
                for _ in 0..<3 {
                    let offset = originalCubeSplitOffset()
                    if let smallCube = spawnEnemy(
                        kind: .cube,
                        at: CGPoint(
                            x: position.x + offset.dx,
                            y: position.y + offset.dy
                        ),
                        freezeFrames: 2,
                        closeToPlayer: true,
                        playBornSound: false
                    ) {
                        smallCube.userData?["cubeTier"] = 4
                        smallCube.userData?["score"] = 50
                        if let smallCube = smallCube as? SKSpriteNode {
                            smallCube.texture = OriginalGraphics.texture(
                                named: "purplesquare2",
                                setIndex: activeGraphicsSetIndex
                            )
                            smallCube.size = smallCube.texture?.size() ?? smallCube.size
                        }
                    }
                }
            }
            emitEnemyDestructionParticles(
                for: enemy,
                kind: kind,
                originalName: originalName,
                preHitParticlesEmitted: preHitParticlesEmitted
            )
            gridSimulation.shockwave(at: position)
            if kind == .snake {
                scheduleSnakeTailExplosion(for: enemy, awardPoints: awardPoints)
            }
            enemy.removeFromParent()
        }
        updateHUD()
    }

    private func destroyTriangle(
        _ triangle: SKNode,
        awardPoints: Bool,
        preHitParticlesEmitted: Bool
    ) {
        guard triangle.parent != nil, triangle.name == "enemy" else { return }
        let position = triangle.position
        let rotation = CGFloat((triangle.userData?["rotation"] as? NSNumber)?.intValue ?? 0)
        let strength = CGFloat(
            (triangle.userData?["triangleStrength"] as? NSNumber)?.doubleValue
                ?? Double(TriangleBondState.initialStrength)
        )
        if let triangleID = triangle.userData?["enemyID"] as? String {
            removeTriangleBondVisuals(involving: triangleID)
        }
        triangle.name = "destroying"
        triangle.physicsBody?.categoryBitMask = 0

        // le.Kill always emits these four strength-coloured particles before
        // changing its attachment state or awarding points.
        if !preHitParticlesEmitted {
            emitParticles(
                count: 4,
                at: position,
                kind: .threeDirections,
                color: ParticleColor(
                    red: 20 + Int(strength * 4),
                    green: 220 - Int(strength * 4),
                    blue: 0
                ),
                rotation: { _ in rotation }
            )
        }

        if !awardPoints {
            // The source clears only this endpoint's `attached` flag here. A
            // bomb visits the other endpoint later in the same list traversal.
            triangle.userData?["trianglePartnerID"] = nil
            triangle.userData?["triangleResist"] = false
        } else {
            showFloatingScore(baseScore: OriginalEnemyKind.triangle.baseScore, at: position)
            for event in session.registerEnemyDestroyed(
                baseScore: OriginalEnemyKind.triangle.baseScore
            ) {
                handleProgressionEvent(event)
            }
            destroyedEnemyCount += 1
        }

        gridSimulation.shockwave(at: position)
        // Unlike the other enemy Kill(False) paths, le.Kill plays this sound
        // even when no points were requested (bomb/Black Hole absorption).
        playSpatial(.triangleKilled, at: position)
        emitParticles(
            count: 32,
            at: position,
            kind: .threeDirections,
            color: colorPalette[.triangle]
        )
        triangle.removeFromParent()
        updateHUD()
    }

    private func emitEnemyDestructionParticles(
        for enemy: SKNode,
        kind: EnemyKind,
        originalName: String?,
        preHitParticlesEmitted: Bool
    ) {
        let position = enemy.position
        let rotation = CGFloat((enemy.userData?["rotation"] as? NSNumber)?.intValue ?? 0)

        if originalName == "generator" {
            emitParticles(
                count: 12,
                at: position,
                kind: .random,
                color: particleColor(for: kind)
            )
            return
        }

        switch kind {
        case .greenSquare:
            emitParticles(
                count: 16,
                at: position,
                kind: .eightDirections,
                color: colorPalette[.square]
            )
        case .pinwheel:
            emitParticles(
                count: 16,
                at: position,
                kind: .eightDirections,
                color: colorPalette[.pinwheel],
                rotation: { _ in rotation }
            )
        case .diamond:
            let positions = (0..<16).map { _ in
                CGPoint(
                    x: position.x + CGFloat(originalRandomInt(-8...8)),
                    y: position.y - CGFloat(originalRandomInt(-8...8))
                )
            }
            emitParticles(
                count: 16,
                at: position,
                kind: .fourDirections,
                color: colorPalette[.diamond],
                positionForIndex: { positions[$0] }
            )
        case .cube:
            emitParticles(
                count: 16,
                at: position,
                kind: .fourDirections,
                color: colorPalette[.cube],
                rotation: { _ in rotation }
            )
        case .seeker:
            emitParticles(
                count: 16,
                at: position,
                kind: .directed,
                color: colorPalette[.seeker],
                rotation: { index in CGFloat(index * 24) + rotation }
            )
        case .blackHole:
            if !preHitParticlesEmitted {
                emitParticles(
                    count: 4,
                    at: position,
                    kind: .random,
                    color: colorPalette[.blackHole]
                )
            }
            emitParticles(
                count: 32,
                at: position,
                kind: .random,
                color: colorPalette[.blackHole]
            )
        case .triangle:
            if !preHitParticlesEmitted {
                let strength = CGFloat(
                    (enemy.userData?["triangleStrength"] as? NSNumber)?.doubleValue
                        ?? Double(TriangleBondState.initialStrength)
                )
                emitParticles(
                    count: 4,
                    at: position,
                    kind: .threeDirections,
                    color: ParticleColor(
                        red: 20 + Int(strength * 4),
                        green: 220 - Int(strength * 4),
                        blue: 0
                    ),
                    rotation: { _ in rotation }
                )
            }
            emitParticles(
                count: 32,
                at: position,
                kind: .threeDirections,
                color: colorPalette[.triangle]
            )
        case .snake:
            emitParticles(
                count: 32,
                at: position,
                kind: .random,
                color: colorPalette[.snake]
            )
        case .interceptor:
            emitParticles(
                count: 16,
                at: position,
                kind: .eightDirections,
                color: colorPalette[.interceptor]
            )
        case .butterfly:
            emitParticles(
                count: 9,
                at: position,
                kind: .threeDirections,
                color: colorPalette[.butterfly],
                rotation: { index in CGFloat(index * 120) + rotation }
            )
        }
    }

    private func particleColor(for kind: EnemyKind) -> ParticleColor {
        switch kind {
        case .greenSquare: colorPalette[.square]
        case .pinwheel: colorPalette[.pinwheel]
        case .diamond: colorPalette[.diamond]
        case .cube: colorPalette[.cube]
        case .seeker: colorPalette[.seeker]
        case .blackHole: colorPalette[.blackHole]
        case .triangle: colorPalette[.triangle]
        case .snake: colorPalette[.snake]
        case .interceptor: colorPalette[.interceptor]
        case .butterfly: colorPalette[.butterfly]
        }
    }

    private func skColor(_ color: ParticleColor) -> SKColor {
        SKColor(
            red: CGFloat(color.red) / 255,
            green: CGFloat(color.green) / 255,
            blue: CGFloat(color.blue) / 255,
            alpha: 1
        )
    }

    private func playSpatial(
        _ effect: OriginalSoundEffect,
        at position: CGPoint,
        rate: CGFloat = 1,
        volume: CGFloat = 1
    ) {
        audio.play(
            effect,
            at: position,
            listener: player.position,
            playfieldSize: playfieldSize,
            rate: rate,
            volume: volume
        )
    }

    private func enemyBornSound(for kind: EnemyKind) -> OriginalSoundEffect {
        switch kind {
        case .greenSquare: .squareBorn
        case .pinwheel: .pinwheelBorn
        case .diamond: .diamondBorn
        case .cube: .cubeBorn
        case .seeker: .seekerBorn
        case .blackHole: .blackHoleBorn
        case .triangle: .triangleBorn
        case .snake: .snakeBorn
        case .interceptor: .interceptorBorn
        case .butterfly: .butterflyBorn
        }
    }

    private func playEnemyDestroyedSound(
        kind: EnemyKind,
        originalName: String?,
        cubeTier: Int,
        at position: CGPoint
    ) {
        if originalName == "generator" {
            playSpatial(.generatorKilled, at: position)
            return
        }
        switch kind {
        case .greenSquare:
            playSpatial(.enemyHit, at: position, rate: 1.1)
        case .diamond:
            playSpatial(.enemyHit, at: position, rate: 0.98)
        case .cube:
            playSpatial(.enemyHit, at: position, rate: cubeTier == 0 ? 1 : 1.25)
        case .interceptor:
            playSpatial(.interceptorHit, at: position)
        case .blackHole:
            playSpatial(.blackHoleKilled, at: position)
        case .triangle:
            playSpatial(.triangleKilled, at: position)
        case .pinwheel, .seeker, .snake, .butterfly:
            playSpatial(.enemyHit, at: position)
        }
    }

    private func handleProgressionEvent(_ event: ProgressionEvent) {
        switch event {
        case let .multiplierIncreased(value):
            messageLabel.text = "\(value)X Multiplier"
            messageLabel.isHidden = false
            messageLabel.run(.sequence([.wait(forDuration: 0.7), .hide()]))
            audio.play(.multiplierIncrease)
        case let .spawnPowerUp(requestedKind):
            let kind = requestedKind ?? choosePowerUpKind()
            spawnPowerUp(at: randomPowerUpPosition(), kind: kind)
            switch requestedKind {
            case .extraPlayer: audio.play(.extraLife)
            case .extraBomb: audio.play(.extraBomb)
            default: audio.play(.bonusBorn)
            }
        case .powerUpCollected:
            break
        }
    }

    private func showFloatingScore(baseScore: Int, at scenePosition: CGPoint) {
        let state = OriginalFloatingScoreState(
            text: String(baseScore * session.multiplier),
            sourcePosition: CGPoint(
                x: Int(scenePosition.x),
                y: Int(playfieldSize.height - scenePosition.y)
            )
        )
        let node = SKNode()
        node.name = "floatingScore"
        node.zPosition = -27
        effectLayer.addChild(node)
        floatingScores.append(FloatingScoreEffect(state: state, node: node))
        renderFloatingScore(floatingScores.count - 1)
    }

    private func updateFloatingScores() {
        for index in floatingScores.indices.reversed() {
            guard floatingScores[index].node.parent != nil else {
                floatingScores.remove(at: index)
                continue
            }
            floatingScores[index].state.advance()
            if floatingScores[index].state.life <= 0 {
                floatingScores[index].node.removeFromParent()
                floatingScores.remove(at: index)
            } else {
                renderFloatingScore(index)
            }
        }
    }

    private func renderFloatingScore(_ index: Int) {
        guard floatingScores.indices.contains(index) else { return }
        let effect = floatingScores[index]
        let component = CGFloat(effect.state.colorComponent) / 255
        effect.node.removeAllChildren()
        effect.node.addChild(vectorFont.makeNode(
            effect.state.text,
            x: effect.state.drawX,
            yFromTop: effect.state.drawY,
            scale: effect.state.scale,
            arenaHeight: playfieldSize.height,
            color: SKColor(red: component, green: component, blue: 32 / 255, alpha: 1),
            lineWidth: 2
        ))
    }

    private func choosePowerUpKind() -> PowerUpKind {
        OriginalPowerUpRule.choose(
            cannons: session.cannons,
            shotSpeed: session.shotSpeed,
            lives: session.lives,
            bombs: session.bombs,
            randomInt: { originalRandomInt($0) }
        )
    }

    @discardableResult
    private func spawnPowerUp(
        at position: CGPoint,
        kind: PowerUpKind,
        freezeFrames: Int = 2,
        pushesGrid: Bool = true
    ) -> SKNode {
        let powerUp = SKNode()
        powerUp.name = "powerUp"
        powerUp.position = position
        let spawnState = originalPowerUpSpawnState()
        let velocity = spawnState.sceneVelocity
        powerUp.userData = NSMutableDictionary(dictionary: [
            "kind": kind.rawValue,
            "lifeFrames": 0,
            "freezeFrames": freezeFrames,
            "rotation": spawnState.rotation,
            "dx": velocity.dx,
            "dy": velocity.dy,
            "isDying": false,
        ])

        let icon = SKSpriteNode(texture: powerUpTexture(for: kind))
        icon.name = "powerUpIcon"
        icon.size = CGSize(width: 64, height: 64)
        icon.blendMode = .add
        powerUp.addChild(icon)

        let star = SKSpriteNode(texture: OriginalGraphics.texture(
            named: "whitestar",
            setIndex: activeGraphicsSetIndex
        ))
        star.name = "powerUpStar"
        star.size = star.texture?.size() ?? CGSize(width: 98, height: 98)
        star.blendMode = .add
        star.color = SKColor(
            red: CGFloat(cyclingRed) / 255,
            green: CGFloat(cyclingGreen) / 255,
            blue: CGFloat(cyclingBlue) / 255,
            alpha: 1
        )
        star.colorBlendFactor = 1
        star.zPosition = -1
        powerUp.addChild(star)
        pickupLayer.addChild(powerUp)
        if pushesGrid {
            gridSimulation.push(at: position, radiusInPoints: 6, amount: 1)
        }
        return powerUp
    }

    private func powerUpTexture(for kind: PowerUpKind) -> SKTexture {
        let frame: Int = switch kind {
        case .reverseShooter: 2
        case .sideShooters: 3
        case .extraCannon: 0
        case .fasterShots: 5
        case .extraPlayer: 6
        case .extraBomb: 8
        case .shield: 9
        case .superShots: 7
        case .bouncyShots: 10
        }
        return OriginalGraphics.frameTexture(
            sheet: "powerups",
            frame: frame,
            columns: 2,
            rows: 8,
            setIndex: activeGraphicsSetIndex
        )
    }

    private func updatePowerUps() {
        let powerUps = pickupLayer.children.filter { $0.name == "powerUp" }
        for powerUp in powerUps where powerUp.parent != nil {
            var isDying = (powerUp.userData?["isDying"] as? NSNumber)?.boolValue ?? false
            if squaredDistance(powerUp.position, player.position)
                < OriginalPowerUpRule.collectionDistanceSquared {
                applyPowerUpCollection(powerUp)
                isDying = true
                powerUp.userData?["isDying"] = true
            }
            var freezeFrames = (powerUp.userData?["freezeFrames"] as? NSNumber)?.intValue ?? 0
            if freezeFrames > 0 {
                freezeFrames -= 1
                powerUp.userData?["freezeFrames"] = freezeFrames
                continue
            }

            var lifeFrames = (powerUp.userData?["lifeFrames"] as? NSNumber)?.intValue ?? 0
            lifeFrames += 1
            powerUp.userData?["lifeFrames"] = lifeFrames
            var rotation = (powerUp.userData?["rotation"] as? NSNumber)?.intValue ?? 0
            rotation += 1
            powerUp.userData?["rotation"] = rotation
            let rawKind = (powerUp.userData?["kind"] as? NSNumber)?.intValue ?? 0
            let kind = PowerUpKind(rawValue: rawKind) ?? .reverseShooter
            var velocity = CGVector(
                dx: CGFloat((powerUp.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                dy: CGFloat((powerUp.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
            )

            powerUp.position.x += velocity.dx
            powerUp.position.y += velocity.dy
            bounce(powerUp, velocity: &velocity, margin: 8)

            if !isDying {
                updatePowerUpForBlackHoles(powerUp, velocity: &velocity)
            }

            if originalRandomInt(0...100) > 96 {
                velocity = OriginalPowerUpRule.velocityTowardPlayer(
                    position: powerUp.position,
                    playerPosition: player.position,
                    velocity: velocity,
                    range: playfieldSize.width
                )
            }

            if OriginalPowerUpRule.canMerge(kind: kind, lifeFrames: lifeFrames) {
                for other in powerUps where other !== powerUp && other.parent != nil
                    && ((other.userData?["kind"] as? NSNumber)?.intValue ?? 0) > 1 {
                    let towardOther = CGVector(
                        dx: other.position.x - powerUp.position.x,
                        dy: other.position.y - powerUp.position.y
                    )
                    if OriginalPowerUpRule.attractsOtherPowerUps(lifeFrames: lifeFrames) {
                        velocity.dx += towardOther.dx == 0 ? 0 : copysign(1.0 / 64.0, towardOther.dx)
                        velocity.dy += towardOther.dy == 0 ? 0 : copysign(1.0 / 64.0, towardOther.dy)
                        var otherVelocity = CGVector(
                            dx: CGFloat((other.userData?["dx"] as? NSNumber)?.doubleValue ?? 0),
                            dy: CGFloat((other.userData?["dy"] as? NSNumber)?.doubleValue ?? 0)
                        )
                        otherVelocity.dx -= towardOther.dx == 0 ? 0 : copysign(1.0 / 64.0, towardOther.dx)
                        otherVelocity.dy -= towardOther.dy == 0 ? 0 : copysign(1.0 / 64.0, towardOther.dy)
                        other.userData?["dx"] = otherVelocity.dx
                        other.userData?["dy"] = otherVelocity.dy
                    }
                    if towardOther.dx * towardOther.dx + towardOther.dy * towardOther.dy
                        < OriginalPowerUpRule.mergeDistanceSquared {
                        other.removeFromParent()
                        isDying = true
                        powerUp.userData?["isDying"] = true
                        spawnGenerator(
                            kind: .butterfly,
                            at: powerUp.position,
                            freezeFrames: 20,
                            rate: 20,
                            generatorSize: 20
                        )
                        emitParticles(
                            count: 8,
                            at: powerUp.position,
                            kind: .random,
                            color: colorPalette[.powerUp]
                        )
                    }
                }
            } else if OriginalPowerUpRule.expiresIntoButterfly(
                kind: kind,
                lifeFrames: lifeFrames
            ) {
                let position = powerUp.position
                isDying = true
                powerUp.userData?["isDying"] = true
                spawnEnemy(kind: .butterfly, at: position, freezeFrames: 30)
                emitParticles(
                    count: 8,
                    at: position,
                    kind: .random,
                    color: colorPalette[.powerUp]
                )
            }

            let speed = velocity.length + 0.001
            if speed > 4 { velocity = velocity / speed * 4 }
            powerUp.userData?["dx"] = velocity.dx
            powerUp.userData?["dy"] = velocity.dy
            updatePowerUpVisual(powerUp, lifeFrames: lifeFrames)
            if isDying { powerUp.removeFromParent() }
        }
    }

    private func updatePowerUpVisual(_ powerUp: SKNode, lifeFrames: Int) {
        let agedColor = SKColor(
            red: 180 / 255,
            green: 80 / 255,
            blue: 200 / 255,
            alpha: 1
        )
        (powerUp.childNode(withName: "powerUpStar") as? SKSpriteNode)?.zRotation =
            CGFloat(lifeFrames * 6) * .pi / 180
        if let icon = powerUp.childNode(withName: "powerUpIcon") as? SKSpriteNode {
            let isAged = OriginalPowerUpRule.iconUsesAgedColor(lifeFrames: lifeFrames)
            icon.color = isAged ? agedColor : .white
            icon.colorBlendFactor = isAged ? 1 : 0
        }
        if let star = powerUp.childNode(withName: "powerUpStar") as? SKSpriteNode {
            star.color = OriginalPowerUpRule.starUsesAgedColor(lifeFrames: lifeFrames)
                ? agedColor
                : SKColor(
                    red: CGFloat(cyclingRed) / 255,
                    green: CGFloat(cyclingGreen) / 255,
                    blue: CGFloat(cyclingBlue) / 255,
                    alpha: 1
                )
            star.colorBlendFactor = 1
        }
    }

    private func updatePowerUpForBlackHoles(_ powerUp: SKNode, velocity: inout CGVector) {
        for blackHole in enemyLayer.children where blackHole.name == "enemy"
            && blackHole.userData?["kind"] as? String == EnemyKind.blackHole.rawValue
            && ((blackHole.userData?["blackHoleActive"] as? NSNumber)?.boolValue ?? false) {
            let blackHoleSize = CGFloat((blackHole.userData?["blackHoleSize"] as? NSNumber)?.doubleValue ?? 20)
            let difference = CGVector(
                dx: blackHole.position.x - powerUp.position.x,
                dy: blackHole.position.y - powerUp.position.y
            )
            let distance = difference.length + 0.001
            guard distance < 75 + blackHoleSize * 5 else { continue }
            velocity = velocity + difference / distance * ((400 - distance) / 4_096)
            if distance < 12 + blackHoleSize {
                let position = powerUp.position
                let rotation = CGFloat(
                    (powerUp.userData?["rotation"] as? NSNumber)?.intValue ?? 0
                )
                powerUp.removeFromParent()
                emitParticles(
                    count: 15,
                    at: position,
                    kind: .directed,
                    color: colorPalette[.powerUp],
                    rotation: { index in CGFloat(index * 24) + rotation }
                )
                growBlackHole(blackHole, amount: 1)
                return
            }
        }
    }

    private func applyPowerUpCollection(_ powerUp: SKNode) {
        let position = powerUp.position
        let rawKind = (powerUp.userData?["kind"] as? NSNumber)?.intValue ?? PowerUpKind.extraBomb.rawValue
        let kind = PowerUpKind(rawValue: rawKind) ?? .extraBomb
        let events = session.collectPowerUp(kind)
        for event in events {
            if case let .powerUpCollected(_, message) = event {
                showPowerUpCollectionMessage(kind: kind, message: message, at: position)
            } else {
                handleProgressionEvent(event)
            }
        }
        playSpatial(.powerUpCollected, at: position)
        updatePlayerShield()
        updateHUD()
    }

    private func showPowerUpCollectionMessage(
        kind: PowerUpKind,
        message: String,
        at scenePosition: CGPoint
    ) {
        let messageLength = OriginalPowerUpRule.messageLength(kind: kind, message: message)
        let state = OriginalFloatingScoreState(
            text: message,
            sourcePosition: CGPoint(
                x: Int(scenePosition.x - CGFloat(messageLength * 6)),
                y: Int(playfieldSize.height - scenePosition.y - 8)
            ),
            life: 50
        )
        let node = SKNode()
        node.name = "floatingScore"
        node.zPosition = -27
        effectLayer.addChild(node)
        floatingScores.append(FloatingScoreEffect(state: state, node: node))
        renderFloatingScore(floatingScores.count - 1)
    }

    private func startGetReadySequence() {
        getReadyFrame = 0
        centerPlayerAndCamera()
        playerMotion.reset()
        player.isHidden = true
        player.alpha = 1
        playerShield.isHidden = true
        readyRings.forEach { $0.isHidden = true }
        messageLabel.text = "GET READY"
        messageLabel.setScale(1)
        messageLabel.isHidden = true
        readyMessageNode.removeAllChildren()
        readyMessageNode.isHidden = false
        audio.play(.getReady)
    }

    private func advanceGetReadySequence(updatesGrid: Bool = true) {
        let frame = getReadyFrame
        if updatesGrid {
            if frame == OriginalGetReadyRule.ringPullFrame {
                gridSimulation.pull(at: player.position, radiusInPoints: 20, amount: 20)
            }
            let updateCount = frame == OriginalGetReadyRule.ringPullFrame
                ? OriginalGetReadyRule.gridUpdatesPerFrame
                : OriginalGetReadyRule.gridUpdatesPerFrame - 1
            for _ in 0..<updateCount { gridSimulation.update() }
        }
        if frame < OriginalGetReadyRule.ringPullFrame {
            let pulse = abs(sin(CGFloat(frame) * .pi / 180))
            let color = SKColor(
                red: 0,
                green: (55 + pulse * 200) / 255,
                blue: 0,
                alpha: 1
            )
            readyMessageNode.removeAllChildren()
            readyMessageNode.addChild(vectorFont.makeNode(
                "GET READY",
                x: size.width / 2 - pulse * 19 * 5 * 9 * 0.5,
                yFromTop: size.height / 2 - pulse * 100,
                scale: pulse * 20,
                arenaHeight: size.height,
                color: color
            ))
            readyMessageNode.isHidden = false
            player.isHidden = true
            readyRings.forEach { $0.isHidden = true }
        } else {
            let ringFrame = frame - OriginalGetReadyRule.ringPullFrame
            readyMessageNode.isHidden = true
            player.isHidden = ringFrame <= 10
            let contractions: [CGFloat] = [6, 8, 12]
            for (ring, contraction) in zip(readyRings, contractions) {
                let radius = max(0, 300 - CGFloat(ringFrame) * contraction)
                ring.position = player.position
                // DrawPlayer leaves Max2D's draw colour white before the
                // source calls DrawCircle, so the rings are white rather than
                // the configured player colour.
                ring.fillColor = .white
                ring.path = originalCirclePath(radius: Int(radius))
                ring.isHidden = radius == 0
            }
        }

        getReadyFrame += 1
        if getReadyFrame >= 100 {
            getReadyFrame = -1
            readyRings.forEach { $0.isHidden = true }
            messageLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
            messageLabel.setScale(1)
            messageLabel.isHidden = true
            readyMessageNode.removeAllChildren()
            readyMessageNode.isHidden = true
            player.isHidden = false
            session.finishGetReady()
            updatePlayerShield()
            audio.startMusic(.gameplay)
        }
    }

    private func originalCirclePath(radius: Int) -> CGPath {
        let path = CGMutablePath()
        guard radius > 0 else { return path }

        func plot(_ x: Int, _ y: Int) {
            path.addRect(OriginalDrawRectRule.sceneRect(
                at: CGPoint(x: x, y: -y),
                width: 1,
                height: 1
            ))
        }
        func plotOctants(x: Int, y: Int) {
            plot(x, y)
            plot(-x, y)
            plot(x, -y)
            plot(-x, -y)
            plot(y, x)
            plot(-y, x)
            plot(y, -x)
            plot(-y, -x)
        }

        var x = 0
        var y = radius
        var decision = 1 - radius
        plotOctants(x: x, y: y)
        while x < y {
            x += 1
            if decision >= 0 {
                y -= 1
            }
            if decision < 0 {
                decision += (x << 1) + 1
            } else {
                decision += ((x - y) << 1) + 1
            }
            plotOctants(x: x, y: y)
        }
        return path
    }

    private func advanceDeathSequence() {
        deathFramesRemaining -= 1
        guard deathFramesRemaining == 0 else { return }

        let isFinalLife = session.lives == 1
        if !isFinalLife {
            enemyLayer.removeAllChildren()
            projectileLayer.removeAllChildren()
            pickupLayer.removeAllChildren()
            effectLayer.removeAllChildren()
            floatingScores.removeAll()
            gridSimulation.reset()
            particleSimulation.reset()
        }
        session.registerPlayerHit()
        updateHUD()
        centerPlayerAndCamera()
        playerMotion.reset()

        if session.isGameOver {
            player.isHidden = true
            playerShield.isHidden = true
            frameInput = OriginalResolvedInput()
            messageLabel.isHidden = true
            screenFlow.showGameOver()
            audio.play(.gameOver)
        } else {
            touchAim = .zero
            inputResolver.reset()
            frameInput = OriginalResolvedInput()
            startGetReadySequence()
        }
    }

    private func markKiller(_ killer: SKNode?) {
        guard let killer else { return }
        killer.userData?["killer"] = true

        let snakeHeadID: String?
        if killer.name == "snakeTail" {
            snakeHeadID = killer.userData?["snakeHeadID"] as? String
        } else if killer.userData?["kind"] as? String == EnemyKind.snake.rawValue {
            snakeHeadID = killer.userData?["enemyID"] as? String
        } else {
            snakeHeadID = nil
        }
        guard let snakeHeadID else { return }

        for node in enemyLayer.children {
            let isHead = node.userData?["enemyID"] as? String == snakeHeadID
            let isTail = node.userData?["snakeHeadID"] as? String == snakeHeadID
            if isHead || isTail {
                node.userData?["killer"] = true
            }
        }
    }

    private func removeNonKillerEntities() {
        audio.stopAllBlackHoleLoops()
        for node in enemyLayer.children {
            let isKiller = (node.userData?["killer"] as? NSNumber)?.boolValue ?? false
            if !isKiller {
                node.removeFromParent()
            }
        }
        projectileLayer.removeAllChildren()
        pickupLayer.removeAllChildren()
        trailLayer.removeAllChildren()
        // RemoveAll(False) clears all four pending wave counters in the original.
        spawnDirector.reset()
    }

    @discardableResult
    private func hitPlayer(killer: SKNode? = nil) -> Bool {
        guard !godMode,
              session.shieldFrames == 0,
              deathFramesRemaining == 0,
              getReadyFrame < 0 else { return false }

        markKiller(killer)
        deathFramesRemaining = 100
        player.isHidden = true
        playerShield.isHidden = true
        messageLabel.isHidden = true
        removeNonKillerEntities()
        gridSimulation.pull(at: player.position, radiusInPoints: 32, amount: 64)

        emitParticles(
            count: 256,
            at: player.position,
            kind: .random,
            color: colorPalette[.player]
        )
        audio.stopMusic()
        audio.play(.playerHit)
        return true
    }

    private func emitParticles(
        count: Int,
        at position: CGPoint,
        kind: OriginalParticleKind,
        color: ParticleColor,
        rotation: (Int) -> CGFloat = { _ in 0 },
        positionForIndex: ((Int) -> CGPoint)? = nil
    ) {
        guard count > 0 else { return }
        for index in 0..<count {
            if var random = captureRandom {
                particleSimulation.emit(
                    at: positionForIndex?(index) ?? position,
                    kind: kind,
                    color: color,
                    rotationDegrees: rotation(index),
                    using: &random
                )
                captureRandom = random
            } else {
                particleSimulation.emit(
                    at: positionForIndex?(index) ?? position,
                    kind: kind,
                    color: color,
                    rotationDegrees: rotation(index),
                    using: &spawnRandom
                )
            }
        }
    }

    private func updateHUD() {
        renderHUD()
    }

    private func renderHUD() {
        let highScore = highScores[session.difficulty].first?.score ?? 0
        hudRenderer.render(
            session: session,
            highScore: highScore,
            playerY: playfieldSize.height - player.position.y,
            simulationFrame: simulationFrame,
            debugEnabled: debugEnabled,
            message: messageLabel,
            getReadyFrame: getReadyFrame,
            playerColor: colorPalette[.player],
            scoreColor: colorPalette[.score],
            size: size
        )
    }

    func setKey(
        _ keyCode: UInt16,
        originalKeyCode: Int? = nil,
        pressed: Bool,
        isRepeat: Bool,
        characters: String? = nil
    ) {
        if pressed {
            pressedKeys.insert(keyCode)
        } else {
            pressedKeys.remove(keyCode)
        }
        if let originalKeyCode {
            if pressed {
                pressedOriginalKeys.insert(originalKeyCode)
            } else {
                pressedOriginalKeys.remove(originalKeyCode)
            }
        }

        if highScoreNameEntry != nil {
            guard pressed, !isRepeat else { return }
            var entry = highScoreNameEntry ?? OriginalHighScoreNameEntry()
            let previousEntry = entry
            switch keyCode {
            case 123: entry.moveSelection(by: -1)
            case 124: entry.moveSelection(by: 1)
            case 126: entry.cycleCharacter(by: -1)
            case 125: entry.cycleCharacter(by: 1)
            case 36:
                finishHighScoreNameEntry()
                renderPresentation()
                return
            case 49: entry.setASCII(32)
            default:
                if var ascii = originalKeyCode, (48...90).contains(ascii) {
                    let shiftIsDown = pressedOriginalKeys.contains(160)
                        || pressedOriginalKeys.contains(161)
                    if (65...90).contains(ascii), !shiftIsDown { ascii += 32 }
                    entry.setASCII(ascii)
                }
            }
            if entry != previousEntry { audio.play(.enemyHit) }
            highScoreNameEntry = entry
            renderPresentation()
            return
        }

        if let pauseState = OriginalCheatPauseRule.pauseState(
            keyCode: keyCode,
            pressed: pressed,
            cheatMode: cheatMode,
            isPlaying: screenFlow.phase == .playing
        ) {
            gameplayPaused = pauseState
            renderPresentation()
            return
        }

        guard pressed, !isRepeat else { return }
        if gameplayPaused {
            if OriginalCheatPauseRule.shouldAdvanceSingleFrame(
                keyCode: keyCode,
                pressed: pressed,
                isRepeat: isRepeat,
                cheatMode: cheatMode,
                isPlaying: screenFlow.phase == .playing,
                isPaused: gameplayPaused
            ) {
                gridRenderer.advanceAnimation()
                simulateFrame()
                renderPresentation()
            }
            return
        }
        if menuModel.isOpen {
            if let originalKeyCode,
               menuModel.captureKeyboardKey(originalKeyCode) {
                applyRuntimeSettings()
                renderPresentation()
                return
            }
            switch keyCode {
            case 126: menuModel.moveSelection(by: -1)
            case 125: menuModel.moveSelection(by: 1)
            case 123: handleMenuOutcome(menuModel.adjust(by: -1))
            case 124: handleMenuOutcome(menuModel.adjust(by: 1))
            case 36, 49: handleMenuOutcome(menuModel.activate())
            case 53: handleMenuOutcome(menuModel.back())
            default: break
            }
            applyRuntimeSettings()
            renderPresentation()
            return
        }

        if handleRuntimeKey(keyCode) {
            renderPresentation()
            return
        }

        if keyCode == 53 {
            openOptions()
            return
        }
        switch screenFlow.phase {
        case .attract:
            if originalKeyCode == menuModel.settings.keyBomb { beginGame() }
            return
        case .gameOver:
            if originalKeyCode == menuModel.settings.keyBomb { skipGameOverToScores() }
            return
        case .playing:
            break
        }
        if originalKeyCode == menuModel.settings.keyBomb {
            triggerBomb()
        }
    }

    func setPointerLocation(_ location: CGPoint, relativeDelta: CGVector = .zero) {
        pointerLocation = location
        if !menuModel.isOpen {
            relativeMouseMovement = relativeMouseMovement + relativeDelta
        }
        hasPointerLocation = true
        if menuModel.isOpen, let index = screenRenderer.menuIndex(at: location) {
            menuModel.select(index)
        }
    }

    func setMouseButton(_ button: Int, pressed: Bool) {
        guard (1...3).contains(button) else { return }
        if pressed {
            mouseButtons.insert(button)
        } else {
            mouseButtons.remove(button)
        }
        guard pressed else { return }

        if highScoreNameEntry != nil {
            if button == menuModel.settings.mouseBombButton {
                finishHighScoreNameEntry()
                renderPresentation()
            }
            return
        }
        if menuModel.isOpen {
            if let index = screenRenderer.menuIndex(at: pointerLocation) {
                menuModel.select(index)
            }
            let outcome = handleMenuMouseButton(button)
            handleMenuOutcome(outcome)
            applyRuntimeSettings()
            renderPresentation()
            return
        }

        switch screenFlow.phase {
        case .attract:
            if button == menuModel.settings.mouseBombButton { beginGame() }
        case .gameOver:
            if button == menuModel.settings.mouseBombButton { skipGameOverToScores() }
        case .playing:
            if button == menuModel.settings.mouseBombButton {
                triggerBomb()
            }
        }
    }

    private func handleMenuMouseButton(_ button: Int) -> OriginalMenuOutcome {
        let direction = button == 1 ? -1 : 1
        switch menuModel.page {
        case .options, .confirmExit, .confirmEndGame, .confirmKeepVideo,
             .confirmKeepGame, .settings, .keyboard:
            return menuModel.activate()
        case .controller:
            return menuModel.selection == 0
                ? menuModel.adjust(by: direction)
                : menuModel.activate()
        case .video, .game, .audio, .hybrid, .mouse, .joypad, .dualAnalog:
            if menuModel.selection == menuModel.lines.count - 1 {
                return menuModel.activate()
            }
            if menuModel.page == .dualAnalog,
               button == 2,
               (1...4).contains(menuModel.selection) {
                menuModel.select(menuModel.selection + 4)
                return menuModel.adjust(by: 1)
            }
            return menuModel.adjust(by: direction)
        }
    }

    func triggerBomb() {
        switch screenFlow.phase {
        case .attract:
            beginGame()
            return
        case .gameOver:
            skipGameOverToScores()
            return
        case .playing:
            break
        }
        if getReadyFrame >= 0 {
            getReadyFrame = getReadyFrame < 60 ? 60 : 99
            return
        }
        guard deathFramesRemaining == 0 else { return }
        guard bombCooldownFrames == 0 else { return }
        guard session.useBomb() else { return }
        bombCooldownFrames = 60
        for angle in 0..<360 {
            particleSimulation.emit(
                at: player.position,
                kind: .radialBomb,
                color: colorPalette[.bomb],
                rotationDegrees: CGFloat(angle),
                using: &spawnRandom
            )
            particleSimulation.emit(
                at: player.position,
                kind: .bombInternal,
                color: colorPalette[.bomb],
                using: &spawnRandom
            )
        }
        let enemies = enemyLayer.children.filter { $0.name == "enemy" || $0.name == "generator" }
        for enemy in enemies {
            destroyEnemy(enemy, playSound: false, awardPoints: false)
        }
        gridSimulation.pull(at: player.position, radiusInPoints: 60, amount: 60)

        let ring = SKShapeNode(circleOfRadius: 12)
        ring.position = player.position
        ring.strokeColor = .white
        ring.lineWidth = 5
        ring.glowWidth = 7
        effectLayer.addChild(ring)
        ring.run(.sequence([
            .group([
                .scale(to: 70, duration: 0.42),
                .fadeOut(withDuration: 0.42),
            ]),
            .removeFromParent(),
        ]))
        audio.play(.superBomb)
        updateHUD()
    }

    private func openOptions() {
        let duringGame = screenFlow.phase == .playing || screenFlow.phase == .gameOver
        if duringGame, let view {
            screenRenderer.captureMenuBackground(from: self, view: view)
        } else {
            screenRenderer.clearMenuBackground()
        }
        menuModel.open(duringGame: duringGame)
        hudLayer.isHidden = true
        menuPresentationPage = .options
        menuPresentationFrame = 0
        mouseButtons.removeAll()
        frameInput = OriginalResolvedInput()
        particleRenderer.node.zPosition = 201
        renderPresentation()
    }

    private func handleMenuOutcome(_ outcome: OriginalMenuOutcome) {
        switch outcome {
        case .none:
            break
        case .close:
            menuModel.close()
            particleRenderer.node.zPosition = screenFlow.phase == .playing ? 5 : 201
            switch screenFlow.phase {
            case .attract: showAttractTouchControls()
            case .playing, .gameOver: showGameplayTouchControls()
            }
            persistState()
        case .endGame:
            let route = OriginalEndGameRoute.resolve(
                phase: screenFlow.phase,
                score: session.score
            )
            if route == .exitApplication {
                performExitApplication()
                return
            }
            menuModel.close()
            persistState()
            audio.stopAllBlackHoleLoops()
            audio.stopMusic()
            if route == .scores {
                presentPostGameResult()
            } else {
                audio.startMusic(.intro)
                screenFlow.returnToTitle()
                particleSimulation.reset()
                gridSimulation.reset()
                attractDisplayEffects.removeAll(keepingCapacity: true)
                createAttractDisplayEffects()
                clearScorePresentation()
                enterAttractPresentation()
            }
        case .exitApplication:
            performExitApplication()
        }
    }

    private func performExitApplication() {
        persistState()
        audio.stopAllBlackHoleLoops()
        audio.stopMusic()
        #if os(macOS)
        NSApplication.shared.terminate(nil)
        #else
        menuModel.close()
        audio.startMusic(.intro)
        screenFlow.returnToTitle()
        particleSimulation.reset()
        gridSimulation.reset()
        attractDisplayEffects.removeAll(keepingCapacity: true)
        createAttractDisplayEffects()
        clearScorePresentation()
        enterAttractPresentation()
        #endif
    }

    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if highScoreNameEntry != nil, let touch = touches.first {
            let location = touch.location(in: self)
            let control = min(4, max(0, Int(location.x / (size.width / 5))))
            var entry = highScoreNameEntry ?? OriginalHighScoreNameEntry()
            let previousEntry = entry
            switch control {
            case 0: entry.moveSelection(by: -1)
            case 1: entry.moveSelection(by: 1)
            case 2: entry.cycleCharacter(by: -1)
            case 3: entry.cycleCharacter(by: 1)
            default:
                finishHighScoreNameEntry()
                renderPresentation()
                return
            }
            if entry != previousEntry { audio.play(.enemyHit) }
            highScoreNameEntry = entry
            renderPresentation()
            return
        }
        if menuModel.isOpen {
            if let touch = touches.first {
                let location = touch.location(in: self)
                if let index = screenRenderer.menuIndex(at: location) {
                    menuModel.select(index)
                    handleMenuOutcome(menuModel.activate())
                    applyRuntimeSettings()
                    renderPresentation()
                }
            }
            return
        }

        switch screenFlow.phase {
        case .attract:
            for touch in touches {
                let location = touch.location(in: self)
                if optionsButton.contains(location) {
                    openOptions()
                    return
                }
                if bombButton.contains(location) {
                    beginGame()
                    return
                }
            }
            return
        case .gameOver:
            for touch in touches {
                let location = touch.location(in: self)
                if optionsButton.contains(location) {
                    openOptions()
                    return
                }
                if bombButton.contains(location) {
                    skipGameOverToScores()
                    return
                }
            }
            return
        case .playing:
            break
        }

        for touch in touches {
            let location = touch.location(in: self)
            if optionsButton.contains(location) {
                openOptions()
            } else if bombButton.contains(location) {
                triggerBomb()
            } else if location.x < size.width / 2, movementTouch == nil {
                movementTouch = touch
                movementTouchOrigin = location
                movementStick.show(at: location)
            } else if aimingTouch == nil {
                aimingTouch = touch
                aimingTouchOrigin = location
                aimingStick.show(at: location)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            if touch === movementTouch {
                touchMovement = stickVector(from: movementTouchOrigin, to: location)
                movementStick.update(vector: touchMovement)
            } else if touch === aimingTouch {
                touchAim = stickVector(from: aimingTouchOrigin, to: location).normalized
                aimingStick.update(vector: stickVector(from: aimingTouchOrigin, to: location))
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    private func endTouches(_ touches: Set<UITouch>) {
        for touch in touches {
            if touch === movementTouch {
                movementTouch = nil
                touchMovement = .zero
                movementStick.hide()
            } else if touch === aimingTouch {
                aimingTouch = nil
                touchAim = .zero
                aimingStick.hide()
            }
        }
    }

    private func stickVector(from origin: CGPoint, to location: CGPoint) -> CGVector {
        let vector = CGVector(dx: location.x - origin.x, dy: location.y - origin.y)
        let magnitude = min(1, vector.length / 62)
        return vector.normalized * magnitude
    }
    #endif
}

@MainActor
private final class VirtualStickNode: SKNode {
    private let base = SKShapeNode(circleOfRadius: 52)
    private let knob = SKShapeNode(circleOfRadius: 22)

    override init() {
        super.init()
        base.fillColor = SKColor(white: 0.1, alpha: 0.38)
        base.strokeColor = SKColor(white: 0.8, alpha: 0.55)
        base.lineWidth = 2
        knob.fillColor = SKColor(red: 0.15, green: 0.5, blue: 1, alpha: 0.7)
        knob.strokeColor = .white
        knob.lineWidth = 2
        addChild(base)
        addChild(knob)
        isHidden = true
        zPosition = 10
    }

    required init?(coder decoder: NSCoder) {
        nil
    }

    func show(at position: CGPoint) {
        self.position = position
        knob.position = .zero
        isHidden = false
    }

    func update(vector: CGVector) {
        knob.position = CGPoint(x: vector.dx * 42, y: vector.dy * 42)
    }

    func hide() {
        isHidden = true
        knob.position = .zero
    }
}
