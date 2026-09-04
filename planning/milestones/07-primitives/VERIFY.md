# Verify milestone 07

Run on a clean clone before closing the milestone. Record the date and commit.

| Check | Command or steps | Expected | Result |
|-------|------------------|----------|--------|
| Builds | `make build` | exit 0, no warnings introduced | pass (2026-09-04, blur regions) |
| Tests | `make test` | all green | pass, 379 tests in 39 suites (2026-09-04) |
| Format | `make format && git diff --exit-code` | no diff | pass (2026-09-04) |
| Lint | `make lint` | clean | pass (2026-09-04) |
| Blur export gate | `TEST_RUNNER_REFRAMED_RUN_EXPORT_TESTS=1 make test T=ExportPipelineTests` | blur configuration exports through the compositor | pass, 3 tests (2026-09-04) |
| Transition automation | focused mutation, remapping, and golden-render suites | tool updates text/image/slice targets; cut remapping preserves settings; midpoint fades render | pass (2026-09-04) |
| Silences, no audio | open a screen-only `.frm`, Video tab | Silences section greyed out | |
| Silences, preview | record 20 s with two long pauses, Video tab, Preview | line reads "2 silences, N s removed", timeline unchanged | |
| Silences, apply | press Apply | Cuts track appears with the kept slices, playback jumps over the pauses | |
| Silences, undo | ⌘Z once | previous slices restored; History popover row reads "Silences removed" | |
| Silences, existing cut | cut once by hand, remove one slice, then Apply | the removed slice stays removed, silences cut only inside kept slices | |
| Text overlay, add | open any `.frm`, Effects tab, Add Text | Overlays track animates in with a "Title" chip of 3 s at the playhead; the preview shows a white title on a black pill in the centre | |
| Text overlay, edit | right-click the chip, change the text, size, position, colours, transitions | preview updates live; the chip text truncates with the chip width; the row in the Effects tab seeks to the overlay | |
| Text overlay, drag | drag the chip and its edges; switch the timeline to compressed mode | chip moves and resizes within the recording; read-only in compressed mode like the other tracks | |
| Text overlay, export | export MP4 with one overlay that fades in and slides out | the exported frame matches the preview at the same time; fade and slide play at the same moments | |
| Text overlay, undo | ⌘Z after adding | overlay disappears; History popover row reads "Text overlay added" | |
| Image overlay, add | open any `.frm`, Effects tab, Add Image; cancel once, then choose a transparent PNG | cancel adds nothing; chooser is limited to images; the image appears for 3 s at the playhead with transparency preserved | |
| Image overlay, edit | right-click the image chip; change width, corners, opacity, shadow, position, offsets and transitions | chip shows the photo icon and source name; every control updates the preview live | |
| Image overlay, drag | drag the image chip and its edges; switch the timeline to compressed mode | chip moves and resizes within the recording; it is read-only in compressed mode | |
| Image overlay, export | export with overlapping text and image overlays using fade, scale and slide | image draws after text and before captions; exported frames match the preview at the same times | |
| Image overlay, portability | copy the `.frm`, reopen it, then remove its `image-*` file and reopen | copied project retains the image; missing file drops the overlay and logs a warning | |
| Blur, add and edit | Effects > Add Blur; adjust left, top, width, height and radius; drag and resize the chip | preview updates live; the rectangle remains inside the source; one History entry describes each settled edit | |
| Blur, zoom and export | cover a sharp field, enable 2× zoom, scrub, then export SDR and HDR | blur follows the selected source pixels and exported frames match preview | |
| Blur, cuts and undo | span a blur across two kept slices, export, then undo its creation | both exported pieces stay blurred; one Undo removes the region | |
| Agent transition | ask either provider to fade a title and slide a logo; Undo each call | timeline and preview update immediately; each call creates one labelled History row | |
| Manual smoke | record 5 s of screen, open editor, export MP4 | file plays | |

Silence, text-overlay, image-overlay, blur, agent-transition and manual-smoke rows need a human with the app. The primitive branch gate was rerun after T7 (379 tests in 39 suites plus 3 gated export tests); transition automation passes in the milestone 06 integration suite (669 tests in 76 suites).
