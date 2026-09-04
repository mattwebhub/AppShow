# 0001. Fork jkuri/Reframed as the base of this product

Status: accepted
Date: 2026-09-03

## Context

We want a macOS screen recorder with an editor and export pipeline. `jkuri/Reframed` (MIT, Swift 6, SwiftUI, ~33k lines, actively released, v0.14.7 on 2026-04-16) already implements capture, `.frm` project bundles, a timeline editor, cursor effects, zoom keyframes, captions via WhisperKit, and MP4/MOV/GIF export. It has no tests and no CI.

## Decision

Fork the repository, keep `upstream` as a remote, and build our product on top of it rather than starting from scratch. The fork began as `mattwebhub/Reframed` and became `mattwebhub/AppShow` in the identity migration (ADR 0005). We keep the MIT license and attribution.

## Consequences

- We inherit a large, untested codebase; milestone 01 puts the pure-logic layer under test before we change behavior.
- We must keep merging upstream to benefit from fixes; see `planning/upstream-sync.md`.
- Everything we add lives in folders upstream does not touch to keep merges cheap.
