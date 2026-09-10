import hashlib
import json
import os
import plistlib
import shutil
import subprocess
from pathlib import Path

from agent_runtime_versions import read_versions, runtime_lock


def embed():
    project = Path(os.environ['SRCROOT'])
    app = Path(os.environ['TARGET_BUILD_DIR']) / os.environ['WRAPPER_NAME']
    staging = Path(os.environ.get('APPSHOW_STORE_RUNTIME_DIR', str(project / '.build/store-agent-runtimes')))
    with runtime_lock(staging, exclusive=False):
        embed_locked(project, app, staging)


def embed_locked(project, app, staging):
    manifest_path = staging / 'manifest.json'
    if not manifest_path.is_file():
        raise ValueError('Stage verified provider runtimes in .build/store-agent-runtimes before building AppShowStore. See STORE-IMPLEMENTATION.md.')
    manifest = json.loads(manifest_path.read_text())
    if manifest.get('versions') != read_versions(project / 'scripts/agent-runtime-versions.json'):
        raise ValueError('Staged runtime versions differ from scripts/agent-runtime-versions.json. Run make stage-store-agents.')
    architectures = os.environ.get('ARCHS', '').split()
    if not architectures or any(arch not in ('arm64', 'x86_64') for arch in architectures):
        raise ValueError('An explicit supported Store architecture is required.')
    identity = os.environ.get('EXPANDED_CODE_SIGN_IDENTITY') or '-'
    entitlements = Path(os.environ['DERIVED_FILE_DIR']) / 'appshow-agent-inherit.entitlements'
    entitlements.parent.mkdir(parents=True, exist_ok=True)
    entitlements.write_bytes(plistlib.dumps({'com.apple.security.app-sandbox': True, 'com.apple.security.inherit': True}))
    output = app / 'Contents/Helpers/Runtimes'
    if output.exists():
        shutil.rmtree(output)
    for architecture in architectures:
        for name in ('codex', 'codex-code-mode-host', 'claude'):
            relative = architecture + '/' + name
            entry = manifest['files'].get(relative)
            if not entry:
                raise ValueError('Missing provider manifest entry: ' + relative)
            source = staging / relative
            if hashlib.sha256(source.read_bytes()).hexdigest() != entry['sha256']:
                raise ValueError('Provider checksum mismatch: ' + relative)
            available = subprocess.check_output(['lipo', '-archs', str(source)], text=True).split()
            if architecture not in available:
                raise ValueError('Provider architecture mismatch: ' + relative)
            destination = output / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            if name != 'claude':
                subprocess.run(['codesign', '--force', '--sign', identity, '--entitlements', str(entitlements), str(destination)], check=True)
            subprocess.run(['codesign', '--verify', '--strict', str(destination)], check=True)
    helper = app / 'Contents/Helpers/appshow-mcp'
    shutil.copy2(Path(os.environ['BUILT_PRODUCTS_DIR']) / 'appshow-mcp', helper)
    subprocess.run(['codesign', '--force', '--sign', identity, '--entitlements', str(entitlements), str(helper)], check=True)
    resources = app / 'Contents/Resources'
    embedded = {str(path.relative_to(app)): hashlib.sha256(path.read_bytes()).hexdigest() for path in (app / 'Contents/Helpers').rglob('*') if path.is_file()}
    receipt = {'versions': manifest['versions'], 'architectures': architectures, 'sourceFiles': manifest['files'], 'embeddedFiles': embedded, 'claudeSignature': 'vendor-original'}
    (resources / 'AgentRuntimes.json').write_text(json.dumps(receipt, indent=2) + '\n')
    notices = staging / 'NOTICES.txt'
    if not notices.is_file():
        raise ValueError('Provider distribution notices are required.')
    shutil.copy2(notices, resources / 'AgentRuntimeNotices.txt')


if __name__ == '__main__':
    try:
        embed()
    except (KeyError, ValueError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit('error: ' + str(error))
