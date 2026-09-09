import hashlib
import json
import math
import shutil
import subprocess
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIZE = 256
SOURCE = ROOT / 'docs/brand/app-icon.png'
ASSET = ROOT / 'AppShow/Assets.xcassets/MenuBarMark.imageset'


def trace(mask, minimum_area=16, tolerance=0.7):
    edges = defaultdict(list)
    for x, y in sorted(mask):
        for dx, dy, a, b in (
            (0, -1, (x, y), (x + 1, y)),
            (1, 0, (x + 1, y), (x + 1, y + 1)),
            (0, 1, (x + 1, y + 1), (x, y + 1)),
            (-1, 0, (x, y + 1), (x, y)),
        ):
            if (x + dx, y + dy) not in mask:
                edges[a].append(b)
    paths = []
    while edges:
        start = min(edges)
        points = [start]
        a = start
        while True:
            b = edges[a].pop()
            if not edges[a]:
                del edges[a]
            points.append(b)
            a = b
            if a == start:
                break
        area = abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(points, points[1:]))) / 2
        if area < minimum_area:
            continue
        split = max(range(len(points)), key=lambda i: math.dist(points[0], points[i]))
        points = simplify(points[:split + 1], tolerance)[:-1] + simplify(points[split:], tolerance)
        points = points[:-1]
        midpoints = [((a[0] + b[0]) / 2, (a[1] + b[1]) / 2) for a, b in zip(points, points[1:] + points[:1])]
        paths.append(f'M{midpoints[-1][0]:g},{midpoints[-1][1]:g} ' + ' '.join(
            f'Q{x:g},{y:g} {mx:g},{my:g}' for (x, y), (mx, my) in zip(points, midpoints)
        ) + 'Z')
    return ' '.join(paths)


def simplify(points, tolerance):
    if len(points) <= 2:
        return points
    a, b = points[0], points[-1]
    length = math.dist(a, b)
    distances = [abs((b[0] - a[0]) * (a[1] - p[1]) - (a[0] - p[0]) * (b[1] - a[1])) / length for p in points]
    index = max(range(len(points)), key=distances.__getitem__)
    if distances[index] <= tolerance:
        return [a, b]
    return simplify(points[:index + 1], tolerance)[:-1] + simplify(points[index:], tolerance)


def pixels(quantized=False):
    args = ['magick', str(SOURCE), '-resize', f'{SIZE}x{SIZE}!', '-alpha', 'on']
    if quantized:
        args += ['-background', 'black', '-alpha', 'remove', '-alpha', 'off', '-dither', 'None', '-colors', '32']
    return subprocess.check_output(args + ['-depth', '8', 'rgba:-'])


def main():
    if not shutil.which('magick'):
        raise SystemExit('ImageMagick is needed only to regenerate tray vectors; see docs/brand/README.md.')
    raw = pixels()
    quantized = pixels(True)
    mask = set()
    colors = defaultdict(set)
    for y in range(SIZE):
        for x in range(SIZE):
            offset = (y * SIZE + x) * 4
            r, g, b, a = raw[offset:offset + 4]
            if a > 240 and max(r, g, b) > 110 and 0.2126 * r + 0.7152 * g + 0.0722 * b > 42:
                mask.add((x, y))
                color = tuple(quantized[offset:offset + 3])
                colors[color].add((x, y))
    silhouette = trace(mask)
    template = f'''<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 {SIZE} {SIZE}">
  <path fill="#000000" fill-rule="evenodd" d="{silhouette}"/>
</svg>
'''
    layers = []
    for color, region in sorted(colors.items()):
        path = trace(region, minimum_area=8, tolerance=0.5)
        if path:
            fill = '#%02x%02x%02x' % color
            layers.append(f'    <path fill="{fill}" fill-rule="evenodd" d="{path}"/>')
    colored = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 {SIZE} {SIZE}" role="img" aria-labelledby="title">
  <title id="title">AppShow brushstrokes with transparent dark regions</title>
  <defs>
    <clipPath id="brushstrokes"><path clip-rule="evenodd" d="{silhouette}"/></clipPath>
    <linearGradient id="color" x2="1" y2="1"><stop stop-color="#1678ff"/><stop offset=".4" stop-color="#48d7df"/><stop offset=".65" stop-color="#a3e687"/><stop offset="1" stop-color="#ff8269"/></linearGradient>
  </defs>
  <g clip-path="url(#brushstrokes)">
    <path fill="url(#color)" d="M0,0H{SIZE}V{SIZE}H0Z"/>
{chr(10).join(layers)}
  </g>
</svg>
'''
    ASSET.mkdir(parents=True, exist_ok=True)
    (ASSET / 'MenuBarMark.svg').write_text(template)
    (ASSET / 'Contents.json').write_text(json.dumps({
        'images': [{'filename': 'MenuBarMark.svg', 'idiom': 'universal'}],
        'info': {'author': 'xcode', 'version': 1},
        'properties': {'preserves-vector-representation': True, 'template-rendering-intent': 'template'},
    }, indent=2) + '\n')
    (ROOT / 'docs/brand/appshow-transparent.svg').write_text(colored)
    (ROOT / 'docs/brand/tray-source.json').write_text(json.dumps({
        'source': 'docs/brand/app-icon.png',
        'sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'traceSize': SIZE,
        'minimumAlpha': 241,
        'minimumMaxRGB': 111,
        'minimumLuminanceExclusive': 42,
        'quantizedColors': 32,
    }, indent=2) + '\n')
    print('Generated transparent color SVG and vector menu bar template from the current app icon.')


if __name__ == '__main__':
    main()
