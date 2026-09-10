# AppShow presentation assets

The owner approved using the updated Figma set in App Store Connect on September 10 and asked to prepare the release. The first frame was removed; use the four-frame set below. All four screenshots are uploaded and processed in App Store Connect app 6810625498; their numbered order was verified after reload and in Media Manager. No new recordings are requested.

The editable [Figma presentation](https://www.figma.com/design/5nqdxqb29569Umo2dBg9xT) contains four 2880 × 1800 frames. It uses the existing AppShow icon and Rubik, the font used by Toone's web landing page. Each slide has its own feature view:

| Frame | Feature and native capture |
| --- | --- |
| 1 · Record. Tell AI. Show. (`5:2`) | Owner’s hero headline with the real Store conversation, MCP activity and provider controls |
| 2 · Cut the waiting. (`6:2`) | Selected speed region and pacing controls |
| 3 · Make it yours. (`7:2`) | Background palette, canvas and framing controls |
| 4 · Ready to share. (`7:12`) | Owner’s enlarged native export sheet and output choices |

Keep headlines, copy, icon and image fills editable. Do not replace the app interface with generated UI. Provider labels describe the integration; a provider account is required. Both providers now complete live Debug Store MCP edits; milestone 21 retains exact universal-candidate and recovery acceptance.

The current upload pack is under ignored `dist/app-store-submission/2026-09-10-owner-approved/`. Its `screenshots/` directory holds fresh native Figma exports; `upload/` holds the four numbered RGB PNGs without alpha. Decoded pixel hashes prove the upload copies are visually identical to the owner’s exports. `screenshot-manifest.json` records order, frame IDs, dimensions and SHA-256 hashes. Use only these four upload files. The older five-frame pack under `2026-09-09-rubik/` is historical.

## Cropped demonstration source

The working project is `dist/app-store-submission/demo-project/Routine demo.appshow`. It was prepared from the owner's 62.05-second Toone routine export, which is sample content inside AppShow rather than a recording of AppShow's interface.

The previous export contained a baked matte. The replacement screen track crops 3836 × 2476 to 3452 × 2228 at x=192, y=124, removing approximately five percent from each edge. The HEVC output retains the source duration and copied audio stream. Project timing and overlays remain editable. The original working media is preserved as `routine-demo-uncropped.mp4` in the asset directory; the Desktop original and original projects remain untouched. `source-crop.json` records the operation.

## Review scope

These are owner-approved listing assets. The hero retains the earlier real Store conversation; pacing, canvas and export stills originate from the Direct build with the cropped source. They do not establish final Store candidate acceptance. Runtime, rights, distribution signing, account and App Review gates remain in the [readiness evaluation](../../planning/releases/APP-STORE-EVAL.md).

Apple's [Mac screenshot specification](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) includes 2880 × 1800. No preview video is included in this upload pack; the owner will record it later.

The owner removed the former first frame and moved the hero headline into the agent frame. Native Figma inspection and export preserved those edits, the gray hero, the three feature colors and the enlarged export sheet. No Figma content was changed during this upload preparation.

The external project failed to open during the earlier capture pass, then opened successfully in both the Debug Store app and the fresh universal archive on September 10. This successful retest does not explain the earlier failure or close the complete file-access matrix. The corresponding Debug Store chat failures are resolved; final universal-candidate and recovery checks remain open.
