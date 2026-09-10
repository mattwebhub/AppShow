# AppShow brand assets

AppShow's identity is the supplied blue-to-coral brushstroke artwork. Let the texture carry the expression; keep typography and surrounding surfaces quiet.

## Files

| File | Purpose |
| --- | --- |
| [artwork.png](artwork.png) | Original 1254 × 1254 artwork supplied by the project owner on September 8, 2026, preserved unchanged |
| [app-icon.png](app-icon.png) | 1024 × 1024 macOS icon master with genuine alpha transparency |
| [README icon](../assets/app-icon.png) | 256 × 256 icon for documentation |
| [Banner](../assets/banner.svg) | Self-contained 1280 × 640 SVG with embedded artwork and editable typography |
| [Social preview](../assets/social-preview.png) | 1280 × 640 PNG ready for the repository's social-preview setting |

The app asset catalog contains all ten macOS size/scale slots, from 16 points at 1× through 512 points at 2×. The icon's artwork occupies an 824-pixel rounded square inside the 1024-pixel canvas, with transparent margins and a restrained shadow.

## Regenerate

The checked-in exports are ready to use. To rebuild them after an intentional brand change, run:

```sh
make brand
```

This uses macOS `sips`, the Python provided with Xcode at `/usr/bin/python3`, and `rsvg-convert` from librsvg. Install librsvg separately if you want to regenerate the graphics. These tools are not extra requirements for building AppShow itself.

The generator is [scripts/generate-brand-assets.py](../../scripts/generate-brand-assets.py). It builds the icon wrapper from the original artwork, checks for an alpha channel, fills the asset catalog, and exports the banner. Intermediate SVG/JPEG files stay under the ignored `.build/brand/` directory. Text remains text in the banner SVG; no remote fonts or external image requests are needed.

## Visual guidance

- Preserve the brushstroke composition and color order. Use the supplied icon for compact placements.
- Use the full artwork as an expressive background, with generous dark space behind copy.
- The supporting palette is ink `#07111e`, chalk `#f5f8fc`, muted text `#b8c6d8`, and mint `#80e4be`.
- Use a system sans serif, clear hierarchy, and a small amount of copy. Keep text legible at narrow README widths.

## Provenance

The source artwork was supplied by the project owner. Two built-in imagegen concept passes explored the app-icon treatment with these prompts:

1. Preserve the exact supplied brushstroke artwork; fit it into a centered rounded macOS icon with transparent margins and a subtle shadow, without adding text, symbols, or a bevel.
2. Remove the painted checkerboard outside that icon and export a real alpha channel, keeping the icon unchanged.

Both concept outputs were opaque, so neither is shipped. The production assets use the original supplied image inside a deterministic SVG wrapper, exported with librsvg. This keeps the source artwork intact and makes transparency reproducible.

The [editor reference](../assets/editor-preview.jpg) is the existing repository screenshot inherited from Reframed, resized to 1920 pixels and exported as JPEG from its [original attachment](https://github.com/user-attachments/assets/ea3d9554-8695-4d98-846f-90c422b25550). The README labels its provenance. A current AppShow screenshot remains a manual presentation follow-up; do not present the reference as a screenshot of newly added features.

## Repository presentation

The prepared social preview can be uploaded in the repository settings when these changes are published. The README uses local assets, so previews work in forks and checkouts without depending on an attachment hosted elsewhere.

## Transparent vector and menu bar icon

[appshow-transparent.svg](appshow-transparent.svg) is a vector rendition of the current icon with its dark background removed. It contains traced quadratic paths and 32-color artwork, with transparent negative space. It deliberately simplifies photographic texture for small sizes. The original artwork and Dock icon remain the source masters.

The app loads [MenuBarMark.svg](../../AppShow/Assets.xcassets/MenuBarMark.imageset/MenuBarMark.svg) from the asset catalog as an 18-point template with preserved vector representation. Its black paths represent the visible strokes; the background and removed dark areas have no geometry. macOS tints the template for the menu bar appearance. Selection, countdown, recording, pause, processing pulse and editing indicators occupy the lower-left negative space. The icon also describes its state for accessibility.

```sh
make tray
make eval-tray
make preview-tray
make test T=MenuBarIconTests
```

`make tray` uses ImageMagick (`magick`) and the system Python to trace the existing master at 256 pixels. Pixels survive only when alpha exceeds 240/255, their brightest RGB channel exceeds 110/255, and their encoded-channel luminance exceeds 42/255. Small islands are removed and contours are simplified into quadratic paths; the colored version and template share the same silhouette. [tray-source.json](tray-source.json) records the source SHA-256 and settings. No raster image is embedded in either SVG. These regeneration tools are not needed to build the app from the checked-in assets.

The [asset evaluation](../../scripts/evaluate-tray-icon.py) also uses `rsvg-convert` to check real rasterized alpha, compare the shape with source pixels, validate vector-only XML and template metadata, and regenerate twice to prove determinism. It writes `.build/brand/tray-eval.json` and exits nonzero on failure. Exact geometry is shared; a bounded edge-antialiasing tolerance accounts for the colored version's clipping.

See the [native state preview](tray-preview.png) for every state at 1×/2× with light/dark template tints. This contact sheet renders the production `MenuBarIcon` with the compiled asset; actual menu bar highlight and interaction checks remain in the [public-release checklist](../../planning/releases/PUBLIC-RELEASE-CHECKLIST.md).
