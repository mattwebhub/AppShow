# 04 — Dependencies

Sources of truth: `Reframed.xcodeproj/project.pbxproj` (`XCRemoteSwiftPackageReference` / `XCSwiftPackageProductDependency` sections, lines ~1460–1530), the resolved pins in `Reframed.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, the vendored `Reframed/Libraries/`, and `grep -rn "^import"` over `Reframed/`. License text was read from `.build/SourcePackages/checkouts/*/LICENSE*` where present.

There is no `Package.swift` for the app itself; all packages are added through the Xcode project. `AGENTS.md` notes that SPM `PBXBuildFile` entries must use `productRef` only (no `fileRef`), which matches the pbxproj.

## 1. Direct dependencies

| Package / library | Pinned | Requirement in pbxproj | Product | Imported in | Used for | License | Runtime necessity |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **swift-log** (`apple/swift-log`) | 1.9.1 | `upToNextMajor` from 1.6.0 | `Logging` | 24 files (`Logger(label: "eu.jankuri.reframed.…")`); bootstrapped in `Reframed/Logging/LogBootstrap.swift` | Structured logging; `RotatingFileLogHandler` implements `LogHandler` | Apache-2.0 | **Hard** — every subsystem logs; could be replaced by `os.Logger` but not removed without touching ~26 files |
| **MenuBarExtraAccess** (`orchetect/MenuBarExtraAccess`) | 1.2.2 | `upToNextMajor` from 1.2.0 | `MenuBarExtraAccess` | `Reframed/ReframedApp.swift` only | `.menuBarExtraAccess(isPresented:) { statusItem in … }` to obtain the `NSStatusBarButton` (`SessionState.statusItemButton`) used for click-to-stop and icon swapping | MIT | **Hard** for the click-to-stop feature; trivially removable otherwise (one modifier) |
| **rnnoise-spm** (`jkuri/rnnoise-spm`) | 1.1.0 | `upToNextMajor` from 1.0.0 | `RNNoise` (C target compiled from source) | `Reframed/Utilities/RNNoiseProcessor.swift` only | Microphone noise reduction (`rnnoise_create`/`rnnoise_process_frame`), invoked from the editor (`EditorState.syncNoiseReduction`) and from export preprocessing | The SPM wrapper repo ships **no LICENSE file** (checkout contains only `Package.swift` and `Sources/`); upstream xiph/rnnoise is BSD-3-Clause and the wrapper is by the same author as Reframed. Treat as BSD-3-Clause but confirm before redistributing. | **Optional at runtime** (feature-gated by `micNoiseReductionEnabled`), **hard at link time** |
| **WhisperKit** (`argmaxinc/WhisperKit`) | 0.15.0 | `upToNextMajor` from 0.15.0 | `WhisperKit` | `Reframed/Utilities/WhisperModelManager.swift`, `Reframed/Utilities/TranscriptionService.swift` | On-device captions: model download to `~/.reframed`, `WhisperKit(config).transcribe` with word timestamps | MIT | **Optional at runtime** (user must download a model; Apple-silicon only in practice), **hard at link time**; by far the heaviest dependency (pulls in swift-transformers, CoreML) |
| **Sparkle** (`sparkle-project/Sparkle`) | 2.9.0 (binary `xcframework` artifact) | `upToNextMajor` from 2.0.0 | `Sparkle` | `Reframed/Utilities/SparkleUpdater.swift` only; touched from `AppDelegate.applicationDidFinishLaunching` (`_ = SparkleUpdater.shared`) and `SettingsAboutTab` ("Check for Updates") | Auto-update | MIT (multi-copyright: Matuschak, Elgato, Lesiński, …) | **Optional** — see §3; must be reconfigured or removed in a fork |
| **gifski** (vendored) | unknown version — no version string in `gifski.h`; check `strings libgifski.a | grep -i version` | n/a (static lib) | Clang module `gifski` via `Reframed/Libraries/gifski/module.modulemap` | `Reframed/Compositor/VideoCompositor+GIFExport.swift` only (`gifski_new`, `gifski_set_file_output`, `gifski_add_frame_rgba`, `gifski_finish`) | GIF encoding | **No licence file in the repo.** Upstream gifski (Kornel Lesiński) is **AGPL-3.0** with a commercial licence available. `gifski.h` carries no licence text and neither `LICENSE`, `Credits.html` nor `README.md` mention it. This is the single most important licensing item for a fork to resolve. | **Optional at runtime** (GIF format only), **hard at link time** (`OTHER_LDFLAGS = -lgifski`) |

Apple system frameworks linked explicitly in the pbxproj: `ScreenCaptureKit.framework`, `AVFoundation.framework`. Others (`Vision`, `VideoToolbox`, `CoreMediaIO`, `Accelerate`, `CoreImage`, `ApplicationServices`, `Combine`, `QuartzCore`, `ImageIO`, `UniformTypeIdentifiers`, `CoreText`) are auto-linked via `import`.

Import frequency across `Reframed/` (for orientation): `SwiftUI` 99, `Foundation` 85, `AppKit` 66, `AVFoundation` 63 (+5 `@preconcurrency`), `CoreMedia` 37, `CoreGraphics` 27, `Logging` 24, `ScreenCaptureKit` 10 (+4 `@preconcurrency`), `CoreVideo` 10, `VideoToolbox` 4, `QuartzCore` 4, `WhisperKit` 2, `Vision` 1, `Sparkle` 1, `RNNoise` 1, `MenuBarExtraAccess` 1, `gifski` 1, `os.lock` 1.

## 2. Transitive dependencies (from `Package.resolved`)

None of these are imported by Reframed code; they arrive through WhisperKit → swift-transformers.

| Package | Pinned | Pulled in by | License |
| --- | --- | --- | --- |
| swift-transformers (`huggingface/swift-transformers`) | 1.1.8 | WhisperKit (`.upToNextMinor(from: "1.1.2")`) | Apache-2.0 |
| swift-jinja (`huggingface/swift-jinja`) | 2.3.2 | swift-transformers | Apache-2.0 |
| yyjson (`ibireme/yyjson`) | 0.12.0 (`exact`) | swift-transformers | MIT |
| swift-collections (`apple/swift-collections`) | 1.3.0 | swift-transformers | Apache-2.0 |
| swift-crypto (`apple/swift-crypto`) | 4.2.0 | swift-transformers | Apache-2.0 |
| swift-asn1 (`apple/swift-asn1`) | 1.5.1 | swift-crypto | Apache-2.0 |
| swift-argument-parser (`apple/swift-argument-parser`) | 1.7.0 | WhisperKit (declared for its CLI product; resolved even though the app only links the `WhisperKit` library) | Apache-2.0 |

WhisperKit's `Package.swift` also declares Vapor / swift-openapi packages for its server target; they are **not** in `Package.resolved`, so they are not part of this build graph.

Removing WhisperKit removes all seven transitive packages and most of the build time.

## 3. Sparkle — what a fork must change

Sparkle is initialised unconditionally at launch:

```swift
// Reframed/Utilities/SparkleUpdater.swift
controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
controller.updater.automaticallyChecksForUpdates = true
controller.updater.updateCheckInterval = 3600
```

and `AppDelegate.applicationDidFinishLaunching` touches `SparkleUpdater.shared` as its first statement. With the current configuration a fork build **will check `jkuri/Reframed`'s appcast every hour and offer to replace itself with the upstream binary** whenever the upstream version is newer than `MARKETING_VERSION`. The `SUPublicEDKey` in `Info.plist` is upstream's, so upstream's EdDSA-signed DMGs validate. Sparkle 2 also compares Apple code-signing identities between the running app and the update when the running app is signed, which would normally block installation of a differently-signed binary — but do not rely on that as the fork's only protection; the poll, the prompt, and any misconfiguration still leak to upstream.

Where the upstream feed and key are configured:

| Setting | Location | Current value |
| --- | --- | --- |
| Appcast URL | `Reframed/Info.plist` → `SUFeedURL` | `https://github.com/jkuri/Reframed/releases/download/appcast/appcast.xml` |
| EdDSA public key | `Reframed/Info.plist` → `SUPublicEDKey` | `fbTkPksA1K4eUhGRCvIscQ7QGdUy3tstkNtWy/NstdY=` |
| Automatic checks | Upstream: `SUEnableAutomaticChecks` = `true` in `Reframed/Info.plist` and `automaticallyChecksForUpdates = true` in code. Fork: both set to `false`, feed URL points at `mattwebhub/Reframed` (ADR 0004) | done |
| Signing side | `scripts/generate-appcast.sh` — reads the private key from `$REFRAMED_SPARKLE_KEY`, signs the DMG with Sparkle's `sign_update` (found under `.build/SourcePackages/artifacts/sparkle/Sparkle/bin/`), and hard-codes `DOWNLOAD_URL="https://github.com/jkuri/Reframed/releases/download/v${VERSION}/${DMG_NAME}"` and `<link>https://github.com/jkuri/Reframed</link>` | |
| Release pipeline | `Makefile` targets `appcast` and `publish` (`tag` + `dmg-release` + `appcast` + `scripts/publish-release.sh`) | |

Not Sparkle, but same problem: `Reframed/Utilities/UpdateChecker.swift` fetches `https://api.github.com/repos/jkuri/Reframed/releases/latest` to show the changelog in `SettingsAboutTab`, and `SettingsAboutTab.swift` links to `github.com/jkuri/Reframed` and `/issues`. `Reframed/Credits.html` and `Info.plist`'s `NSHumanReadableCopyright` name the upstream author.

Minimum fork-safe change set:

1. Either remove the `SUFeedURL`/`SUPublicEDKey` keys and the `Sparkle` package (delete `SparkleUpdater.swift`, the `_ = SparkleUpdater.shared` line, the About-tab button, and the pbxproj package/product references), **or** generate a new key pair (`generate_keys`), replace `SUPublicEDKey`, host your own `appcast.xml`, and point `SUFeedURL`, `scripts/generate-appcast.sh` and `scripts/publish-release.sh` at it.
2. Change `UpdateChecker.fetchLatestChangelog()`'s URL or delete the changelog feature.
3. Change `PRODUCT_BUNDLE_IDENTIFIER`, `DEVELOPMENT_TEAM` and `CODE_SIGN_IDENTITY` in the pbxproj; note the UTI `eu.jankuri.reframed.project` in `Info.plist` is what Launch Services uses to associate `.frm` bundles — changing it will orphan existing bundles unless you keep it or declare the old one as an imported type.
4. Keep the `MIT` `LICENSE` and copyright notice (required by the MIT licence).

## 4. Build-time facts that affect dependencies

- Deployment target `MACOSX_DEPLOYMENT_TARGET = 15.0`; `make release` builds `ARCHS="arm64 x86_64"`. WhisperKit runs its CoreML models on Apple silicon; on Intel it will fall back or fail at model load — the app does not guard for this beyond the download UI.
- `libgifski.a` must contain both slices for the universal release build; verify with `lipo -info Reframed/Libraries/gifski/libgifski.a`.
- Hardened runtime is on and the sandbox is off; Sparkle's XPC-less "install as root" paths are not used (`SPUStandardUpdaterController` default).
- `.build/` (derived data, including `SourcePackages/`) and `dist/` are git-ignored; `Package.resolved` **is** committed, so builds are reproducible.
- `Config.xcconfig` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) is the single version source; `Info.plist` maps both `CFBundleShortVersionString` and `CFBundleVersion` to `$(MARKETING_VERSION)` (the build number is not used in the bundle).

## 5. Dependency-by-feature matrix

| Feature | Requires | Where it is switched on |
| --- | --- | --- |
| Screen / window / area capture | ScreenCaptureKit (system) | always |
| iOS device capture | AVFoundation `.external` devices + CoreMediaIO (`Reframed/Recording/DeviceDiscovery.swift`) | `CaptureMode.device` |
| Webcam background replacement | Vision (system) via `PersonSegmentationProcessor` | `EditorState.cameraBackgroundStyle != .none` |
| Noise reduction | rnnoise-spm | `EditorState.micNoiseReductionEnabled` |
| Captions | WhisperKit (+ 7 transitive) + a downloaded model | `PropertiesPanel+CaptionsTab` → `EditorState+Captions` |
| GIF export | gifski (vendored, licence unresolved) | `ExportFormat.gif` |
| Auto-update | Sparkle | always (at launch) |
| Menu-bar click-to-stop | MenuBarExtraAccess | always |
| Logging | swift-log | always |

## 6. How to verify these facts locally

```bash
# packages and pins
grep -n "repositoryURL\|minimumVersion" Reframed.xcodeproj/project.pbxproj
cat Reframed.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

# import sites
grep -rln "^import Sparkle\|^import WhisperKit\|^import RNNoise\|^import MenuBarExtraAccess\|^import gifski" Reframed

# Sparkle configuration
grep -n -A1 "SUFeedURL\|SUPublicEDKey\|SUEnableAutomaticChecks" Reframed/Info.plist
grep -rn "jkuri" Reframed scripts Makefile

# vendored gifski
lipo -info Reframed/Libraries/gifski/libgifski.a
strings Reframed/Libraries/gifski/libgifski.a | grep -i "gifski [0-9]" | head

# licences of resolved packages (after a build has populated .build/)
for p in .build/SourcePackages/checkouts/*; do echo "$p"; head -3 "$p"/LICENSE* 2>/dev/null; done
```
