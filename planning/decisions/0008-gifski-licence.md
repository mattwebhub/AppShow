# 0008. Licence of the vendored gifski library

Status: accepted
Date: 2026-09-03

## Context

`AppShow/Libraries/gifski/libgifski.a` is a prebuilt static library linked into the app for GIF export (`AppShow/Compositor/VideoCompositor+GIFExport.swift`). gifski (`ImageOptim/gifski`) is licensed AGPL-3.0-or-later; its author offers commercial licences for closed-source use. Upstream ships only `gifski.h`, `libgifski.a`, and `module.modulemap`, no licence text. The app itself is MIT. AGPL obligations attach to distribution, not to private development.

## Decision

The product stays fully open source. We keep gifski, ship the AGPL-3.0 text next to the library (`AppShow/Libraries/gifski/LICENSE`), credit gifski in `AppShow/Credits.html` and the README, and offer the combined distributed app under AGPL-compatible terms (source always published). No commercial gifski licence is needed.

## Consequences

- GIF export stays as upstream built it; merges stay simple.
- Any future move to closed-source or paid distribution reopens this decision: replace gifski or buy a commercial licence first.
- The test bundle must not link `libgifski.a` directly (see `docs/architecture/07-testability.md`).
- Owner decided on 2026-09-03: "we will keep fully open source".
