import base64
import json
import os
import plistlib
import re
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = 'mattwebhub/AppShow'


def configured_version(root=ROOT):
    config = (root / 'Config.xcconfig').read_text()
    values = {}
    for name in ('MARKETING_VERSION', 'CURRENT_PROJECT_VERSION'):
        matches = re.findall(r'^\s*' + name + r'\s*=\s*([^\s/]+)\s*$', config, re.MULTILINE)
        if len(matches) != 1:
            raise ValueError(f'Expected one literal {name} in Config.xcconfig.')
        values[name] = matches[0]
    version, build = values['MARKETING_VERSION'], values['CURRENT_PROJECT_VERSION']
    if not re.fullmatch(r'\d+\.\d+\.\d+', version) or not re.fullmatch(r'[1-9]\d*', build):
        raise ValueError('Use a three-part marketing version and a positive integer build number.')
    return version, build


def built_metadata(root=ROOT):
    version, build = configured_version(root)
    app = root / '.build/Build/Products/Release/AppShow.app'
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != 'com.mattwebhub.appshow':
        raise ValueError('Release bundle has the wrong application identifier.')
    if info.get('CFBundleShortVersionString') != version or info.get('CFBundleVersion') != build:
        raise ValueError('Release bundle version/build does not match Config.xcconfig; rebuild the candidate.')
    minimum = info.get('LSMinimumSystemVersion', '')
    if not re.fullmatch(r'\d+(?:\.\d+){0,2}', minimum):
        raise ValueError('Release bundle is missing a valid minimum macOS version.')
    key = info.get('SUPublicEDKey', '')
    if key and (not isinstance(key, str) or len(base64.b64decode(key, validate=True)) != 32):
        raise ValueError('Release bundle contains an invalid Sparkle public key.')
    return {'version': version, 'build': build, 'minimumOS': minimum, 'publicKey': key,
            'updates': 'sparkle' if key else 'manual', 'app': str(app), 'tag': 'v' + version}


def atomic_write(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix='.' + path.name, dir=path.parent)
    try:
        with os.fdopen(descriptor, 'wb') as handle:
            handle.write(data)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == '__main__':
    try:
        print(json.dumps(built_metadata(), indent=2))
    except (ValueError, OSError, plistlib.InvalidFileException) as error:
        raise SystemExit(f'Error: {error}')
