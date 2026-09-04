# Verify milestone 07

Run on a clean clone before closing the milestone. Record the date and commit.

| Check | Command or steps | Expected | Result |
|-------|------------------|----------|--------|
| Builds | `make build` | exit 0, no warnings introduced | |
| Tests | `make test` | all green | |
| Format | `make format && git diff --exit-code` | no diff | |
| Lint | `make lint` | clean | |
| Silences, no audio | open a screen-only `.frm`, Video tab | Silences section greyed out | |
| Silences, preview | record 20 s with two long pauses, Video tab, Preview | line reads "2 silences, N s removed", timeline unchanged | |
| Silences, apply | press Apply | Cuts track appears with the kept slices, playback jumps over the pauses | |
| Silences, undo | ⌘Z once | previous slices restored; History popover row reads "Silences removed" | |
| Silences, existing cut | cut once by hand, remove one slice, then Apply | the removed slice stays removed, silences cut only inside kept slices | |
| Manual smoke | record 5 s of screen, open editor, export MP4 | file plays | |
