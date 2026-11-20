VERSION ?= $(or $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//'),0.0.0)
APP     := build/Slide.app
DMG     := build/Slide.dmg

# Command Line Tools ship Swift Testing outside the default search paths; Xcode does not need this.
DEV := /Library/Developer/CommandLineTools/Library/Developer
ifeq ($(shell xcode-select -p),/Library/Developer/CommandLineTools)
TEST_FLAGS := -Xswiftc -F$(DEV)/Frameworks -Xlinker -F$(DEV)/Frameworks \
	-Xlinker -rpath -Xlinker $(DEV)/Frameworks -Xlinker -rpath -Xlinker $(DEV)/usr/lib
endif

.PHONY: test app dmg run clean

test:
	swift test $(TEST_FLAGS)

app:
	swift build -c release --triple arm64-apple-macosx14.0
	swift build -c release --triple x86_64-apple-macosx14.0
	rm -rf $(APP) && mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	lipo -create -output $(APP)/Contents/MacOS/Slide \
		.build/arm64-apple-macosx/release/Slide .build/x86_64-apple-macosx/release/Slide
	sed 's/$$(VERSION)/$(VERSION)/g' Resources/Info.plist > $(APP)/Contents/Info.plist
	swift scripts/icon.swift build/AppIcon.iconset
	iconutil -c icns build/AppIcon.iconset -o $(APP)/Contents/Resources/AppIcon.icns
	codesign --force --sign - $(APP)

dmg: app
	rm -rf build/dmg $(DMG) && mkdir build/dmg
	cp -R $(APP) build/dmg/ && ln -s /Applications build/dmg/Applications
	hdiutil create -volname Slide -srcfolder build/dmg -fs HFS+ -format UDZO -ov $(DMG)

run: app
	pkill -x Slide || true
	open $(APP)

clean:
	rm -rf .build build
