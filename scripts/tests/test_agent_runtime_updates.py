import hashlib
import importlib.util
import io
import json
import os
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))


def module(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), SCRIPTS / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class RuntimeUpdateTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.output = self.root / 'runtimes'
        self.output.mkdir()
        self.old = {'versions': {'codex': '0.1.0', 'claude': '1.0.0'}}
        (self.output / 'manifest.json').write_text(json.dumps(self.old))
        (self.output / 'keep').write_text('previous verified payload')
        self.stage = module('stage-store-agents')
        self.responses = self.fixture()

    def fixture(self):
        responses = {}
        assets = []
        for arch in ['aarch64', 'x86_64']:
            for name in ['codex', 'codex-code-mode-host']:
                payload = (name + arch).encode()
                archive = io.BytesIO()
                with tarfile.open(fileobj=archive, mode='w:gz') as output:
                    entry = tarfile.TarInfo(name)
                    entry.size = len(payload)
                    output.addfile(entry, io.BytesIO(payload))
                filename = f'{name}-{arch}-apple-darwin.tar.gz'
                url = 'https://github.com/openai/codex/releases/download/rust-v0.2.0/' + filename
                responses[url] = archive.getvalue()
                assets.append({'name': filename, 'browser_download_url': url, 'digest': 'sha256:' + hashlib.sha256(archive.getvalue()).hexdigest()})
        responses['https://api.github.com/repos/openai/codex/releases/tags/rust-v0.2.0'] = json.dumps({'assets': assets}).encode()
        platforms = {}
        for arch in ['arm64', 'x64']:
            payload = ('claude' + arch).encode()
            platforms['darwin-' + arch] = {'checksum': hashlib.sha256(payload).hexdigest()}
            responses[f'https://downloads.claude.ai/claude-code-releases/2.0.0/darwin-{arch}/claude'] = payload
        responses['https://downloads.claude.ai/claude-code-releases/2.0.0/manifest.json'] = json.dumps({'platforms': platforms}).encode()
        for name in ['LICENSE', 'NOTICE']:
            responses['https://raw.githubusercontent.com/openai/codex/rust-v0.2.0/' + name] = name.encode()
        return responses

    def assert_previous_preserved(self):
        self.assertEqual(json.loads((self.output / 'manifest.json').read_text()), self.old)
        self.assertEqual((self.output / 'keep').read_text(), 'previous verified payload')
        self.assertEqual(set(path.name for path in self.output.iterdir()), {'manifest.json', 'keep'})

    def test_late_download_failure_preserves_previous_runtime_set(self):
        def fetch(url):
            if url.endswith('/NOTICE'):
                raise OSError('interrupted download')
            return self.responses[url]
        with patch.object(self.stage, 'fetch', side_effect=fetch), self.assertRaises(OSError):
            self.stage.stage(self.output, '0.2.0', '2.0.0')
        self.assert_previous_preserved()

    def test_checksum_failure_preserves_previous_runtime_set(self):
        self.responses['https://downloads.claude.ai/claude-code-releases/2.0.0/darwin-arm64/claude'] = b'corrupted'
        with patch.object(self.stage, 'fetch', side_effect=self.responses.__getitem__), self.assertRaisesRegex(ValueError, 'checksum'):
            self.stage.stage(self.output, '0.2.0', '2.0.0')
        self.assert_previous_preserved()

    def test_success_replaces_complete_set_with_matching_receipt(self):
        with patch.object(self.stage, 'fetch', side_effect=self.responses.__getitem__):
            self.stage.stage(self.output, '0.2.0', '2.0.0')
        receipt = json.loads((self.output / 'manifest.json').read_text())
        self.assertEqual(receipt['versions'], {'codex': '0.2.0', 'claude': '2.0.0'})
        self.assertEqual(len(receipt['files']), 6)
        self.assertFalse((self.output / 'keep').exists())
        self.assertTrue((self.output / 'NOTICES.txt').is_file())
        for relative, entry in receipt['files'].items():
            self.assertEqual(hashlib.sha256((self.output / relative).read_bytes()).hexdigest(), entry['sha256'])
            self.assertTrue(os.access(self.output / relative, os.X_OK))

    def test_invalid_versions_rejected_before_network_or_filesystem_changes(self):
        with patch.object(self.stage, 'fetch') as fetch, self.assertRaises(ValueError):
            self.stage.stage(self.output, '../latest', '2.0.0')
        fetch.assert_not_called()
        self.assert_previous_preserved()

    def test_failed_promotion_restores_previous_runtime_set(self):
        replace = os.replace
        def fail_promotion(source, destination):
            if Path(source).name == 'verified':
                raise OSError('promotion failed')
            return replace(source, destination)
        with patch.object(self.stage, 'fetch', side_effect=self.responses.__getitem__), patch.object(self.stage.os, 'replace', side_effect=fail_promotion), self.assertRaisesRegex(OSError, 'promotion failed'):
            self.stage.stage(self.output, '0.2.0', '2.0.0')
        self.assert_previous_preserved()

    def test_staging_refuses_to_replace_runtimes_while_a_build_reads_them(self):
        versions = module('agent_runtime_versions')
        with versions.runtime_lock(self.output, exclusive=False), patch.object(self.stage, 'fetch') as fetch, self.assertRaises(BlockingIOError):
            self.stage.stage(self.output, '0.2.0', '2.0.0')
        fetch.assert_not_called()
        self.assert_previous_preserved()

    def test_embedding_rejects_stale_pins_before_touching_application(self):
        (self.root / 'scripts').mkdir()
        (self.root / 'scripts/agent-runtime-versions.json').write_text(json.dumps({'codex': '0.2.0', 'claude': '2.0.0'}))
        app = self.root / 'Test.app'
        app.mkdir()
        (app / 'keep').write_text('signed app')
        environment = {'SRCROOT': str(self.root), 'TARGET_BUILD_DIR': str(self.root), 'WRAPPER_NAME': 'Test.app', 'APPSHOW_STORE_RUNTIME_DIR': str(self.output)}
        with patch.dict(os.environ, environment, clear=True), self.assertRaisesRegex(ValueError, 'versions'):
            module('embed-store-agents').embed()
        self.assertEqual((app / 'keep').read_text(), 'signed app')

    def test_pins_require_exact_stable_versions_for_both_providers(self):
        versions = module('agent_runtime_versions')
        path = self.root / 'pins.json'
        for invalid in [{'codex': 'latest', 'claude': '2.0.0'}, {'codex': '0.2.0'}, {'codex': '0.2.0', 'claude': '2.0.0-beta.1'}]:
            path.write_text(json.dumps(invalid))
            with self.assertRaises(ValueError):
                versions.read_versions(path)

    def test_update_check_reports_newer_versions_without_changing_pins(self):
        versions = module('agent_runtime_versions')
        pins = {'codex': '0.2.0', 'claude': '2.0.0'}
        def fetch(url):
            return b'{"tag_name":"rust-v0.3.0","prerelease":false,"draft":false}' if 'github.com' in url else b'2.0.1\n'
        with patch.object(versions, 'fetch', side_effect=fetch):
            report = versions.check_updates(pins)
        self.assertEqual(report['codex'], {'pinned': '0.2.0', 'latest': '0.3.0', 'updateAvailable': True})
        self.assertEqual(report['claude']['latest'], '2.0.1')
        self.assertEqual(pins, {'codex': '0.2.0', 'claude': '2.0.0'})

    def test_update_check_rejects_prereleases(self):
        versions = module('agent_runtime_versions')
        with patch.object(versions, 'fetch', return_value=b'{"tag_name":"rust-v0.3.0","prerelease":true,"draft":false}'), self.assertRaises(ValueError):
            versions.check_updates({'codex': '0.2.0', 'claude': '2.0.0'})


if __name__ == '__main__':
    unittest.main()
