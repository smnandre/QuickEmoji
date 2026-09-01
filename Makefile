.PHONY: help build test lint package run verify clean release-app release-dmg release-cask
.DEFAULT_GOAL := help

APP    := QuickEmoji
URL    := https://github.com/smnandre/QuickEmoji
AUTHOR := Simon André
RULE   := ──────────────────────────────────────

help:
	@printf '\n'
	@printf '%11s\033[2m%s\033[0m\n'    '' '$(RULE)'
	@printf '%25s\033[1m%s\033[0m\n'    '' '$(APP)'
	@printf '%11s\033[2m%s\033[0m\n'    '' '$(RULE)'
	@printf '%11s\033[4;34m%s\033[0m\n' '' '$(URL)'
	@printf '%19s\033[2;3m%s\033[0m\n'  '' 'Crafted by $(AUTHOR)'
	@printf '\n'
	@printf '  \033[1;4mTargets\033[0m\n\n'
	@printf '    \033[36m%-14s\033[0m %s\n' 'build'         'Compile the SwiftPM target (debug)'
	@printf '    \033[36m%-14s\033[0m %s\n' 'test'          'Run the test suite'
	@printf '    \033[36m%-14s\033[0m %s\n' 'lint'          'Run Swift format lint and ShellCheck'
	@printf '    \033[36m%-14s\033[0m %s\n' 'package'       'Build and verify the ARM64 app bundle'
	@printf '    \033[36m%-14s\033[0m %s\n' 'run'           'Package and launch QuickEmoji'
	@printf '    \033[36m%-14s\033[0m %s\n' 'verify'        'Test, lint, package, and smoke-test startup'
	@printf '    \033[36m%-14s\033[0m %s\n' 'clean'         'Remove build artifacts'
	@printf '\n'

build:
	swift build --arch arm64

test:
	swift test

lint:
	swift-format lint --recursive --strict Sources Tests Package.swift
	shellcheck Scripts/*.sh
	bash -n Scripts/*.sh
	yamllint .github/workflows .yamllint.yml
	plutil -lint Config/Info.plist Config/Version.plist
	jq empty Sources/QuickEmoji/Resources/Localizable.xcstrings
	./Scripts/validate-homebrew-cask.sh
	git diff --check

clean:
	swift package clean
	rm -rf build dist

package:
	./Scripts/build-app.sh

run:
	./Scripts/run-app.sh

verify: test lint package
	./Scripts/run-app.sh --no-build --smoke

release-app:
	SIGNING_MODE=release APP_IDENTITY="$(APP_IDENTITY)" ./Scripts/build-app.sh

release-dmg:
	./Scripts/create-dmg.sh "$(VERSION)"

release-cask:
	./Scripts/render-homebrew-cask.sh "$(VERSION)" "$(SHA256)" "$(OUTPUT)"
