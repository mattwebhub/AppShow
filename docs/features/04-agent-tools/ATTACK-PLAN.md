# Attack plan 04 — Agent tools

Phased, test-first plan for `SPIKE.md`. Every phase lists the failing tests to write first (name, file under `ReframedTests/`, assertion, tier from `docs/architecture/07-testability.md`), then the production change, then a manual check. Sizes are relative: S = under a day, M = a few days, L = a week or more. Rules are `planning/tdd-strategy.md`; new code lives in `Reframed/Agent/` and `ReframedTests/Agent/`; upstream files are touched only at the seams named per phase and recorded in `planning/upstream-sync.md`.

## Dependencies

| Needs | From | Why |
| --- | --- | --- |
| `ReframedTests/Fixtures/screen-2s.mov` (+ optional `mic-2s.m4a`, `cursor-metadata.json`) | milestone 01 test foundation | `EditorState(result:)` + `await setup()` needs a real movie for `duration` (`07-testability.md` §T2) |
| Seam S3 `ExportConfiguration.outputDirectory` | milestone 01 | `export_draft` must not write to `~/Movies` |
| Seam S7 on `AudioWaveformGenerator.extractSamples` | milestone 01 or phase 5 here | silence detection |
| Keep-slices model and remap | spike 01 (`docs/features/01-lossless-cut/`) | `set_keep_slices`, `remove_silences`; until then phase 4 maps cuts to `videoRegions` |
| Music track model, bundle import, mix | spike 02 (`docs/features/02-music-tracks/`) | phase 10 |
| Chat panel: provider spawn, stream parsing, tool-call rows, confirmation UI | spike 03 (`docs/features/03-agent-chat/`) | phases 2, 4, 12; phases 1, 3, 5–9 do not need it |

Phases 1, 3, 5, 6, 7, 8 can be built and fully tested before spike 03 lands, using the dispatcher directly.

---

## Phase 1 — Tool catalog and dispatcher (pure) · size M · milestone 05

**Failing tests first**

| Test | File | Assertion | Tier |
| --- | --- | --- | --- |
| `everyToolHasUniqueSnakeCaseNameAndObjectSchema()` | `ReframedTests/Agent/AgentToolCatalogTests.swift` | `AgentToolCatalog.all` names match `^[a-z][a-z0-9_]*$`, are unique, each `inputSchema.type == "object"`, `additionalProperties == false`, `description` non-empty | T1 |
| `catalogEncodesToMCPToolListJSON()` | same | `JSONEncoder` output of `tools/list` result contains `name`, `description`, `inputSchema` for `get_timeline`; decodes back equal | T1 |
| `readOnlyToolsAreFlaggedAndMutatingToolsRequireLabelField()` | same | `tool.isMutating == false` for every `get_*`; every mutating tool's schema has an optional `label` string | T1 |
| `unknownToolReturnsErrorWithoutTouchingState()` | `ReframedTests/Agent/AgentToolDispatcherTests.swift` (`@MainActor`) | `dispatcher.call("nope", [:])` → `isError`, code `UNKNOWN_TOOL`, `history.entries.count` unchanged | T2 (fixture) |
| `invalidArgumentsAreRejectedBeforeMutation()` | same | `add_spotlight` with `start: "x"` → `TOOL_ARGUMENTS_INVALID`, `didMutate == false`, `spotlightRegions` unchanged | T2 |
| `timesAreClampedToDuration()` | same | `set_trim {start:-1, end: 99}` on the 2 s fixture → trim `[0, 2.0]` | T2 |
| `observedPropertiesMatchSnapshotFields()` | `ReframedTests/Editor/EditorStateObservationTests.swift` | mutate each property that `createSnapshot()` serializes and assert `scheduleUndoSnapshot` is scheduled; mutate `agentActivity` and assert it is not | T2 |

**Production**

- `Reframed/Agent/AgentTool.swift`: `struct AgentTool: Codable, Sendable { name, description, inputSchema: JSONSchema, isMutating, isGated }`; `enum AgentToolCatalog { static let all: [AgentTool] }` written as data, one entry per row of `SPIKE.md` §3.1–3.2 (phase 3/4 fill the handlers; the catalog is complete from day one so skills can be written against it).
- `Reframed/Agent/AgentToolDispatcher.swift` (`@MainActor final class`): `call(_ name: String, _ args: [String: JSONValue]) async -> AgentToolResult`; validates with a small in-house schema checker (`type`, `required`, `enum`, `minimum/maximum`, `additionalProperties`); clamps; snapshots `pre = editorState.createSnapshot()`; on throw restores `pre`.
- `Reframed/Agent/AgentToolResult.swift`: `{ok, code?, message?, didMutate, historyIndex?, label?, timeline?: TimelineSummary}`, `Codable`.
- `Reframed/Agent/JSONValue.swift`: minimal `enum JSONValue: Codable` (no third-party JSON dependency).

**Manual check** — none (pure).

---

## Phase 2 — Transport and auth · size M · milestone 05 · depends on spike 03 for the spawn

**Failing tests first**

| Test | File | Assertion | Tier |
| --- | --- | --- | --- |
| `decodesNewlineDelimitedJSONRPCRequestsAndEncodesResponses()` | `ReframedTests/Agent/JSONRPCCodecTests.swift` | `{"jsonrpc":"2.0","id":1,"method":"tools/list"}` round-trips; a partial line is buffered; id preserved as int or string | T1 |
| `initializeReturnsServerInfoAndToolsCapability()` | same | `AgentRPCHandler.handle(initialize)` → `serverInfo.name == "reframed"`, `capabilities.tools` present, protocol version echoed | T1 |
| `serverRejectsWrongTokenAndAcceptsRightOne()` | `ReframedTests/Agent/AgentBridgeServerTests.swift` (`@Suite(.serialized)`) | start `AgentBridgeServer` on a socket in a temp dir; connect with `NWConnection`; wrong `REFRAMED_AGENT_TOKEN` in the first frame → connection closed with error `-32001`; right token → `tools/list` returns the catalog | T2 |
| `toolsCallIsDispatchedOnMainActorAndAnswersOnTheSocket()` | same | send `tools/call get_timeline` → response contains `duration` from the fixture editor | T2 |
| `slowToolTimesOutWithStructuredError()` | same | register a test tool that sleeps 2 s with a 0.5 s timeout → `TOOL_TIMEOUT`, server still answers the next call | T2 |
| `claudeMCPConfigAndCodexOverridesAreGenerated()` | `ReframedTests/Agent/AgentSessionConfigTests.swift` | `AgentSessionConfig.claudeMCPConfigJSON` == `{"mcpServers":{"reframed":{"type":"stdio","command":…,"env":{…}}}}` (sorted keys); `codexArguments` starts with `["-c","mcp_servers={}"]` and contains `mcp_servers.reframed.command=…`, `.env_vars=[…]`, `.tool_timeout_sec=600`, one `approval_mode="approve"` per non-gated tool | T1 |
| `bundledShimInjectsAuthenticationAndListsEditingTools()` | `ReframedTests/Agent/AgentShimTests.swift`, `.enabled(if: env["REFRAMED_RUN_SHIM_TESTS"] == "1")` | spawn the embedded `appshow-mcp`, initialize without the private token field, and discover the editing catalog through the live app socket | T2, gated |

**Production**

- `Reframed/Agent/JSONRPC.swift` (codec), `Reframed/Agent/AgentRPCHandler.swift` (`initialize`, `tools/list`, `tools/call`, `ping`), `Reframed/Agent/AgentBridgeServer.swift` (`actor`, `NWListener` on `NWEndpoint.unix`, one connection per session, token + editor id check, per-tool timeout).
- New target `appshow-mcp` (`Tools/appshow-mcp/main.swift`, Foundation only): reads stdin lines, injects session authentication into `initialize`, connects to `REFRAMED_AGENT_SOCKET`, forwards and relays; exits when stdin closes. Copied into `Contents/Helpers` by a Copy Files phase and signed with the app.
- `Reframed/Agent/AgentSessionConfig.swift`: workspace layout, token generation, `claudeMCPConfigJSON`, `codexArguments`, `processEnvironment`.
- `Makefile`: `test-shim` target gated like `test-export`.

**Manual check** — with the chat panel: start a session, `/mcp` in Claude Code lists `reframed` with the catalog; Codex `/mcp` shows the same; a wrong token in the env file is refused and logged under `eu.jankuri.reframed.agent-bridge`.

---

## Phase 3 — Read-only tools · size M · milestone 05

**Failing tests first**

| Test | File | Assertion | Tier |
| --- | --- | --- | --- |
| `getProjectReportsBundleAndMedia()` | `ReframedTests/Agent/ReadOnlyToolsTests.swift` (`@MainActor`) | on `EditorState(result: fixture)`: `duration ≈ 2.0`, `hasWebcam == false`, `fps` from `RecordingResult` | T2 |
| `getTimelineSummaryListsEveryTrack()` | same | after adding one spotlight and one camera region: summary has `spotlights.count == 1`, `camera.count == 1`, `trim == [0,2]`, `historyIndex` | T2 |
| `getTranscriptReturnsWordsWhenPresent()` | same | seed `captionSegments` with two segments with words → `withWords:true` returns 2 segments, word count matches; `from/to` filters by overlap | T2 |
| `getClickClustersGroupsClicksByDwell()` | same | in-memory `CursorMetadataFile` with clicks at 0.2/0.3 s and 1.5 s → 2 clusters with centers and `[start,end]` | T1 (provider constructed in memory) |
| `getHistoryIncludesLabelsAndDescriptions()` | same | after `set_trim` (phase 4) `get_history` last entry has `label` and `description` from `describeChanges` | T2 |
| `renderPreviewFrameWritesPNGOfExpectedSize()` | `ReframedTests/Agent/PreviewFrameTests.swift` | `render_preview_frame {atSeconds: 1.0, width: 64}` → PNG at `<tmp>/frames/…png`, decoded size 64×36 for the 16:9 fixture; background pixel equals `backgroundStyle` color (golden-frame policy from `tdd-strategy.md`) | T2 |

**Production**

- `Reframed/Agent/Tools/InspectionTools.swift`: handlers for `get_project`, `get_timeline`, `get_transcript`, `get_click_clusters`, `get_history`; `TimelineSummary: Codable`.
- `Reframed/Agent/PreviewFrameRenderer.swift`: `AVAssetImageGenerator` at `atSeconds` for screen and webcam → `CVPixelBuffer`s → `VideoCompositor.buildCompositionInstruction` (needs a composition; reuse `EditorState.export`'s config assembly by extracting `makeExportConfiguration(settings:)` from `EditorState+Export.swift:143-208` into a method the tool can call, additive) → `FrameRenderer.renderFrame` → PNG via `CGImageDestination`.
- `export_draft` handler once seam S3 exists: `ExportSettings` with `resolution` capped and `fps` 15, `outputDirectory = <workspace>/drafts`.

**Manual check** — ask the agent "describe this recording"; it answers with duration, click clusters, and transcript excerpts without editing anything; badge stays hidden for read-only calls.

---

## Phase 4 — First mutating tools, history labels, live badge · size L · milestone 06 · depends on spike 03 for confirmations

**Failing tests first**

| Test | File | Assertion | Tier |
| --- | --- | --- | --- |
| `historyEntryLabelSurvivesRoundTripAndIsOptional()` | `ReframedTests/Editor/HistoryTests.swift` | encode `HistoryEntry(label:"x")`, decode; decode legacy JSON without `label` → `nil` | T1 |
| `pushSnapshotSkipsWhenEqualToCurrentEntry()` | same | `EditorStateData: Equatable`; pushing the same snapshot twice yields one entry | T1 |
| `setTrimCreatesOneLabelledUndoStep()` | `ReframedTests/Agent/MutatingToolsTests.swift` (`@MainActor`) | `set_trim {start:0.5,end:1.5,label:"tighten"}` → `history.entries.count` +1 exactly (also after `Task.sleep(1.6 s)` the debounced push did not add a second), label `"Agent: tighten"`, trim applied | T2 |
| `addCutInsertsExactRangeSortedAndUndoRestores()` | same | `add_cut {start:0.4,end:0.9}` → `videoRegions` contains `[0.4,0.9]` sorted; `undo` → previous regions | T2 |
| `addZoomEnablesZoomAndAddsFourKeyframes()` | same | `add_zoom {at:1.0,centerX:0.5,centerY:0.5}` → `zoomEnabled`, `zoomTimeline.allKeyframes.count == 4` | T2 |
| `addSpotlightAppliesStyleAndEnablesSpotlight()` | same | `add_spotlight {start:0.2,end:0.8,radius:150}` → one region with `customRadius 150`, `spotlightEnabled` | T2 |
| `setBackgroundWithImagePathOutsideWorkspaceIsGated()` | same | returns `NEEDS_CONFIRMATION`; with `confirmationId` from `AgentConfirmations.approve` the file is copied as `background-image.png` into the bundle (temp bundle) | T2 |
| `batchProducesOneUndoStepAndUserUndoCancelsIt()` | same | `begin_batch`, three mutations, `end_batch` → +1 entry; new batch, one mutation, `editorState.undo()` → next tool returns `USER_UNDO` and state equals pre-batch | T2 |
| `agentActivityAndLastChangeAreSetDuringCallAndNotPersisted()` | same | during a call `agentActivity != nil`; after, `lastAgentChange == (track,start,end)`; neither appears in `createSnapshot()` | T2 |
| `toolThrowingMidwayRestoresPreCallSnapshot()` | same | inject a handler that mutates then throws → state equals `pre`, result `TOOL_FAILED`, no history entry | T2 |
| `generateCaptionsToolAwaitsTranscriptionWithoutSecondPush()` | same, `.enabled(if: env["REFRAMED_RUN_WHISPER_TESTS"] == "1")` | with a downloaded model: one history entry labelled "Agent: captions" | T3, gated |

**Production**

- Upstream seams (additive, listed in `upstream-sync.md`): `HistoryEntry.label: String?` (`History.swift:3-6`); `History.pushSnapshot(_:label:)` with equality dedupe (`:24-35`); `EditorStateData: Equatable` (`ProjectMetadata.swift:463`); `EditorState.agentActivity`, `lastAgentChange` stored properties (not observed); `HistoryPopover` shows the label prefix.
- `Reframed/Agent/Tools/EditingTools.swift`: handlers for every row of `SPIKE.md` §3.2; each wraps `pre`/`post`, cancels `pendingUndoTask`, pushes with label, sets `lastAgentChange`, seeks when paused.
- `Reframed/Agent/AgentConfirmations.swift` (`@MainActor @Observable`): pending confirmations keyed by id; the chat panel binds Allow/Deny.
- UI: agent pill in `EditorTopBar.swift` (reuse `IconButton`/`FontSize`/`ReframedColors`), highlight band in `TimelineView+Overlays.swift`.

**Manual check** — "add a spotlight on the first click" → Spotlight track chip appears, preview dims around the cursor, History popover shows "Agent: …", ⌘Z removes it in one step; run a 3-tool batch and confirm one ⌘Z reverts all three.

---

## Phase 5 — Silence detection and `remove_silences` · size M · milestone 07 · depends on spike 01 for keep-slices (falls back to `videoRegions`)

**Failing tests first**

| Test | File | Assertion | Tier |
| --- | --- | --- | --- |
| `detectsGapsBelowThresholdLongerThanMinGap()` | `ReframedTests/Editor/SilenceDetectorTests.swift` | synthetic `[Float]` at 100 Hz: loud 0–1 s, silent 1–2.5 s, loud 2.5–3 s → one gap `[1.0, 2.5]` ± 0.02 with `minGap 0.8`; `minGap 2.0` → none | T1 |
| `paddingKeepsSpeechEdges()` | same | `padding 0.15` shrinks the gap to `[1.15, 2.35]` | T1 |
| `gapsContainingClicksOrWordsAreDropped()` | same | a click at 1.8 s or a word `[1.7,1.9]` removes that gap | T1 |
| `removeSilencesDryRunDoesNotMutate()` | `ReframedTests/Agent/MutatingToolsTests.swift` | `dryRun:true` returns gaps, history unchanged; without it, keep-slices equal the complement of the gaps and one history entry exists | T2 |
| `extractSamplesReadsFixtureAudio()` | `ReframedTests/Editor/AudioWaveformGeneratorTests.swift` | seam S7: `extractSamples(from: mic-2s.m4a)` returns > 0 samples at the reported rate | T2 |

**Production** — `Reframed/Editor/SilenceDetector.swift` (T1, RMS windows in dB); drop `private` on `AudioWaveformGenerator.extractSamples`; `get_silences` and `remove_silences` handlers; `Remove silences` also exposed as a button in the Audio tab (`PropertiesPanel+AudioTab.swift`) so the feature ships by hand too.

**Manual check** — record 20 s with two long pauses; "remove the silences" → Screen track shows kept slices, playback skips the gaps, ⌘Z restores.

---

## Phase 6 — Text overlay primitive · size L · milestone 07

**Failing tests first**

| Test | File | Assertion | Tier |
| --- | --- | --- | --- |
| `textOverlayDataRoundTripsAndOldProjectsDecodeWithoutIt()` | `ReframedTests/Project/ProjectMetadataTests.swift` | `EditorStateData.textOverlays` optional; a v1 `project.json` without it decodes | T1 |
| `textOverlayChangeRuleDescribesAddRemoveAdjust()` | `ReframedTests/Editor/HistoryChangeRulesTests.swift` | `regions(\.textOverlays, …)` yields "Text overlay added/removed/adjusted" | T1 |
| `renderFrameDrawsTextInsideRectAtActiveTime()` | `ReframedTests/Compositor/TextOverlayRenderTests.swift` | 128×72 buffer, solid green screen, overlay "Hi" white at (0.5,0.5) active `[0,1]`: at t=0.5 the centre region has non-green pixels; at t=1.5 it is all green | T2 golden |
| `textOverlayFadeEntryScalesAlpha()` | same | `entry: fade, duration 0.4` → at t=0.2 centre alpha ≈ 50 % (±3/255) | T2 |
| `addTextToolCreatesOverlayAndUndoStep()` | `ReframedTests/Agent/MutatingToolsTests.swift` | `add_text {text:"Intro",start:0,end:2,position:{x:0.5,y:0.2}}` → one overlay, one labelled entry | T2 |

**Production** — model + state + rule + snapshot/restore + load (12-site checklist); `ExportConfiguration.textOverlays`; `CompositionInstruction.textOverlays`; `FrameRenderer+TextOverlays.swift` drawn between spotlight and captions; HDR variant; `VideoPreviewContainer+TextOverlays.swift` with `CATextLayer`; `TimelineView+OverlayTrack.swift` and `TextOverlayEditPopover` modeled on the spotlight track; `PropertiesPanel+EffectsTab` section; tools `add_text/update_text/remove_text`.

**Manual check** — add a title card by hand and by tool; preview and export match; old project still opens.

---

## Phase 7 — Image overlay primitive · size M · milestone 07 · after phase 6

Tests mirror phase 6 (`ImageOverlayRenderTests`: a 2×2 red PNG overlay at rect (0.25,0.25,0.5,0.5) makes the centre red at t inside range; `imageIsCopiedIntoBundleAndRemovedWithOverlay()` in `MutatingToolsTests` on a temp bundle). Production reuses the overlay track and popover; image files follow the `setBackgroundImage` copy pattern with `overlay-<id>.<ext>`; `remove_image` deletes the file only if no other overlay references it. Manual check: drag an image onto the preview, then ask the agent to place a logo top-right for the first 5 s.

---

## Phase 8 — Blur region primitive · size M · milestone 07

**Failing tests first**

| Test | File | Assertion | Tier |
| --- | --- | --- | --- |
| `blurRegionBlursOnlyInsideRectInSourceCoordinates()` | `ReframedTests/Compositor/BlurRegionRenderTests.swift` | screen buffer with a sharp black/white edge inside the rect: after render the edge pixels are grey (neither < 40 nor > 215); a pixel outside the rect is unchanged | T2 golden |
| `blurRegionFollowsZoomCrop()` | same | with a `zoomTimeline` at 2× centred on the rect, the blurred area is still the same source content (compare with unzoomed render scaled) | T2 |
| `addBlurToolClampsRectToUnitSquare()` | `MutatingToolsTests` | `rect {x:0.9,y:0.9,w:0.5,h:0.5}` → stored `w/h` clamped to 0.1 | T2 |

**Production** — `BlurRegionData`, state, rule; `CompositionInstruction.blurRegions`; blur applied in `drawScreenVideo` (`FrameRenderer+Screen.swift:5`) before the zoom crop using a static `CIContext` as in `FrameRenderer+HDR.swift`; preview layer with `CIFilter` mask over `screenPlayerLayer`; chips on the Screen track; tools `add_blur/remove_blur`.

**Manual check** — blur a password field; scrub with zoom on; export and confirm the blur stays over the field.

---

## Phase 9 — Transitions and animations · size S · milestone 07 · after phases 6–8

Tests: `transitionResolversApplyToOverlays()` in `TextOverlayRenderTests` (scale entry at progress 0.5 draws the text at half size, measured by the non-background bounding box); `setTransitionToolRejectsUnknownTargetId()` in `MutatingToolsTests`. Production: `entryTransition/exitTransition/durations` on `TextOverlayData`, `ImageOverlayData`, keep-slices; reuse `computeRegionTransition`/`resolveActiveTransitionType` (`FrameRenderer+Helpers.swift:41-77`); `set_transition` tool. Manual check: fade a title in and out; slide a logo.

---

## Phase 10 — Music tools · size S · milestone 07 · depends on spike 02

Status: complete on milestone 06. Import is confirmation-bound; automatic ducking remains out of scope for v1.

Tests: `addMusicCopiesFileAndCreatesTrackWithFades()` and `duckUnderSpeechLowersVolumeInsideWordRanges()` in `MutatingToolsTests` (the second asserts the automation envelope the music model exposes, whatever spike 02 names it). Production: `add_music/set_music/remove_music` handlers over spike 02's `EditorState` API; gated when `path` is outside the workspace. Manual check: "lay a quiet music bed" → Music track appears, preview plays it under the narration.

---

## Phase 11 — Skills folder and shipping · size M · milestone 05 (folder) + 07 (all five skills)

Status: code complete on milestone 06; real-provider discovery remains a manual check.

**Failing tests first**

| Test | File | Assertion | Tier |
| --- | --- | --- | --- |
| `everyShippedSkillHasFrontmatterMatchingItsFolder()` | `ReframedTests/Agent/SkillBundleTests.swift` | for each `Reframed/Agent/Skills/*/SKILL.md`: YAML `name` equals the folder name, `description` ≤ 1024 chars, file ≤ 256 KB (Toone parser limits) | T1 |
| `skillsReferenceOnlyCatalogTools()` | same | every backticked `snake_case` token that looks like a tool name is in `AgentToolCatalog.all` | T1 |
| `workspaceMaterializerWritesBothSkillTreesAndAgentsFile()` | `ReframedTests/Agent/AgentWorkspaceTests.swift` | in a temp dir: `.claude/skills/<n>/SKILL.md`, `.agents/skills/<n>/SKILL.md`, `AGENTS.md`, `CLAUDE.md` symlink, `mcp.json`; running twice is idempotent and overwrites edits | T2 |
| `agentsFileStatesSafetyRulesAndToolNames()` | same | `AGENTS.md` contains the five rules from `SPIKE.md` §6.1 and the bundle path variable | T1 |

**Production** — `Reframed/Agent/Skills/{presentation-cut,remove-silences,spotlight-clicks,add-title-cards,music-bed}/SKILL.md` per `SPIKE.md` §5.3; folder reference in the app target; `Reframed/Agent/AgentWorkspace.swift` (materialize, token file, cleanup of `frames/` and `drafts/` older than 7 days); `AGENTS.md` template as a resource.

**Manual check** — Claude Code `/presentation-cut` and Codex `$presentation-cut` both load; the runtime lists the five skills without truncation.

---

## Phase 12 — End-to-end "presentation" demo · size M · milestone 07 · depends on everything above

**Failing tests first**

| Test | File | Assertion | Tier |
| --- | --- | --- | --- |
| `presentationScriptProducesExpectedTimeline()` | `ReframedTests/Agent/PresentationScenarioTests.swift`, `.enabled(if: env["REFRAMED_RUN_SCENARIO_TESTS"] == "1")` | replay a checked-in JSON list of tool calls (the calls `presentation-cut` is written to make) against a 20 s fixture with clicks and speech: kept duration between 8 and 14 s, ≥ 2 spotlights, ≥ 1 title card, 1 music track, exactly one history entry (batch), `undo` returns to the untouched snapshot, `project.json` and `history.json` decode | T2, gated |
| `exportDraftOfScenarioHasExpectedDurationAndSize()` | same | `export_draft` → MP4 duration ≈ kept duration, width ≤ 640 | T2, gated (`REFRAMED_RUN_EXPORT_TESTS`) |

**Production** — nothing new beyond fixes the scenario surfaces; `make test-scenario` target.

**Manual check (the acceptance demo)** — record a 2-minute product flow with narration; open the editor; type "make an awesome presentation of this"; watch: badge on, silences removed, spotlights and zooms on click clusters, three title cards, music bed, blur on any password field the agent spots in the transcript; ⌘Z once reverts the batch; press Export by hand.

---

## Phase order and sizes

| Phase | Size | Milestone | Blocked by |
| --- | --- | --- | --- |
| 1 catalog + dispatcher | M | 05 | milestone 01 fixture |
| 2 transport + auth | M | 05 | spike 03 spawn (tests do not need it) |
| 3 read-only tools | M | 05 | 1; S3 for `export_draft` |
| 11 skills folder (first skill: `spotlight-clicks`) | S | 05 | 1 |
| 4 mutating tools + labels + badge | L | 06 | 1, 2, spike 03 confirmations |
| 5 silence detection | M | 07 | 4, S7, spike 01 (fallback exists) |
| 6 text overlay | L | 07 | 4 |
| 7 image overlay | M | 07 | 6 |
| 8 blur region | M | 07 | 4 |
| 9 transitions | S | 07 | 6, 7 |
| 10 music tools | S | 07 | 4, spike 02 |
| 11 remaining skills | M | 07 | 5, 6, 10 |
| 12 end-to-end demo | M | 07 | all |

---

## Definition of done

- `make test`, `make lint`, `make build` green with zero warnings; gated suites (`test-shim`, `test-export`, `test-scenario`) green on the developer machine and listed in the milestone's `VERIFY.md`.
- Every tool in `AgentToolCatalog.all` has a handler test that asserts the state change, the single labelled history entry, and undo; every read-only tool has a test asserting no history entry.
- Every new primitive has: a golden-frame test in `ReframedTests/Compositor/`, a preview mirror, a timeline track, a Properties panel control, a change rule, and a legacy-`project.json` decode test.
- `EditorState.observeChanges()` and `createSnapshot()` are verified equal by `observedPropertiesMatchSnapshotFields()`.
- An old `.frm` from upstream `v0.14.7` opens, edits by the agent are undoable in one step each, and the exported file matches the preview for text, image, blur, and spotlight.
- `AGENTS.md` in the workspace, the allowed/denied tool lists, and the confirmation gate are exercised by tests, and a manual run confirms that `Bash` is unavailable to Claude Code and that Codex runs sandboxed.
- Every upstream file touched is listed in `planning/upstream-sync.md` with the seam name; every structural decision (shim target, socket transport, history labels) has an ADR in `planning/decisions/`.
