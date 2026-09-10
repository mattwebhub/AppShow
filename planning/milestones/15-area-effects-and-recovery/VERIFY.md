# Area effects and recovery verification

September 8, 2026. Local branch: `webcam-presentation-and-review`.

## Automated checks

- Full suite: 752 tests in 87 suites pass.
- Area geometry: selected rectangle fits inside the crop; cursor movement cannot override it; legacy keyframes decode and retain cursor following; invalid geometry/timing is rejected.
- Editor and agent: area targets survive snapshot encoding and Auto Zoom regeneration; overlaps fail without changing the timeline; Undo restores the previous zoom state.
- Rendering: crop resolution uses source time across cuts; a pixel test proves the selected content fills the output only during its selected interval. Existing timed/source-space blur pixel tests pass.
- Microphone: removal silences the track immediately, persists through snapshot restore, supports Undo, leaves system audio unchanged, and preserves source bytes and audio regions. Export already excludes microphone sources at effective volume zero.
- Recovery: early EOF preserves partial replies; checkpoints survive reopening; resumed and fresh-session retries retain context without duplicating the user request; terminal provider errors release a process that stays alive. Fixtures use local subprocesses and isolated storage.
- Final `make format`, strict lint, and Debug build pass without warnings. Project plist, signature verification, and `git diff --check` pass.
- Seven gated export tests pass, including area zoom with timed blur in both SDR and HDR. Six recovery tests pass again against the final build.
- The updated Debug application was reopened after the test host exited.

## Manual checks

- [ ] Right-click the Mic label and waveform, remove it, verify silence, then Undo or unmute in Audio properties.
- [ ] Draw zoom and blur selections in the source-frame picker, including portrait recordings and a range near the end. Inspect the corresponding timeline controls.
- [ ] Preview a fixed area while the cursor moves elsewhere; inspect the exported video and timed blur visually.
- [ ] Interrupt a real Codex/Claude Code provider session and use Retry. Exercise Start fresh with an unavailable provider session.

No real provider account was used for recovery tests. No changes have been pushed.
