# Milestone 06: agent editing tools

Goal: the single persisted project conversation can inspect and safely edit the open timeline through authenticated typed tools, with visible progress and reversible history.

Source of truth: `planning/features/agent-editing/` and phases 4 onward in `docs/features/04-agent-tools/ATTACK-PLAN.md`.

## Exit criteria

- Both supported providers discover the same authenticated tool catalog through the bundled shim.
- Every mutation is schema-validated, visible immediately, and represented by exactly one labeled undo step per call or batch.
- Failure, denial, cancellation, timeout, and user undo leave a coherent project.
- External paths and export require explicit confirmation; exports never overwrite silently.
- Automated and manual rows in `VERIFY.md` pass.
