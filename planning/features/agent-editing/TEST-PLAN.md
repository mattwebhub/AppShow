# Test plan: Agent editing tools

| Phase | Proof | Status |
|---|---|---|
| P1 transaction | labeled history round trip; equal snapshot dedupe; failed-call rollback | green |
| P1 tools | set trim, add zoom, add spotlight, read-only refusal, destructive MCP hints | green |
| P2 cuts | exact keep-slice operations, normalization, undo | green |
| P3 batches | one undo entry, timeout, user-undo cancellation | green |
| P4 confirmations | allow/deny/expiry and normalized-operation binding | green |
| P5 bridge/UI | authenticated tool listing, live activity badge and timeline highlight | green |
| P6 export/import | confirmation, user-selected destination, no overwrite, cancellation | planned |
| P7 runtime E2E | both providers call a read and mutation through the shim | planned |

Manual verification belongs in `planning/milestones/06-agent-tools-editing/VERIFY.md`.
