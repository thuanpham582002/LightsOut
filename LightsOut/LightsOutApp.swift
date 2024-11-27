import SwiftUI
import CoreGraphics
import AppKit

@main
struct BlackOutApp: App {
    @StateObject private var viewModel = DisplaysViewModel()

    var body: some Scene {
        MenuBarExtra("LightsOut", systemImage: "display") {
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
