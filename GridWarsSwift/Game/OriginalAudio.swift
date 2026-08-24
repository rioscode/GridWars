import AVFoundation
import CoreGraphics
import Foundation

enum OriginalSoundEffect: CaseIterable {
    case squareBorn
    case pinwheelBorn
    case diamondBorn
    case cubeBorn
    case seekerBorn
    case blackHoleBorn
    case blackHoleLoop
    case blackHoleShrink
    case blackHoleGrow
    case blackHoleExplode
    case blackHoleKilled
    case snakeBorn
    case snakeTailExplode
    case snakeTailHit
    case interceptorBorn
    case interceptorShield
    case butterflyBorn
    case generatorBorn
    case generatorHit
    case generatorKilled
    case triangleBorn
    case triangleHit
    case triangleKilled
    case powerUpCollected
    case getReady
    case playerHit
    case shotBorn
    case shotWall
    case gameOver
    case superBomb
    case extraLife
    case extraBomb
    case multiplierIncrease
    case bonusBorn
    case highScore
    case enemyHit
    case interceptorHit
    case shieldWarning

    var fileName: String {
        switch self {
        case .squareBorn: "buzz3.wav"
        case .pinwheelBorn: "pop2.wav"
        case .diamondBorn: "pop3.wav"
        case .cubeBorn: "snake1.wav"
        case .seekerBorn: "gruntborn.wav"
        case .blackHoleBorn: "sun1.wav"
        case .blackHoleLoop: "bondloop.wav"
        case .blackHoleShrink: "sunhit1.wav"
        case .blackHoleGrow: "sizzle1.wav"
        case .blackHoleExplode: "sunexp.wav"
        case .blackHoleKilled, .superBomb: "Explo1.wav"
        case .snakeBorn: "wee.wav"
        case .snakeTailExplode: "snakehit.wav"
        case .snakeTailHit: "tailhit.wav"
        case .interceptorBorn: "warn1.wav"
        case .interceptorShield: "shield1.wav"
        case .butterflyBorn: "butterfly.wav"
        case .generatorBorn: "cat.wav"
        case .generatorHit: "genhit1.wav"
        case .generatorKilled: "genkilled1.wav"
        case .triangleBorn: "buzz1.wav"
        case .triangleHit: "echo1.wav"
        case .triangleKilled: "elastic.wav"
        case .powerUpCollected, .highScore: "bonus1.wav"
        case .getReady: "startup.wav"
        case .playerHit: "die1.wav"
        case .shotBorn: "shotborn.wav"
        case .shotWall: "shotwall.wav"
        case .gameOver: "gameover.wav"
        case .extraLife: "brainborn.wav"
        case .extraBomb: "buzz2.wav"
        case .multiplierIncrease: "bonus2.wav"
        case .bonusBorn: "bonusborn.wav"
        case .enemyHit: "quarkhit.wav"
        case .interceptorHit: "quarkhit2.wav"
        case .shieldWarning: "shieldwarning.wav"
        }
    }
}

enum OriginalMusicTrack: Int, CaseIterable {
    case intro
    case gameplay
    case highScore

    var fileName: String {
        "Theme\(rawValue).m4a"
    }
}

struct OriginalAudioMix: Equatable {
    var pan: Float
    var volume: Float
}

enum OriginalSpatialAudio {
    static func mix(
        source: CGPoint,
        listener: CGPoint,
        playfieldSize: CGSize
    ) -> OriginalAudioMix {
        let width = max(1, playfieldSize.width)
        let height = max(1, playfieldSize.height)
        let originalPan = (source.x - listener.x) / width
        let originalVolume = (1 - abs(originalPan) / 10)
            * (1 - (abs(source.y - listener.y) / height) / 10)
        return OriginalAudioMix(
            pan: Float(min(1, max(-1, originalPan))),
            volume: Float(min(1, max(0, originalVolume)))
        )
    }
}

@MainActor
final class OriginalAudioEngine {
    private struct LoopChannel {
        let player: AVAudioPlayerNode
        let rateUnit: AVAudioUnitVarispeed
        let mixer: AVAudioMixerNode
        var mix: OriginalAudioMix
    }

    private let bundle: Bundle
    private let fileManager: FileManager
    private var soundEffectsVolume: Float = 0.5
    private var musicVolume: Float = 0.5
    private var soundSetIndex = 0
    private var oneShotPlayers: [AVAudioPlayer] = []
    private var musicPlayer: AVAudioPlayer?
    private var musicTrack: OriginalMusicTrack?
    private let loopEngine = AVAudioEngine()
    private var loopBuffer: AVAudioPCMBuffer?
    private var loopChannels: [String: LoopChannel] = [:]
    private var loopOrder: [String] = []

    init(bundle: Bundle = .main, fileManager: FileManager = .default) {
        self.bundle = bundle
        self.fileManager = fileManager
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
    }

    func configure(settings: OriginalRuntimeSettings) {
        let nextSoundSet = settings.soundSetIndex
        soundEffectsVolume = Float(min(1, max(0, settings.soundEffectsVolume)))
        musicVolume = Float(min(1, max(0, settings.musicVolume)))
        musicPlayer?.volume = musicVolume

        if nextSoundSet != soundSetIndex {
            soundSetIndex = nextSoundSet
            stopAllBlackHoleLoops()
            loopBuffer = nil
            oneShotPlayers.forEach { $0.stop() }
            oneShotPlayers.removeAll()
        }
        for channel in loopChannels.values {
            channel.mixer.volume = soundEffectsVolume * channel.mix.volume
        }
    }

    func play(
        _ effect: OriginalSoundEffect,
        rate: CGFloat = 1,
        pan: CGFloat = 0,
        volume: CGFloat = 1
    ) {
        guard soundEffectsVolume > 0,
              let url = soundURL(for: effect),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        pruneOneShots()
        player.enableRate = true
        player.rate = Float(min(2, max(0.5, rate)))
        player.pan = Float(min(1, max(-1, pan)))
        player.volume = soundEffectsVolume * Float(min(1, max(0, volume)))
        player.prepareToPlay()
        player.play()
        oneShotPlayers.append(player)
    }

    func play(
        _ effect: OriginalSoundEffect,
        at source: CGPoint,
        listener: CGPoint,
        playfieldSize: CGSize,
        rate: CGFloat = 1,
        volume: CGFloat = 1
    ) {
        let mix = OriginalSpatialAudio.mix(
            source: source,
            listener: listener,
            playfieldSize: playfieldSize
        )
        play(
            effect,
            rate: rate,
            pan: CGFloat(mix.pan),
            volume: CGFloat(mix.volume) * volume
        )
    }

    func startMusic(_ track: OriginalMusicTrack) {
        if musicTrack == track, musicPlayer?.isPlaying == true { return }
        stopMusic()
        let name = (track.fileName as NSString).deletingPathExtension
        let ext = (track.fileName as NSString).pathExtension
        guard let url = bundle.url(
            forResource: name,
            withExtension: ext,
            subdirectory: "music"
        ) ?? bundle.url(forResource: name, withExtension: ext),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.volume = musicVolume
        player.prepareToPlay()
        player.play()
        musicPlayer = player
        musicTrack = track
    }

    func stopMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
        musicTrack = nil
    }

    func startBlackHoleLoop(
        id: String,
        at source: CGPoint,
        listener: CGPoint,
        playfieldSize: CGSize,
        size: CGFloat
    ) {
        if loopChannels[id] != nil {
            updateBlackHoleLoop(
                id: id,
                at: source,
                listener: listener,
                playfieldSize: playfieldSize,
                size: size
            )
            return
        }
        guard soundEffectsVolume > 0, let buffer = loadLoopBuffer() else { return }
        if loopChannels.count >= 8, let oldest = loopOrder.first {
            stopBlackHoleLoop(id: oldest)
        }

        let player = AVAudioPlayerNode()
        let rateUnit = AVAudioUnitVarispeed()
        let mixer = AVAudioMixerNode()
        loopEngine.attach(player)
        loopEngine.attach(rateUnit)
        loopEngine.attach(mixer)
        loopEngine.connect(player, to: rateUnit, format: buffer.format)
        loopEngine.connect(rateUnit, to: mixer, format: buffer.format)
        loopEngine.connect(mixer, to: loopEngine.mainMixerNode, format: buffer.format)

        let mix = OriginalSpatialAudio.mix(
            source: source,
            listener: listener,
            playfieldSize: playfieldSize
        )
        rateUnit.rate = Float(min(4, max(0.25, size / 16)))
        mixer.pan = mix.pan
        mixer.volume = soundEffectsVolume * mix.volume
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        if !loopEngine.isRunning {
            loopEngine.prepare()
            try? loopEngine.start()
        }
        player.play()
        loopChannels[id] = LoopChannel(
            player: player,
            rateUnit: rateUnit,
            mixer: mixer,
            mix: mix
        )
        loopOrder.append(id)
    }

    func updateBlackHoleLoop(
        id: String,
        at source: CGPoint,
        listener: CGPoint,
        playfieldSize: CGSize,
        size: CGFloat
    ) {
        guard var channel = loopChannels[id] else { return }
        let mix = OriginalSpatialAudio.mix(
            source: source,
            listener: listener,
            playfieldSize: playfieldSize
        )
        channel.rateUnit.rate = Float(min(4, max(0.25, size / 16)))
        channel.mixer.pan = mix.pan
        channel.mixer.volume = soundEffectsVolume * mix.volume
        channel.mix = mix
        loopChannels[id] = channel
    }

    func stopBlackHoleLoop(id: String) {
        guard let channel = loopChannels.removeValue(forKey: id) else { return }
        loopOrder.removeAll { $0 == id }
        channel.player.stop()
        loopEngine.disconnectNodeOutput(channel.player)
        loopEngine.disconnectNodeOutput(channel.rateUnit)
        loopEngine.disconnectNodeOutput(channel.mixer)
        loopEngine.detach(channel.player)
        loopEngine.detach(channel.rateUnit)
        loopEngine.detach(channel.mixer)
    }

    func stopAllBlackHoleLoops() {
        for id in Array(loopChannels.keys) {
            stopBlackHoleLoop(id: id)
        }
        loopEngine.stop()
    }

    private func pruneOneShots() {
        oneShotPlayers.removeAll { !$0.isPlaying }
        if oneShotPlayers.count >= 128 {
            oneShotPlayers.removeFirst(oneShotPlayers.count - 127)
        }
    }

    private func loadLoopBuffer() -> AVAudioPCMBuffer? {
        if let loopBuffer { return loopBuffer }
        guard let url = soundURL(for: .blackHoleLoop),
              let file = try? AVAudioFile(forReading: url),
              file.length <= AVAudioFramePosition(UInt32.max),
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: file.processingFormat,
                  frameCapacity: AVAudioFrameCount(file.length)
              ) else { return nil }
        do {
            try file.read(into: buffer)
            loopBuffer = buffer
            return buffer
        } catch {
            return nil
        }
    }

    private func soundURL(for effect: OriginalSoundEffect) -> URL? {
        let name = effect.fileName
        if soundSetIndex == 1 {
            if let support = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first {
                let userURL = support
                    .appendingPathComponent("GridWars/sounds/user", isDirectory: true)
                    .appendingPathComponent(name)
                if fileManager.fileExists(atPath: userURL.path) { return userURL }
            }
            if let bundledUser = bundle.url(
                forResource: name,
                withExtension: nil,
                subdirectory: "sounds/user"
            ) { return bundledUser }
        }
        return bundle.url(
            forResource: name,
            withExtension: nil,
            subdirectory: "sounds"
        ) ?? bundle.url(forResource: name, withExtension: nil)
    }
}
