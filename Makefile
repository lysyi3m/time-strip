# Time Strip — common tasks.
# Requires: xcodegen (all targets).  brew install xcodegen

PROJECT    := Time Strip.xcodeproj
SCHEME     := Time Strip
APP        := build/Build/Products/Debug/$(SCHEME).app
# The dev app shares the App Store app's name, so it installs to ~/Applications and is addressed
# by bundle ID; /Applications/Time Strip.app is the App Store app.
INSTALLED  := $(HOME)/Applications/$(SCHEME).app
APP_ID     := com.mlkshkvch.time-strip.dev
WIDGET_ID  := $(APP_ID).widget
SIM        ?= iPhone 17
SIM_APP    := build/Build/Products/Debug-iphonesimulator/$(SCHEME).app
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

LOCAL_XCCONFIG := Config/Local.xcconfig
TEAM_SETTING   := ^DEVELOPMENT_TEAM = [A-Z0-9]{10}$$
# A compiler warning fails `make` and CI. Xcode's ⌘R still only warns, so iterating stays fast.
STRICT := SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES

# `make install` needs a Team-signed build, and so the Team ID that `local-config` projects from
# .env. Fail early rather than produce an ad-hoc build the widget daemon ignores.
require-team = @grep -qsE '$(TEAM_SETTING)' $(LOCAL_XCCONFIG) || { echo "✗ Set DEVELOPMENT_TEAM in .env (copy .env.example)"; exit 1; }

.DEFAULT_GOAL := help
.PHONY: help generate local-config test build build-ios run-ios install uninstall clean

help: ## List available targets
	@grep -E '^[a-z][a-zA-Z-]*:.*##' $(MAKEFILE_LIST) | sed -E 's/:.*## / — /' | sort

generate: local-config ## Regenerate the Xcode project from project.yml
	xcodegen generate

# Xcode cannot read .env, so the machine-local settings it needs are projected into an xcconfig
# that Config/Base.xcconfig includes. This keeps .env the single place to set DEVELOPMENT_TEAM,
# for both `xcodebuild` and a plain Cmd-R in Xcode. Only a 10-character Team ID is projected;
# quotes and a trailing comment are dropped, and anything else counts as unset.
local-config: ## Project machine-local settings from .env into Config/Local.xcconfig
	@mkdir -p Config
	@printf '// Generated from .env by `make generate`. Do not edit, do not commit.\n' > $(LOCAL_XCCONFIG)
	@if [ -f .env ]; then \
		sed -nE "s/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*[\"']?([A-Z0-9]{10})[\"']?([[:space:]]*(#.*)?)?$$/DEVELOPMENT_TEAM = \1/p" .env \
			>> $(LOCAL_XCCONFIG); \
	fi
	@grep -qE '$(TEAM_SETTING)' $(LOCAL_XCCONFIG) \
		&& echo "✓ DEVELOPMENT_TEAM from .env" \
		|| echo "• no valid DEVELOPMENT_TEAM in .env (a 10-character Team ID) — signing will need a team picked in Xcode"

test: generate ## Run the unit tests
	xcodebuild test -project "$(PROJECT)" -scheme "$(SCHEME)" \
		-destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO $(STRICT)

build: generate ## Build the dev app for macOS (compile check; unsigned)
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Debug \
		-derivedDataPath build CODE_SIGNING_ALLOWED=NO $(STRICT) clean build

build-ios: generate ## Build the dev app for iOS (compile check; unsigned)
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Debug \
		-destination 'generic/platform=iOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO $(STRICT) clean build

# Ad-hoc signed, no Team needed. An unsigned build installs and lists the widget, but the
# App Intents runtime cannot resolve its configuration intent, so the widget never renders.
run-ios: generate ## Build and launch on the iOS Simulator (SIM="iPhone 17")
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Debug \
		-destination 'platform=iOS Simulator,name=$(SIM)' -derivedDataPath build \
		CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= $(STRICT) build
	xcrun simctl boot "$(SIM)" 2>/dev/null || true
	open -a Simulator
	xcrun simctl install "$(SIM)" "$(SIM_APP)"
	xcrun simctl launch "$(SIM)" $(APP_ID)

# Re-deploy a signed dev build to ~/Applications and refresh the widget daemon. NOTE: macOS only
# *activates* a development-signed widget once a dev provisioning profile exists for it — with a
# free/personal team that profile is created by running the app from Xcode (⌘R) at least once.
# After that first Xcode run, this target is a fast way to push rebuilds without Xcode.
install: generate ## Re-deploy the dev app to ~/Applications (needs one prior Xcode ⌘R to provision)
	$(require-team)
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Debug \
		-derivedDataPath build -allowProvisioningUpdates $(STRICT) clean build
	@codesign -dvv "$(APP)" 2>&1 | grep -q adhoc \
		&& { echo "✗ built ad-hoc (no Team) — is DEVELOPMENT_TEAM in .env correct?"; exit 1; } \
		|| echo "✓ Team-signed"
	-osascript -e 'quit app id "$(APP_ID)"' 2>/dev/null || true
	mkdir -p "$(HOME)/Applications"
	rm -rf "$(INSTALLED)"
	cp -R "$(APP)" "$(INSTALLED)"
	"$(LSREGISTER)" -f "$(INSTALLED)"
	-killall chronod 2>/dev/null || true
	open "$(INSTALLED)"
	@sleep 2
	@pluginkit -mv | grep -iq "$(WIDGET_ID)" \
		&& echo "✅ Widget registered — right-click the desktop → Edit Widgets → search '$(SCHEME)'." \
		|| echo "⚠️  Not registered yet — reboot, then re-run 'make install'."

uninstall: ## Quit and remove the dev app from ~/Applications
	-osascript -e 'quit app id "$(APP_ID)"' 2>/dev/null || true
	rm -rf "$(INSTALLED)"

clean: ## Remove build artifacts
	rm -rf build
