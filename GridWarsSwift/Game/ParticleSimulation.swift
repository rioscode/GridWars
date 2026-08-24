import CoreGraphics

struct ParticleColor: Equatable, Codable {
    var red: Int
    var green: Int
    var blue: Int
}

enum OriginalParticleColor {
    static let greenSquare = ParticleColor(red: 32, green: 255, blue: 32)
    static let pinwheel = ParticleColor(red: 200, green: 64, blue: 255)
    static let diamond = ParticleColor(red: 32, green: 255, blue: 255)
    static let cube = ParticleColor(red: 255, green: 32, blue: 255)
    static let seeker = ParticleColor(red: 32, green: 64, blue: 255)
    static let butterfly = ParticleColor(red: 128, green: 32, blue: 255)
    static let blackHole = ParticleColor(red: 255, green: 32, blue: 32)
    static let interceptor = ParticleColor(red: 255, green: 32, blue: 32)
    static let snake = ParticleColor(red: 190, green: 32, blue: 255)
    static let snakeTail = ParticleColor(red: 255, green: 180, blue: 96)
    static let triangle = ParticleColor(red: 255, green: 128, blue: 32)
    static let player = ParticleColor(red: 255, green: 255, blue: 200)
    static let shot = ParticleColor(red: 200, green: 200, blue: 128)
    static let superShot = ParticleColor(red: 200, green: 32, blue: 32)
    static let bouncyShot = ParticleColor(red: 32, green: 200, blue: 32)
    static let bomb = ParticleColor(red: 255, green: 255, blue: 255)
    static let powerUp = ParticleColor(red: 255, green: 255, blue: 32)
}

enum OriginalParticleKind: Int {
    case random = 0
    case radialBomb = 1
    case directed = 2
    case fourDirections = 3
    case eightDirections = 6
    case slowDirected = 7
    case threeDirections = 8
    case bombInternal = 9
}

struct ParticleState: Equatable {
    var position = CGPoint.zero
    var velocity = CGVector.zero
    var color = ParticleColor(red: 0, green: 0, blue: 0)
    var activeFrames = 0
}

struct ParticleSimulation: Equatable {
    let arenaSize: CGSize
    let capacity: Int
    var particleLife: Int
    var decay: CGFloat

    private(set) var particles: [ParticleState]
    private(set) var nextSlot = 0

    init(
        arenaSize: CGSize,
        capacity: Int = 2_048,
        particleLife: Int = 40,
        decay: CGFloat = 0.95
    ) {
        self.arenaSize = arenaSize
        self.capacity = capacity
        self.particleLife = particleLife
        self.decay = decay
        particles = Array(repeating: ParticleState(), count: capacity)
    }

    var activeCount: Int {
        particles.reduce(into: 0) { count, particle in
            if particle.activeFrames > 0 { count += 1 }
        }
    }

    mutating func emit(
        at position: CGPoint,
        kind: OriginalParticleKind,
        color: ParticleColor,
        rotationDegrees: CGFloat = 0,
        size: Int = 1
    ) {
        var random = SystemRandomNumberGenerator()
        emit(
            at: position,
            kind: kind,
            color: color,
            rotationDegrees: rotationDegrees,
            size: size,
            using: &random
        )
    }

    mutating func emit<R: RandomNumberGenerator>(
        at position: CGPoint,
        kind: OriginalParticleKind,
        color: ParticleColor,
        rotationDegrees: CGFloat = 0,
        size: Int = 1,
        using random: inout R
    ) {
        guard capacity > 0 else { return }
        var activeFrames = Int.random(
            in: (particleLife - 20)...particleLife,
            using: &random
        )
        let direction: CGFloat
        let magnitude: CGFloat
        switch kind {
        case .random:
            direction = CGFloat(Int.random(in: 0...359, using: &random))
            magnitude = CGFloat.random(in: 3..<10, using: &random)
        case .radialBomb:
            direction = rotationDegrees
            magnitude = 16
            activeFrames = 24
        case .directed:
            direction = CGFloat(Int(rotationDegrees))
            magnitude = 8
        case .threeDirections:
            direction = CGFloat(120 * Int.random(in: 0...2, using: &random) + Int(rotationDegrees))
            magnitude = CGFloat.random(in: 3..<10, using: &random)
        case .fourDirections:
            direction = CGFloat(90 * Int.random(in: 0...3, using: &random) + Int(rotationDegrees))
            magnitude = CGFloat.random(in: 3..<10, using: &random)
        case .eightDirections:
            direction = CGFloat(45 * Int.random(in: 0...7, using: &random) + Int(rotationDegrees))
            magnitude = CGFloat.random(in: 3..<10, using: &random)
        case .slowDirected:
            direction = rotationDegrees
            magnitude = CGFloat.random(in: 0.5..<1, using: &random)
        case .bombInternal:
            direction = CGFloat(Int.random(in: 0...359, using: &random))
            magnitude = CGFloat.random(in: 1..<13, using: &random)
        }

        storeParticle(
            at: position,
            color: color,
            activeFrames: activeFrames,
            directionDegrees: direction,
            magnitude: magnitude,
            size: size
        )
    }

    mutating func emit(
        at position: CGPoint,
        kind: OriginalParticleKind,
        color: ParticleColor,
        rotationDegrees: CGFloat = 0,
        size: Int = 1,
        using random: inout BlitzMaxRandomNumberGenerator
    ) {
        guard capacity > 0 else { return }
        var activeFrames = random.rand(particleLife - 20, particleLife)
        let direction: CGFloat
        let magnitude: CGFloat
        switch kind {
        case .random:
            direction = -CGFloat(random.rand(0, 359))
            magnitude = CGFloat(random.rnd(3, 10))
        case .radialBomb:
            direction = -rotationDegrees
            magnitude = 16
            activeFrames = 24
        case .directed:
            direction = -CGFloat(Int(rotationDegrees))
            magnitude = 8
        case .threeDirections:
            direction = -CGFloat(120 * random.rand(0, 2) + Int(rotationDegrees))
            magnitude = CGFloat(random.rnd(3, 10))
        case .fourDirections:
            direction = -CGFloat(90 * random.rand(0, 3) + Int(rotationDegrees))
            magnitude = CGFloat(random.rnd(3, 10))
        case .eightDirections:
            direction = -CGFloat(45 * random.rand(0, 7) + Int(rotationDegrees))
            magnitude = CGFloat(random.rnd(3, 10))
        case .slowDirected:
            direction = -rotationDegrees
            magnitude = CGFloat(random.rnd(0.5, 1))
        case .bombInternal:
            direction = -CGFloat(random.rand(0, 359))
            magnitude = CGFloat(random.rnd(1, 13))
        }

        storeParticle(
            at: position,
            color: color,
            activeFrames: activeFrames,
            directionDegrees: direction,
            magnitude: magnitude,
            size: size
        )
    }

    private mutating func storeParticle(
        at position: CGPoint,
        color: ParticleColor,
        activeFrames: Int,
        directionDegrees: CGFloat,
        magnitude: CGFloat,
        size: Int
    ) {
        var particle = ParticleState(
            position: position,
            velocity: .zero,
            color: color,
            activeFrames: activeFrames
        )

        let radians = directionDegrees * .pi / 180
        particle.velocity = CGVector(
            dx: cos(radians) * magnitude * 2,
            dy: sin(radians) * magnitude * 2
        )
        particle.position.x += particle.velocity.dx * CGFloat(size)
        particle.position.y += particle.velocity.dy * CGFloat(size)
        particles[nextSlot] = particle
        nextSlot += 1
        if nextSlot > capacity - 1 { nextSlot = 0 }
    }

    mutating func update() {
        for index in particles.indices where particles[index].activeFrames > 0 {
            var particle = particles[index]
            particle.position.x += particle.velocity.dx
            particle.position.y += particle.velocity.dy

            if particle.position.x <= particle.velocity.dx {
                particle.velocity.dx = abs(particle.velocity.dx)
                particle.position.x += particle.velocity.dx * 2
            }
            if particle.position.x > arenaSize.width - 1 - particle.velocity.dx {
                particle.velocity.dx = -abs(particle.velocity.dx)
                particle.position.x += particle.velocity.dx * 2
            }
            if particle.position.y >= arenaSize.height + particle.velocity.dy {
                particle.velocity.dy = -abs(particle.velocity.dy)
                particle.position.y += particle.velocity.dy * 2
            }
            if particle.position.y < 1 - particle.velocity.dy {
                particle.velocity.dy = abs(particle.velocity.dy)
                particle.position.y += particle.velocity.dy * 2
            }

            particle.velocity = particle.velocity * decay
            particle.activeFrames -= 1
            if particle.activeFrames < 20 {
                let colorDecay: CGFloat = particle.activeFrames < 10 ? 0.8 : 0.97
                particle.color.red = Int(CGFloat(particle.color.red) * colorDecay)
                particle.color.green = Int(CGFloat(particle.color.green) * colorDecay)
                particle.color.blue = Int(CGFloat(particle.color.blue) * colorDecay)
            } else if particle.activeFrames > 200 {
                particle.activeFrames = 200
            }
            particles[index] = particle
        }
    }

    mutating func applyBlackHole(
        at center: CGPoint,
        size: CGFloat,
        frame: Int
    ) {
        let parity = frame % 2
        let spin: CGFloat = parity == 0 ? -3 : 3
        for index in stride(from: parity, to: particles.count, by: 2)
            where particles[index].activeFrames > 0 {
            var particle = particles[index]
            var difference = CGVector(
                dx: center.x - particle.position.x,
                dy: center.y - particle.position.y
            )
            let distance = difference.length
            guard distance < size * 8, distance > 8 else { continue }
            if distance < size / 4 {
                difference = difference / -distance
                particle.velocity.dx += difference.dx / 2 + difference.dy / spin
                particle.velocity.dy += difference.dy / 2 - difference.dx / spin
            } else {
                particle.activeFrames += 3
                difference = difference / distance
                particle.velocity.dx += difference.dx / 2 - difference.dy / spin
                particle.velocity.dy += difference.dy / 2 + difference.dx / spin
            }
            if particle.velocity.dx * particle.velocity.dx
                + particle.velocity.dy * particle.velocity.dy > 12 * 12 {
                particle.velocity = particle.velocity.normalized
            }
            particles[index] = particle
        }
    }

    mutating func reset() {
        particles = Array(repeating: ParticleState(), count: capacity)
        nextSlot = 0
    }
}
