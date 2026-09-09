# Milestone 20 verification

Local preparation evidence, 2026-09-09. Final captures, authenticated account setup and submission remain incomplete.

| Check | Result |
| --- | --- |
| Suggested footage | Latest Desktop export inspected with ffprobe and one extracted frame: 62.05 seconds, 3836 × 2476, HEVC/60 fps, AAC. It shows a Toone demonstration, not AppShow UI. |
| Presentation project | Independent exported-video copy and valid `Routine demo.appshow` metadata prepared under ignored `dist/`; opened in AppShowStore with an editor window observed through Accessibility. Original projects/export unchanged. |
| Screen capture | `CGPreflightScreenCaptureAccess()` and the explicit system request returned false. Window-specific `screencapture` failed. System Settings opened; native capture remains pending. Accessibility is available separately. |
| Apple access | App Store Connect login reached. Chrome and Safari site-scoped session imports found no saved Apple session. System browser opened for owner authentication. No authenticated account inspection or account changes. |
| Layout rendering | Five 2880 × 1800 opaque 8-bit RGB PNGs rendered with the installed Chromium headless shell. All five inspected visually. Canonical gallery: `dist/app-store-submission/design/index.html`; initial review copy: `dist/app-store-submission/review/index.html`. |
| Asset evaluator | All five explicitly report `layout-proof-only`, all capture inputs missing, `submissionReady: false`. Icon copy is the unchanged 1024-pixel macOS master. |
| Missing-capture guard | `--require-captures` exited 2 before rendering and listed all five required files. |
| Source checks | Python syntax, JSON identifiers, documentation links, `git diff --check`, `make format` and warning-free `make build` pass. No runtime source changed; app tests were not rerun. |
| Owner review | Gallery opened and PNG folder revealed in Finder. User explicitly requires review before submission. Layout approval and final-image approval are both pending. |

The regular AppShow process was brought back to the foreground after the owner asked about the assistant panel. The Store validation build omits it provisionally; no assistant history was modified or deleted. The initial five-image design set covers the currently enabled Store editor features and does not settle the shipping assistant decision.

## Owner-supplied screenshot follow-up

The owner authorized use of Desktop screenshots. The full editor captures at 19:51:29 and 19:54:40 were inspected and copied unchanged to the hero and pace input slots. They show the direct-edition assistant, video preview and actual cut/speed timeline regions. The regenerated gallery labels both as direct-edition design review and leaves the other three as pending-capture proofs. Source hashes and dimensions are recorded in the local `asset-evaluation.json`; original screenshots are unchanged. These captures do not close Store candidate parity or authorize submission.
