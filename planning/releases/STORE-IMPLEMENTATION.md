# Local App Store implementation

The `AppShowStore` target is a local validation edition. It shares application sources with the direct-download target, uses the `APP_STORE` compilation condition, and has independent entitlements, Info.plist, framework dependencies and resources. It retains the AppShow bundle identifier and display name, and produces `AppShowStore.app` so local builds do not overwrite the direct-download product. Do not run both variants concurrently against the same document.

## Build and evaluate

```sh
make stage-store-agents
make test-store
make store-build
make eval-store
make store-release
make store-archive
/usr/bin/python3 -B scripts/evaluate-store-build.py --app .build/Build/Products/Release/AppShowStore.app --universal
```

Rebuild with `make store-build` after hosted Store tests before running the evaluator; Xcode injects test frameworks and temporary test entitlements into its test host.

The archive is `.build/AppShowStore.xcarchive`; its app is under `Products/Applications/AppShowStore.app`. Run the same evaluator with that path and `--universal`. Local archive creation does not imply App Store distribution signing or an accepted upload.

These commands do not upload, publish, register an app record or obtain distribution credentials. Local signing follows the existing developer configuration. The evaluator checks compiled metadata, all Mach-O linkage for Sparkle, helper payloads, entitlements, privacy declarations, architectures and strict signature integrity. Its foundation result is not App Review or distribution approval.

## Validation feature set

Capture, editing, audio, captions and exports remain available for sandbox runtime testing. The Store target now includes the project assistant, the MCP shim, workspace guidance and editing skills. About excludes direct-download updates, releases and the online changelog. Sparkle is absent. [Milestone 21](../milestones/21-sandboxed-agents/PLAN.md) tracks the remaining authenticated-provider and candidate acceptance.

The staging command downloads the Codex, code-mode host and Claude Code versions selected in `scripts/agent-runtime-versions.json` for Apple Silicon and Intel. It verifies official release digests, records source URLs and binary hashes, and collects notices. The build embeds only the requested architectures and rejects staged versions that differ from the pins. Codex and the MCP shim use App Sandbox inheritance entitlements. Claude's original vendor binary and signature are preserved; successful local validation does not establish App Store acceptance of that signing arrangement or its distribution rights.

Store executable discovery is confined to the bundled runtime directory. Provider state and hashed per-project workspaces live in the container; external provider homes and shell configuration are not imported. Both sign-in buttons run the provider's native login flow, open only provider authorization URLs and offer cancellation. Claude also exposes its native Console flow. OAuth callbacks use the network-server entitlement. Before a provider's first send in an editor session, the app identifies the recipient and data being shared and obtains explicit permission. Full exports retain the existing separate confirmation.

MCP frame previews include a PNG content block as well as structured timing/path metadata, so providers can inspect the image without launching a separate file viewer. The September 9 live Codex test established login, streamed replies, MCP inspection/editing, Undo/Redo and resumed turns. Codex also described the actual PNG returned by MCP after a cold relaunch. An authenticated Claude edit remains pending. A subsequent longer-conversation send exposed a native SwiftUI layout stall; that unresolved runtime issue prevents claiming candidate acceptance.

The Store packaging build phase disables Xcode's build-script sandbox because copying and signing nested binaries requires dynamically generated paths. This setting concerns the build script, not the application sandbox. The resulting app retains App Sandbox without temporary exceptions. The evaluator verifies the runtime receipt, embedded file hashes, preserved Claude hash, nested signatures, inheritance entitlements and absence of updaters.

The store edition does not request Accessibility or install the global keyboard event tap. Local keyboard shortcuts, the recording toolbar and menu bar recording controls remain available. Cross-app resize/centering and AX window raising are excluded; capture selection and window-following still need real runtime verification. The shortcuts settings explain their local scope.

## Updating the bundled CLIs

Settings → Agents shows installed versions and opens the Mac App Store. Bundled providers update with AppShow; Claude background and manual self-updates are disabled. The direct-download edition has Toone-derived automatic managed CLI updates, a manual check/install action and version rechecks. Its downloader is excluded from Store compilation. See [ADR 0021](../decisions/0021-agent-runtime-updates.md).

1. Run `make check-agent-updates` to compare the pins with official stable releases. This does not download binaries or modify the version file.
2. Edit `scripts/agent-runtime-versions.json` to select exact stable versions for both providers. Keep the previous pins in source control for rollback. Codex's code-mode host follows the Codex pin automatically.
3. Run `make stage-store-agents`. Allow space for both the old and new universal payloads during staging. A failed download, checksum or promotion preserves the previous set. A concurrent build/stage operation is refused; retry after it finishes.
4. Run `make test-agent-updates`, `make test`, `make test-store`, `make store-build`, `make eval-store`, and `make store-release`. Evaluate the universal Release app with `scripts/evaluate-store-build.py --app .build/Build/Products/Release/AppShowStore.app --universal`.
5. Verify both providers' sign-in, streamed replies, MCP editing/images, Undo, resumed sessions, cancellation and cold relaunch on both supported architectures. Recheck notices, distribution rights and signatures for the selected releases.
6. Bump AppShow's marketing version/build and prepare the normal Store candidate only after those checks pass. Runtime staging does not publish anything. An already shipped runtime rollback also needs a new AppShow Store release.

As of September 9, the live update check reports Codex 0.153.4 and Claude Code 2.1.267. The pins remain at the previously probed 0.153.3 and 2.1.263 until newer versions receive compatibility validation. The unresolved long-conversation layout stall and Claude account test still block candidate acceptance.

## File access

Store settings, models and default Projects/Exports directories live under the container's `Library/Application Support/AppShow`. Scratch media uses the process's sandbox temporary directory. Legacy home migration remains exclusive to the direct-download edition; existing user projects can be opened explicitly.

Choosing a project/export folder creates a security-scoped bookmark before changing the selection. Reopening resolves the bookmark's URL, including moved locations, and refreshes stale bookmark data while access is held. Failed grant resolution surfaces an error instead of silently choosing a different output folder. Folder-selection failures offer re-selection. Project opening from Finder retains a project bookmark before loading media. Recent projects resolve the selected folder and recognize both `.appshow` and `.frm`.

Resolved folder/project grants stay alive for the application session because several editors and asynchronous recording/export tasks can share them. Replacing a selection retains the old grant until process exit so an in-flight operation is not interrupted. Transient audio, overlay and background imports hold scoped access only across the complete read/copy operation, including asynchronous audio loading. Security scopes are released only when their matching start succeeded.

The bookmark database is container-local. A corrupt database is rejected rather than overwritten automatically. Before shipping, test re-selection/recovery, stale/moved/deleted/offline locations, folder changes during export, imported media, project renaming/Save As and cold relaunch on a signed sandboxed installation. Isolated unit tests validate bookmark control flow. The separate store-hosted suite also persists/restores a native container bookmark and exports synthetic projects under App Sandbox; it does not replace external-folder and cold-relaunch tests. The store test host redirects settings and scratch files into a unique sandbox temporary directory.

## Submission gates still open

Use [A1–A12](APP-STORE-EVAL.md), including rights for the linked AGPL gifski library, SDK/resource privacy review, model download behavior, intended feature decisions, store signing/provisioning, an actual distribution archive, TestFlight, current AppShow screenshots, support/privacy URLs and App Store Connect metadata. No store rights conclusion or owner/account information is inferred from a successful build.

References: [Apple sandbox file access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox), [security-scoped bookmarks](https://developer.apple.com/documentation/professional-video-applications/enabling-security-scoped-bookmark-and-url-access).
