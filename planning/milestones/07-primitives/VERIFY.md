# Verify milestone 07

Run on a clean clone before closing the milestone. Record the date and commit.

| Check | Command or steps | Expected | Result |
|-------|------------------|----------|--------|
| Builds | `make build` | exit 0, no warnings introduced | pass (2026-09-04, image overlays) |
| Tests | `make test` | all green | pass, 366 tests in 37 suites (2026-09-04) |
| Format | `make format && git diff --exit-code` | no diff | pass (2026-09-04) |
| Lint | `make lint` | clean | pass (2026-09-04) |
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
| Manual smoke | record 5 s of screen, open editor, export MP4 | file plays | |

Silence, text-overlay, image-overlay and manual-smoke rows need a human with the app. The automated gate was rerun after T6 (366 tests in 37 suites).
