import AppKit
import SlideCore

/// Reads the menu bar's items through Accessibility and pairs each with its window.
///
/// Since macOS 26 every item window belongs to Control Center, so the window list alone
/// cannot say whose item is whose. Accessibility can: each app lists its own items.
@MainActor
final class Bar {
    struct Window {
        let id: CGWindowID
        let frame: CGRect
        let isOnScreen: Bool
    }

    /// Items that cannot move, by identifier: the clock and Control Center, plus any item
    /// that refused a drag this session, such as a privacy indicator.
    var immovable: Set<String> = ["com.apple.menuextra.clock", "com.apple.menuextra.controlcenter"]

    /// Apps known to own items, so a step does not query every running process.
    private var owners: [pid_t]?
    private var windowIDs: Set<CGWindowID> = []

    init() {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.1)
    }

    /// The items Slide can move right now, excluding its own.
    func items() -> [BarItem] {
        let windows = Self.windows()
        // Any item appearing or leaving may belong to an app not yet known as an owner.
        let ids = Set(windows.map(\.id))
        if ids != windowIDs {
            owners = nil
            windowIDs = ids
        }
        var found: [pid_t] = []
        var items: [BarItem] = []
        for pid in owners ?? NSWorkspace.shared.runningApplications.map(\.processIdentifier) where pid != getpid() {
            let extras = Self.extras(of: pid)
            if !extras.isEmpty { found.append(pid) }
            for (index, element) in extras.enumerated() {
                // Prefer stable names; an item's index shifts when its app adds or drops one.
                let name: String? = Self.value(element, kAXDescriptionAttribute) ?? Self.value(element, kAXTitleAttribute)
                let key = Self.value(element, kAXIdentifierAttribute) ?? "\(pid)/\(name ?? String(index))"
                guard !immovable.contains(key),
                      let frame = Self.frame(of: element),
                      let window = windows.first(where: { Self.matches($0.frame, frame) })
                else { continue }
                items.append(BarItem(key: key, pid: pid, frame: frame, windowID: window.id, isVisible: window.isOnScreen))
            }
        }
        // Only a full scan defines the owners: a cached app that answered slowly this
        // time keeps its place for the next step.
        if owners == nil { owners = found }
        return items
    }

    static func frame(of window: CGWindowID) -> CGRect? {
        let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, window) as? [[String: Any]]
        return info?.first.flatMap(bounds)
    }

    private static func windows() -> [Window] {
        let info = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        let level = Int(CGWindowLevelForKey(.statusWindow))
        return info.compactMap { window in
            guard window[kCGWindowLayer as String] as? Int == level,
                  let id = window[kCGWindowNumber as String] as? CGWindowID,
                  let frame = bounds(window)
            else { return nil }
            return Window(id: id, frame: frame, isOnScreen: window[kCGWindowIsOnscreen as String] as? Bool ?? false)
        }
    }

    private static func bounds(_ window: [String: Any]) -> CGRect? {
        guard let bounds = window[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: bounds)
    }

    private static func matches(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 2 && abs(a.minY - b.minY) < 2 && abs(a.width - b.width) < 2
    }

    private static func extras(of pid: pid_t) -> [AXUIElement] {
        guard let bar: AXUIElement = value(AXUIElementCreateApplication(pid), kAXExtrasMenuBarAttribute) else { return [] }
        return value(bar, kAXChildrenAttribute) ?? []
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let position: AXValue = value(element, kAXPositionAttribute),
              let size: AXValue = value(element, kAXSizeAttribute)
        else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &origin), AXValueGetValue(size, .cgSize, &extent) else { return nil }
        return CGRect(origin: origin, size: extent)
    }

    private static func value<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
