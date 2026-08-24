@preconcurrency import SpriteKit

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum OriginalGraphicsSet: Int, CaseIterable, Sendable {
    case solid
    case low
    case medium
    case high
    case user

    init(index: Int) {
        self = OriginalGraphicsSet(rawValue: index) ?? .solid
    }

    var folderName: String {
        switch self {
        case .solid: "solid"
        case .low: "low"
        case .medium: "med"
        case .high: "high"
        case .user: "user"
        }
    }

    var snakeFrameSize: CGSize {
        switch self {
        case .low, .medium: CGSize(width: 32, height: 32)
        case .solid, .high, .user: CGSize(width: 56, height: 56)
        }
    }

    var iconFrameSize: CGSize {
        switch self {
        case .low: CGSize(width: 24, height: 24)
        case .medium: CGSize(width: 32, height: 32)
        case .solid, .high, .user: CGSize(width: 64, height: 64)
        }
    }
}

enum OriginalGraphics {
    static func commonTexture(named name: String) -> SKTexture {
        let texture: SKTexture
        if let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "gfx"
        ) {
            #if os(iOS)
            texture = UIImage(contentsOfFile: url.path).map(SKTexture.init(image:))
                ?? SKTexture(imageNamed: name)
            #elseif os(macOS)
            texture = NSImage(contentsOf: url).map(SKTexture.init(image:))
                ?? SKTexture(imageNamed: name)
            #endif
        } else {
            texture = SKTexture(imageNamed: name)
        }
        texture.filteringMode = .linear
        return texture
    }

    static func texture(named name: String, setIndex: Int) -> SKTexture {
        let set = OriginalGraphicsSet(index: setIndex)
        let texture: SKTexture
        if let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "gfx/\(set.folderName)"
        ) {
            #if os(iOS)
            if let image = UIImage(contentsOfFile: url.path) {
                texture = SKTexture(image: image)
            } else {
                texture = SKTexture(imageNamed: name)
            }
            #elseif os(macOS)
            if let image = NSImage(contentsOf: url) {
                texture = SKTexture(image: image)
            } else {
                texture = SKTexture(imageNamed: name)
            }
            #endif
        } else {
            // The top-level High assets remain a compatibility fallback for
            // test hosts and older builds made before all five sets shipped.
            texture = SKTexture(imageNamed: name)
        }
        texture.filteringMode = .linear
        return texture
    }

    static func frameTexture(
        sheet name: String,
        frame: Int,
        columns: Int,
        rows: Int,
        setIndex: Int
    ) -> SKTexture {
        let sheet = texture(named: name, setIndex: setIndex)
        let column = frame % columns
        let rowFromTop = frame / columns
        let texture = SKTexture(
            rect: CGRect(
                x: CGFloat(column) / CGFloat(columns),
                y: CGFloat(rows - 1 - rowFromTop) / CGFloat(rows),
                width: 1 / CGFloat(columns),
                height: 1 / CGFloat(rows)
            ),
            in: sheet
        )
        texture.filteringMode = .linear
        return texture
    }

    static func commonFrameTexture(
        sheet name: String,
        frame: Int,
        columns: Int,
        rows: Int
    ) -> SKTexture {
        let sheet = commonTexture(named: name)
        let column = frame % columns
        let rowFromTop = frame / columns
        let texture = SKTexture(
            rect: CGRect(
                x: CGFloat(column) / CGFloat(columns),
                y: CGFloat(rows - 1 - rowFromTop) / CGFloat(rows),
                width: 1 / CGFloat(columns),
                height: 1 / CGFloat(rows)
            ),
            in: sheet
        )
        texture.filteringMode = .linear
        return texture
    }
}
