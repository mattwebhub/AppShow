import argparse
import hashlib
import json
import os
import subprocess

from release_metadata import ROOT, REPOSITORY, atomic_write, built_metadata, configured_version


def run(*arguments):
    result = subprocess.run(arguments, cwd=ROOT, text=True, capture_output=True, timeout=120)
    if result.returncode:
        raise ValueError(f'{arguments[0]} {arguments[1] if len(arguments) > 1 else ""} failed: {result.stderr.strip()}')
    return result.stdout.strip()


def clean_commit():
    if run('git', 'status', '--porcelain'):
        raise ValueError('Commit all source and release-note changes before preparing, tagging or publishing.')
    return run('git', 'rev-parse', 'HEAD')


def checksum(path):
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def tag_release():
    commit = clean_commit()
    version, _ = configured_version()
    tag = 'v' + version
    if run('git', 'tag', '--list', tag):
        raise ValueError(f'{tag} already exists; tags are never overwritten.')
    run('git', 'tag', '-a', tag, '-m', tag, commit)
    print(f'Created {tag} at {commit}; working tree unchanged.')


def verify_distribution(metadata, archive):
    app = metadata['app']
    run('codesign', '--verify', '--deep', '--strict', app)
    result = subprocess.run(['codesign', '-dv', '--verbose=4', app], text=True, capture_output=True, timeout=30)
    if result.returncode or 'Authority=Developer ID Application:' not in result.stderr:
        raise ValueError('The candidate must be signed with Developer ID Application, not a development or ad-hoc identity.')
    run('spctl', '--assess', '--type', 'execute', '--verbose', app)
    run('xcrun', 'stapler', 'validate', str(archive))
    run('spctl', '--assess', '--type', 'open', '--context', 'context:primary-signature', '--verbose', str(archive))


def prepare():
    commit = clean_commit()
    version, _ = configured_version()
    tag = 'v' + version
    if run('git', 'tag', '--list', tag) and run('git', 'rev-parse', tag + '^{commit}') != commit:
        raise ValueError(f'{tag} identifies another commit; select a new release version before preparing.')
    identity = os.environ.get('APPSHOW_SIGNING_IDENTITY', '')
    if not identity.startswith('Developer ID Application:'):
        raise ValueError('Set APPSHOW_SIGNING_IDENTITY to the Developer ID Application identity for this release.')
    if not all(os.environ.get(key) for key in ('APPSHOW_APPLE_ID', 'APPSHOW_TEAM_ID', 'APPSHOW_APP_PASSWORD')):
        raise ValueError('Configure the existing notarization environment variables before preparing a release.')
    for command in [['make', 'release'], ['./scripts/create-dmg.sh', '--sign', identity, '--notarize']]:
        subprocess.run(command, cwd=ROOT, check=True)
    metadata = built_metadata()
    archive = ROOT / 'dist' / f'AppShow-{version}.dmg'
    verify_distribution(metadata, archive)
    artifacts = [archive]
    if metadata['updates'] == 'sparkle':
        subprocess.run(['/bin/bash', str(ROOT / 'scripts/generate-appcast.sh')], cwd=ROOT, check=True)
        artifacts.append(ROOT / 'dist/appcast.xml')
    previous = subprocess.run(['git', 'describe', '--tags', '--abbrev=0', commit + '^'], cwd=ROOT, text=True, capture_output=True)
    revision = previous.stdout.strip() + '..' + commit if previous.returncode == 0 else commit
    notes = '# AppShow ' + version + '\n\n' + run('git', 'log', '--no-merges', '--format=- %s', revision) + '\n'
    notes_path = ROOT / 'dist/release-notes.md'
    atomic_write(notes_path, notes.encode())
    artifacts.append(notes_path)
    if clean_commit() != commit:
        raise ValueError('Source changed during preparation; no candidate receipt was written.')
    receipt = {key: metadata[key] for key in ('version', 'build', 'updates')}
    receipt.update({'schema': 1, 'commit': commit,
                    'artifacts': [{'name': path.name, 'sha256': checksum(path)} for path in artifacts]})
    atomic_write(ROOT / 'dist/release.json', (json.dumps(receipt, indent=2) + '\n').encode())
    print('Prepared dist/release.json and release-notes.md. Review the candidate, then tag and preview publication.')


def candidate():
    commit = clean_commit()
    metadata = built_metadata()
    receipt = json.loads((ROOT / 'dist/release.json').read_text())
    if receipt.get('schema') != 1 or receipt.get('commit') != commit:
        raise ValueError('The candidate receipt does not identify the current source commit; prepare again.')
    for key in ('version', 'build', 'updates'):
        if receipt.get(key) != metadata[key]:
            raise ValueError(f'Candidate {key} no longer matches the built bundle; prepare again.')
    tag = metadata['tag']
    if run('git', 'rev-parse', tag + '^{commit}') != commit:
        raise ValueError('Release tag does not identify the prepared source commit.')
    names = [f'AppShow-{metadata["version"]}.dmg', 'release-notes.md']
    if metadata['updates'] == 'sparkle':
        names.append('appcast.xml')
    artifacts = receipt.get('artifacts', [])
    if len(artifacts) != len(names) or sorted(item.get('name', '') for item in artifacts) != sorted(names):
        raise ValueError('The candidate artifact set does not match its update delivery mode.')
    for item in artifacts:
        if checksum(ROOT / 'dist' / item['name']) != item.get('sha256'):
            raise ValueError(f'Candidate artifact changed after preparation: {item["name"]}')
    return metadata, receipt


def publish(dry_run):
    metadata, receipt = candidate()
    tag = metadata['tag']
    archive = ROOT / 'dist' / f'AppShow-{metadata["version"]}.dmg'
    print(json.dumps({'repository': REPOSITORY, 'tag': tag, 'commit': receipt['commit'],
                      'version': metadata['version'], 'build': metadata['build'], 'updates': metadata['updates'],
                      'artifacts': receipt['artifacts'], 'dryRun': dry_run}, indent=2), flush=True)
    if dry_run:
        return
    verify_distribution(metadata, archive)
    run('gh', 'auth', 'status')
    existing = subprocess.run(['gh', 'release', 'view', tag, '--repo', REPOSITORY], cwd=ROOT, capture_output=True)
    if existing.returncode == 0:
        raise ValueError('This GitHub release already exists; versioned releases are never overwritten.')
    run('git', 'push', f'https://github.com/{REPOSITORY}.git', f'refs/tags/{tag}')
    run('gh', 'release', 'create', tag, '--repo', REPOSITORY, '--verify-tag', '--title', 'AppShow ' + tag,
        '--notes-file', str(ROOT / 'dist/release-notes.md'), str(archive), str(ROOT / 'dist/release.json'))
    if metadata['updates'] == 'sparkle':
        feed = str(ROOT / 'dist/appcast.xml')
        existing_feed = subprocess.run(['gh', 'release', 'view', 'appcast', '--repo', REPOSITORY], cwd=ROOT, capture_output=True)
        if existing_feed.returncode == 0:
            run('gh', 'release', 'upload', 'appcast', feed, '--repo', REPOSITORY, '--clobber')
        else:
            run('gh', 'release', 'create', 'appcast', feed, '--repo', REPOSITORY, '--title', 'Appcast',
                '--notes', 'Sparkle update feed.', '--latest=false')
    print(f'Published {tag}.')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['prepare', 'tag', 'publish'])
    options = parser.add_mutually_exclusive_group()
    options.add_argument('--dry-run', action='store_true')
    options.add_argument('--publish', action='store_true')
    args = parser.parse_args()
    if args.action != 'publish' and (args.dry_run or args.publish):
        parser.error('Publication flags only apply to publish.')
    if args.action == 'prepare':
        prepare()
    elif args.action == 'tag':
        tag_release()
    else:
        publish(dry_run=not args.publish)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(f'Error: {error}')
