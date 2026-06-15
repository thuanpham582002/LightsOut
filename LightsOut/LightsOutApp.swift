import SwiftUI
import AppKit
import Sparkle

@main
struct LightsOutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var eventMonitor: Any?
    let displaysViewModel = DisplaysViewModel()
    var updateController: SPUStandardUpdaterController!
    var contextMenuManager: ContextMenuManager!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        popover = NSPopover()
        popover.behavior = .applicationDefined
        
        // Set up the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(named: "menubarIcon")
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover.isShown == true {
                self?.popover.performClose(nil)
            }
        }
        
        updateController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        
//        #if !DEBUG
        if updateController.updater.automaticallyChecksForUpdates {
            updateController.updater.checkForUpdatesInBackground()
        }
//        #endif
        
        contextMenuManager = ContextMenuManager(updateController: updateController.updater, statusItem: statusItem)
    }

    @objc func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            contextMenuManager.showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            let contentView = MenuBarView().environmentObject(displaysViewModel)
            popover.contentViewController = NSHostingController(rootView: contentView)

            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                
                // Ensure the app and popover window become active
                NSApp.activate(ignoringOtherApps: true)
                popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
                popover.contentViewController?.view.window?.makeFirstResponder(popover.contentViewController?.view)
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "lightsout" {
            handle(url: url)
        }
    }

    private func handle(url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let idParam = components?.queryItems?.first(where: { $0.name == "id" })?.value

        switch url.host {
        // UI control
        case "toggle", nil:
            if let button = statusItem?.button { togglePopover(button) }
        case "menu":
            contextMenuManager.showContextMenu()
        case "close":
            if popover.isShown { popover.performClose(nil) }

        // Display control
        case "disconnect":
            forEachTargetedDisplay(idParam) { try self.displaysViewModel.disconnectDisplay(display: $0) }
        case "disable":
            forEachTargetedDisplay(idParam) { try self.displaysViewModel.disableDisplay(display: $0) }
        case "enable":
            forEachTargetedDisplay(idParam) { try self.displaysViewModel.turnOnDisplay(display: $0) }
        case "toggle-display":
            forEachTargetedDisplay(idParam) { display in
                if display.state.isOff() {
                    try self.displaysViewModel.turnOnDisplay(display: display)
                } else {
                    try self.displaysViewModel.disconnectDisplay(display: display)
                }
            }
        case "reset":
            displaysViewModel.resetAllDisplays()
        case "recover":
            displaysViewModel.forceRecovery()
        case "refresh":
            displaysViewModel.fetchDisplays()
        case "list":
            writeDisplayList()

        default:
            break
        }
    }

    /// Writes the current display list (id, name, state, primary) as JSON to
    /// the sandbox container's Data directory so external scripts can read it:
    ///   ~/Library/Containers/Steelworks.LightsOut/Data/lightsout-displays.json
    private func writeDisplayList() {
        displaysViewModel.fetchDisplays()

        let payload = displaysViewModel.displays.map { display -> [String: Any] in
            let stateString: String
            switch display.state {
            case .active:       stateString = "active"
            case .mirrored:     stateString = "mirrored"
            case .disconnected: stateString = "disconnected"
            case .pending:      stateString = "pending"
            }
            return [
                "id": display.id,
                "name": display.name,
                "state": stateString,
                "isPrimary": display.isPrimary
            ]
        }

        let url = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("lightsout-displays.json")
        do {
            let data = try JSONSerialization.data(withJSONObject: payload,
                                                  options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
            print("LightsOut wrote display list to \(url.path)")
        } catch {
            print("LightsOut failed to write display list: \(error)")
        }
    }

    /// Resolves the `id` query parameter to one or more displays and runs
    /// `action` against each. `id` may be a specific `CGDirectDisplayID`, or
    /// `"all"`/`nil` to target every known display. Errors are swallowed so a
    /// single failing display does not abort the batch.
    private func forEachTargetedDisplay(_ idParam: String?, action: @escaping (DisplayInfo) throws -> Void) {
        displaysViewModel.fetchDisplays()

        let targets: [DisplayInfo]
        if let idParam, idParam.lowercased() != "all", let id = CGDirectDisplayID(idParam) {
            targets = displaysViewModel.displays.filter { $0.id == id }
        } else {
            targets = displaysViewModel.displays
        }

        for display in targets {
            do {
                try action(display)
            } catch {
                print("LightsOut URL command failed for '\(display.name)': \(error)")
            }
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(DisplaysViewModel())
}
