#if os(macOS)
import AppKit
import CoreGraphics
@preconcurrency import MetalKit
@preconcurrency import SpriteKit
import SwiftUI

private nonisolated final class MetalCommandFailureState: @unchecked Sendable {
    private let lock = NSLock()
    private var pendingMessage: String?

    func record(_ message: String) {
        lock.lock()
        pendingMessage = message
        lock.unlock()
    }

    func take() -> String? {
        lock.lock()
        defer { lock.unlock() }
        defer { pendingMessage = nil }
        return pendingMessage
    }
}

internal struct MetalPlatformGameView: NSViewRepresentable {
    internal let scene: GameScene

    internal func makeCoordinator() -> Coordinator {
        Coordinator(scene: scene)
    }

    internal func makeNSView(context: Context) -> NSView {
        context.coordinator.makeView()
    }

    internal func updateNSView(_ view: NSView, context: Context) {
        if let spriteView = view as? KeyboardSKView {
            spriteView.sceneController = scene
            if spriteView.scene !== scene {
                spriteView.presentScene(scene)
            }
        } else if let metalView = view as? KeyboardMTKView {
            metalView.sceneController = scene
        }
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
    }

    @MainActor
    internal final class Coordinator {
        private let scene: GameScene
        private var compositor: MetalSceneCompositor?

        internal init(scene: GameScene) {
            self.scene = scene
        }

        internal func makeView() -> NSView {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let commandQueue = device.makeCommandQueue() else {
                return makeSpriteKitFallback(reason: "Metal device unavailable")
            }

            // SpriteKit and the legacy Max2D evidence both treat the supplied
            // RGB channels as display-space values. An sRGB render target
            // would encode the Metal fragment output a second time.
            let pixelFormat = MTLPixelFormat.bgra8Unorm
            let effectsRenderer: MetalEffectsRenderer
            do {
                effectsRenderer = try MetalEffectsRenderer(
                    device: device,
                    colorPixelFormat: pixelFormat
                )
            } catch {
                return makeSpriteKitFallback(reason: String(describing: error))
            }

            scene.prepareForMetalRendering()
            let spriteRenderer = SKRenderer(device: device)
            spriteRenderer.scene = scene
            spriteRenderer.ignoresSiblingOrder = true

            let view = KeyboardMTKView(frame: .zero, device: device)
            view.sceneController = scene
            view.colorPixelFormat = pixelFormat
            view.clearColor = MTLClearColorMake(0, 0, 0, 1)
            view.preferredFramesPerSecond = 60
            view.enableSetNeedsDisplay = false
            view.isPaused = false
            view.framebufferOnly = scene.pendingMetalCaptureOutputPath == nil

            let compositor = MetalSceneCompositor(
                scene: scene,
                spriteRenderer: spriteRenderer,
                effectsRenderer: effectsRenderer,
                commandQueue: commandQueue
            )
            self.compositor = compositor
            scene.setMetalMenuBackgroundCapture { [weak compositor] in
                compositor?.captureSpriteKitMenuBackground()
            }
            view.delegate = compositor
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
            return view
        }

        private func makeSpriteKitFallback(reason: String) -> KeyboardSKView {
            fputs("GridWars Metal prototype disabled: \(reason)\n", stderr)
            scene.setMetalMenuBackgroundCapture(nil)
            let view = KeyboardSKView()
            view.sceneController = scene
            view.preferredFramesPerSecond = 60
            view.ignoresSiblingOrder = true
            view.presentScene(scene)
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
            return view
        }
    }
}

@MainActor
private final class MetalSceneCompositor: NSObject, MTKViewDelegate {
    private struct CaptureReadback {
        let buffer: MTLBuffer
        let outputPath: String
        let width: Int
        let height: Int
        let bytesPerRow: Int
    }

    private let scene: GameScene
    private let spriteRenderer: SKRenderer
    private let effectsRenderer: MetalEffectsRenderer
    private let commandQueue: MTLCommandQueue
    private let commandFailureState = MetalCommandFailureState()
    private var prototypeDisabledAfterFailure = false

    init(
        scene: GameScene,
        spriteRenderer: SKRenderer,
        effectsRenderer: MetalEffectsRenderer,
        commandQueue: MTLCommandQueue
    ) {
        self.scene = scene
        self.spriteRenderer = spriteRenderer
        self.effectsRenderer = effectsRenderer
        self.commandQueue = commandQueue
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        spriteRenderer.update(atTime: CACurrentMediaTime())
        if let failure = commandFailureState.take() {
            prototypeDisabledAfterFailure = true
            fputs("GridWars Metal GPU failure; using SpriteKit: \(failure)\n", stderr)
        }
        let presentation = scene.metalEffectsPresentation()
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else { return }

        let viewport = CGRect(origin: .zero, size: view.drawableSize)
        let effectsViewport = MetalEffectsViewport(
            sceneSize: scene.size,
            drawableSize: view.drawableSize,
            cameraOffset: presentation.cameraOffset
        )

        let commandBuffer: MTLCommandBuffer
        if prototypeDisabledAfterFailure || presentation.effects.coverage.isEmpty {
            guard let fallback = commandQueue.makeCommandBuffer() else { return }
            encodeFullSpriteKitFrame(
                viewport: viewport,
                commandBuffer: fallback,
                descriptor: descriptor
            )
            commandBuffer = fallback
        } else {
            do {
                guard let prototype = commandQueue.makeCommandBuffer() else { return }
                try encodeCompositedFrame(
                    presentation.effects,
                    viewport: viewport,
                    effectsViewport: effectsViewport,
                    commandBuffer: prototype,
                    descriptor: descriptor
                )
                commandBuffer = prototype
            } catch {
                scene.restoreMetalSpriteKitVisibility()
                prototypeDisabledAfterFailure = true
                fputs("GridWars Metal frame failed; using SpriteKit: \(error)\n", stderr)
                guard let fallback = commandQueue.makeCommandBuffer() else { return }
                encodeFullSpriteKitFrame(
                    viewport: viewport,
                    commandBuffer: fallback,
                    descriptor: descriptor
                )
                commandBuffer = fallback
            }
        }

        let readback = makeCaptureReadback(
            for: drawable.texture,
            commandBuffer: commandBuffer
        )
        let failureState = commandFailureState
        commandBuffer.addCompletedHandler { completed in
            guard completed.status == .error else { return }
            failureState.record(completed.error?.localizedDescription ?? "unknown command error")
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()

        guard let readback else { return }
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed,
              let image = makeCaptureImage(readback) else {
            fputs("GridWars Metal capture failed\n", stderr)
            NSApplication.shared.terminate(nil)
            return
        }
        scene.writeMetalCapture(image, to: readback.outputPath)
    }

    func captureSpriteKitMenuBackground() -> CGImage? {
        scene.restoreMetalSpriteKitVisibility()
        let width = max(1, Int(scene.size.width.rounded()))
        let height = max(1, Int(scene.size.height.rounded()))
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.storageMode = .private
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = commandQueue.device.makeTexture(descriptor: textureDescriptor),
              let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        encodeFullSpriteKitFrame(
            viewport: CGRect(x: 0, y: 0, width: width, height: height),
            commandBuffer: commandBuffer,
            descriptor: descriptor
        )
        guard let readback = encodeReadback(
            for: texture,
            commandBuffer: commandBuffer,
            outputPath: ""
        ) else { return nil }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else { return nil }
        return makeCaptureImage(readback)
    }

    private func encodeCompositedFrame(
        _ frame: MetalEffectsFrame,
        viewport: CGRect,
        effectsViewport: MetalEffectsViewport,
        commandBuffer: MTLCommandBuffer,
        descriptor: MTLRenderPassDescriptor
    ) throws {
        let frameSlot = effectsRenderer.beginFrame()
        let gridUsesMetal = frame.coverage.contains(.pointsCyclingGrid)

        if gridUsesMetal {
            try configureFirstPassToClear(descriptor)
            try encodeMetalPass(commandBuffer: commandBuffer, descriptor: descriptor) { encoder in
                try effectsRenderer.encodeGrid(
                    from: frame,
                    viewport: effectsViewport,
                    frameSlot: frameSlot,
                    into: encoder
                )
            }
        }

        scene.applyMetalSpriteKitPass(.background, coverage: frame.coverage)
        renderSpriteKit(
            viewport: viewport,
            commandBuffer: commandBuffer,
            descriptor: descriptor,
            clear: !gridUsesMetal
        )

        scene.applyMetalSpriteKitPass(.particles, coverage: frame.coverage)
        if frame.coverage.contains(.particleLinesStyleOne) {
            try encodeMetalPass(commandBuffer: commandBuffer, descriptor: descriptor) { encoder in
                try effectsRenderer.encodeParticles(
                    from: frame,
                    viewport: effectsViewport,
                    frameSlot: frameSlot,
                    into: encoder
                )
            }
        } else {
            renderSpriteKit(
                viewport: viewport,
                commandBuffer: commandBuffer,
                descriptor: descriptor
            )
        }

        scene.applyMetalSpriteKitPass(.foreground, coverage: frame.coverage)
        renderSpriteKit(
            viewport: viewport,
            commandBuffer: commandBuffer,
            descriptor: descriptor
        )
        scene.restoreMetalSpriteKitVisibility()
    }

    private func encodeFullSpriteKitFrame(
        viewport: CGRect,
        commandBuffer: MTLCommandBuffer,
        descriptor: MTLRenderPassDescriptor
    ) {
        scene.restoreMetalSpriteKitVisibility()
        renderSpriteKit(
            viewport: viewport,
            commandBuffer: commandBuffer,
            descriptor: descriptor,
            clear: true
        )
    }

    private func configureFirstPassToClear(
        _ descriptor: MTLRenderPassDescriptor
    ) throws {
        guard let attachment = descriptor.colorAttachments[0] else {
            throw MetalEffectsRendererError.renderTargetUnavailable
        }
        attachment.loadAction = .clear
        attachment.storeAction = .store
        attachment.clearColor = MTLClearColorMake(0, 0, 0, 1)
    }

    private func encodeMetalPass(
        commandBuffer: MTLCommandBuffer,
        descriptor: MTLRenderPassDescriptor,
        encode: (MTLRenderCommandEncoder) throws -> Void
    ) throws {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            throw MetalEffectsRendererError.commandEncoderUnavailable
        }
        defer { encoder.endEncoding() }
        try encode(encoder)
        descriptor.colorAttachments[0]?.storeAction = .store
        descriptor.colorAttachments[0]?.loadAction = .load
    }

    private func renderSpriteKit(
        viewport: CGRect,
        commandBuffer: MTLCommandBuffer,
        descriptor: MTLRenderPassDescriptor,
        clear: Bool = false
    ) {
        if clear {
            descriptor.colorAttachments[0]?.loadAction = .clear
            descriptor.colorAttachments[0]?.clearColor = MTLClearColorMake(0, 0, 0, 1)
        } else {
            descriptor.colorAttachments[0]?.loadAction = .load
        }
        descriptor.colorAttachments[0]?.storeAction = .store
        spriteRenderer.render(
            withViewport: viewport,
            commandBuffer: commandBuffer,
            renderPassDescriptor: descriptor
        )
    }

    private func makeCaptureReadback(
        for texture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) -> CaptureReadback? {
        guard let outputPath = scene.pendingMetalCaptureOutputPath else { return nil }
        return encodeReadback(
            for: texture,
            commandBuffer: commandBuffer,
            outputPath: outputPath
        )
    }

    private func encodeReadback(
        for texture: MTLTexture,
        commandBuffer: MTLCommandBuffer,
        outputPath: String
    ) -> CaptureReadback? {
        let width = texture.width
        let height = texture.height
        let tightBytesPerRow = width * 4
        let bytesPerRow = (tightBytesPerRow + 255) & ~255
        let length = bytesPerRow * height
        guard width > 0, height > 0,
              let buffer = texture.device.makeBuffer(
                  length: length,
                  options: .storageModeShared
              ),
              let blit = commandBuffer.makeBlitCommandEncoder() else { return nil }
        blit.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: buffer,
            destinationOffset: 0,
            destinationBytesPerRow: bytesPerRow,
            destinationBytesPerImage: length
        )
        blit.endEncoding()
        return CaptureReadback(
            buffer: buffer,
            outputPath: outputPath,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow
        )
    }

    private func makeCaptureImage(_ readback: CaptureReadback) -> CGImage? {
        let length = readback.bytesPerRow * readback.height
        let data = Data(bytes: readback.buffer.contents(), count: length)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
            ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        )
        return CGImage(
            width: readback.width,
            height: readback.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: readback.bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

@MainActor
private final class KeyboardMTKView: MTKView {
    weak var sceneController: GameScene?
    private var mouseTrackingArea: NSTrackingArea?
    private var originalKeysByPhysicalCode: [UInt16: Int] = [:]

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        if let mouseTrackingArea {
            removeTrackingArea(mouseTrackingArea)
        }
        let options: NSTrackingArea.Options = [
            .activeInKeyWindow,
            .inVisibleRect,
            .mouseMoved,
            .enabledDuringMouseDrag,
        ]
        let newArea = NSTrackingArea(rect: bounds, options: options, owner: self)
        addTrackingArea(newArea)
        mouseTrackingArea = newArea
        super.updateTrackingAreas()
    }

    override func keyDown(with event: NSEvent) {
        let originalKey = KeyboardSKView.originalKeyCode(for: event)
        if let originalKey {
            originalKeysByPhysicalCode[event.keyCode] = originalKey
        }
        sceneController?.setKey(
            event.keyCode,
            originalKeyCode: originalKey,
            pressed: true,
            isRepeat: event.isARepeat,
            characters: event.characters
        )
    }

    override func keyUp(with event: NSEvent) {
        let originalKey = originalKeysByPhysicalCode.removeValue(forKey: event.keyCode)
            ?? KeyboardSKView.originalKeyCode(for: event)
        sceneController?.setKey(
            event.keyCode,
            originalKeyCode: originalKey,
            pressed: false,
            isRepeat: false
        )
    }

    override func flagsChanged(with event: NSEvent) {
        guard let modifier = KeyboardSKView.modifier(for: event.keyCode) else {
            super.flagsChanged(with: event)
            return
        }
        let aggregateIsActive = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .contains(modifier.flag)
        let pressed = aggregateIsActive
            && originalKeysByPhysicalCode[event.keyCode] == nil
        if pressed {
            originalKeysByPhysicalCode[event.keyCode] = modifier.originalKey
        } else {
            originalKeysByPhysicalCode.removeValue(forKey: event.keyCode)
        }
        sceneController?.setKey(
            event.keyCode,
            originalKeyCode: modifier.originalKey,
            pressed: pressed,
            isRepeat: false
        )
    }

    override func mouseMoved(with event: NSEvent) { updatePointer(with: event) }
    override func mouseDragged(with event: NSEvent) { updatePointer(with: event) }

    override func mouseDown(with event: NSEvent) {
        updatePointer(with: event)
        sceneController?.setMouseButton(1, pressed: true)
    }

    override func mouseUp(with event: NSEvent) {
        updatePointer(with: event)
        sceneController?.setMouseButton(1, pressed: false)
    }

    override func rightMouseDown(with event: NSEvent) {
        updatePointer(with: event)
        sceneController?.setMouseButton(2, pressed: true)
    }

    override func rightMouseUp(with event: NSEvent) {
        updatePointer(with: event)
        sceneController?.setMouseButton(2, pressed: false)
    }

    override func otherMouseDown(with event: NSEvent) {
        updatePointer(with: event)
        sceneController?.setMouseButton(Int(event.buttonNumber) + 1, pressed: true)
    }

    override func otherMouseUp(with event: NSEvent) {
        updatePointer(with: event)
        sceneController?.setMouseButton(Int(event.buttonNumber) + 1, pressed: false)
    }

    private func updatePointer(with event: NSEvent) {
        guard let sceneController else { return }
        let point = convert(event.locationInWindow, from: nil)
        let sceneSize = sceneController.size
        let scale = min(
            bounds.width / max(1, sceneSize.width),
            bounds.height / max(1, sceneSize.height)
        )
        let contentSize = CGSize(
            width: sceneSize.width * scale,
            height: sceneSize.height * scale
        )
        let offset = CGPoint(
            x: (bounds.width - contentSize.width) / 2,
            y: (bounds.height - contentSize.height) / 2
        )
        sceneController.setPointerLocation(
            CGPoint(
                x: (point.x - offset.x) / max(scale, 0.000_1),
                y: (point.y - offset.y) / max(scale, 0.000_1)
            ),
            relativeDelta: CGVector(dx: event.deltaX, dy: -event.deltaY)
        )
    }
}
#endif
