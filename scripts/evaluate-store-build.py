import argparse
import hashlib
import json
import plistlib
import subprocess
from pathlib import Path

from release_metadata import ROOT, configured_version
from agent_runtime_versions import read_versions


def run(*arguments):
    result = subprocess.run(arguments, capture_output=True, check=True)
    return result.stdout


def evaluate(app, universal):
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    version, build = configured_version()
    executable_name = info.get('CFBundleExecutable')
    if not executable_name:
        raise ValueError('The bundle must explicitly declare CFBundleExecutable.')
    executable = app / 'Contents/MacOS' / executable_name
    entitlements = plistlib.loads(run('codesign', '-d', '--entitlements', ':-', str(app)))
    mach_o_magic = {b'\xfe\xed\xfa\xce', b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'}
    binaries = []
    for path in app.rglob('*'):
        if path.is_file() and not path.is_symlink():
            with path.open('rb') as handle:
                if handle.read(4) in mach_o_magic:
                    binaries.append(path)
    libraries = '\n'.join(run('otool', '-L', str(path)).decode() for path in binaries)
    architectures = run('lipo', '-archs', str(executable)).decode().strip().split()
    paths = [str(path.relative_to(app)) for path in app.rglob('*')]
    manifest = app / 'Contents/Resources/PrivacyInfo.xcprivacy'
    declared = plistlib.loads(manifest.read_bytes()).get('NSPrivacyAccessedAPITypes', []) if manifest.is_file() else []
    reasons = {item['NSPrivacyAccessedAPIType']: set(item.get('NSPrivacyAccessedAPITypeReasons', [])) for item in declared}
    checks = {
        'sandbox': entitlements.get('com.apple.security.app-sandbox') is True,
        'selectedFiles': entitlements.get('com.apple.security.files.user-selected.read-write') is True,
        'persistentBookmarks': entitlements.get('com.apple.security.files.bookmarks.app-scope') is True,
        'noSandboxExceptions': not any('temporary-exception' in key for key in entitlements),
        'noRuntimeExceptions': not any(key.startswith('com.apple.security.cs.') and value for key, value in entitlements.items() ),
        'bundleIdentity': info.get('CFBundleIdentifier') == 'com.mattwebhub.appshow',
        'applicationType': info.get('CFBundlePackageType') == 'APPL',
        'versionAndBuild': info.get('CFBundleShortVersionString') == version and info.get('CFBundleVersion') == build,
        'noUpdateConfiguration': not any(key.startswith('SU') for key in info),
        'noSparkleLinkage': 'Sparkle' not in libraries,
        'noUpdater': not any('Sparkle' in path for path in paths),
        'privacyManifest': {'C617.1', '3B52.1'} <= reasons.get('NSPrivacyAccessedAPICategoryFileTimestamp', set()) and '35F9.1' in reasons.get('NSPrivacyAccessedAPICategorySystemBootTime', set()),
        'releaseNotDebuggable': not universal or not entitlements.get('com.apple.security.get-task-allow'),
        'architectures': set(architectures) == {'arm64', 'x86_64'} if universal else bool(architectures),
    }
    runtime_manifest = app / 'Contents/Resources/AgentRuntimes.json'
    runtime_checks = []
    try:
        receipt = json.loads(runtime_manifest.read_text())
        runtime_checks.append(receipt.get('versions') == read_versions())
        runtime_architectures = set(receipt['architectures'])
        runtime_checks.append(runtime_architectures == set(architectures))
        expected = ['Contents/Helpers/appshow-mcp']
        expected += [f'Contents/Helpers/Runtimes/{arch}/{name}' for arch in architectures for name in ('codex', 'codex-code-mode-host', 'claude')]
        runtime_checks.append(set(receipt['embeddedFiles']) == set(expected))
        for relative in expected:
            path = app / relative
            runtime_checks.append(hashlib.sha256(path.read_bytes()).hexdigest() == receipt['embeddedFiles'][relative])
            run('codesign', '--verify', '--strict', str(path))
            if path.name == 'claude':
                source = receipt['sourceFiles'][path.parent.name + '/claude']
                runtime_checks.append(hashlib.sha256(path.read_bytes()).hexdigest() == source['sha256'])
            else:
                child = plistlib.loads(run('codesign', '-d', '--entitlements', ':-', str(path)))
                runtime_checks.append(child == {'com.apple.security.app-sandbox': True, 'com.apple.security.inherit': True})
        runtime_checks.append((app / 'Contents/Resources/AgentRuntimeNotices.txt').is_file())
        checks['bundledAgentRuntimes'] = all(runtime_checks)
    except (KeyError, ValueError, OSError, subprocess.SubprocessError):
        checks['bundledAgentRuntimes'] = False
    try:
        run('codesign', '--verify', '--deep', '--strict', str(app))
        checks['signatureIntegrity'] = True
    except subprocess.CalledProcessError:
        checks['signatureIntegrity'] = False
    report = {'scope': 'Local store build foundation; not distribution or App Review approval',
              'app': str(app), 'version': version, 'build': build, 'architectures': architectures,
              'entitlements': entitlements, 'binaries': [str(path.relative_to(app)) for path in binaries], 'checks': checks, 'passed': all(checks.values())}
    print(json.dumps(report, indent=2))
    return report['passed']


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--app', type=Path, default=ROOT / '.build/Build/Products/Debug/AppShowStore.app')
    parser.add_argument('--universal', action='store_true')
    arguments = parser.parse_args()
    try:
        raise SystemExit(0 if evaluate(arguments.app, arguments.universal) else 1)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(f'Error: {error}')
