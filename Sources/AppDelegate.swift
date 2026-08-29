import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    let model = RenameModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "character.cursor.ibeam", accessibilityDescription: "RenameIt")
            button.imagePosition = .imageLeading
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 520, height: 620)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: RenameView(model: model) { [weak self] in
                self?.togglePopover()
            }
        )

        statusItem.button?.action = #selector(togglePopover(_:))
    }

    @objc private func togglePopover(_ sender: Any?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    private func togglePopover() {
        if let button = statusItem.button {
            togglePopover(button)
        }
    }
}
