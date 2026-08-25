import CoreGraphics
import Foundation

enum OriginalMovementLimit: Equatable {
    case unit
    case mouse(sensitivity: CGFloat)
}

struct OriginalInputSnapshot: Equatable {
    var pressedKeys = Set<Int>()
    var mouseButtons = Set<Int>()
    var mouseDelta = CGVector.zero
    var pointerFromPlayer = CGVector.zero
    var pointerFromCenter = CGVector.zero
    var controllerAxes = Array(repeating: CGFloat.zero, count: 15)
    var controllerDPad = CGVector.zero
    var controllerButtons = Set<Int>()
    var touchMovement = CGVector.zero
    var touchAim = CGVector.zero
    var touchIsActive = false
}

struct OriginalResolvedInput: Equatable {
    var movement = CGVector.zero
    var aim = CGVector.zero
    var isFiring = false
    var bombIsHeld = false
    var optionIsHeld = false
    var movementLimit = OriginalMovementLimit.unit
}

struct OriginalHighScoreControllerInput: Equatable {
    var moveX: CGFloat
    var moveY: CGFloat
    var fireY: CGFloat
    var finishIsPressed: Bool
}

enum OriginalHighScoreControllerRule {
    static func resolve(
        settings: OriginalRuntimeSettings,
        controllerAxes: [CGFloat],
        pressedButtons: Set<Int>
    ) -> OriginalHighScoreControllerInput {
        let port = settings.joyPorts[min(3, max(0, settings.dualAnalogPort))]
        let finishButton: Int? = switch settings.controllerType {
        case .dualAnalog: port.bombButton
        case .joypad: settings.joypadBombButton
        case .mouse, .keyboard, .hybrid: nil
        }
        return OriginalHighScoreControllerInput(
            moveX: calibratedAxis(0, port: port, values: controllerAxes),
            moveY: calibratedAxis(1, port: port, values: controllerAxes),
            fireY: calibratedAxis(3, port: port, values: controllerAxes),
            finishIsPressed: finishButton.map(pressedButtons.contains) ?? false
        )
    }

    private static func calibratedAxis(
        _ controlIndex: Int,
        port: OriginalJoyPortSettings,
        values: [CGFloat]
    ) -> CGFloat {
        let axisID = port.axes[controlIndex]
        guard axisID > 0, values.indices.contains(axisID - 1) else { return 0 }
        let scale = port.scale[controlIndex] == 0 ? 1 : port.scale[controlIndex]
        return values[axisID - 1] / scale
            * CGFloat(port.inversion[controlIndex])
            - port.center[controlIndex]
    }
}

struct OriginalInputResolver: Equatable {
    private(set) var retainedAim = CGVector.zero

    mutating func resolve(
        settings: OriginalRuntimeSettings,
        snapshot: OriginalInputSnapshot
    ) -> OriginalResolvedInput {
        if snapshot.touchIsActive {
            if snapshot.touchAim.length > 0 {
                retainedAim = snapshot.touchAim
            }
            return OriginalResolvedInput(
                movement: snapshot.touchMovement,
                aim: retainedAim,
                isFiring: snapshot.touchAim.length > 0
            )
        }

        switch settings.controllerType {
        case .dualAnalog:
            return resolveDualAnalog(settings: settings, snapshot: snapshot)
        case .mouse:
            return resolveMouse(settings: settings, snapshot: snapshot)
        case .keyboard:
            return resolveKeyboard(settings: settings, snapshot: snapshot)
        case .joypad:
            return resolveJoypad(settings: settings, snapshot: snapshot)
        case .hybrid:
            return resolveHybrid(settings: settings, snapshot: snapshot)
        }
    }

    mutating func reset() {
        retainedAim = .zero
    }

    private mutating func resolveDualAnalog(
        settings: OriginalRuntimeSettings,
        snapshot: OriginalInputSnapshot
    ) -> OriginalResolvedInput {
        let port = settings.joyPorts[min(3, max(0, settings.dualAnalogPort))]
        var movement = CGVector(
            dx: calibratedAxis(0, port: port, values: snapshot.controllerAxes),
            dy: -calibratedAxis(1, port: port, values: snapshot.controllerAxes)
        )
        var aim = CGVector(
            dx: calibratedAxis(2, port: port, values: snapshot.controllerAxes),
            dy: -calibratedAxis(3, port: port, values: snapshot.controllerAxes)
        )
        applyPairedDeadZone(&movement, x: port.deadZone[0], y: port.deadZone[1])
        applyPairedDeadZone(&aim, x: port.deadZone[2], y: port.deadZone[3])
        retainedAim = aim
        return OriginalResolvedInput(
            movement: movement,
            aim: aim,
            isFiring: aim.length > 0,
            bombIsHeld: snapshot.controllerButtons.contains(port.bombButton),
            optionIsHeld: snapshot.controllerButtons.contains(port.optionButton)
        )
    }

    private mutating func resolveMouse(
        settings: OriginalRuntimeSettings,
        snapshot: OriginalInputSnapshot
    ) -> OriginalResolvedInput {
        let factor = 1 + settings.mouseSensitivity * 5
        let movement = snapshot.mouseDelta / 128 * factor
        if snapshot.mouseButtons.contains(settings.mouseFireButton) {
            if snapshot.mouseDelta.length > 0 {
                retainedAim = snapshot.mouseDelta / 16
            }
        } else if !settings.autoFire {
            retainedAim = .zero
        }
        return OriginalResolvedInput(
            movement: movement,
            aim: retainedAim,
            isFiring: retainedAim.length > 0,
            bombIsHeld: isKeyPressed(settings.keyBomb, in: snapshot)
                || snapshot.mouseButtons.contains(settings.mouseBombButton),
            movementLimit: .mouse(sensitivity: settings.mouseSensitivity)
        )
    }

    private mutating func resolveKeyboard(
        settings: OriginalRuntimeSettings,
        snapshot: OriginalInputSnapshot
    ) -> OriginalResolvedInput {
        let movement = keyboardMovement(settings: settings, snapshot: snapshot)
        retainedAim = keyboardAim(
            settings: settings,
            snapshot: snapshot,
            retainingPrevious: settings.autoFire
        )
        return OriginalResolvedInput(
            movement: movement,
            aim: retainedAim,
            isFiring: retainedAim.length > 0,
            bombIsHeld: isKeyPressed(settings.keyBomb, in: snapshot)
        )
    }

    private mutating func resolveJoypad(
        settings: OriginalRuntimeSettings,
        snapshot: OriginalInputSnapshot
    ) -> OriginalResolvedInput {
        let buttons = fourButtonVector(settings: settings, snapshot: snapshot)
        let dPad = CGVector(dx: snapshot.controllerDPad.dx, dy: -snapshot.controllerDPad.dy)
        var movement = settings.joypadConfiguration == 0 ? dPad : buttons
        var aim = settings.joypadConfiguration == 0 ? buttons : dPad
        movement = componentDeadZone(movement, threshold: 0.5)
        aim = componentDeadZone(aim, threshold: 0.5)
        retainedAim = aim
        return OriginalResolvedInput(
            movement: movement,
            aim: aim,
            isFiring: aim.length > 0,
            bombIsHeld: snapshot.controllerButtons.contains(settings.joypadBombButton),
            optionIsHeld: snapshot.controllerButtons.contains(settings.joypadOptionButton)
        )
    }

    private mutating func resolveHybrid(
        settings: OriginalRuntimeSettings,
        snapshot: OriginalInputSnapshot
    ) -> OriginalResolvedInput {
        let bomb = isKeyPressed(settings.keyBomb, in: snapshot)
            || snapshot.mouseButtons.contains(settings.mouseBombButton)
        switch settings.hybridConfiguration {
        case 0:
            if snapshot.mouseButtons.contains(settings.mouseFireButton) {
                let divisor = max(1, snapshot.pointerFromPlayer.length)
                retainedAim = snapshot.pointerFromPlayer / divisor
            } else if !settings.autoFire {
                retainedAim = .zero
            }
            return OriginalResolvedInput(
                movement: keyboardMovement(settings: settings, snapshot: snapshot),
                aim: retainedAim,
                isFiring: retainedAim.length > 0,
                bombIsHeld: bomb
            )
        case 1:
            retainedAim = keyboardAim(
                settings: settings,
                snapshot: snapshot,
                retainingPrevious: settings.autoFire
            )
            let factor = 1 + settings.mouseSensitivity * 5
            return OriginalResolvedInput(
                movement: snapshot.mouseDelta / 128 * factor,
                aim: retainedAim,
                isFiring: retainedAim.length > 0,
                bombIsHeld: bomb,
                movementLimit: .mouse(sensitivity: settings.mouseSensitivity)
            )
        default:
            updateCenteredHybridAim(settings: settings, snapshot: snapshot)
            return OriginalResolvedInput(
                movement: keyboardMovement(settings: settings, snapshot: snapshot),
                aim: retainedAim,
                isFiring: retainedAim.length > 0,
                bombIsHeld: bomb
            )
        }
    }

    private mutating func updateCenteredHybridAim(
        settings: OriginalRuntimeSettings,
        snapshot: OriginalInputSnapshot
    ) {
        let mouseFire = snapshot.mouseButtons.contains(settings.mouseFireButton)
        if settings.autoFire || mouseFire {
            if snapshot.pointerFromCenter.length > 1 {
                retainedAim = snapshot.pointerFromCenter.normalized
            }
        } else {
            retainedAim = .zero
        }

        if isKeyPressed(settings.keyFireUp, in: snapshot) {
            retainedAim.dy = min(1, retainedAim.dy + 0.1)
            retainedAim.dx *= 0.8
        }
        if isKeyPressed(settings.keyFireDown, in: snapshot) {
            retainedAim.dy = max(-1, retainedAim.dy - 0.1)
            retainedAim.dx *= 0.8
        }
        if isKeyPressed(settings.keyFireRight, in: snapshot) {
            retainedAim.dx = min(1, retainedAim.dx + 0.1)
            retainedAim.dy *= 0.8
        }
        if isKeyPressed(settings.keyFireLeft, in: snapshot) {
            retainedAim.dx = max(-1, retainedAim.dx - 0.1)
            retainedAim.dy *= 0.8
        }
    }

    private func keyboardMovement(
        settings: OriginalRuntimeSettings,
        snapshot: OriginalInputSnapshot
    ) -> CGVector {
        CGVector(
            dx: boolValue(isKeyPressed(settings.keyMoveRight, in: snapshot))
                - boolValue(isKeyPressed(settings.keyMoveLeft, in: snapshot)),
            dy: boolValue(isKeyPressed(settings.keyMoveUp, in: snapshot))
                - boolValue(isKeyPressed(settings.keyMoveDown, in: snapshot))
        )
    }

    private func keyboardAim(
        settings: OriginalRuntimeSettings,
        snapshot: OriginalInputSnapshot,
        retainingPrevious: Bool
    ) -> CGVector {
        guard retainingPrevious else {
            return CGVector(
                dx: boolValue(isKeyPressed(settings.keyFireRight, in: snapshot))
                    - boolValue(isKeyPressed(settings.keyFireLeft, in: snapshot)),
                dy: boolValue(isKeyPressed(settings.keyFireUp, in: snapshot))
                    - boolValue(isKeyPressed(settings.keyFireDown, in: snapshot))
            )
        }

        var aim = retainedAim
        if isKeyPressed(settings.keyFireRight, in: snapshot) {
            aim.dx = 1
            aim.dy = boolValue(isKeyPressed(settings.keyFireUp, in: snapshot))
                - boolValue(isKeyPressed(settings.keyFireDown, in: snapshot))
        }
        if isKeyPressed(settings.keyFireLeft, in: snapshot) {
            aim.dx = -1
            aim.dy = boolValue(isKeyPressed(settings.keyFireUp, in: snapshot))
                - boolValue(isKeyPressed(settings.keyFireDown, in: snapshot))
        }
        if isKeyPressed(settings.keyFireDown, in: snapshot) {
            aim.dy = -1
            aim.dx = boolValue(isKeyPressed(settings.keyFireRight, in: snapshot))
                - boolValue(isKeyPressed(settings.keyFireLeft, in: snapshot))
        }
        if isKeyPressed(settings.keyFireUp, in: snapshot) {
            aim.dy = 1
            aim.dx = boolValue(isKeyPressed(settings.keyFireRight, in: snapshot))
                - boolValue(isKeyPressed(settings.keyFireLeft, in: snapshot))
        }
        return aim
    }

    private func fourButtonVector(
        settings: OriginalRuntimeSettings,
        snapshot: OriginalInputSnapshot
    ) -> CGVector {
        let left = settings.joypadButtons[0]
        let down = settings.joypadButtons[1]
        let right = settings.joypadButtons[2]
        let up = settings.joypadButtons[3]
        return CGVector(
            dx: boolValue(snapshot.controllerButtons.contains(right))
                - boolValue(snapshot.controllerButtons.contains(left)),
            dy: boolValue(snapshot.controllerButtons.contains(up))
                - boolValue(snapshot.controllerButtons.contains(down))
        )
    }

    private func calibratedAxis(
        _ controlIndex: Int,
        port: OriginalJoyPortSettings,
        values: [CGFloat]
    ) -> CGFloat {
        let axisID = port.axes[controlIndex]
        guard axisID > 0, values.indices.contains(axisID - 1) else { return 0 }
        let scale = port.scale[controlIndex] == 0 ? 1 : port.scale[controlIndex]
        return values[axisID - 1] / scale
            * CGFloat(port.inversion[controlIndex])
            - port.center[controlIndex]
    }

    private func applyPairedDeadZone(
        _ vector: inout CGVector,
        x: CGFloat,
        y: CGFloat
    ) {
        if abs(vector.dx) < x, abs(vector.dy) < y {
            vector = .zero
        }
    }

    private func componentDeadZone(_ vector: CGVector, threshold: CGFloat) -> CGVector {
        CGVector(
            dx: abs(vector.dx) < threshold ? 0 : vector.dx,
            dy: abs(vector.dy) < threshold ? 0 : vector.dy
        )
    }

    private func isKeyPressed(_ key: Int, in snapshot: OriginalInputSnapshot) -> Bool {
        snapshot.pressedKeys.contains(key)
    }

    private func boolValue(_ value: Bool) -> CGFloat {
        value ? 1 : 0
    }
}

enum OriginalKeyName {
    static func displayName(for code: Int) -> String {
        switch code {
        case 8: "Backspace"
        case 9: "Tab"
        case 12: "Clear"
        case 13: "Return"
        case 16: "Shift"
        case 17: "Control"
        case 18: "Alt"
        case 19: "Pause"
        case 20: "Caps Lock"
        case 27: "Escape"
        case 32: "Space"
        case 33: "Page Up"
        case 34: "Page Down"
        case 35: "End"
        case 36: "Home"
        case 37: "Cursor (Left)"
        case 38: "Cursor (Up)"
        case 39: "Cursor (Right)"
        case 40: "Cursor (Down)"
        case 46: "Delete"
        case 48...57, 65...90: String(UnicodeScalar(code) ?? "?")
        case 96...105: "Numpad \(code - 96)"
        case 112...123: "F\(code - 111)"
        default: "Key \(code)"
        }
    }
}
