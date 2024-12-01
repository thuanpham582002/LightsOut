import SwiftUI
import CoreGraphics
import AppKit
import Sparkle

@main
struct LightsOutApp: App {
    @StateObject private var viewModel = DisplaysViewModel()
    
    var body: some Scene {
        MenuBarExtra("LightsOut", image: "MenubarIcon") {
            MenuBarView()
                .environmentObject(viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(DisplaysViewModel())
}
