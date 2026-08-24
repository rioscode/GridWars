import SpriteKit
import SwiftUI

struct GameView: View {
    @State private var scene = GameScene(size: CGSize(width: 1_024, height: 768))

    var body: some View {
        #if os(macOS)
        PlatformGameView(scene: scene)
            .frame(width: 1_024, height: 768)
            .preferredColorScheme(.dark)
        #else
        PlatformGameView(scene: scene)
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
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
        sceneController?.setKey(event.keyCode, pressed: true, isRepeat: event.isARepeat)
    }

    override func keyUp(with event: NSEvent) {
        sceneController?.setKey(event.keyCode, pressed: false, isRepeat: false)
    }

    override func mouseMoved(with event: NSEvent) {
        updatePointer(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        updatePointer(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        updatePointer(with: event)
        sceneController?.setMouseFiring(true)
    }

    override func mouseUp(with event: NSEvent) {
        updatePointer(with: event)
        sceneController?.setMouseFiring(false)
    }

    override func rightMouseDown(with event: NSEvent) {
        updatePointer(with: event)
        sceneController?.setMouseBomb(true)
    }

    override func rightMouseUp(with event: NSEvent) {
        updatePointer(with: event)
        sceneController?.setMouseBomb(false)
    }

    private func updatePointer(with event: NSEvent) {
        guard let sceneController else { return }
        let pointInView = convert(event.locationInWindow, from: nil)
        sceneController.setPointerLocation(sceneController.convertPoint(fromView: pointInView))
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
