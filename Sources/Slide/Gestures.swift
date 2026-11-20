import AppKit
import os
import SlideCore

/// Hold Control-Option over the menu bar: click turns the carousel one slot, scrolling turns it
/// one slot per notch. Those events are consumed, so the item under the pointer never sees them.
///
/// The tap runs on its own thread: it sees every click and scroll on the system, and must
/// never wait behind the main thread's Accessibility work.
final class Gestures: @unchecked Sendable {
    private let onRotate: @Sendable (Int) -> Void
    /// Menu bar strips in display coordinates, one per screen. Written on main, read on the tap thread.
    private let strips = OSAllocatedUnfairLock<[CGRect]>(initialState: [])
    private var tap: CFMachPort?

    // Touched only on the tap thread.
    private var swallowingClick = false
    private var wheel = ScrollNotches(threshold: 1)
    private var trackpad = ScrollNotches(threshold: 40)

    init(onRotate: @escaping @Sendable (Int) -> Void) {
        self.onRotate = onRotate
    }

    /// Needs Accessibility access; returns false while the tap cannot be created.
    @MainActor
    func start() -> Bool {
        let types: [CGEventType] = [.leftMouseDown, .leftMouseUp, .scrollWheel]
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: types.reduce(CGEventMask(0)) { $0 | 1 << $1.rawValue },
            callback: tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap
        updateStrips()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.updateStrips() } }
        nonisolated(unsafe) let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        Thread {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CFRunLoopRun()
        }.start()
        return true
    }

    @MainActor
    private func updateStrips() {
        let screens = NSScreen.screens
        let fallback = NSStatusBar.system.thickness
        let everyScreenHasABar = NSScreen.screensHaveSeparateSpaces
        let rects: [CGRect] = screens.enumerated().compactMap { index, screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            else { return nil }
            let display = CGDisplayBounds(id)
            var height = screen.frame.maxY - screen.visibleFrame.maxY
            // An auto-hidden menu bar leaves visibleFrame full height. Without separate
            // Spaces, only the first screen has a menu bar at all.
            if height <= 0 {
                guard everyScreenHasABar || index == 0 else { return nil }
                height = fallback
            }
            return CGRect(x: display.minX, y: display.minY, width: display.width, height: height)
        }
        strips.withLock { $0 = rects }
    }

    fileprivate func consumes(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if event.getIntegerValueField(.eventSourceUserData) == Mover.tag { return false }
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // The mouse up may have slipped past while the tap was off.
            swallowingClick = false
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .leftMouseUp where swallowingClick:
            swallowingClick = false
            return true
        case .leftMouseDown where isGesture(event):
            swallowingClick = true
            onRotate(1)
            return true
        case .scrollWheel where isGesture(event):
            let steps = notches(event)
            if steps != 0 { onRotate(steps) }
            return true
        default:
            return false
        }
    }

    /// Exactly Control-Option: adding Command or Shift means the user wants something else.
    private func isGesture(_ event: CGEvent) -> Bool {
        let held = event.flags.intersection([.maskControl, .maskAlternate, .maskCommand, .maskShift])
        guard held == [.maskControl, .maskAlternate] else { return false }
        let point = event.location
        return strips.withLock { $0.contains { $0.contains(point) } }
    }

    /// Wheels report whole lines; trackpads report points. Either axis works, so a
    /// sideways swipe turns the bar the way it looks like it should.
    private func notches(_ event: CGEvent) -> Int {
        // Momentum after the fingers lift would keep the bar spinning.
        guard event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0 else { return 0 }
        let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let (vertical, horizontal) = continuous
            ? (event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1), event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2))
            : (Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1)), Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2)))
        let delta = vertical != 0 ? vertical : horizontal
        return continuous ? trackpad.feed(delta) : wheel.feed(delta)
    }
}

/// Outside any actor: a closure written inside `start()` would inherit its main-actor isolation,
/// and Swift traps when the tap thread calls it.
private func tapCallback(
    _: CGEventTapProxy, type: CGEventType, event: CGEvent, gestures: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let gestures = Unmanaged<Gestures>.fromOpaque(gestures!).takeUnretainedValue()
    return gestures.consumes(type, event) ? nil : Unmanaged.passUnretained(event)
}
