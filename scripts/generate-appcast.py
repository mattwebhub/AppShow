import base64
import email.utils
import os
import subprocess
import xml.etree.ElementTree as ET

from release_metadata import ROOT, REPOSITORY, atomic_write, built_metadata

SPARKLE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'


def generate():
    metadata = built_metadata()
    if metadata['updates'] != 'sparkle':
        raise ValueError('This build uses manual downloads; no appcast is required. Configure SUPublicEDKey before enabling Sparkle.')
    archive = ROOT / 'dist' / f'AppShow-{metadata["version"]}.dmg'
    if not archive.is_file():
        raise ValueError('Candidate DMG is missing; package the release first.')
    private_key = os.environ.get('APPSHOW_SPARKLE_KEY', '')
    if not private_key:
        raise ValueError('APPSHOW_SPARKLE_KEY is required for this Sparkle-enabled candidate.')
    signer = ROOT / '.build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update'
    result = subprocess.run([str(signer), '--ed-key-file', '-', str(archive), '-p'],
                            input=private_key + '\n', text=True, capture_output=True, timeout=120)
    signature = result.stdout.strip()
    if result.returncode or len(base64.b64decode(signature, validate=True)) != 64:
        raise ValueError('Sparkle signing failed or returned an invalid signature; the existing feed is unchanged.')
    cache = ROOT / '.build/release-tools/ModuleCache'
    cache.mkdir(parents=True, exist_ok=True)
    verification = subprocess.run(['/usr/bin/swift', '-module-cache-path', str(cache),
                                   str(ROOT / 'scripts/VerifyUpdateSignature.swift'),
                                   metadata['publicKey'], signature, str(archive)],
                                  capture_output=True, timeout=120)
    if verification.returncode:
        raise ValueError("Update signature does not match the archive and the app's public key; the existing feed is unchanged.")
    ET.register_namespace('sparkle', SPARKLE)
    rss = ET.Element('rss', {'version': '2.0'})
    channel = ET.SubElement(rss, 'channel')
    for key, value in [('title', 'AppShow'), ('link', f'https://github.com/{REPOSITORY}'), ('description', 'AppShow Updates'), ('language', 'en')]:
        ET.SubElement(channel, key).text = value
    item = ET.SubElement(channel, 'item')
    for key, value in [('title', 'Version ' + metadata['version']), ('pubDate', email.utils.formatdate(usegmt=True)),
                       (f'{{{SPARKLE}}}version', metadata['build']),
                       (f'{{{SPARKLE}}}shortVersionString', metadata['version']),
                       (f'{{{SPARKLE}}}minimumSystemVersion', metadata['minimumOS'])]:
        ET.SubElement(item, key).text = value
    ET.SubElement(item, f'{{{SPARKLE}}}releaseNotesLink').text = f'https://github.com/{REPOSITORY}/releases/tag/{metadata["tag"]}'
    ET.SubElement(item, 'enclosure', {
        'url': f'https://github.com/{REPOSITORY}/releases/download/{metadata["tag"]}/{archive.name}',
        'length': str(archive.stat().st_size), 'type': 'application/octet-stream', f'{{{SPARKLE}}}edSignature': signature,
    })
    ET.indent(rss)
    destination = ROOT / 'dist/appcast.xml'
    atomic_write(destination, ET.tostring(rss, encoding='utf-8', xml_declaration=True) + b'\n')
    print(f'Appcast generated for {metadata["version"]} (build {metadata["build"]}, macOS {metadata["minimumOS"]}+): {destination}')


if __name__ == '__main__':
    try:
        generate()
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(f'Error: {error}')
