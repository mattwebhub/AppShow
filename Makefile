APP_NAME = AppShow
SCHEME = AppShow
ARCH = $(shell uname -m)
DESTINATION = platform=macOS,arch=$(ARCH)
BUILD_DIR = .build
RELEASE_DIR = $(BUILD_DIR)/Build/Products/Release
DEBUG_DIR = $(BUILD_DIR)/Build/Products/Debug
TEST_TARGET = AppShowTests
TEST_FILTER = $(if $(T),-only-testing:'$(TEST_TARGET)/$(T)',-only-testing:$(TEST_TARGET))
TEST_OUTPUT_FILTER = ^(◇|✔|✘|Test Suite|\*\* )|Executed|: error:|: warning:|failed

.PHONY: build release run dev test test-shim test-agent-skills test-scenario dmg dmg-release format lint clean help install uninstall changelog tag appcast publish prepare-release release-preview store-build store-release store-archive test-store eval-store brand tray eval-tray preview-tray

all: help

brand:
	@/usr/bin/python3 scripts/generate-brand-assets.py

tray:
	@/usr/bin/python3 scripts/generate-tray-assets.py

preview-tray: build
	@./scripts/preview-tray.sh

eval-tray:
	@/usr/bin/python3 scripts/evaluate-tray-icon.py

build:
	@xcodebuild -project AppShow.xcodeproj -scheme $(SCHEME) -configuration Debug build -quiet -derivedDataPath $(BUILD_DIR) -destination '$(DESTINATION)'

release:
	@xcodebuild -project AppShow.xcodeproj -scheme $(SCHEME) -configuration Release build -quiet -derivedDataPath $(BUILD_DIR) -destination 'generic/platform=macOS' ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO

store-build:
	@xcodebuild -project AppShow.xcodeproj -scheme AppShowStore -configuration Debug build -quiet -derivedDataPath $(BUILD_DIR) -destination '$(DESTINATION)'

store-release:
	@xcodebuild -project AppShow.xcodeproj -scheme AppShowStore -configuration Release build -quiet -derivedDataPath $(BUILD_DIR) -destination 'generic/platform=macOS' ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO

store-archive:
	@xcodebuild -project AppShow.xcodeproj -scheme AppShowStore -configuration Release archive -quiet -derivedDataPath $(BUILD_DIR) -archivePath $(BUILD_DIR)/AppShowStore.xcarchive -destination 'generic/platform=macOS' ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO

test-store:
	@set -o pipefail; xcodebuild -project AppShow.xcodeproj -scheme AppShowStore -configuration Debug test -derivedDataPath $(BUILD_DIR) -destination '$(DESTINATION)' -parallel-testing-enabled NO 2>&1 | grep -E '$(TEST_OUTPUT_FILTER)'

eval-store:
	@/usr/bin/python3 -B scripts/evaluate-store-build.py

run: release
	@open $(RELEASE_DIR)/$(APP_NAME).app

dev: build
	@open $(DEBUG_DIR)/$(APP_NAME).app

test:
	@set -o pipefail; xcodebuild -project AppShow.xcodeproj -scheme $(SCHEME) -configuration Debug test -derivedDataPath $(BUILD_DIR) -destination '$(DESTINATION)' -parallel-testing-enabled NO $(TEST_FILTER) 2>&1 | grep -E '$(TEST_OUTPUT_FILTER)'

test-shim:
	@TEST_RUNNER_APPSHOW_RUN_SHIM_TESTS=1 $(MAKE) test T=AgentShimTests

test-agent-skills:
	@TEST_RUNNER_APPSHOW_RUN_AGENT_SKILL_E2E=1 TEST_RUNNER_APPSHOW_AGENT_CLAUDE_MODEL="$(CLAUDE_MODEL)" $(MAKE) test T=AgentSkillLiveTests

test-scenario:
	@TEST_RUNNER_APPSHOW_RUN_SCENARIO_TESTS=1 TEST_RUNNER_APPSHOW_RUN_EXPORT_TESTS=1 $(MAKE) test T=PresentationScenarioTests

dmg: release
	@./scripts/create-dmg.sh

dmg-release: release
	@./scripts/create-dmg.sh --sign "$(APPSHOW_SIGNING_IDENTITY)" --notarize

install: uninstall release
	@cp -rf $(RELEASE_DIR)/$(APP_NAME).app /Applications/

uninstall:
	@rm -rf /Applications/$(APP_NAME).app

tag:
	@/usr/bin/python3 -B scripts/release_workflow.py tag

changelog:
	@./scripts/changelog.sh --unreleased

appcast:
	@./scripts/generate-appcast.sh

prepare-release:
	@/usr/bin/python3 -B scripts/release_workflow.py prepare

release-preview:
	@./scripts/publish-release.sh --dry-run

publish:
	@./scripts/publish-release.sh --publish

format:
	@swift format -i -r AppShow/ Tools/ $(wildcard AppShowTests AppShowStoreTests)

lint:
	@swift format lint -r -s AppShow/ Tools/ $(wildcard AppShowTests AppShowStoreTests)

clean:
	@rm -rf $(BUILD_DIR) dist

help:
	@echo "AppShow Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build     - Build debug version"
	@echo "  release   - Build release version"
	@echo "  store-build - Build the sandboxed store validation app"
	@echo "  store-release - Build the universal store validation app"
	@echo "  store-archive - Create a local universal store archive"
	@echo "  test-store - Run sandbox-hosted synthetic project/export smoke tests"
	@echo "  eval-store - Audit the local store build artifact"
	@echo "  dmg         - Create .dmg installer"
	@echo "  dmg-release - Create signed and notarized .dmg installer"
	@echo "  install   - Install to /Applications"
	@echo "  uninstall - Remove from /Applications"
	@echo "  run       - Build release and run"
	@echo "  dev       - Build debug and run"
	@echo "  test      - Run unit tests (make test T=SuiteName for one suite)"
	@echo "  test-shim - Run the bundled MCP shim integration test"
	@echo "  test-agent-skills - Run live provider skill tests (optional CLAUDE_MODEL=name)"
	@echo "  test-scenario - Replay and export the deterministic presentation scenario"
	@echo "  format    - Format Swift source files"
	@echo "  brand     - Regenerate app icons and repository graphics"
	@echo "  tray      - Regenerate transparent SVG and menu bar template"
	@echo "  eval-tray - Evaluate SVG transparency, fidelity, and regeneration"
	@echo "  preview-tray - Render native menu bar states at 1x/2x"
	@echo "  clean     - Clean build artifacts"
	@echo "  tag       - Tag the clean committed release version"
	@echo "  changelog - Generate CHANGELOG.md"
	@echo "  appcast   - Generate appcast.xml for Sparkle updates"
	@echo "  prepare-release - Build, notarize, and record a local release candidate"
	@echo "  release-preview - Validate and preview a prepared candidate without publishing"
	@echo "  publish   - Publish the already prepared and tagged candidate"
	@echo "  help      - Show this help"
