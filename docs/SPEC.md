# Slide: research and spec

## The problem

A Mac menu bar has fixed room. App menus take the left side, and on a MacBook the notch takes the middle. Status icons fill in from the right, and whatever does not fit is dropped: macOS gives no overflow indicator and no way to reach the dropped icons. On a 13-inch notched MacBook it takes only about a dozen icons before some vanish.

What people report, from Apple Community threads, TidBITS, and the issue trackers of the existing tools:

- **Icons disappear behind the notch with no sign they exist.** "When the icons are hidden behind the notch, they cannot be accessed." Apple has shipped no fix since the notch arrived in 2021.
- **People feel they are paying to fix an OS bug.** One user called paying for Bartender to work around a macOS bug "ridiculous".
- **The fixes are fiddly.** Bartender, Ice, Hidden Bar and their peers all work by hiding: you sort icons into "shown" and "hidden" sections, then toggle a section open to reach something. Finding one icon means opening a section, scanning it, and closing it again, and you have to maintain the sorting.
- **The fixes break with each macOS release.** On macOS 26 every status item window moved into Control Center's process, and Ice's issue tracker filled with move timeouts, empty layout screens and items snapping back. Tools that need Screen Recording access to draw their own copy of the bar add a second permission prompt, plus the privacy indicator that comes with it.
- **Trust.** Bartender was sold to a new owner in 2024 without notice, which pushed many users to open source alternatives.

## Competitors

| App | Price | How you reach hidden icons | Notes |
|---|---|---|---|
| Bartender | Paid | Hidden sections, a secondary bar, search, triggers | Most complete. Closed source, changed owner in 2024. |
| Ice / Thaw | Free, GPL | Hidden sections, "Ice Bar" panel under the menu bar, search | Thaw is the Tahoe-era fork. Large codebases (Thaw: hundreds of files). |
| Hidden Bar | Free | A divider you toggle | Simple, but hides rather than reveals; no notch handling. |
| Dozer, Vanilla | Free | A divider you toggle | Older, minimal. |
| PeekBar, iBar, Tuck, ChocolateBar | Paid / mixed | A floating panel or second row for icons hidden by the notch | Panels need Screen Recording to draw icon copies. |
| macOS 26 | Built in | System Settings > Menu Bar can switch items off | Removes icons; does not help reach them. |

Every one of them is built on the same idea: **hide some icons, then open a hiding place**. None of them treat the bar as what it is, a strip that is simply too short.

## The idea

Slide treats the menu bar as a carousel. Your icons form a ring; the bar shows as many as fit. Turn the ring and the next icon slides into view while the one at the far end slides out. Nothing is sorted, nothing is hidden on purpose, nothing pops up. Every icon is always one or two clicks away, in a real menu bar slot, behaving exactly as it normally does.

## Controls

Three ways to turn the ring, as asked:

1. **The clicker.** A small Slide icon at the right end of the bar. Click it and the ring turns one slot: the rightmost icon wraps to the far left, everything slides right, and the next hidden icon appears.
2. **Hold and click, or scroll.** Hold Control-Option and click anywhere on the menu bar to turn one slot per click. Scroll (or swipe sideways on a trackpad) with Control-Option held to turn one slot per notch, either way. These events are consumed, so the icon under the pointer never sees them.
3. **Page arrows.** A `‹ ›` item. Each half turns the ring by a whole screen (the number of icons currently visible), so you flip through the bar a page at a time.

Right-click either item for the menu: rotate back, show or hide the page arrows, open at login, about, quit.

## How it works

macOS lets a person rearrange menu bar icons by Command-dragging them. Slide does the same drag with synthesized events: one turn is one drag, from one end of the row to the other.

1. **Find the items.** Accessibility lists each app's menu bar items with their frames (`AXExtrasMenuBar`). Since macOS 26 every item window belongs to Control Center, so the window list cannot say whose item is whose; Accessibility can. Each item is matched to its window by frame, which gives the window ID the events must carry and whether the item is on screen. The clock and Control Center cannot move and are skipped.
2. **Plan the step** (pure, unit tested in `SlideCore`): forward moves the rightmost item to the left of the leftmost; backward does the reverse. A page is one step per visible item.
3. **Drag.** A Command mouse-down addressed to the item's window, then two mouse-ups at the drop point, posted both to the session and to the item's app. The cursor is put back afterwards.
4. **Verify.** Slide polls the window's position until the item lands on the requested side of its target. A drag that starts but does not land is retried from fresh positions; an item that ignores the drag entirely (a privacy indicator, say) is left out of the ring for the rest of the session.
5. **Queue.** Requests that arrive during a rotation join one signed counter, so a burst of scroll notches becomes one smooth run, and opposite requests cancel.

Permissions: **Accessibility only.** No Screen Recording, no network, no analytics.

## Running alongside other things

- **A second copy of Slide** (for example a local build next to the downloaded one) sees the first one running, says so, and quits.
- **Another menu bar manager** (Bartender, Ice, Thaw, Hidden Bar, Dozer, Vanilla) moves the same icons, and two movers fight. Slide warns at launch and offers to quit, with a "don't ask again" option.

## Distribution

- **Free:** a universal (Apple silicon and Intel) DMG on GitHub Releases, linked from the website. It is not notarized until there is a Developer ID, so the first launch needs System Settings > Privacy & Security > Open Anyway.
- **Paid:** the same app on the Mac App Store, once there is a developer account. The App Store sandbox restricts event posting and Accessibility, so the store build needs testing against review before it is promised.

## Requirements

macOS 14 or later. Built and tested on macOS 26.

## Out of scope for 1.0

Search, per-icon rules, icon groups, hotkey customisation, multiple-display page sizes. Each can be added when someone asks for it. The page size uses the display Accessibility reports, normally the one with the menu bar active.

## Sources

- [Apple Community: icons hidden behind the notch](https://discussions.apple.com/thread/253334703)
- [TidBITS: menu items behind the MacBook Pro notch](https://talk.tidbits.com/t/menu-items-behind-the-macbook-pro-notch/17215)
- [Michael Tsai: Bartender and the notch](https://mjtsai.com/blog/2022/01/18/bartender-and-the-notch)
- [MacRumors: six Bartender alternatives](https://www.macrumors.com/2024/06/06/alternatives-bartender-mac-menu-bar/)
- [Ice issue #1024: items revert after a drag on macOS 26](https://github.com/jordanbaird/Ice/issues/1024)
- [Ice issue #656: moves time out on macOS 26](https://github.com/jordanbaird/Ice/issues/656)
- [Thaw](https://github.com/thaw-app/Thaw)
- [PeekBar on Setapp](https://setapp.com/apps/peekbar)
