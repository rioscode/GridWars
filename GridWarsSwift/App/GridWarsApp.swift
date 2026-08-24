import SwiftUI

@main
struct GridWarsApp: App {
    var body: some Scene {
        WindowGroup("GridWars") {
            GameView()
                .background(Color.black)
        }
        #if os(macOS)
        .defaultSize(width: 1_024, height: 768)
        .windowResizability(.contentSize)
        #endif
    }
}
