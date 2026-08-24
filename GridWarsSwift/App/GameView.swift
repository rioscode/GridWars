import SpriteKit
import SwiftUI

struct GameView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var scene = GameScene(size: CGSize(width: 1_024, height: 768))

    var body: some View {
        #if os(macOS)
        PlatformGameView(scene: scene)
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

private final class KeyboardSKView: SKView {
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

    private static func modifier(for keyCode: UInt16) -> (flag: NSEvent.ModifierFlags, originalKey: Int)? {
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

    private static func originalKeyCode(for event: NSEvent) -> Int? {
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
        let view = SKView()
        view.isMultipleTouchEnabled = true
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        if view.scene !== scene {
            view.presentScene(scene)
        }
    }
}
#endif
