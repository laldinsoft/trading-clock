.PHONY: all build run test install release icon sounds speech clean

all: build

## Build dist/Trading Clock.app (universal). ARCH=host for a quicker single-arch build.
build:
	TRADING_CLOCK_ARCHS=$(or $(ARCH),universal) ./scripts/build.sh

## Build and launch.
run: build
	open "dist/Trading Clock.app"

## Unit tests for the calendar, sessions, events and range logic.
test:
	swift test

## Copy the built app into /Applications.
install: build
	rm -rf "/Applications/Trading Clock.app"
	cp -R "dist/Trading Clock.app" /Applications/
	@echo "Installed. Open it from Applications, then enable Launch at Login from its menu."

## Build, sign with Developer ID, notarize, and wrap in dist/TradingClock.dmg.
release:
	./scripts/release.sh

## Redraw the app icon into Resources/AppIcon.icns and docs/icon.png.
icon:
	./icon/build-icns.sh

## Re-render the chimes with SuperCollider.
sounds:
	./sounds/render.sh

## Re-render the spoken phrases (needs the laldinsoft-studio TTS tool).
speech:
	./sounds/speak.sh

clean:
	rm -rf .build dist sounds/out icon/out
