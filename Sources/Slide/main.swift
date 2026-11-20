import AppKit
import ServiceManagement
import SlideCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = Engine()
    private lazy var gestures = Gestures { [engine] steps in
        Task { @MainActor in engine.rotate(steps) }
    }
    private var clicker: NSStatusItem!
    private var pager: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard Launch.mayRun() else {
            NSApp.terminate(nil)
            return
        }
        // First launch only: sit at the right end, beside Control Center, where nothing hides them.
        UserDefaults.standard.register(defaults: [
            "NSStatusItem Preferred Position SlideClicker": 1,
            "NSStatusItem Preferred Position SlidePager": 2,
        ])
        clicker = statusItem("SlideClicker", image: Icons.mark, label: "Slide: rotate one slot")
        pager = statusItem("SlidePager", image: Icons.chevrons, label: "Slide: page back or forward")
        Task { await waitForAccess() }
    }

    private func statusItem(_ name: String, image: NSImage, label: String) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = name
        if let button = item.button {
            button.image = image
            button.setAccessibilityLabel(label)
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        return item
    }

    private func waitForAccess() async {
        let prompt = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(prompt)
        // The tap can only be created once access is granted.
        while !gestures.start() {
            try? await Task.sleep(for: .seconds(1))
        }
    }

    @objc private func clicked(_ button: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu(from: button)
        } else if !AXIsProcessTrusted() {
            openAccessibilitySettings()
        } else if button === pager.button {
            let x = button.convert(event.locationInWindow, from: nil).x
            engine.page(x < button.bounds.midX ? .backward : .forward)
        } else {
            engine.rotate(1)
        }
    }

    private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        if !AXIsProcessTrusted() {
            menu.addItem(item("Allow Accessibility Access…", #selector(openAccessibilitySettings)))
            menu.addItem(.separator())
        }
        menu.addItem(item("Rotate Forward", #selector(rotateForward)))
        menu.addItem(item("Rotate Back", #selector(rotateBack)))
        let hint = NSMenuItem(title: "Or hold ⌃⌥ and click or scroll the menu bar", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())
        menu.addItem(item("Page Arrows", #selector(togglePager), on: pager.isVisible))
        menu.addItem(item("Open at Login", #selector(toggleLogin), on: SMAppService.mainApp.status == .enabled))
        menu.addItem(.separator())
        menu.addItem(item("About Slide", #selector(about)))
        menu.addItem(item("Quit Slide", #selector(NSApplication.terminate), key: "q", target: NSApp))
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 6), in: button)
    }

    private func item(_ title: String, _ action: Selector, on: Bool = false, key: String = "", target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target ?? self
        item.state = on ? .on : .off
        return item
    }

    @objc private func rotateForward() { engine.rotate(1) }

    @objc private func rotateBack() { engine.rotate(-1) }

    @objc private func togglePager() { pager.isVisible.toggle() }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            try service.status == .enabled ? service.unregister() : service.register()
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @objc private func about() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

/// Decides whether this copy should run: never twice, and only knowingly beside another manager.
@MainActor
enum Launch {
    static func mayRun() -> Bool {
        let me = NSRunningApplication.current
        let twins = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        if twins.contains(where: { $0 != me }) {
            alert("Slide is already running", "It is in your menu bar. This copy will close.").runModal()
            return false
        }
        let others = Conflicts.names(running: NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let key = "IgnoreConflicts"
        guard !others.isEmpty, !UserDefaults.standard.bool(forKey: key) else { return true }
        let names = others.formatted()
        let alert = alert(
            "Another menu bar manager is running",
            "\(names) moves the same icons Slide does, and the two will fight over them. Quit \(names) for the smoothest ride."
        )
        alert.addButton(withTitle: "Run Anyway")
        alert.addButton(withTitle: "Quit Slide")
        alert.showsSuppressionButton = true
        let runAnyway = alert.runModal() == .alertFirstButtonReturn
        if runAnyway, alert.suppressionButton?.state == .on {
            UserDefaults.standard.set(true, forKey: key)
        }
        return runAnyway
    }

    private static func alert(_ message: String, _ info: String) -> NSAlert {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        return alert
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
