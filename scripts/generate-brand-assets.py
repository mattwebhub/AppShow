import base64
import json
import shutil
import subprocess
from pathlib import Path


root = Path(__file__).resolve().parents[1]
brand = root / "docs/brand"
assets = root / "docs/assets"
icons = root / "AppShow/Assets.xcassets/AppIcon.appiconset"
scratch = root / ".build/brand"

for executable in ("sips", "rsvg-convert"):
    if not shutil.which(executable):
        raise SystemExit(f"Missing {executable}. See docs/brand/README.md.")

for directory in (assets, icons, scratch):
    directory.mkdir(parents=True, exist_ok=True)


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def resize(source, destination, size):
    run("sips", "-z", str(size), str(size), str(source), "--out", str(destination))


def embedded(path, mime):
    return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode()


icon = brand / "app-icon.png"
icon_artwork = embedded(brand / "artwork.png", "image/png")
icon_svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <clipPath id="shape"><rect x="100" y="100" width="824" height="824" rx="184"/></clipPath>
    <filter id="shadow" x="0" y="0" width="1024" height="1024" filterUnits="userSpaceOnUse">
      <feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#000000" flood-opacity="0.22"/>
    </filter>
  </defs>
  <rect x="100" y="100" width="824" height="824" rx="184" fill="#07111e" filter="url(#shadow)"/>
  <image href="{icon_artwork}" x="100" y="100" width="824" height="824" clip-path="url(#shape)"/>
</svg>
'''
(scratch / "app-icon.svg").write_text(icon_svg)
run("rsvg-convert", str(scratch / "app-icon.svg"), "-o", str(icon))
if "hasAlpha: yes" not in run("sips", "-g", "hasAlpha", str(icon)):
    raise SystemExit("The icon master must have a real alpha channel.")

for size in (16, 32, 64, 128, 256, 512, 1024):
    name = "AppIcon.png" if size == 1024 else f"AppIcon-{size}.png"
    resize(icon, icons / name, size)

images = []
for size in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        pixels = size * scale
        images.append({
            "filename": "AppIcon.png" if pixels == 1024 else f"AppIcon-{pixels}.png",
            "idiom": "mac",
            "scale": f"{scale}x",
            "size": f"{size}x{size}",
        })
(icons / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
resize(icon, assets / "app-icon.png", 256)
run("sips", "-s", "format", "jpeg", "-s", "formatOptions", "85", "-Z", "1000", str(brand / "artwork.png"), "--out", str(scratch / "artwork.jpg"))

artwork = embedded(scratch / "artwork.jpg", "image/jpeg")
logo = embedded(assets / "app-icon.png", "image/png")
banner = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="640" viewBox="0 0 1280 640" role="img" aria-labelledby="title description">
  <title id="title">AppShow — Screen recordings. Worth watching.</title>
  <desc id="description">A native Mac screen recorder and presentation editor. Blue, green, and coral brushstrokes sweep across the right side.</desc>
  <defs>
    <clipPath id="canvas"><rect width="1280" height="640" rx="24"/></clipPath>
    <linearGradient id="fade"><stop offset="0" stop-color="#07111e"/><stop offset="0.44" stop-color="#07111e"/><stop offset="0.82" stop-color="#07111e" stop-opacity="0"/></linearGradient>
  </defs>
  <g clip-path="url(#canvas)">
    <rect width="1280" height="640" fill="#07111e"/>
    <image href="{artwork}" x="520" y="-70" width="920" height="920"/>
    <rect width="1280" height="640" fill="url(#fade)"/>
    <image href="{logo}" x="66" y="53" width="72" height="72"/>
    <g font-family="Helvetica Neue, Helvetica, Arial, sans-serif" fill="#f5f8fc">
      <text x="148" y="100" font-size="31" font-weight="600" letter-spacing="-1">AppShow</text>
      <text x="80" y="263" font-size="76" font-weight="600" letter-spacing="-3.5">Screen recordings.</text>
      <text x="80" y="348" font-size="76" font-weight="600" letter-spacing="-3.5">Worth watching.</text>
      <text x="84" y="409" font-size="22" fill="#b8c6d8">Record, compose, and share from your Mac.</text>
      <path d="M84 495H470" stroke="#526477" stroke-opacity="0.5"/>
      <circle cx="89" cy="543" r="4" fill="#80e4be"/>
      <text x="106" y="548" font-size="12" font-weight="500" letter-spacing="2" fill="#d4dfe9">OPEN SOURCE</text>
      <text x="275" y="548" font-size="12" font-weight="500" letter-spacing="2" fill="#d4dfe9">MADE FOR MAC</text>
    </g>
  </g>
</svg>
'''
(assets / "banner.svg").write_text(banner)
run("rsvg-convert", str(assets / "banner.svg"), "-o", str(assets / "social-preview.png"))
print("Generated 10 app-icon slots, README icon, banner, and 1280 × 640 social preview.")
