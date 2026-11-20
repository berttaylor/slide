import CoreGraphics

/// A menu bar item as Slide sees it: who owns it, where it is, and whether it is on screen.
public struct BarItem: Equatable, Sendable {
    public let key: String
    public let pid: pid_t
    public let frame: CGRect
    public let windowID: CGWindowID
    public let isVisible: Bool

    public init(key: String, pid: pid_t, frame: CGRect, windowID: CGWindowID, isVisible: Bool) {
        self.key = key
        self.pid = pid
        self.frame = frame
        self.windowID = windowID
        self.isVisible = isVisible
    }
}

public enum Direction: Sendable {
    /// The rightmost item wraps around to the far left, so everything slides right
    /// and the next hidden item comes into view.
    case forward
    /// The leftmost item wraps around to the far right, so everything slides left.
    case backward
}

/// One Command-drag: put `item` on `side` of `target`.
public struct Move: Equatable, Sendable {
    public enum Side: Sendable { case left, right }

    public let item: BarItem
    public let target: BarItem
    public let side: Side
}

/// The menu bar as a ring: one move per step, whichever way it turns.
public enum Carousel {
    public static func step(_ items: [BarItem], _ direction: Direction) -> Move? {
        let byX: (BarItem, BarItem) -> Bool = { $0.frame.minX < $1.frame.minX }
        guard let first = items.min(by: byX), let last = items.max(by: byX), first != last else { return nil }
        return switch direction {
        case .forward: Move(item: last, target: first, side: .left)
        case .backward: Move(item: first, target: last, side: .right)
        }
    }

    /// How many steps replace what is on screen: one per visible item.
    public static func pageSize(_ items: [BarItem]) -> Int {
        max(1, items.count { $0.isVisible })
    }

    /// Where the drag starts and is dropped. The system places a dragged item by the drop
    /// point's distance from the target's edge, so a rightward drag lands one width short.
    public static func dragPoints(_ move: Move) -> (start: CGPoint, end: CGPoint) {
        let item = move.item.frame
        let target = move.target.frame
        var start: CGPoint
        var end: CGPoint
        switch move.side {
        case .left:
            start = CGPoint(x: target.minX, y: target.minY)
            end = start
            if item.maxX <= target.minX { end.x -= item.width } else { start.x -= 1 }
        case .right:
            start = CGPoint(x: target.maxX, y: target.minY)
            end = start
            if item.minX <= target.maxX { end.x -= item.width } else { start.x += 1 }
        }
        return (start, end)
    }

    /// Whether the moved item now sits on the requested side of its target.
    public static func isComplete(_ side: Move.Side, item: CGRect, target: CGRect) -> Bool {
        switch side {
        case .left: item.maxX <= target.minX
        case .right: item.minX >= target.maxX
        }
    }
}

/// Requested steps that have not run yet, as one signed count: forward is positive.
/// Opposite requests cancel out instead of queueing pointless round trips.
public struct StepQueue: Sendable {
    public private(set) var pending = 0

    public init() {}

    public mutating func add(_ steps: Int) { pending += steps }

    public mutating func clear() { pending = 0 }

    public mutating func next() -> Direction? {
        if pending > 0 { pending -= 1; return .forward }
        if pending < 0 { pending += 1; return .backward }
        return nil
    }
}

/// Turns a stream of scroll deltas into whole notches. Reversing direction drops
/// the partial notch so the carousel never moves against the finger.
public struct ScrollNotches: Sendable {
    private let threshold: Double
    private var sum = 0.0

    public init(threshold: Double) { self.threshold = threshold }

    public mutating func feed(_ delta: Double) -> Int {
        guard delta != 0 else { return 0 }
        if sum != 0, (sum < 0) != (delta < 0) { sum = 0 }
        sum += delta
        let notches = Int(sum / threshold)
        sum -= Double(notches) * threshold
        return notches
    }
}
