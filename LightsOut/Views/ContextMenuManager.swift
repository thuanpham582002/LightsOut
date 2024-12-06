//
//  ContextMenuManager.swift
//  LightsOut
//

import AppKit
import Sparkle

class ContextMenuManager {
    private let updateController: SPUUpdater
    private weak var statusItem: NSStatusItem?

    init(updateController: SPUUpdater, statusItem: NSStatusItem) {
        self.updateController = updateController
        self.statusItem = statusItem
    }

    func showContextMenu() {
        guard let statusItem = statusItem else { return }
        
        let menu = NSMenu()

        // Check for Updates
        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = self
        menu.addItem(checkForUpdatesItem)

        // Automatic Updates Toggle Item
        let autoUpdatesOn = updateController.automaticallyChecksForUpdates
        let statusString = autoUpdatesOn ? " On" : " Off"
        let statusColor = autoUpdatesOn ? NSColor.systemGreen : NSColor.systemRed
        let attributedTitle = NSMutableAttributedString(string: "Automatic Update Checks:")
        let statusAttr = NSAttributedString(string: statusString, attributes: [.foregroundColor: statusColor])
        attributedTitle.append(statusAttr)

        let autoUpdateItem = NSMenuItem()
        autoUpdateItem.attributedTitle = attributedTitle
        autoUpdateItem.action = #selector(toggleAutomaticUpdates)
        autoUpdateItem.target = self
        menu.addItem(autoUpdateItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        menu.addItem(NSMenuItem(
            title: "Quit LightsOut",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleAutomaticUpdates() {
        updateController.automaticallyChecksForUpdates.toggle()
    }

    @objc func checkForUpdates() {
        updateController.checkForUpdates()
    }
}
