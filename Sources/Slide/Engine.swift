import AppKit
import SlideCore

/// Runs rotation requests one move at a time. Requests that arrive mid-rotation
/// join the queue, so a burst of clicks or scroll notches turns into one smooth run.
@MainActor
final class Engine {
    private let bar = Bar()
    private var queue = StepQueue()
    private var isRunning = false

    func rotate(_ steps: Int) {
        queue.add(steps)
        guard !isRunning else { return }
        isRunning = true
        Task {
            while let direction = queue.next() {
                guard await step(direction) else {
                    queue.clear()
                    NSSound.beep()
                    break
                }
            }
            isRunning = false
        }
    }

    func page(_ direction: Direction) {
        let size = Carousel.pageSize(bar.items())
        rotate(direction == .forward ? size : -size)
    }

    /// Each attempt plans from fresh positions. An item that ignores the drag entirely is left
    /// alone for the rest of the session; a drag that started but did not land is just retried.
    private func step(_ direction: Direction) async -> Bool {
        for _ in 0..<3 {
            guard let move = Carousel.step(bar.items(), direction) else { return false }
            switch await Mover.perform(move) {
            case .moved: return true
            case .ignored: bar.immovable.insert(move.item.key)
            case .unfinished: continue
            }
        }
        return false
    }
}

/// Moves an item the way a person does: a Command-drag, synthesized.
@MainActor
enum Mover {
    enum Outcome { case moved, ignored, unfinished }

    /// Marks Slide's own events so its event tap lets them through.
    nonisolated static let tag: Int64 = 0x534C_4944_45
    /// Not public API: the window an event is addressed to. The event sequence follows the one
    /// Ice uses on macOS 26 (github.com/jordanbaird/Ice, MenuBarItemManager).
    private static let windowField = CGEventField(rawValue: 0x33)!

    static func perform(_ move: Move) async -> Outcome {
        let item = move.item.windowID
        let target = move.target.windowID
        guard let source = CGEventSource(stateID: .hidSystemState) else { return .unfinished }

        let cursor = CGEvent(source: nil)?.location
        defer { if let cursor { CGWarpMouseCursorPosition(cursor) } }
        allowUserInputDuringMove()

        let (start, end) = Carousel.dragPoints(move)
        let pid = move.item.pid
        guard let down = event(.leftMouseDown, at: start, window: item, flags: .maskCommand, pid: pid, source: source),
              let up = event(.leftMouseUp, at: end, window: target, flags: [], pid: pid, source: source)
        else { return .unfinished }

        let origin = Bar.frame(of: item)?.origin
        post(down, to: pid)
        let lifted = await poll { Bar.frame(of: item)?.origin != origin }
        // A second mouse up keeps the item from staying attached to the drag.
        post(up, to: pid)
        post(up, to: pid)
        guard lifted else { return .ignored }
        let landed = await poll {
            guard let itemFrame = Bar.frame(of: item), let targetFrame = Bar.frame(of: target) else { return false }
            return Carousel.isComplete(move.side, item: itemFrame, target: targetFrame)
        }
        return landed ? .moved : .unfinished
    }

    private static func event(
        _ type: CGEventType, at point: CGPoint, window: CGWindowID, flags: CGEventFlags, pid: pid_t, source: CGEventSource
    ) -> CGEvent? {
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
        else { return nil }
        event.flags = flags
        for field in [CGEventField.mouseEventWindowUnderMousePointer, .mouseEventWindowUnderMousePointerThatCanHandleThisEvent, windowField] {
            event.setIntegerValueField(field, value: Int64(window))
        }
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(pid))
        event.setIntegerValueField(.eventSourceUserData, value: tag)
        return event
    }

    /// The window server routes the drag; the owning app needs to see it too.
    private static func post(_ event: CGEvent, to pid: pid_t) {
        event.post(tap: .cgSessionEventTap)
        event.postToPid(pid)
    }

    /// Synthetic events otherwise mute the real mouse and keyboard for a moment.
    private static func allowUserInputDuringMove() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let all: CGEventFilterMask = [.permitLocalMouseEvents, .permitLocalKeyboardEvents, .permitSystemDefinedEvents]
        source.setLocalEventsFilterDuringSuppressionState(all, state: .eventSuppressionStateRemoteMouseDrag)
        source.setLocalEventsFilterDuringSuppressionState(all, state: .eventSuppressionStateSuppressionInterval)
        source.localEventsSuppressionInterval = 0
    }

    private static func poll(timeout: Duration = .milliseconds(500), _ done: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if done() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return done()
    }
}
