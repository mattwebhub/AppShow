# Milestone 11 verification

727 tests in 82 suites pass. Format, strict lint, project validation and Debug build pass without compiler warnings. Six gated export tests pass, including six parameterized webcam variants (fullscreen, left half and right third in SDR/HDR), for eleven encoded export cases. Hardware microphone/webcam behavior, real-model transcription quality and live-provider interaction require the manual checks in ../../features/webcam-voice/TEST-PLAN.md.

Red evidence: /tmp/appshow-voice-silence-red.log (stale cut overwrite, immediate Undo, export exclusion), /tmp/appshow-split-red.log (missing split geometry/contracts), /tmp/appshow-caption-red.log (missing voice/generation seam), /tmp/appshow-voice-tools-red.log (missing caption tool), /tmp/appshow-stereo-red.log (opposite-phase stereo misclassified as silence), /tmp/appshow-drift-red.log (missing source-clock alignment), /tmp/appshow-model-red.log (missing isolated model download seam), /tmp/appshow-corner-red.log (missing radius scaling seam).


Final local evidence: /tmp/appshow-spoken-final-tests.log, /tmp/appshow-spoken-lint.log, /tmp/appshow-spoken-build.log, /tmp/appshow-spoken-exports.log. Spoken-context red/green evidence is in /tmp/appshow-spoken-red.log and /tmp/appshow-spoken-green.log; canceled-batch red evidence is in /tmp/appshow-voice-batch-red.log. Frame pixel checks cover all four split layouts at entry, settled state and exit.

The initial full run found an obsolete timer-implementation assertion and exact floating-point comparisons; the tests now assert no extra undo entry and subpixel geometry tolerance. Later test attempts hit disk exhaustion during Xcode diagnostic collection; generated AppShow test artifacts and stale compiler caches were pruned before successful validation. Source recordings were not modified by this work.

The running app instance predates this build. Restart AppShow to load the new code for manual verification. No GitHub push or publication was performed.
