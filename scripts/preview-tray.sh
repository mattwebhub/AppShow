#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
PREVIEW_BUNDLE="$ROOT_DIR/.build/brand/TrayPreview.app"
mkdir -p "$PREVIEW_BUNDLE/Contents/MacOS" "$PREVIEW_BUNDLE/Contents/Resources"
cp .build/Build/Products/Debug/AppShow.app/Contents/Resources/Assets.car "$PREVIEW_BUNDLE/Contents/Resources/Assets.car"
cat > "$PREVIEW_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.mattwebhub.appshow.tray-preview</string><key>CFBundleExecutable</key><string>TrayPreview</string><key>CFBundlePackageType</key><string>APPL</string><key>LSUIElement</key><true/></dict></plist>
PLIST
swiftc AppShow/Utilities/MenuBarIcon.swift \
  .build/Build/Intermediates.noindex/AppShow.build/Debug/AppShow.build/DerivedSources/GeneratedAssetSymbols.swift \
  scripts/RenderTrayPreview.swift -o "$PREVIEW_BUNDLE/Contents/MacOS/TrayPreview"
"$PREVIEW_BUNDLE/Contents/MacOS/TrayPreview" "$ROOT_DIR/.build/brand/tray-native-preview.png"
printf '%s\n' 'Native state preview: .build/brand/tray-native-preview.png'
