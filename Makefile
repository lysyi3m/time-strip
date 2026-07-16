# Time Strip — common tasks.
# Requires: xcodegen (all targets).  brew install xcodegen

PROJECT    := Time Strip.xcodeproj
SCHEME     := Time Strip
APP        := build/Build/Products/Release/$(SCHEME).app
INSTALLED  := /Applications/$(SCHEME).app
WIDGET_ID  := com.mlkshkvch.timestrip.widget
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.DEFAULT_GOAL := help
.PHONY: help generate test build install uninstall clean

help: ## List available targets
	@grep -E '^[a-z][a-zA-Z-]*:.*##' $(MAKEFILE_LIST) | sed -E 's/:.*## / — /' | sort

generate: ## Regenerate the Xcode project from project.yml
	xcodegen generate

test: generate ## Run the unit tests
	xcodebuild test -project "$(PROJECT)" -scheme "$(SCHEME)" \
		-destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

build: generate ## Build a Release .app (compile check; unsigned)
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Release \
		-derivedDataPath build CODE_SIGNING_ALLOWED=NO clean build

# Re-deploy a signed build to /Applications and refresh the widget daemon. NOTE: macOS only
# *activates* a development-signed widget once a dev provisioning profile exists for it — with a
# free/personal team that profile is created by running the app from Xcode (⌘R) at least once.
# After that first Xcode run, this target is a fast way to push rebuilds without Xcode.
install: generate ## Re-deploy to /Applications (needs one prior Xcode ⌘R to provision)
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Release \
		-derivedDataPath build -allowProvisioningUpdates clean build
	@codesign -dvv "$(APP)" 2>&1 | grep -q adhoc \
		&& { echo "✗ built ad-hoc (no Team) — set DEVELOPMENT_TEAM in project.yml"; exit 1; } \
		|| echo "✓ Team-signed"
	-osascript -e 'quit app "$(SCHEME)"' 2>/dev/null || true
	rm -rf "$(INSTALLED)"
	cp -R "$(APP)" "$(INSTALLED)"
	"$(LSREGISTER)" -f "$(INSTALLED)"
	-killall chronod 2>/dev/null || true
	open "$(INSTALLED)"
	@sleep 2
	@pluginkit -mv | grep -iq "$(WIDGET_ID)" \
		&& echo "✅ Widget registered — right-click the desktop → Edit Widgets → search '$(SCHEME)'." \
		|| echo "⚠️  Not registered yet — reboot, then re-run 'make install'."

uninstall: ## Quit and remove the installed app from /Applications
	-osascript -e 'quit app "$(SCHEME)"' 2>/dev/null || true
	rm -rf "$(INSTALLED)"

clean: ## Remove build artifacts
	rm -rf build
