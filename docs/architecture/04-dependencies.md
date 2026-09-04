# 04 — Dependencies

Sources of truth: `AppShow.xcodeproj/project.pbxproj` (`XCRemoteSwiftPackageReference` / `XCSwiftPackageProductDependency` sections, lines ~1460–1530), the resolved pins in `AppShow.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, the vendored `AppShow/Libraries/`, and `grep -rn "^import"` over `AppShow/`. License text was read from `.build/SourcePackages/checkouts/*/LICENSE*` where present.

There is no `Package.swift` for the app itself; all packages are added through the Xcode project. `AGENTS.md` notes that SPM `PBXBuildFile` entries must use `productRef` only (no `fileRef`), which matches the pbxproj.

## 1. Direct dependencies

| Package / library | Pinned | Requirement in pbxproj | Product | Imported in | Used for | License | Runtime necessity |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **swift-log** (`apple/swift-log`) | 1.9.1 | `upToNextMajor` from 1.6.0 | `Logging` | component loggers under `com.mattwebhub.appshow.*`; bootstrapped in `AppShow/Logging/LogBootstrap.swift` | Structured logging; `RotatingFileLogHandler` implements `LogHandler` | Apache-2.0 | **Hard** — every subsystem logs; could be replaced by `os.Logger` but not removed without touching ~26 files |
| **MenuBarExtraAccess** (`orchetect/MenuBarExtraAccess`) | 1.2.2 | `upToNextMajor` from 1.2.0 | `MenuBarExtraAccess` | `AppShow/AppShowApp.swift` only | `.menuBarExtraAccess(isPresented:) { statusItem in … }` to obtain the `NSStatusBarButton` (`SessionState.statusItemButton`) used for click-to-stop and icon swapping | MIT | **Hard** for the click-to-stop feature; trivially removable otherwise (one modifier) |
| **rnnoise-spm** (`jkuri/rnnoise-spm`) | 1.1.0 | `upToNextMajor` from 1.0.0 | `RNNoise` (C target compiled from source) | `AppShow/Utilities/RNNoiseProcessor.swift` only | Microphone noise reduction (`rnnoise_create`/`rnnoise_process_frame`), invoked from the editor (`EditorState.syncNoiseReduction`) and from export preprocessing | The SPM wrapper repo ships **no LICENSE file** (checkout contains only `Package.swift` and `Sources/`); upstream xiph/rnnoise is BSD-3-Clause. Confirm the wrapper terms before redistributing. | **Optional at runtime** (feature-gated by `micNoiseReductionEnabled`), **hard at link time** |
| **WhisperKit** (`argmaxinc/WhisperKit`) | 0.15.0 | `upToNextMajor` from 0.15.0 | `WhisperKit` | `AppShow/Utilities/WhisperModelManager.swift`, `AppShow/Utilities/TranscriptionService.swift` | On-device captions: model download under `~/.appshow`, `WhisperKit(config).transcribe` with word timestamps | MIT | **Optional at runtime** (user must download a model; Apple-silicon only in practice), **hard at link time**; by far the heaviest dependency (pulls in swift-transformers, CoreML) |
| **Sparkle** (`sparkle-project/Sparkle`) | 2.9.0 (binary `xcframework` artifact) | `upToNextMajor` from 2.0.0 | `Sparkle` | `AppShow/Utilities/SparkleUpdater.swift` only; touched from `AppDelegate.applicationDidFinishLaunching` (`_ = SparkleUpdater.shared`) and `SettingsAboutTab` ("Check for Updates") | Auto-update | MIT (multi-copyright: Matuschak, Elgato, Lesiński, …) | **Optional** — see §3; must be reconfigured or removed in a fork |
| **gifski** (vendored) | unknown version — no version string in `gifski.h`; check `strings libgifski.a | grep -i version` | n/a (static lib) | Clang module `gifski` via `AppShow/Libraries/gifski/module.modulemap` | `AppShow/Compositor/VideoCompositor+GIFExport.swift` only (`gifski_new`, `gifski_set_file_output`, `gifski_add_frame_rgba`, `gifski_finish`) | GIF encoding | AGPL-3.0-or-later; licence text is shipped beside the library and attribution appears in Credits and README (ADR 0008). | **Optional at runtime** (GIF format only), **hard at link time** (`OTHER_LDFLAGS = -lgifski`) |

Apple system frameworks linked explicitly in the pbxproj: `ScreenCaptureKit.framework`, `AVFoundation.framework`. Others (`Vision`, `VideoToolbox`, `CoreMediaIO`, `Accelerate`, `CoreImage`, `ApplicationServices`, `Combine`, `QuartzCore`, `ImageIO`, `UniformTypeIdentifiers`, `CoreText`) are auto-linked via `import`.

Import frequency across `AppShow/` (for orientation): `SwiftUI` 99, `Foundation` 85, `AppKit` 66, `AVFoundation` 63 (+5 `@preconcurrency`), `CoreMedia` 37, `CoreGraphics` 27, `Logging` 24, `ScreenCaptureKit` 10 (+4 `@preconcurrency`), `CoreVideo` 10, `VideoToolbox` 4, `QuartzCore` 4, `WhisperKit` 2, `Vision` 1, `Sparkle` 1, `RNNoise` 1, `MenuBarExtraAccess` 1, `gifski` 1, `os.lock` 1.

## 2. Transitive dependencies (from `Package.resolved`)

None of these are imported by AppShow code; they arrive through WhisperKit → swift-transformers.

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

## 3. Sparkle configuration

AppShow keeps Sparkle linked but does not start its controller unless `SUPublicEDKey` exists in the application bundle. The inherited upstream key was removed, automatic checks are disabled, and the About button is hidden while the controller is unavailable.

| Setting | Location | Current value |
| --- | --- | --- |
| Appcast URL | `AppShow/Info.plist` → `SUFeedURL` | `https://github.com/mattwebhub/AppShow/releases/download/appcast/appcast.xml` |
| EdDSA public key | `AppShow/Info.plist` → `SUPublicEDKey` | absent until an AppShow key is provisioned |
| Automatic checks | `SUEnableAutomaticChecks` and `SparkleUpdater` | disabled |
| Signing side | `scripts/generate-appcast.sh` | reads `$APPSHOW_SPARKLE_KEY` and signs `AppShow-<version>.dmg` |
| Release pipeline | `Makefile` targets `appcast` and `publish` | AppShow repository and artifact names |

Before enabling updates, generate an AppShow EdDSA pair with Sparkle's `generate_keys`, add only the public key to Info.plist, keep the private key outside the repository, and publish the matching appcast. The changelog fetch and About links already target `mattwebhub/AppShow`. See ADR 0004.

The AppShow bundle id is `com.mattwebhub.appshow`. The current document UTI is `com.mattwebhub.appshow.project`; `eu.jankuri.reframed.project` remains an imported legacy type so `.frm` bundles still open. The upstream MIT attribution remains required.

## 4. Build-time facts that affect dependencies

- Deployment target `MACOSX_DEPLOYMENT_TARGET = 15.0`; `make release` builds `ARCHS="arm64 x86_64"`. WhisperKit runs its CoreML models on Apple silicon; on Intel it will fall back or fail at model load — the app does not guard for this beyond the download UI.
- `libgifski.a` must contain both slices for the universal release build; verify with `lipo -info AppShow/Libraries/gifski/libgifski.a`.
- Hardened runtime is on and the sandbox is off; Sparkle's XPC-less "install as root" paths are not used (`SPUStandardUpdaterController` default).
- `.build/` (derived data, including `SourcePackages/`) and `dist/` are git-ignored; `Package.resolved` **is** committed, so builds are reproducible.
- `Config.xcconfig` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) is the single version source; `Info.plist` maps both `CFBundleShortVersionString` and `CFBundleVersion` to `$(MARKETING_VERSION)` (the build number is not used in the bundle).

## 5. Dependency-by-feature matrix

| Feature | Requires | Where it is switched on |
| --- | --- | --- |
| Screen / window / area capture | ScreenCaptureKit (system) | always |
| iOS device capture | AVFoundation `.external` devices + CoreMediaIO (`AppShow/Recording/DeviceDiscovery.swift`) | `CaptureMode.device` |
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
grep -n "repositoryURL\|minimumVersion" AppShow.xcodeproj/project.pbxproj
cat AppShow.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

# import sites
grep -rln "^import Sparkle\|^import WhisperKit\|^import RNNoise\|^import MenuBarExtraAccess\|^import gifski" AppShow

# Sparkle configuration
grep -n -A1 "SUFeedURL\|SUPublicEDKey\|SUEnableAutomaticChecks" AppShow/Info.plist
grep -rn "jkuri" AppShow scripts Makefile

# vendored gifski
lipo -info AppShow/Libraries/gifski/libgifski.a
strings AppShow/Libraries/gifski/libgifski.a | grep -i "gifski [0-9]" | head

# licences of resolved packages (after a build has populated .build/)
for p in .build/SourcePackages/checkouts/*; do echo "$p"; head -3 "$p"/LICENSE* 2>/dev/null; done
```
