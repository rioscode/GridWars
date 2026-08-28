import CoreGraphics
import Foundation
@preconcurrency import Metal

/// Opt-in switch for the experimental Metal renderer. The default remains SpriteKit.
internal struct MetalEffectsConfiguration: Equatable, Sendable {
    internal static let environmentKey = "GRIDWARS_METAL_EFFECTS"
    internal static let enableArgument = "--metal-effects"
    internal static let disableArgument = "--no-metal-effects"

    internal let isEnabled: Bool

    internal static func resolved(
        environment: [String: String],
        arguments: [String]
    ) -> MetalEffectsConfiguration {
        if arguments.contains(disableArgument) {
            return MetalEffectsConfiguration(isEnabled: false)
        }
        if arguments.contains(enableArgument) {
            return MetalEffectsConfiguration(isEnabled: true)
        }

        let enabledValues: Set<String> = ["1", "true", "yes", "on", "prototype", "metal"]
        let value = environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return MetalEffectsConfiguration(isEnabled: value.map(enabledValues.contains) ?? false)
    }

    @MainActor
    internal static var current: MetalEffectsConfiguration {
        resolved(
            environment: ProcessInfo.processInfo.environment,
            arguments: ProcessInfo.processInfo.arguments
        )
    }
}

internal struct MetalEffectsCoverage: OptionSet, Equatable, Sendable {
    internal let rawValue: UInt8

    internal static let pointsCyclingGrid = MetalEffectsCoverage(rawValue: 1 << 0)
    internal static let particleLinesStyleOne = MetalEffectsCoverage(rawValue: 1 << 1)
}

internal struct MetalEffectColor: Equatable, Sendable {
    internal var red: Float
    internal var green: Float
    internal var blue: Float

    internal init(red: Int, green: Int, blue: Int) {
        self.red = Float(min(255, max(0, red))) / 255
        self.green = Float(min(255, max(0, green))) / 255
        self.blue = Float(min(255, max(0, blue))) / 255
    }
}

/// One instanced rectangle or butt-capped line. Three float4 fields keep the
/// Swift and Metal layouts identical (48-byte stride on both platforms).
internal struct MetalEffectInstance: Equatable, Sendable {
    internal enum Kind: Float, Sendable {
        case rectangle = 0
        case line = 1
    }

    /// Rectangle: origin.xy, size.zw. Line: start.xy, end.zw.
    internal var geometry: SIMD4<Float>
    /// Unpremultiplied RGBA. The fragment shader premultiplies before additive blending.
    internal var color: SIMD4<Float>
    /// kind.x, lineWidth.y, unused.zw.
    internal var parameters: SIMD4<Float>

    internal static func rectangle(
        origin: CGPoint,
        size: CGSize,
        color: MetalEffectColor,
        alpha: CGFloat
    ) -> MetalEffectInstance {
        MetalEffectInstance(
            geometry: SIMD4(
                Float(origin.x),
                Float(origin.y),
                Float(size.width),
                Float(size.height)
            ),
            color: SIMD4(color.red, color.green, color.blue, Float(clampedAlpha(alpha))),
            parameters: SIMD4(Kind.rectangle.rawValue, 0, 0, 0)
        )
    }

    internal static func line(
        start: CGPoint,
        end: CGPoint,
        width: CGFloat,
        color: MetalEffectColor,
        alpha: CGFloat
    ) -> MetalEffectInstance {
        MetalEffectInstance(
            geometry: SIMD4(
                Float(start.x),
                Float(start.y),
                Float(end.x),
                Float(end.y)
            ),
            color: SIMD4(color.red, color.green, color.blue, Float(clampedAlpha(alpha))),
            parameters: SIMD4(Kind.line.rawValue, Float(width), 0, 0)
        )
    }

    private static func clampedAlpha(_ alpha: CGFloat) -> CGFloat {
        min(1, max(0, alpha))
    }
}

/// Immutable CPU snapshot consumed by the renderer. Passing nil for a pass
/// means that SpriteKit remains authoritative for that pass.
internal struct MetalEffectsFrame: Equatable, Sendable {
    internal let coverage: MetalEffectsCoverage
    internal let gridInstances: [MetalEffectInstance]
    internal let particleInstances: [MetalEffectInstance]

    internal static func make(
        pointsCyclingGrid grid: GridSimulation?,
        cyclingColor: MetalEffectColor,
        gridOpacity: CGFloat,
        particleLinesStyleOne particles: ParticleSimulation?,
        interpolationAlpha: CGFloat = 1
    ) -> MetalEffectsFrame {
        var coverage: MetalEffectsCoverage = []
        let gridInstances: [MetalEffectInstance]
        let particleInstances: [MetalEffectInstance]

        if let grid {
            coverage.insert(.pointsCyclingGrid)
            gridInstances = makePointsCyclingGrid(
                grid,
                color: cyclingColor,
                opacity: abs(gridOpacity),
                interpolationAlpha: interpolationAlpha
            )
        } else {
            gridInstances = []
        }

        if let particles {
            coverage.insert(.particleLinesStyleOne)
            particleInstances = makeParticleLinesStyleOne(
                particles,
                interpolationAlpha: interpolationAlpha
            )
        } else {
            particleInstances = []
        }

        return MetalEffectsFrame(
            coverage: coverage,
            gridInstances: gridInstances,
            particleInstances: particleInstances
        )
    }

    private static func makePointsCyclingGrid(
        _ grid: GridSimulation,
        color: MetalEffectColor,
        opacity: CGFloat,
        interpolationAlpha: CGFloat
    ) -> [MetalEffectInstance] {
        let pointCount = max(0, grid.columns * grid.rows)
        var instances: [MetalEffectInstance] = []
        instances.reserveCapacity(pointCount + pointCount / 2)

        // Preserve GridRenderer's three source-ordered additive passes: all
        // 2x2 points, then highlighted columns, then highlighted rows.
        for column in 0..<grid.columns {
            for row in 0..<grid.rows {
                appendPoint(
                    at: grid[column, row].presentationPosition(
                        interpolationAlpha: interpolationAlpha
                    ),
                    size: 2,
                    color: color,
                    opacity: opacity,
                    to: &instances
                )
            }
        }
        for column in 1..<grid.columns where column.isMultiple(of: 4) {
            for row in 0..<grid.rows {
                appendPoint(
                    at: grid[column, row].presentationPosition(
                        interpolationAlpha: interpolationAlpha
                    ),
                    size: 3,
                    color: color,
                    opacity: opacity,
                    to: &instances
                )
            }
        }
        for row in 1..<grid.rows where row.isMultiple(of: 4) {
            for column in 0..<grid.columns {
                appendPoint(
                    at: grid[column, row].presentationPosition(
                        interpolationAlpha: interpolationAlpha
                    ),
                    size: 3,
                    color: color,
                    opacity: opacity,
                    to: &instances
                )
            }
        }
        return instances
    }

    private static func appendPoint(
        at point: CGPoint,
        size: CGFloat,
        color: MetalEffectColor,
        opacity: CGFloat,
        to instances: inout [MetalEffectInstance]
    ) {
        let rect = OriginalDrawRectRule.sceneRect(at: point, width: size, height: size)
        instances.append(.rectangle(
            origin: rect.origin,
            size: rect.size,
            color: color,
            alpha: opacity
        ))
    }

    private static func makeParticleLinesStyleOne(
        _ simulation: ParticleSimulation,
        interpolationAlpha: CGFloat
    ) -> [MetalEffectInstance] {
        var instances: [MetalEffectInstance] = []
        instances.reserveCapacity(min(simulation.particles.count, 2_048))
        for particle in simulation.particles where particle.activeFrames > 0 {
            let start = OriginalLineRasterRule.scenePixelCenter(
                particle.presentationPosition(interpolationAlpha: interpolationAlpha)
            )
            let velocity = particle.presentationVelocity(
                interpolationAlpha: interpolationAlpha
            )
            let end = CGPoint(
                x: start.x + velocity.dx * 2,
                y: start.y + velocity.dy * 2
            )
            guard start != end else { continue }
            instances.append(.line(
                start: start,
                end: end,
                width: 2,
                color: boostedParticleColor(particle.color),
                // ParticleRenderer uses sqrt(0.9) to compensate SpriteKit's
                // double node-alpha application. Metal premultiplies once.
                alpha: 0.9
            ))
        }
        return instances
    }

    private static func boostedParticleColor(_ color: ParticleColor) -> MetalEffectColor {
        MetalEffectColor(
            red: min(255, Int(CGFloat(color.red) * 1.25)),
            green: min(255, Int(CGFloat(color.green) * 1.25)),
            blue: min(255, Int(CGFloat(color.blue) * 1.25))
        )
    }
}

internal struct MetalEffectsPresentation: Equatable, Sendable {
    internal let effects: MetalEffectsFrame
    internal let cameraOffset: CGPoint
}

internal enum MetalSpriteKitPass: Sendable {
    case background
    case particles
    case foreground
}

/// Aspect-fit mapping from the fixed SpriteKit scene into a Metal drawable.
internal struct MetalEffectsViewport: Equatable, Sendable {
    internal let drawableSize: SIMD2<Float>
    internal let scale: Float
    internal let contentOffset: SIMD2<Float>
    internal let cameraOffset: SIMD2<Float>

    internal init(sceneSize: CGSize, drawableSize: CGSize, cameraOffset: CGPoint) {
        let sceneWidth = max(1, sceneSize.width)
        let sceneHeight = max(1, sceneSize.height)
        let drawableWidth = max(1, drawableSize.width)
        let drawableHeight = max(1, drawableSize.height)
        let scale = min(drawableWidth / sceneWidth, drawableHeight / sceneHeight)
        let contentSize = CGSize(width: sceneWidth * scale, height: sceneHeight * scale)

        self.drawableSize = SIMD2(Float(drawableWidth), Float(drawableHeight))
        self.scale = Float(scale)
        contentOffset = SIMD2(
            Float((drawableWidth - contentSize.width) / 2),
            Float((drawableHeight - contentSize.height) / 2)
        )
        self.cameraOffset = SIMD2(Float(cameraOffset.x), Float(cameraOffset.y))
    }
}

internal enum MetalEffectsRendererError: Error, Equatable {
    case shaderSourceUnavailable
    case missingShaderFunction(String)
    case shaderCompilationFailed(String)
    case bufferAllocationFailed
    case commandEncoderUnavailable
    case renderTargetUnavailable
}

private final class MetalEffectsShaderBundleToken {}

/// Selects one of the renderer's grow-only buffers. Acquire exactly one slot
/// after obtaining a drawable and reuse it for both effect passes in that frame.
internal struct MetalEffectsFrameSlot: Equatable, Sendable {
    fileprivate let index: Int
}

/// Low-level encoder used by an MTKView/SKRenderer compositor. It never owns
/// gameplay state and can be discarded at any time to return to SpriteKit.
@MainActor
internal final class MetalEffectsRenderer {
    private static let framesInFlight = 3

    private struct Uniforms {
        var drawableAndScale: SIMD4<Float>
        var offsetAndCamera: SIMD4<Float>
    }

    private struct InstanceBuffer {
        var buffer: MTLBuffer?
        var capacity = 0
    }

    private struct InstanceBufferRing {
        var slots = Array(
            repeating: InstanceBuffer(),
            count: 3
        )
    }

    private let device: MTLDevice
    private let pipeline: MTLRenderPipelineState
    private var gridBuffers = InstanceBufferRing()
    private var particleBuffers = InstanceBufferRing()
    private var nextFrameSlot = 0

    internal init(
        device: MTLDevice,
        colorPixelFormat: MTLPixelFormat,
        sampleCount: Int = 1,
        library: MTLLibrary? = nil
    ) throws {
        self.device = device
        let shaderLibrary = try library ?? Self.makeShaderLibrary(device: device)

        guard let vertex = shaderLibrary.makeFunction(name: "gridWarsEffectVertex") else {
            throw MetalEffectsRendererError.missingShaderFunction("gridWarsEffectVertex")
        }
        guard let fragment = shaderLibrary.makeFunction(name: "gridWarsEffectFragment") else {
            throw MetalEffectsRendererError.missingShaderFunction("gridWarsEffectFragment")
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "GridWars Metal Effects Prototype"
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.rasterSampleCount = max(1, sampleCount)
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        if let attachment = descriptor.colorAttachments[0] {
            attachment.isBlendingEnabled = true
            attachment.rgbBlendOperation = .add
            attachment.sourceRGBBlendFactor = .one
            attachment.destinationRGBBlendFactor = .one
            attachment.alphaBlendOperation = .add
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .one
        }
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func makeShaderLibrary(device: MTLDevice) throws -> MTLLibrary {
        if let defaultLibrary = device.makeDefaultLibrary(),
           defaultLibrary.makeFunction(name: "gridWarsEffectVertex") != nil,
           defaultLibrary.makeFunction(name: "gridWarsEffectFragment") != nil {
            return defaultLibrary
        }
        let bundle = Bundle(for: MetalEffectsShaderBundleToken.self)
        guard let sourceURL = bundle.url(
            forResource: "GridWarsEffects",
            withExtension: "metal"
        ), let shaderSource = try? String(contentsOf: sourceURL, encoding: .utf8) else {
            throw MetalEffectsRendererError.shaderSourceUnavailable
        }
        do {
            return try device.makeLibrary(source: shaderSource, options: nil)
        } catch {
            throw MetalEffectsRendererError.shaderCompilationFailed(
                error.localizedDescription
            )
        }
    }

    internal func beginFrame() -> MetalEffectsFrameSlot {
        let slot = MetalEffectsFrameSlot(index: nextFrameSlot)
        nextFrameSlot = (nextFrameSlot + 1) % Self.framesInFlight
        return slot
    }

    internal func encodeGrid(
        from frame: MetalEffectsFrame,
        viewport: MetalEffectsViewport,
        frameSlot: MetalEffectsFrameSlot,
        into encoder: MTLRenderCommandEncoder
    ) throws {
        guard frame.coverage.contains(.pointsCyclingGrid) else { return }
        try encode(
            instances: frame.gridInstances,
            viewport: viewport,
            label: "Grid style 1",
            buffer: &gridBuffers.slots[frameSlot.index],
            into: encoder
        )
    }

    internal func encodeParticles(
        from frame: MetalEffectsFrame,
        viewport: MetalEffectsViewport,
        frameSlot: MetalEffectsFrameSlot,
        into encoder: MTLRenderCommandEncoder
    ) throws {
        guard frame.coverage.contains(.particleLinesStyleOne) else { return }
        try encode(
            instances: frame.particleInstances,
            viewport: viewport,
            label: "Particle style 1",
            buffer: &particleBuffers.slots[frameSlot.index],
            into: encoder
        )
    }

    private func encode(
        instances: [MetalEffectInstance],
        viewport: MetalEffectsViewport,
        label: String,
        buffer: inout InstanceBuffer,
        into encoder: MTLRenderCommandEncoder
    ) throws {
        guard !instances.isEmpty else { return }
        let instanceBuffer = try upload(instances, storage: &buffer)
        var uniforms = Uniforms(
            drawableAndScale: SIMD4(
                viewport.drawableSize.x,
                viewport.drawableSize.y,
                viewport.scale,
                0
            ),
            offsetAndCamera: SIMD4(
                viewport.contentOffset.x,
                viewport.contentOffset.y,
                viewport.cameraOffset.x,
                viewport.cameraOffset.y
            )
        )

        encoder.pushDebugGroup(label)
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(instanceBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: 6,
            instanceCount: instances.count
        )
        encoder.popDebugGroup()
    }

    private func upload(
        _ instances: [MetalEffectInstance],
        storage: inout InstanceBuffer
    ) throws -> MTLBuffer {
        let byteCount = instances.count * MemoryLayout<MetalEffectInstance>.stride
        if storage.buffer == nil || storage.capacity < byteCount {
            let newCapacity = nextPowerOfTwo(max(1, byteCount))
            guard let newBuffer = device.makeBuffer(
                length: newCapacity,
                options: .storageModeShared
            ) else {
                throw MetalEffectsRendererError.bufferAllocationFailed
            }
            newBuffer.label = "GridWars Metal Effect Instances"
            storage = InstanceBuffer(buffer: newBuffer, capacity: newCapacity)
        }

        guard let buffer = storage.buffer else {
            throw MetalEffectsRendererError.bufferAllocationFailed
        }
        instances.withUnsafeBytes { bytes in
            guard let source = bytes.baseAddress else { return }
            buffer.contents().copyMemory(from: source, byteCount: byteCount)
        }
        return buffer
    }

    private func nextPowerOfTwo(_ value: Int) -> Int {
        var result = 1
        while result < value { result <<= 1 }
        return result
    }
}
