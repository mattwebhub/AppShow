# Verify milestone 03

| Check | Command or steps | Expected | Result |
|-------|------------------|----------|--------|
| Builds | `make build` | exit 0, no new warnings | |
| Tests | `make test` | all green | |
| Gated | `TEST_RUNNER_REFRAMED_RUN_EXPORT_TESTS=1 TEST_RUNNER_REFRAMED_RUN_AUDIO_ENGINE_TESTS=1 make test` | green | |
| Lint, format | `make lint && make format && git diff --exit-code` | clean | |
| Pre-feature project | open a `.frm` made before this milestone | no Audio rows, no history entry | |
| Import | add an mp3 and a wav | rows appear at the playhead, waveform drawn, bundle holds `audio-*` copies | |
| Edit | move, trim both edges, set fades, mute | chip follows, history labels readable, undo works | |
| Preview | play from before, inside, after a track; seek; cut a gap over it | music audible only inside the track, restarts correctly after a gap | |
| Export | MP4 with two tracks and one cut | music present at the right places, fades audible, file plays | |

Closed on: (date, commit, PR)
