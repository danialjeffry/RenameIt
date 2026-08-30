import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel?
    let model = RenameModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "character.cursor.ibeam", accessibilityDescription: "RenameIt")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePanel(_:))
        }
    }

    @objc private func togglePanel(_ sender: Any?) {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
            styleMask: [.titled, .closable, .utilityWindow, .hudWindow, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "RenameIt"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        let hostingView = NSHostingController(
            rootView: RenameView(model: model) { [weak self] in
                self?.panel?.orderOut(nil)
            }
        )
        panel.contentViewController = hostingView

        if let button = statusItem.button, let window = button.window {
            var point = window.convertPoint(toScreen: NSPoint(x: button.bounds.midX, y: button.bounds.minY))
            point.x -= panel.frame.width / 2
            point.y -= panel.frame.height
            panel.setFrameOrigin(point)
        } else {
            panel.center()
        }

        panel.orderFront(nil)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }
}
