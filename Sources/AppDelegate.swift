import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel?
    let model = RenameModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        model.loadSettingsFromDefaults()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "character.cursor.ibeam", accessibilityDescription: "RenameIt")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePanel(_:))
        }

        NSEvent.addGlobalMonitorForEvents(matching: [.rightMouseUp]) { [weak self] event in
            Task { @MainActor in
                if let button = self?.statusItem.button,
                   let window = button.window,
                   event.window == window {
                    self?.showContextMenu()
                }
            }
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open RenameIt", action: #selector(openPanel), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openPanel() {
        togglePanel(nil)
    }

    @objc private func quitApp() {
        model.saveSettingsToDefaults()
        NSApplication.shared.terminate(nil)
    }

    @objc private func togglePanel(_ sender: Any?) {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }

        if let existing = panel {
            positionPanel(existing)
            existing.orderFront(nil)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 740),
            styleMask: [.titled, .closable, .utilityWindow, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "RenameIt"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 400, height: 500)

        let hostingView = NSHostingController(
            rootView: RenameView(model: model) { [weak self] in
                self?.panel?.orderOut(nil)
            }
        )
        panel.contentViewController = hostingView

        panel.delegate = self

        if let savedFrame = UserDefaults.standard.string(forKey: "RenameIt.panelFrame") {
            panel.setFrameOrigin(NSPoint(x: 0, y: 0))
            panel.setFrame(NSRectFromString(savedFrame), display: true)
        } else {
            positionPanel(panel)
        }

        panel.orderFront(nil)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    private func positionPanel(_ panel: NSPanel) {
        if let button = statusItem.button, let window = button.window {
            var point = window.convertPoint(toScreen: NSPoint(x: button.bounds.midX, y: button.bounds.minY))
            point.x -= panel.frame.width / 2
            point.y -= panel.frame.height
            if point.y < 0 { point.y = 0 }
            panel.setFrameOrigin(point)
        } else {
            panel.center()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.saveSettingsToDefaults()
        if let panel, panel.isVisible {
            UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "RenameIt.panelFrame")
        }
        return .terminateNow
    }
}

extension AppDelegate: NSWindowDelegate {
    nonisolated func windowDidResize(_ notification: Notification) {
        MainActor.assumeIsolated {
            savePanelFrame()
        }
    }

    nonisolated func windowDidMove(_ notification: Notification) {
        MainActor.assumeIsolated {
            savePanelFrame()
        }
    }

    private func savePanelFrame() {
        if let panel {
            UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "RenameIt.panelFrame")
        }
    }
}
