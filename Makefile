# Time Strip — common tasks.
# Requires: xcodegen (all targets).  brew install xcodegen

PROJECT    := Time Strip.xcodeproj
SCHEME     := Time Strip
APP        := build/Build/Products/Release/$(SCHEME).app
INSTALLED  := /Applications/$(SCHEME).app
WIDGET_ID  := com.mlkshkvch.time-strip.widget
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

LOCAL_XCCONFIG := Config/Local.xcconfig
TEAM_SETTING   := ^DEVELOPMENT_TEAM = [A-Z0-9]{10}$$

# `make install` needs a Team-signed build, and so the Team ID that `local-config` projects from
# .env. Fail early rather than produce an ad-hoc build the widget daemon ignores.
require-team = @grep -qsE '$(TEAM_SETTING)' $(LOCAL_XCCONFIG) || { echo "✗ Set DEVELOPMENT_TEAM in .env (copy .env.example)"; exit 1; }

.DEFAULT_GOAL := help
.PHONY: help generate local-config test build install uninstall clean

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
		-destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

build: generate ## Build a Release .app (compile check; unsigned)
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Release \
		-derivedDataPath build CODE_SIGNING_ALLOWED=NO clean build

# Re-deploy a signed build to /Applications and refresh the widget daemon. NOTE: macOS only
# *activates* a development-signed widget once a dev provisioning profile exists for it — with a
# free/personal team that profile is created by running the app from Xcode (⌘R) at least once.
# After that first Xcode run, this target is a fast way to push rebuilds without Xcode.
install: generate ## Re-deploy to /Applications (needs one prior Xcode ⌘R to provision)
	$(require-team)
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Release \
		-derivedDataPath build -allowProvisioningUpdates clean build
	@codesign -dvv "$(APP)" 2>&1 | grep -q adhoc \
		&& { echo "✗ built ad-hoc (no Team) — is DEVELOPMENT_TEAM in .env correct?"; exit 1; } \
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
