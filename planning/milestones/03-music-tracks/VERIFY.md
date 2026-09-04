# Verify milestone 03

| Check | Command or steps | Expected | Result |
|-------|------------------|----------|--------|
| Builds | `make build` | exit 0, no new warnings | pass |
| Tests | `make test` | all green | pass, 332 tests in 39 suites |
| Gated | `TEST_RUNNER_REFRAMED_RUN_EXPORT_TESTS=1 TEST_RUNNER_REFRAMED_RUN_AUDIO_ENGINE_TESTS=1 make test` | green | pass (3 export, 2 engine) |
| Lint, format | `make lint && make format && git diff --exit-code` | clean | pass |
| Pre-feature project | open a `.frm` made before this milestone | no Audio rows, no history entry | |
| Import | add an mp3 and a wav | rows appear at the playhead, waveform drawn, bundle holds `audio-*` copies | |
| Edit | move, trim both edges, set fades, mute | chip follows, history labels readable, undo works | |
| Preview | play from before, inside, after a track; seek; cut a gap over it | music audible only inside the track, restarts correctly after a gap | |
| Export | MP4 with two tracks and one cut | music present at the right places, fades audible, file plays | |

Manual rows need a human with the app; steps in `planning/features/music-tracks/TASKS.md`.

Closed on: pending manual checks; PR https://github.com/mattwebhub/Reframed/pull/5
