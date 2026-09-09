# App Store design package

Status: design review. Two owner-supplied screenshots from the direct edition now fill the hero and pace layouts; three captures remain pending. The owner explicitly requested review before anything is submitted. No assets, metadata or build have been submitted.

The five images use the existing brushstroke identity, ink background, restrained accent colors and large system typography. Every image has one feature claim and space for a complete, authentic AppShow Store window. The editable [shot list](shots.json) supplies copy and capture direction; [slide.html](slide.html) controls the layout.

## Render and review

```sh
/usr/bin/python3 -B scripts/render-store-assets.py --capture-edition direct
open dist/app-store-submission/design/index.html
```

The renderer finds an installed Playwright Chromium headless shell, or accepts another compatible executable through `--chrome`. The system Google Chrome executable is the fallback; its screenshot process timed out on the preparation machine, so the installed headless shell was used for verification. Rendering uses a temporary profile, embedded local images and no account session.

The renderer makes five opaque RGB PNGs at 2880 × 1800, a local review gallery, a copy of the existing 1024-pixel macOS icon and `asset-evaluation.json`. It verifies PNG dimensions, color format and source/output hashes. Missing captures produce conspicuously labeled layout proofs. These are not submission images. `--require-captures` fails before rendering if any required input is absent.

Native PNG inputs go in ignored `dist/app-store-submission/captures/`, using the names in the shot list. Rendered outputs and private source footage also stay in ignored `dist/`. Do not substitute the inherited Reframed screenshot, generated UI, or a different app's window. The renderer does not crop or retouch the app capture; it places the complete image inside the layout.

The supplied September 9 screenshots at 19:51:29 and 19:54:40 show the real editor, assistant conversation, preview, cuts and speed tracks. They are used unchanged in images 01 and 02. `--capture-edition direct` records that provenance in the report and adds a visible design-review label. Their assistant UI differs from the current Store validation target, so they establish a design direction rather than Store candidate parity. The visible imported music title and demonstration content remain part of the final visible-content/rights review; no audio has been included in these still images.

## Footage prepared locally

The owner suggested the latest Desktop video. `routine-demo-v2.mp4` is 62.05 seconds, HEVC, 3836 × 2476 at 60 fps, with AAC audio. A sampled frame shows a Toone routine demonstration. It is suitable as sample content inside AppShow, subject to visible-content and rights review; it does not itself demonstrate AppShow's interface.

An independent `Routine demo.appshow` project was prepared under `dist/app-store-submission/demo-project/` with a copy of that export as its screen track. It has no assistant history, external audio or original project metadata. This is a presentation project, not an automated test fixture. The original Desktop export and original projects remain unchanged.

## Acceptance evaluation

- [ ] Each native capture comes from the intended Store candidate; record commit, version/build, architecture, macOS version and capture date.
- [ ] The shown controls and edits really work in that edition. A1/A2/A4/A7/A11 feature decisions and runtime gates remain applicable.
- [ ] Full-size and thumbnail review confirms readable titles, uncut windows, correct colors and no exposed personal/client material.
- [ ] Rights to the sample content, icon and visible third-party material are recorded against A8.
- [ ] All five source captures exist; render with `--require-captures`, inspect every PNG and retain the generated report.
- [ ] The owner reviews the completed screenshot set and explicitly approves submission. Approval of layout proofs alone does not approve later screenshots.

## Optional 24-second preview storyboard

| Time | Capture from the actual AppShow Store edition |
| --- | --- |
| 0–5 s | Open the prepared project and play a short section. Introduce the recording-to-editor workflow. |
| 5–10 s | Make one visible cut and undo/reapply it. |
| 10–15 s | Change the background and spacing with the real controls. |
| 15–20 s | Add or select a zoom region and play through it. |
| 20–24 s | Open the export sheet and show the supported output choices. |

Record fresh AppShow UI footage when screen capture is available. Use only cleared narration/audio. Do not transcode the Desktop demonstration and label it as an AppShow app preview. The storyboard is prepared; a preview video has not been recorded or rendered.

Apple's [Mac screenshot specification](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) includes 2880 × 1800 at 16:10. Its [preview specification](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/) calls for Mac landscape 1920 × 1080, 15–30 seconds, at most 30 fps and 500 MB; H.264 uses the documented profile, bitrate and audio settings. The [app icon](https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon/) is supplied through the Xcode build. Recheck these requirements at upload time.
