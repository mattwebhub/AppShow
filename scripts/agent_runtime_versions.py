import argparse
import contextlib
import fcntl
import json
import re
import urllib.request
from pathlib import Path


VERSIONS = Path(__file__).with_name('agent-runtime-versions.json')


def fetch(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'AppShow-runtime-packager/1.0'})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def stable_version(value):
    if not isinstance(value, str) or not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', value):
        raise ValueError('Runtime versions must be exact stable versions, such as 1.2.3.')
    return value


def read_versions(path=VERSIONS):
    versions = json.loads(path.read_text())
    if not isinstance(versions, dict) or set(versions) != {'codex', 'claude'}:
        raise ValueError('Runtime versions must contain exactly codex and claude.')
    return {name: stable_version(value) for name, value in versions.items()}


@contextlib.contextmanager
def runtime_lock(output, exclusive):
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.with_name(output.name + '.lock').open('a') as handle:
        fcntl.flock(handle, (fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH) | fcntl.LOCK_NB)
        try:
            yield
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def check_updates(pinned):
    release = json.loads(fetch('https://api.github.com/repos/openai/codex/releases/latest'))
    if release.get('prerelease') is not False or release.get('draft') is not False or not release.get('tag_name', '').startswith('rust-v'):
        raise ValueError('The latest Codex release is not a published stable runtime.')
    latest = {
        'codex': stable_version(release['tag_name'][6:]),
        'claude': stable_version(fetch('https://downloads.claude.ai/claude-code-releases/latest').decode().strip()),
    }
    return {
        name: {'pinned': stable_version(pinned[name]), 'latest': value, 'updateAvailable': tuple(map(int, value.split('.'))) > tuple(map(int, pinned[name].split('.')))}
        for name, value in latest.items()
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Check official CLI releases without downloading binaries or changing pins.')
    parser.add_argument('--versions', type=Path, default=VERSIONS)
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()
    try:
        report = check_updates(read_versions(args.versions))
        if args.json:
            print(json.dumps(report, indent=2))
        else:
            for name, entry in report.items():
                status = 'update available' if entry['updateAvailable'] else 'no newer release'
                print(f"{name}: pinned {entry['pinned']}, latest {entry['latest']} ({status})")
            print(f'Edit {args.versions}, then run make stage-store-agents and validate a new AppShow Store release.')
    except (KeyError, ValueError, OSError) as error:
        raise SystemExit('error: ' + str(error))
