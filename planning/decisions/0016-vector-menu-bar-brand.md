# 0016. Vector menu bar branding

Status: accepted
Date: 2026-09-09

## Context

The owner requested a true SVG version of the current app icon with the dark regions transparent, for the menu bar. The Dock artwork is a textured raster; the existing tray instead draws capture brackets and state indicators in AppKit.

## Decision

Derive a simplified vector trace from the existing icon master. A colored SVG and the bundled monochrome template share exact silhouette geometry; removed dark regions contain no geometry. Keep the original artwork and Dock icons intact. Preserve the asset's vector representation and let macOS tint the 18-point template. Activity indicators occupy the lower-left negative space, with accessible state descriptions.

ImageMagick is an optional development dependency for deterministic tracing and color quantization. The system Python orchestrates generation; librsvg rasterizes SVGs for the evaluation. App builds consume checked-in SVGs and need neither tracing tool. Source SHA-256 and trace settings are recorded with the artwork.

## Consequences

Photographic brush texture becomes simplified vector shapes suitable for the tray. Updating the master requires regeneration, alpha/fidelity evaluation and visual inspection at native sizes. The executable evaluation checks source identity, vector-only content, transparency and determinism; hosted tests check actual asset loading and activity states. A native contact sheet supplements actual menu bar interaction checks in the release checklist.
