# 0008. Licence of the vendored gifski library

Status: proposed
Date: 2026-09-03

## Context

`Reframed/Libraries/gifski/libgifski.a` is a prebuilt static library linked into the app for GIF export (`Reframed/Compositor/VideoCompositor+GIFExport.swift`). gifski upstream (`ImageOptim/gifski`) is licensed AGPL-3.0; the folder contains only `gifski.h`, `libgifski.a`, and `module.modulemap`, no licence text and no source. The app itself is MIT. AGPL obligations attach to distribution of a combined work, not to private development, so this does not block local work or testing.

## Decision

Pending. Options when we distribute:

1. Keep gifski and publish the fork's complete source under AGPL-compatible terms, adding the gifski licence text to `Reframed/Credits.html` and the repo.
2. Replace gifski with an MIT/Apache GIF encoder (ImageIO `CGImageDestination` with `kCGImagePropertyGIFDictionary`, lower quality; or a permissively licensed quantizer) and delete `Libraries/gifski`.
3. Drop GIF export.

Recommendation: decide before the first external release; keep gifski until then so upstream merges stay simple.

## Consequences

To be filled when accepted. Whatever is chosen, the test bundle must not link `libgifski.a` directly (see `docs/architecture/07-testability.md`).
