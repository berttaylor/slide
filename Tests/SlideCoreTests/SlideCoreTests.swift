import CoreGraphics
import Testing
@testable import SlideCore

private func item(_ key: String, x: CGFloat, width: CGFloat = 30, visible: Bool = true) -> BarItem {
    BarItem(key: key, pid: 1, frame: CGRect(x: x, y: 0, width: width, height: 24), windowID: 1, isVisible: visible)
}

private let row = [item("c", x: 100), item("a", x: 0, visible: false), item("b", x: 40, width: 50)]

@Suite struct CarouselTests {
    @Test func forwardWrapsRightmostToFarLeft() throws {
        let move = try #require(Carousel.step(row, .forward))
        #expect(move.item.key == "c")
        #expect(move.target.key == "a")
        #expect(move.side == .left)
    }

    @Test func backwardWrapsLeftmostToFarRight() throws {
        let move = try #require(Carousel.step(row, .backward))
        #expect(move.item.key == "a")
        #expect(move.target.key == "c")
        #expect(move.side == .right)
    }

    @Test func nothingToRotateWithFewerThanTwoItems() {
        #expect(Carousel.step([], .forward) == nil)
        #expect(Carousel.step([item("a", x: 0)], .backward) == nil)
    }

    @Test func pageIsTheVisibleCountButNeverZero() {
        #expect(Carousel.pageSize(row) == 2)
        #expect(Carousel.pageSize([item("a", x: 0, visible: false)]) == 1)
        #expect(Carousel.pageSize([]) == 1)
    }

    @Test func leftwardDragDropsOnTargetLeftEdge() throws {
        let move = try #require(Carousel.step(row, .forward))
        let points = Carousel.dragPoints(move)
        #expect(points.start == CGPoint(x: -1, y: 0))
        #expect(points.end == CGPoint(x: 0, y: 0))
    }

    @Test func rightwardDragDropsOneItemWidthShort() throws {
        let move = try #require(Carousel.step(row, .backward))
        let points = Carousel.dragPoints(move)
        #expect(points.start == CGPoint(x: 130, y: 0))
        #expect(points.end == CGPoint(x: 100, y: 0))
    }

    @Test func rightOfDragFromTheRightNudgesPastTheEdge() {
        let move = Move(item: item("z", x: 200), target: item("a", x: 0), side: .right)
        let points = Carousel.dragPoints(move)
        #expect(points.start == CGPoint(x: 31, y: 0))
        #expect(points.end == CGPoint(x: 30, y: 0))
    }

    @Test func leftOfDragFromTheLeftLandsOneWidthShort() {
        let move = Move(item: item("a", x: 0), target: item("z", x: 200), side: .left)
        let points = Carousel.dragPoints(move)
        #expect(points.start == CGPoint(x: 200, y: 0))
        #expect(points.end == CGPoint(x: 170, y: 0))
    }

    @Test func completionChecksTheRequestedSide() {
        let left = CGRect(x: 0, y: 0, width: 30, height: 24)
        let right = CGRect(x: 30, y: 0, width: 30, height: 24)
        #expect(Carousel.isComplete(.left, item: left, target: right))
        #expect(!Carousel.isComplete(.left, item: right, target: left))
        #expect(Carousel.isComplete(.right, item: right, target: left))
        #expect(!Carousel.isComplete(.right, item: left, target: right))
    }
}

@Suite struct StepQueueTests {
    @Test func drainsForwardThenStops() {
        var queue = StepQueue()
        queue.add(2)
        #expect(queue.next() == .forward)
        #expect(queue.next() == .forward)
        #expect(queue.next() == nil)
    }

    @Test func oppositeRequestsCancel() {
        var queue = StepQueue()
        queue.add(3)
        queue.add(-5)
        #expect(queue.pending == -2)
        #expect(queue.next() == .backward)
        queue.clear()
        #expect(queue.next() == nil)
    }
}

@Suite struct ScrollNotchesTests {
    @Test func wholeNotchesOnlyAndCarriesTheRemainder() {
        var notches = ScrollNotches(threshold: 40)
        #expect(notches.feed(30) == 0)
        #expect(notches.feed(30) == 1)
        #expect(notches.feed(70) == 2)
    }

    @Test func reversingDropsThePartialNotch() {
        var notches = ScrollNotches(threshold: 40)
        #expect(notches.feed(39) == 0)
        #expect(notches.feed(-39) == 0)
        #expect(notches.feed(-1) == -1)
    }

    @Test func zeroDeltaKeepsThePartialNotchEitherWay() {
        var notches = ScrollNotches(threshold: 40)
        #expect(notches.feed(-30) == 0)
        #expect(notches.feed(0) == 0)
        #expect(notches.feed(-30) == -1)
    }

    @Test func wheelLinesAreOneNotchEach() {
        var notches = ScrollNotches(threshold: 1)
        #expect(notches.feed(3) == 3)
        #expect(notches.feed(-1) == -1)
    }
}

@Suite struct ConflictsTests {
    @Test func namesKnownManagersOnce() {
        let running = ["com.apple.finder", "com.jordanbaird.Ice", "com.surteesstudios.Bartender", "com.surteesstudios.Bartender-setapp"]
        #expect(Conflicts.names(running: running) == ["Bartender", "Ice"])
        #expect(Conflicts.names(running: ["com.apple.finder"]).isEmpty)
    }
}
