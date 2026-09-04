# Test plan: Agent editing tools

| Phase | Proof | Status |
|---|---|---|
| P1 transaction | labeled history round trip; equal snapshot dedupe; failed-call rollback | green |
| P1 tools | set trim, add zoom, add spotlight, read-only refusal, destructive MCP hints | green |
| P2 cuts | exact keep-slice operations, normalization, undo | green |
| P3 batches | one undo entry, timeout, user-undo cancellation | green |
| P4 confirmations | allow/deny/expiry and normalized-operation binding | green |
| P5 bridge/UI | authenticated tool listing, live activity badge and timeline highlight | green |
| P6 settings/export | presentation settings and timed captions undo; exact-path confirmation and no overwrite | green |
| P7 primitives | silence preview/removal, text CRUD, confirmed image import and CRUD, blur CRUD, compact overlay results | green |
| P8 runtime E2E | both providers call a read and mutation through the shim | green |
| P9 transitions | text/image/slice targets update and undo; remapping preserves settings; golden midpoint frames | green |
| P10 music tools | confirmed import, update/remove/undo, fades, compact timeline result | green |
| P11 skills | valid provider skill trees, catalog-only tool references, idempotent workspace materialization | green; runtime discovery manual |

Manual verification belongs in `planning/milestones/06-agent-tools-editing/VERIFY.md`.
