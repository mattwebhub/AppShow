import argparse
import concurrent.futures
import hashlib
import io
import json
import os
import tarfile
import tempfile
from pathlib import Path

from agent_runtime_versions import VERSIONS, fetch, read_versions, runtime_lock, stable_version


def stage(output, codex_version, claude_version):
    stable_version(codex_version)
    stable_version(claude_version)
    output = output.absolute()
    with runtime_lock(output, exclusive=True):
        with tempfile.TemporaryDirectory(prefix=output.name + '-staging-', dir=output.parent) as temporary:
            replacement = Path(temporary) / 'verified'
            replacement.mkdir()
            download_runtimes(replacement, codex_version, claude_version)
            previous = Path(temporary) / 'previous'
            if output.exists():
                os.replace(output, previous)
            try:
                os.replace(replacement, output)
            except BaseException:
                if previous.exists():
                    os.replace(previous, output)
                raise


def download_runtimes(output, codex_version, claude_version):
    release_url = f'https://api.github.com/repos/openai/codex/releases/tags/rust-v{codex_version}'
    release = json.loads(fetch(release_url))
    assets = {item['name']: item for item in release['assets']}
    claude_url = f'https://downloads.claude.ai/claude-code-releases/{claude_version}'
    claude_manifest = json.loads(fetch(claude_url + '/manifest.json'))
    jobs = []
    for architecture, codex_arch, claude_arch in [('arm64', 'aarch64', 'arm64'), ('x86_64', 'x86_64', 'x64')]:
        for executable in ['codex', 'codex-code-mode-host']:
            asset = assets[f'{executable}-{codex_arch}-apple-darwin.tar.gz']
            digest = asset.get('digest', '')
            if not digest.startswith('sha256:'):
                raise ValueError('Official release asset is missing its SHA-256 digest.')
            jobs.append((architecture, executable, asset['browser_download_url'], digest[7:], True))
        platform = f'darwin-{claude_arch}'
        jobs.append((architecture, 'claude', f'{claude_url}/{platform}/claude', claude_manifest['platforms'][platform]['checksum'], False))

    def download(job):
        architecture, executable, url, digest, archive = job
        payload = fetch(url)
        if hashlib.sha256(payload).hexdigest() != digest:
            raise ValueError('Official checksum mismatch: ' + url)
        if archive:
            with tarfile.open(fileobj=io.BytesIO(payload), mode='r:gz') as tar:
                candidates = [m for m in tar.getmembers() if m.isfile() and (Path(m.name).name == executable or Path(m.name).name.startswith(executable + '-'))]
                if len(candidates) != 1:
                    raise ValueError('Unexpected runtime archive contents: ' + url)
                payload = tar.extractfile(candidates[0]).read()
        destination = output / architecture / executable
        destination.parent.mkdir(parents=True, exist_ok=True)
        partial = destination.with_suffix('.partial')
        partial.write_bytes(payload)
        partial.chmod(0o755)
        os.replace(partial, destination)
        print('Verified ' + architecture + '/' + executable, flush=True)
        return architecture + '/' + executable, {'sha256': hashlib.sha256(payload).hexdigest(), 'source': url, 'downloadSha256': digest}

    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        files = dict(pool.map(download, jobs))
    root = f'https://raw.githubusercontent.com/openai/codex/rust-v{codex_version}/'
    license_text = fetch(root + 'LICENSE').decode()
    notice_text = fetch(root + 'NOTICE').decode()
    notice = 'CODEX\nSource: ' + root + '\n\n' + license_text + '\n\n' + notice_text
    notice += '\n\nCLAUDE CODE\nCopyright Anthropic PBC. All rights reserved.\nOriginal executable and vendor signature preserved.\nTerms: https://code.claude.com/docs/en/legal-and-compliance\n'
    (output / 'NOTICES.txt').write_text(notice)
    receipt = {'versions': {'codex': codex_version, 'claude': claude_version}, 'files': files, 'sourceManifests': [release_url, claude_url + '/manifest.json']}
    (output / 'manifest.json').write_text(json.dumps(receipt, indent=2) + '\n')
    (output / 'claude-upstream-manifest.json').write_text(json.dumps(claude_manifest, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Stage the pinned, verified universal CLIs for an AppShow Store release.')
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] / '.build/store-agent-runtimes')
    parser.add_argument('--versions', type=Path, default=VERSIONS)
    args = parser.parse_args()
    try:
        versions = read_versions(args.versions)
        stage(args.output, versions['codex'], versions['claude'])
    except (KeyError, ValueError, OSError, tarfile.TarError) as error:
        raise SystemExit('error: ' + str(error))
