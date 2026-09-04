APP_NAME = AppShow
SCHEME = AppShow
ARCH = $(shell uname -m)
DESTINATION = platform=macOS,arch=$(ARCH)
BUILD_DIR = .build
VERSION = $(shell grep MARKETING_VERSION Config.xcconfig | cut -d'=' -f2 | tr -d ' ')
RELEASE_DIR = $(BUILD_DIR)/Build/Products/Release
DEBUG_DIR = $(BUILD_DIR)/Build/Products/Debug
TEST_TARGET = AppShowTests
TEST_FILTER = $(if $(T),-only-testing:'$(TEST_TARGET)/$(T)',-only-testing:$(TEST_TARGET))
TEST_OUTPUT_FILTER = ^(◇|✔|✘|Test Suite|\*\* )|Executed|: error:|: warning:|failed

.PHONY: build release run dev test test-shim test-agent-skills test-scenario dmg dmg-release format lint clean help install uninstall changelog tag appcast publish

all: help

build:
	@xcodebuild -project AppShow.xcodeproj -scheme $(SCHEME) -configuration Debug build -quiet -derivedDataPath $(BUILD_DIR) -destination '$(DESTINATION)'

release:
	@xcodebuild -project AppShow.xcodeproj -scheme $(SCHEME) -configuration Release build -quiet -derivedDataPath $(BUILD_DIR) -destination 'generic/platform=macOS' ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO

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
	@if git rev-parse "v$(VERSION)" >/dev/null 2>&1; then \
		echo "Tag v$(VERSION) already exists"; exit 1; \
	fi
	@git tag -a "v$(VERSION)" -m "v$(VERSION)"
	@echo "Created tag v$(VERSION)"
	@$(MAKE) changelog

changelog:
	@./scripts/changelog.sh --unreleased

appcast:
	@./scripts/generate-appcast.sh

publish: tag dmg-release appcast
	@./scripts/publish-release.sh

format:
	@swift format -i -r AppShow/ Tools/ $(wildcard AppShowTests)

lint:
	@swift format lint -r -s AppShow/ Tools/ $(wildcard AppShowTests)

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
	@echo "  clean     - Clean build artifacts"
	@echo "  tag       - Create git tag from Config.xcconfig version and generate changelog"
	@echo "  changelog - Generate CHANGELOG.md"
	@echo "  appcast   - Generate appcast.xml for Sparkle updates"
	@echo "  publish   - Full release: tag + dmg-release + appcast"
	@echo "  help      - Show this help"
