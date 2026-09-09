import hashlib
import json
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / 'AppShow/Assets.xcassets/MenuBarMark.imageset'
SOURCE = ROOT / 'docs/brand/app-icon.png'
VECTORS = [ASSET / 'MenuBarMark.svg', ROOT / 'docs/brand/appshow-transparent.svg']
FILES = VECTORS + [ASSET / 'Contents.json', ROOT / 'docs/brand/tray-source.json']


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rgba(path, svg=False):
    if svg:
        png = subprocess.check_output(['rsvg-convert', str(path), '-w', '256', '-h', '256'])
        return subprocess.check_output(['magick', 'png:-', '-alpha', 'on', '-depth', '8', 'rgba:-'], input=png)
    return subprocess.check_output(['magick', str(path), '-resize', '256x256!', '-alpha', 'on', '-depth', '8', 'rgba:-'])


def main():
    source_hash = digest(SOURCE)
    provenance = json.loads(FILES[-1].read_text())
    assert source_hash == provenance['sha256'], 'Source changed; regenerate and visually review the tray artwork.'
    for vector in VECTORS:
        tree = ET.parse(vector)
        assert vector.stat().st_size < 200_000, 'Vector exceeds the asset budget.'
        allowed = {'svg', 'title', 'defs', 'clipPath', 'path', 'g', 'linearGradient', 'stop'}
        assert all(node.tag.split('}')[-1] in allowed for node in tree.iter()), 'Expected vector-only geometry.'
        assert all('href' not in key for node in tree.iter() for key in node.attrib), 'External and embedded images are prohibited.'
        assert tree.findall('.//{http://www.w3.org/2000/svg}path'), 'Missing vector paths.'
    catalog = json.loads((ASSET / 'Contents.json').read_text())
    assert catalog['properties']['preserves-vector-representation'] is True
    assert catalog['properties']['template-rendering-intent'] == 'template'
    assert catalog['images'][0]['filename'] == VECTORS[0].name
    source = rgba(SOURCE)
    mask = rgba(VECTORS[0], True)
    colored = rgba(VECTORS[1], True)
    background = []
    disagreement = 0
    for i in range(0, len(source), 4):
        r, g, b, a = source[i:i + 4]
        expected = a > 240 and max(r, g, b) > 110 and .2126 * r + .7152 * g + .0722 * b > 42
        actual = mask[i + 3] > 127
        disagreement += expected != actual
        if (max(r, g, b) < 75 and .2126 * r + .7152 * g + .0722 * b < 30) or a == 0:
            background.append(mask[i + 3] == 0 and colored[i + 3] == 0)
    removed = sum(background) / len(background)
    coverage = sum(mask[i] > 127 for i in range(3, len(mask), 4)) / (256 * 256)
    error = disagreement / (256 * 256)
    assert removed > .99, f'Dark background removal failed: {removed:.3%}'
    assert .2 < coverage < .65, f'Unexpected silhouette coverage: {coverage:.3%}'
    assert error < .035, f'Trace diverged from source: {error:.3%}'
    assert all(mask[(y * 256 + x) * 4 + 3] == 0 for x, y in [(0, 0), (255, 0), (0, 255), (255, 255), (50, 205)])
    template_path = ET.parse(VECTORS[0]).find('.//{http://www.w3.org/2000/svg}path').get('d')
    color_clip = ET.parse(VECTORS[1]).find('.//{http://www.w3.org/2000/svg}clipPath/{http://www.w3.org/2000/svg}path').get('d')
    assert template_path == color_clip, 'Color and template must share exact silhouette geometry.'
    alpha_difference = sum(abs(mask[i] - colored[i]) for i in range(3, len(mask), 4)) / (256 * 256 * 255)
    assert alpha_difference < .003, 'Color clipping diverges beyond edge antialiasing tolerance.'
    before = {str(path.relative_to(ROOT)): digest(path) for path in FILES}
    for _ in range(2):
        subprocess.run([sys.executable, str(ROOT / 'scripts/generate-tray-assets.py')], check=True, stdout=subprocess.DEVNULL)
        assert before == {str(path.relative_to(ROOT)): digest(path) for path in FILES}, 'Regeneration is not deterministic.'
        assert digest(SOURCE) == source_hash, 'Regeneration altered the original icon.'
    result = {'result': 'PASS', 'darkBackgroundTransparent': removed, 'opaqueCoverage': coverage, 'traceDisagreement': error, 'meanAlphaDifference': alpha_difference, 'sha256': before}
    destination = ROOT / '.build/brand/tray-eval.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
