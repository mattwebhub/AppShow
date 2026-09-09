# Local App Store implementation

The `AppShowStore` target is a local validation edition. It shares application sources with the direct-download target, uses the `APP_STORE` compilation condition, and has independent entitlements, Info.plist, framework dependencies and resources. It retains the AppShow bundle identifier and display name, and produces `AppShowStore.app` so local builds do not overwrite the direct-download product. Do not run both variants concurrently against the same document.

## Build and evaluate

```sh
make store-build
make eval-store
make test-store
make store-release
make store-archive
/usr/bin/python3 -B scripts/evaluate-store-build.py --app .build/Build/Products/Release/AppShowStore.app --universal
```

The archive is `.build/AppShowStore.xcarchive`; its app is under `Products/Applications/AppShowStore.app`. Run the same evaluator with that path and `--universal`. Local archive creation does not imply App Store distribution signing or an accepted upload.

These commands do not upload, publish, register an app record or obtain distribution credentials. Local signing follows the existing developer configuration. The evaluator checks compiled metadata, all Mach-O linkage for Sparkle, helper payloads, entitlements, privacy declarations, architectures and strict signature integrity. Its foundation result is not App Review or distribution approval.

## Validation feature set

Capture, editing, audio, captions and exports remain available for sandbox runtime testing. The target excludes Sparkle and the MCP executable. About does not show direct-download updates, releases or the online changelog. The external assistant panel and bridge/process launch are disabled pending the owner's store assistant decision; this is not a permanent removal from the product. The direct-download edition retains them.

The store edition does not request Accessibility or install the global keyboard event tap. Local keyboard shortcuts, the recording toolbar and menu bar recording controls remain available. Cross-app resize/centering and AX window raising are excluded; capture selection and window-following still need real runtime verification. The shortcuts settings explain their local scope.

## File access

Store settings, models and default Projects/Exports directories live under the container's `Library/Application Support/AppShow`. Scratch media uses the process's sandbox temporary directory. Legacy home migration remains exclusive to the direct-download edition; existing user projects can be opened explicitly.

Choosing a project/export folder creates a security-scoped bookmark before changing the selection. Reopening resolves the bookmark's URL, including moved locations, and refreshes stale bookmark data while access is held. Failed grant resolution surfaces an error instead of silently choosing a different output folder. Folder-selection failures offer re-selection. Project opening from Finder retains a project bookmark before loading media. Recent projects resolve the selected folder and recognize both `.appshow` and `.frm`.

Resolved folder/project grants stay alive for the application session because several editors and asynchronous recording/export tasks can share them. Replacing a selection retains the old grant until process exit so an in-flight operation is not interrupted. Transient audio, overlay and background imports hold scoped access only across the complete read/copy operation, including asynchronous audio loading. Security scopes are released only when their matching start succeeded.

The bookmark database is container-local. A corrupt database is rejected rather than overwritten automatically. Before shipping, test re-selection/recovery, stale/moved/deleted/offline locations, folder changes during export, imported media, project renaming/Save As and cold relaunch on a signed sandboxed installation. Isolated unit tests validate bookmark control flow. The separate store-hosted suite also persists/restores a native container bookmark and exports synthetic projects under App Sandbox; it does not replace external-folder and cold-relaunch tests. The store test host redirects settings and scratch files into a unique sandbox temporary directory.

## Submission gates still open

Use [A1–A12](APP-STORE-EVAL.md), including rights for the linked AGPL gifski library, SDK/resource privacy review, model download behavior, intended feature decisions, store signing/provisioning, an actual distribution archive, TestFlight, current AppShow screenshots, support/privacy URLs and App Store Connect metadata. No store rights conclusion or owner/account information is inferred from a successful build.

References: [Apple sandbox file access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox), [security-scoped bookmarks](https://developer.apple.com/documentation/professional-video-applications/enabling-security-scoped-bookmark-and-url-access).
