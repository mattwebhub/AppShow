# 0009. Provenance of code copied from the Toone desktop app

Status: accepted
Date: 2026-09-03

Accepted 2026-09-04 under the owner's instruction to proceed; both repositories are owned by the same account. Reversible by deleting AppShow/Agent/.

## Context

Feature 03 (agent chat) ports stream parsers, command builders, readiness detection, and a markdown renderer from `Projects/toone/apps/toone-desktop/Toone`. That folder has no LICENSE file; its README claims MIT with a dangling link, the monorepo root is a private package with no license field, and sibling packages are MIT. Both repositories are owned by the same GitHub account as this fork. This app is MIT.

## Decision

Pending owner confirmation. Proposed: the owner authorizes copying from the Toone desktop app into this repository under this repository's MIT license, and records that authorization by accepting this ADR before the first commit that contains copied code. Copied files keep no vendor header (the codebase has no comments) but the attack plan lists their origin. Adding a LICENSE to `apps/toone-desktop` is recommended when convenient.

## Consequences

- Copying is unblocked; the copy list lives in `docs/features/03-agent-chat/ATTACK-PLAN.md` ("Toone files to copy first") and is not duplicated here.
- Toone is Swift 5 without strict concurrency, so process and session classes are rewritten as actors rather than copied; parsers and builders copy nearly as-is.
