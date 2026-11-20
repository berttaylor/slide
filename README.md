<p align="center"><img src="docs/icon.png" width="128" alt="Slide icon"></p>

<h1 align="center">Slide</h1>

<p align="center">Your menu bar, on a carousel.<br>Every icon one click away, even the ones behind the notch.</p>

<p align="center"><a href="https://github.com/berttaylor/slide/releases/latest/download/Slide.dmg"><b>Download Slide.dmg</b></a> · <a href="https://berttaylor.github.io/slide/">Website</a> · <a href="docs/SPEC.md">How it works</a></p>

---

When the menu bar runs out of room, macOS drops icons with no way to reach them. Other tools make you sort icons into hidden sections and open them. Slide turns the bar instead: your icons form a ring, and each turn slides the next one into view.

- **Click the Slide icon** to turn one slot.
- **Hold ⌃⌥ and click or scroll** anywhere on the menu bar to turn one slot at a time, either way.
- **Click `‹` or `›`** to turn a whole screen at once.

Right-click either Slide icon for the menu. Slide needs Accessibility access and nothing else: no Screen Recording, no network.

## Install

1. Download [Slide.dmg](https://github.com/berttaylor/slide/releases/latest/download/Slide.dmg) and drag Slide to Applications.
2. Open it. macOS will refuse the first time because Slide is not notarized yet: open **System Settings > Privacy & Security** and click **Open Anyway**.
3. Allow Slide under **Privacy & Security > Accessibility** when asked.

Requires macOS 14 or later. Universal: Apple silicon and Intel.

**After updating**, macOS may keep showing Slide as allowed under Accessibility while ignoring it, because unnotarized builds get a new identity each release. Select Slide in that list, remove it with **−**, and open Slide again to re-allow it. This goes away once Slide is signed with a Developer ID.

## Build

Needs the Xcode Command Line Tools (`xcode-select --install`).

```sh
make test   # unit tests
make run    # build build/Slide.app and open it
make dmg    # build build/Slide.dmg
```

Ad-hoc signed builds change identity each time, so macOS forgets the Accessibility grant after a rebuild: remove Slide from the Accessibility list and open it again.

Pushing a `v*` tag builds the DMG on GitHub Actions and attaches it to a release.

## Layout

| Path | What |
|---|---|
| `Sources/SlideCore` | Pure logic: the carousel, step queue, scroll notches, conflicts. Unit tested. |
| `Sources/Slide` | The app: status items and menu, reading the bar, synthesizing the drag, the ⌃⌥ gesture. |
| `docs/` | The website (GitHub Pages) and [the spec](docs/SPEC.md). |

## License

MIT
