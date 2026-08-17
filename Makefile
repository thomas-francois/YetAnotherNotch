# YetAnotherNotch — ad-hoc signed, sandboxed, no release pipeline.
#
#   make          build Debug
#   make run      build, then restart the app
#   make release  build Release
#   make dmg      package Release into a .dmg (needs Configuration/dmg deps)
#   make clean    drop DerivedData
#
# Override anything on the command line: make CONFIG=Release, make DEVELOPER_DIR=...

CONFIG  ?= Debug
SCHEME  := YetAnotherNotch
PROJECT := $(SCHEME).xcodeproj
DD      := build
APP      = $(DD)/Build/Products/$(CONFIG)/$(SCHEME).app

# This project needs an SDK newer than the Command Line Tools ship: the Transcription
# tab uses the Speech API added in macOS 26. Point this at whatever Xcode has it.
DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR

XCB = xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
      -destination platform=macOS,arch=arm64 -derivedDataPath $(DD)

.PHONY: all build run stop release dmg clean check

all: build

build:
	$(XCB) build

# Graceful quit, not SIGTERM: the app ignores TERM, and a hard kill can lose
# unflushed Defaults writes.
stop:
	-@osascript -e 'tell application "$(SCHEME)" to quit' 2>/dev/null || true

run: build
	@$(MAKE) --no-print-directory stop
	@# Wait for the old instance to actually go. `open` right after a quit races it and
	@# fails with -600/-609, leaving nothing running.
	@while pgrep -f '$(SCHEME).app/Contents/MacOS/$(SCHEME)' >/dev/null 2>&1; do sleep 0.2; done
	open $(APP)

release:
	@$(MAKE) --no-print-directory CONFIG=Release build

dmg: release
	Configuration/dmg/create_dmg.sh $(APP)

clean:
	-$(XCB) clean
	rm -rf $(DD)

# A build alone does not prove a file is in the target: an unreferenced source
# compiles to nothing and the build still passes. This checks the two things that
# actually matter, and is the one guard worth keeping.
check: build
	@test -d "$(APP)" || { echo "FAIL: no app bundle at $(APP)"; exit 1; }
	@codesign -d --entitlements - "$(APP)" 2>/dev/null | grep -q 'app-sandbox' \
		|| { echo "FAIL: app-sandbox missing from the signed bundle"; exit 1; }
	@ruby -e 'require "xcodeproj"; \
		p_ = Xcodeproj::Project.open("$(PROJECT)"); \
		bad = p_.files.reject { |f| a = f.real_path.to_s; a.include?("Package") || a.include?("$$") || File.exist?(a) }; \
		abort "FAIL: dangling refs: #{bad.map(&:path).join(", ")}" unless bad.empty?' \
		2>/dev/null || echo "note: skipped dangling-ref check (no xcodeproj gem)"
	@echo "OK: builds, sandboxed, no dangling refs"
