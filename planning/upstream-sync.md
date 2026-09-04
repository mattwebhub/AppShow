# Upstream sync

Upstream: `jkuri/Reframed`, remote name `upstream`, branch `main`. Upstream releases roughly weekly and has no tests, so every merge is verified by our test suite plus a manual smoke of recording and export.

## Procedure

```bash
git fetch upstream
git log --oneline HEAD..upstream/main          # what is coming
git diff --stat HEAD...upstream/main           # which files
git switch -c sync/upstream-$(date +%Y%m%d)
git merge upstream/main
make build && make test && make format
```

Then open a PR from the sync branch into `main`. Read the CHANGELOG.md diff; upstream documents behavior changes there.

## Conflict hot spots

Files we intentionally diverge on and that upstream edits often:

| File | Why we diverge | On conflict |
|------|----------------|-------------|
| `Reframed.xcodeproj/project.pbxproj` | test target, signing settings | take theirs for source file additions, keep ours for signing and the test target block |
| `AGENTS.md` / `CLAUDE.md` | fork workflow section; upstream edits `CLAUDE.md` as a regular file, ours is a symlink to `AGENTS.md` | keep the symlink, apply their text changes to `AGENTS.md` by hand (ADR 0007) |
| `Makefile` | `test` target, signing variables | merge by hand |
| `Reframed/Info.plist` | Sparkle feed | keep ours |
| `Reframed.xcodeproj/xcshareddata/xcschemes/Reframed.xcscheme` | TestAction with env vars | keep ours |
| `Reframed/App/AppDelegate.swift` | test-host guard line | keep the guard, take their other changes |
| `Reframed/State/ConfigService.swift`, `StateService.swift`, `Recording/FileManager+Reframed.swift` | `ReframedPaths` seams | keep the `ReframedPaths` call, take their other changes |
| `Config.xcconfig` | signing defaults | keep ours |

## Intentional divergences

Keep this list current. Each entry links the ADR that justifies it.

- Signing configured through `Config.xcconfig` and an ignored `Local.xcconfig` instead of a hardcoded team id: `decisions/0003-signing-via-local-xcconfig.md`
- Sparkle automatic checks disabled for the fork until we have our own appcast: `decisions/0004-disable-upstream-sparkle-feed.md`
- `ReframedTests/` unit test target, scheme TestAction, `make test`: `decisions/0006-test-target-shape.md`
- Test-host seams in upstream files: `Reframed/App/AppDelegate.swift` (one guard line), `Reframed/State/ConfigService.swift`, `Reframed/State/StateService.swift`, `Reframed/Recording/FileManager+Reframed.swift` (paths via `ReframedPaths`); new files `Reframed/App/LaunchEnvironment.swift`, `Reframed/Utilities/ReframedPaths.swift`: `decisions/0006-test-target-shape.md`
- About tab links and changelog fetch point at the fork (`Reframed/UI/SettingsAboutTab.swift`, `Reframed/Utilities/UpdateChecker.swift`): `decisions/0004-disable-upstream-sparkle-feed.md`
- `Reframed/Libraries/gifski/LICENSE` (AGPL text) and gifski attribution in `Reframed/Credits.html` and `README.md`: `decisions/0008-gifski-licence.md`
- Lossless cut (milestone 02): `Reframed/Editor/EditorState.swift` region helpers delegate to the new pure `Reframed/Editor/CutTimeline.swift`; `Reframed/Editor/EditorState+VideoRegions.swift` gains `splitVideoRegion(atTime:)` and `clearVideoCuts()` (P1); `EditorView+TransportBar.swift` cut button (P4); slice views moved from `TimelineView+ScreenTrack.swift` to new `TimelineView+CutTrack.swift`, Screen track shows a plain bar while cuts exist, `TimelineView.swift` and `EditorView.swift` gate the Cuts track (P3); `SyncedPlayerController.swift` gains `GapSkipDecision`, `skipsGaps`, a boundary observer at slice ends, `EditorState+AudioRegions.swift` syncs them, `EditorState+Playback.swift` handles gaps in edit mode, `VideoPreviewView(+Update).swift` and `EditorView+Preview.swift` hide the screen in gaps when cuts exist (P5); `History+ChangeRules.swift` video-region strings read Cut added/removed/adjusted, `EditorState+Persistence.swift` and `EditorState.swift` normalize restored regions through `CutTimeline` (P2); `EditorState+Export.swift` export decisions extracted to `exportVideoRegions`/`exportTrimRange`, seam S3 `ExportConfiguration.outputDirectory` honored in `VideoCompositor.swift` via `FileManager.saveURL(for:extension:in:)` (P7): `docs/features/01-lossless-cut/ATTACK-PLAN.md`
- Test seams (milestone 01): `Reframed/Project/ReframedProject.swift` `create(..., cleanupTemp: Bool = true)` (S4); `Reframed/Utilities/TranscriptionService.swift` `mergeShortSegments` and `stripSpecialTokens` widened from `private static` to `static` (S7): `docs/architecture/07-testability.md`
- Lint fix in `Reframed/State/SessionState+WindowInfo.swift` (labeled closure argument) so `make lint` is clean
- `AGENTS.md` canonical, `CLAUDE.md` symlink; assistant-neutral wording: `decisions/0007-assistant-agnostic-docs.md`

## Cadence

Sync at the start of every milestone and before any release. Never sync in the middle of a feature branch; rebase the feature on `main` after the sync lands.
