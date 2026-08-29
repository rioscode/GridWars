import SpriteKit
import SwiftUI

private func configurePerformanceStatistics(on view: SKView) {
    guard ProcessInfo.processInfo.arguments.contains("--performance-stats") else { return }
    view.showsFPS = true
    view.showsNodeCount = true
    view.showsDrawCount = true
    view.showsQuadCount = true
}

struct GameView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var scene = GameScene(size: CGSize(width: 1_024, height: 768))

    var body: some View {
        #if os(macOS)
        Group {
            if MetalEffectsConfiguration.current.isEnabled {
                MetalPlatformGameView(scene: scene)
            } else {
                PlatformGameView(scene: scene)
            }
        }
            .frame(width: 1_024, height: 768)
            .preferredColorScheme(.dark)
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { scene.persistState() }
            }
            .onDisappear { scene.persistState() }
        #else
        PlatformGameView(scene: scene)
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { scene.persistState() }
            }
            .onDisappear { scene.persistState() }
        #endif
    }
}

#if os(macOS)
import AppKit

private struct PlatformGameView: NSViewRepresentable {
    let scene: GameScene

    func makeNSView(context: Context) -> KeyboardSKView {
        let view = KeyboardSKView()
        view.sceneController = scene
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        configurePerformanceStatistics(on: view)
        view.presentScene(scene)

        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ view: KeyboardSKView, context: Context) {
        if view.scene !== scene {
            view.presentScene(scene)
        }
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
    }
}

final class KeyboardSKView: SKView {
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
        let originalKey = Self.originalKeyCode(for: event)
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
            ?? Self.originalKeyCode(for: event)
        sceneController?.setKey(
            event.keyCode,
            originalKeyCode: originalKey,
            pressed: false,
            isRepeat: false
        )
    }

    override func flagsChanged(with event: NSEvent) {
        guard let modifier = Self.modifier(for: event.keyCode) else {
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

    override func mouseMoved(with event: NSEvent) {
        updatePointer(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        updatePointer(with: event)
    }

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
        let pointInView = convert(event.locationInWindow, from: nil)
        sceneController.setPointerLocation(
            sceneController.convertPoint(fromView: pointInView),
            relativeDelta: CGVector(dx: event.deltaX, dy: -event.deltaY)
        )
    }

    static func modifier(for keyCode: UInt16) -> (flag: NSEvent.ModifierFlags, originalKey: Int)? {
        switch keyCode {
        case 56: (.shift, 160)
        case 60: (.shift, 161)
        case 59: (.control, 162)
        case 62: (.control, 163)
        case 58: (.option, 164)
        case 61: (.option, 165)
        case 55: (.command, 91)
        case 54: (.command, 92)
        default: nil
        }
    }

    static func originalKeyCode(for event: NSEvent) -> Int? {
        let fixed: [UInt16: Int] = [
            51: 8, 48: 9, 71: 12, 36: 13, 76: 13, 53: 27, 49: 32,
            116: 33, 121: 34, 119: 35, 115: 36,
            123: 37, 126: 38, 124: 39, 125: 40, 114: 45, 117: 46,
            82: 96, 83: 97, 84: 98, 85: 99, 86: 100,
            87: 101, 88: 102, 89: 103, 91: 104, 92: 105,
            67: 106, 69: 107, 78: 109, 65: 110, 75: 111,
            122: 112, 120: 113, 99: 114, 118: 115, 96: 116, 97: 117,
            98: 118, 100: 119, 101: 120, 109: 121, 103: 122, 111: 123,
            50: 192, 27: 107, 24: 109, 33: 219, 30: 221, 42: 226,
            41: 186, 39: 222, 43: 188, 47: 190, 44: 191,
        ]
        if let modifier = modifier(for: event.keyCode) {
            return modifier.originalKey
        }
        if let value = fixed[event.keyCode] {
            return value
        }
        guard let scalar = event.charactersIgnoringModifiers?.uppercased().unicodeScalars.first,
              scalar.isASCII else { return nil }
        return Int(scalar.value)
    }
}
#else
import UIKit

private struct PlatformGameView: UIViewRepresentable {
    let scene: GameScene

    func makeUIView(context: Context) -> SKView {
        let view = TouchControlsSKView(frame: .zero)
        view.isMultipleTouchEnabled = true
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        configurePerformanceStatistics(on: view)
        view.presentScene(scene)
        view.connect(to: scene)
        view.updateTouchControlLayout()
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        if view.scene !== scene {
            view.presentScene(scene)
        }
        guard let view = view as? TouchControlsSKView else { return }
        view.connect(to: scene)
        view.updateTouchControlLayout()
    }
}

private final class TouchControlsSKView: SKView {
    weak var sceneController: GameScene?
    private let controlsOverlay = MobileTouchControlsOverlayView(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)
        controlsOverlay.isUserInteractionEnabled = false
        controlsOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(controlsOverlay)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        controlsOverlay.frame = bounds
        updateTouchControlLayout()
    }

    func updateTouchControlLayout() {
        sceneController?.updateTouchControlLayout(viewSize: bounds.size)
    }

    func connect(to scene: GameScene) {
        guard sceneController !== scene else {
            scene.publishMobileTouchControls()
            return
        }
        sceneController = scene
        scene.mobileTouchControlsDidChange = { [weak self] presentation in
            self?.controlsOverlay.update(presentation)
        }
        scene.publishMobileTouchControls()
    }
}

private final class MobileTouchControlsOverlayView: UIView {
    private let movementBase = CAShapeLayer()
    private let movementKnob = CAShapeLayer()
    private let aimingBase = CAShapeLayer()
    private let aimingKnob = CAShapeLayer()
    private let optionsButton = CAShapeLayer()
    private let bombButton = CAShapeLayer()
    private let optionsText = CATextLayer()
    private let bombText = CATextLayer()
    private var presentation: MobileTouchControlsPresentation?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        for controlLayer in [
            movementBase, movementKnob, aimingBase, aimingKnob,
            optionsButton, bombButton, optionsText, bombText,
        ] {
            layer.addSublayer(controlLayer)
        }
        configureStick(base: movementBase, knob: movementKnob)
        configureStick(base: aimingBase, knob: aimingKnob)
        configureButton(
            optionsButton,
            fill: UIColor(red: 0.08, green: 0.25, blue: 0.18, alpha: 0.7),
            stroke: UIColor(red: 0.3, green: 1, blue: 0.6, alpha: 1)
        )
        configureButton(
            bombButton,
            fill: UIColor(red: 0.1, green: 0.2, blue: 0.55, alpha: 0.65),
            stroke: UIColor(red: 0.35, green: 0.75, blue: 1, alpha: 1)
        )
        configureText(optionsText, string: "OPT")
        configureText(bombText, string: "BOMB")
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(_ presentation: MobileTouchControlsPresentation) {
        self.presentation = presentation
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let presentation else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let sceneSize = CGSize(width: 1_024, height: 768)
        let scale = min(bounds.width / sceneSize.width, bounds.height / sceneSize.height)
        let origin = CGPoint(
            x: (bounds.width - sceneSize.width * scale) / 2,
            y: (bounds.height - sceneSize.height * scale) / 2
        )
        func viewPoint(_ scenePoint: CGPoint) -> CGPoint {
            CGPoint(
                x: origin.x + scenePoint.x * scale,
                y: origin.y + (sceneSize.height - scenePoint.y) * scale
            )
        }

        let usesOverlay = presentation.layout.usesSideGutters
        layoutStick(
            base: movementBase,
            knob: movementKnob,
            center: viewPoint(presentation.layout.movementStickCenter),
            vector: presentation.movementVector,
            scale: scale,
            isHidden: !usesOverlay || !presentation.showsMovementStick
        )
        layoutStick(
            base: aimingBase,
            knob: aimingKnob,
            center: viewPoint(presentation.layout.aimingStickCenter),
            vector: presentation.aimingVector,
            scale: scale,
            isHidden: !usesOverlay || !presentation.showsAimingStick
        )
        layoutButton(
            button: optionsButton,
            text: optionsText,
            center: viewPoint(presentation.layout.optionsButtonCenter),
            radius: 30 * scale,
            fontSize: 11 * scale,
            isHidden: !usesOverlay || !presentation.showsOptionsButton
        )
        layoutButton(
            button: bombButton,
            text: bombText,
            center: viewPoint(presentation.layout.bombButtonCenter),
            radius: 38 * scale,
            fontSize: 12 * scale,
            isHidden: !usesOverlay || !presentation.showsBombButton
        )
    }

    private func configureStick(base: CAShapeLayer, knob: CAShapeLayer) {
        base.fillColor = UIColor(white: 0.1, alpha: 0.38).cgColor
        base.strokeColor = UIColor(white: 0.8, alpha: 0.55).cgColor
        knob.fillColor = UIColor(red: 0.15, green: 0.5, blue: 1, alpha: 0.7).cgColor
        knob.strokeColor = UIColor.white.cgColor
    }

    private func configureButton(_ button: CAShapeLayer, fill: UIColor, stroke: UIColor) {
        button.fillColor = fill.cgColor
        button.strokeColor = stroke.cgColor
    }

    private func configureText(_ text: CATextLayer, string: String) {
        text.string = string
        text.alignmentMode = .center
        text.foregroundColor = UIColor.white.cgColor
        text.contentsScale = UIScreen.main.scale
    }

    private func layoutStick(
        base: CAShapeLayer,
        knob: CAShapeLayer,
        center: CGPoint,
        vector: CGVector,
        scale: CGFloat,
        isHidden: Bool
    ) {
        base.isHidden = isHidden
        knob.isHidden = isHidden
        guard !isHidden else { return }
        base.lineWidth = max(1, 2 * scale)
        knob.lineWidth = max(1, 2 * scale)
        base.path = circlePath(center: center, radius: 52 * scale)
        let knobCenter = CGPoint(
            x: center.x + vector.dx * 42 * scale,
            y: center.y - vector.dy * 42 * scale
        )
        knob.path = circlePath(center: knobCenter, radius: 22 * scale)
    }

    private func layoutButton(
        button: CAShapeLayer,
        text: CATextLayer,
        center: CGPoint,
        radius: CGFloat,
        fontSize: CGFloat,
        isHidden: Bool
    ) {
        button.isHidden = isHidden
        text.isHidden = isHidden
        guard !isHidden else { return }
        button.lineWidth = max(1, 2 * radius / 38)
        button.path = circlePath(center: center, radius: radius)
        text.fontSize = fontSize
        text.frame = CGRect(
            x: center.x - radius,
            y: center.y - fontSize * 0.62,
            width: radius * 2,
            height: fontSize * 1.3
        )
    }

    private func circlePath(center: CGPoint, radius: CGFloat) -> CGPath {
        UIBezierPath(
            ovalIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        ).cgPath
    }
}
#endif
