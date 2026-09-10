import argparse
import base64
import hashlib
import html
import json
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def default_browser():
    shells = list((Path.home() / "Library/Caches/ms-playwright").glob("chromium_headless_shell-*/chrome-headless-shell-mac-*/chrome-headless-shell"))
    return max(shells, key=lambda path: path.stat().st_mtime) if shells else Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")


def embedded(path):
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


def png_info(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError(f"Invalid PNG: {path.name}")
    width, height, depth, color = struct.unpack(">IIBB", data[16:26])
    return {"width": width, "height": height, "bitDepth": depth, "colorType": color}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description="Render AppShow's editable Store screenshot layouts.")
    parser.add_argument("--captures", type=Path, default=ROOT / "dist/app-store-submission/captures")
    parser.add_argument("--output", type=Path, default=ROOT / "dist/app-store-submission/design")
    parser.add_argument("--chrome", type=Path, default=default_browser())
    parser.add_argument("--require-captures", action="store_true")
    parser.add_argument("--capture-edition", choices=("unverified", "direct", "store"), default="unverified")
    args = parser.parse_args()
    shots = json.loads((ROOT / "docs/app-store/shots.json").read_text())
    missing = [shot["capture"] for shot in shots if not (args.captures / shot["capture"]).is_file()]
    if args.require_captures and missing:
        parser.error("Missing native captures: " + ", ".join(missing))
    if not args.chrome.is_file():
        parser.error("Chrome not found; provide --chrome with a Chromium executable path.")
    args.output.mkdir(parents=True, exist_ok=True)
    template = (ROOT / "docs/app-store/slide.html").read_text()
    icon = ROOT / "docs/brand/app-icon.png"
    art = ROOT / "docs/brand/artwork.png"
    reports = []
    for number, shot in enumerate(shots, 1):
        capture = args.captures / shot["capture"]
        present = capture.is_file()
        if present:
            source_info = png_info(capture)
            if min(source_info["width"], source_info["height"]) < 700:
                raise ValueError(f"Native capture is too small: {capture.name}")
            content = f'<img src="{embedded(capture)}" alt="AppShow {html.escape(shot["id"])}">'
        else:
            content = '<div class="empty"><strong>Native AppShow capture</strong><span>' + html.escape(shot["direction"]) + '</span></div>'
        values = {
            "ACCENT": shot["accent"], "ART": embedded(art), "ICON": embedded(icon),
            "EYEBROW": html.escape(shot["eyebrow"]), "HEADLINE": html.escape(shot["headline"]),
            "DESCRIPTION": html.escape(shot["description"]), "CAPTURE": content,
            "NUMBER": f"{number:02}",
            "DRAFT": '<div class="draft">' + (html.escape(args.capture_edition.upper()) + ' EDITION · DESIGN REVIEW' if present else 'LAYOUT PROOF · CAPTURE PENDING') + '</div>',
        }
        rendered = template
        for key, value in values.items():
            rendered = rendered.replace("@@" + key + "@@", value)
        page = args.output / (shot["id"] + ".html")
        output = args.output / (shot["id"] + ".png")
        page.write_text(rendered)
        with tempfile.TemporaryDirectory(prefix="appshow-store-render-") as profile:
            subprocess.run([
                str(args.chrome), "--headless", "--disable-gpu", "--no-first-run",
                "--no-default-browser-check", "--disable-extensions", "--hide-scrollbars",
                "--force-device-scale-factor=1", "--window-size=2880,1800",
                "--virtual-time-budget=1500", "--run-all-compositor-stages-before-draw",
                "--user-data-dir=" + profile, "--screenshot=" + str(output.resolve()),
                page.resolve().as_uri(),
            ], check=True, capture_output=True, timeout=60)
        info = png_info(output)
        if (info["width"], info["height"], info["bitDepth"], info["colorType"]) != (2880, 1800, 8, 2):
            raise ValueError(f"Expected opaque 8-bit RGB 2880x1800 PNG: {output.name}: {info}")
        reports.append({
            "file": output.name, "sha256": sha(output), **info,
            "nativeCapturePresent": present,
            "captureEdition": args.capture_edition if present else None,
            "captureSHA256": sha(capture) if present else None,
            "captureSize": source_info if present else None,
            "status": "content-review-required" if present else "layout-proof-only",
        })
    shutil.copy2(icon, args.output / "app-icon-1024.png")
    report = {
        "scope": "File format and capture presence only; authenticity, rights, candidate parity and visual review require human evidence.",
        "submissionReady": False,
        "missingCaptures": missing,
        "shots": reports,
        "icon": {"file": "app-icon-1024.png", "sha256": sha(icon), **png_info(icon)},
    }
    (args.output / "asset-evaluation.json").write_text(json.dumps(report, indent=2) + "\n")
    cards = "".join(
        f'<a href="{shot["id"]}.html"><img src="{shot["id"]}.png" alt="{html.escape(shot["headline"])}"><span>{html.escape(shot["headline"].replace(chr(10), " "))}</span></a>'
        for shot in shots
    )
    gallery = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>AppShow · Store asset review</title><style>body{background:#07111e;color:#f5f8fc;font:17px -apple-system,BlinkMacSystemFont,sans-serif;margin:48px auto;max-width:1400px;padding:0 24px}h1{font-size:42px;letter-spacing:-1.5px}p{color:#b8c6d8;line-height:1.6}section{display:grid;grid-template-columns:repeat(auto-fit,minmax(360px,1fr));gap:32px;margin-top:40px}a{color:inherit;text-decoration:none}img{width:100%;border-radius:12px;border:1px solid #ffffff22}span{display:block;margin-top:12px}code{color:#80e4be}</style><h1>AppShow. Ready to show.</h1><p>Store artwork review · 2880 × 1800 · English<br>''' + (
        f'Capture edition: {html.escape(args.capture_edition)}. {len(shots) - len(missing)} of {len(shots)} images use supplied screenshots. Remaining images are layout proofs. Owner review and Store candidate parity are pending; do not upload this draft set.'
    ) + '</p><section>' + cards + '</section><p>File checks: <a href="asset-evaluation.json"><code>asset-evaluation.json</code></a></p></html>'
    (args.output / "index.html").write_text(gallery)
    print(json.dumps({"output": str(args.output), "images": len(reports), "missingCaptures": missing, "submissionReady": False}))


if __name__ == "__main__":
    main()
