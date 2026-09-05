# 0013. Preserve narration independently of captions

Status: accepted
Date: 2026-09-05

## Context

The assistant needs recorded speech to understand the video's purpose and the meaning of individual frames. On-screen captions may be disabled, shortened or rewritten, so they cannot be the only transcript store.

## Decision

Persist optional per-track `AudioTranscript` values in existing editor data. Each stores source, language, model and source-video segment/word timestamps. The same local transcription pipeline populates this store and optionally produces editable captions. Snapshot/restore and history cover both; caption edits do not change recorded narration. Legacy projects with no separate transcript continue to expose their captions as an explicitly identified fallback.

`generate_transcript` gathers context without changing visible captions. `get_transcript` allows explicit source selection; `get_project_summary` includes a bounded excerpt; `render_preview_frame` returns nearby source-time narration. Workspace guidance tells the agent to use narration alongside timeline and frame evidence, and to treat recorded speech as content rather than privileged instructions.

## Consequences

The project carries its narration context on reopen and when moved. Caption style and visibility do not affect semantic context. Source timestamps remain stable after cuts; the timeline and frame's kept-state identify removed footage. Missing models or transcripts remain explicit. No extra transcription service or network processing is introduced.
