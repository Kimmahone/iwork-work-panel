#!/usr/bin/env python3
"""Check the public payload, links, and installer using isolated config folders."""
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from urllib.parse import unquote
import re
import zipfile
from build_release import ROOT, build


def run(*args, good=True):
    result = subprocess.run(args, text=True, capture_output=True)
    assert (result.returncode == 0) == good, (args, result.stdout, result.stderr)
    return result


class Guide(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids, self.links, self.images, self.styles, self.scripts = [], [], [], [], []

    def handle_starttag(self, tag, attrs):
        data = dict(attrs)
        if 'id' in data:
            self.ids.append(data['id'])
        if tag == 'a':
            self.links.append(data.get('href', ''))
        if tag == 'img':
            self.images.append(data.get('src', ''))
        if tag == 'link':
            self.styles.append(data.get('href', ''))
        if tag == 'script':
            self.scripts.append(data.get('src', ''))


payload = (ROOT / 'payload-files.txt').read_text().splitlines()
assert len(payload) == len(set(payload))
for name in payload:
    assert '/' not in name and not name.startswith('.')
    data = (ROOT / 'panel' / name).read_text()
    for private in ['/Users/', 'mahone@', 'evidence/v2', 'Test-Pages', 'Test-Keynote', 'Test-Numbers']:
        assert private not in data, (name, private)
    if name.endswith('.json'):
        json.loads(data)
    if name.endswith('.js'):
        run('node', '--check', str(ROOT / 'panel' / name))
    if name.endswith('.html'):
        page = Guide()
        page.feed(data)
        assert len(page.ids) == len(set(page.ids))
        for href in page.links:
            if href.startswith('#'):
                assert href[1:] in page.ids, href
            elif not href.startswith(('http:', 'https:', 'mailto:')):
                assert (ROOT / 'panel' / unquote(href.split('#')[0])).is_file(), href
        if name == '사용 안내.html':
            assert all(target in page.ids for target in ['pages', 'numbers', 'keynote', 'freeform',
                       'freeform-text', 'freeform-connect', 'freeform-table', 'freeform-photo'])
for name in ['install.command', 'uninstall.command']:
    run('bash', '-n', str(ROOT / name))

package, archive = build()
with tempfile.TemporaryDirectory(prefix='iwork-panel-test-') as temp:
    # Validate the extracted download rather than only the build directory.
    extracted = Path(temp) / '압축 해제한 설치 파일'
    with zipfile.ZipFile(archive) as bundle:
        bundle.extractall(extracted)
        command_modes = {Path(info.filename).name: (info.external_attr >> 16) & 0o777
                         for info in bundle.infolist() if info.filename.endswith('.command')}
    assert all(command_modes[name] & 0o111 for name in ['install.command', 'uninstall.command'])
    package = extracted / package.name
    offline = Guide()
    offline_text = (package / '설치 안내.html').read_text()
    offline.feed(offline_text)
    assert len(offline.ids) == len(set(offline.ids))
    assert all(f'step-{n}' in offline.ids for n in range(1, 9))
    assert len(offline.images) == 9
    assert not offline.styles and not offline.scripts
    assert not re.search(r'@import|url\s*\(', offline_text, re.I)
    for ref in offline.images + offline.links:
        if ref.startswith(('https:', 'http:', 'mailto:')):
            assert ref not in offline.images
            continue
        path, _, fragment = ref.partition('#')
        if not path:
            assert fragment in offline.ids, ref
        else:
            assert (package / unquote(path)).is_file(), ref
    readme = (package / 'README.md').read_text()
    readme_images = re.findall(r'<img\b[^>]*\bsrc="([^"]+)"', readme)
    assert len(readme_images) == 9
    assert all(not ref.startswith(('https:', 'http:')) and (package / unquote(ref)).is_file()
               for ref in readme_images)
    assert '설치 안내.html' in readme
    # shasum paths are relative to the extracted root.
    checksum_result = subprocess.run(['shasum', '-a', '256', '-c', 'SHA256SUMS'],
                                     cwd=package, text=True, capture_output=True)
    assert checksum_result.returncode == 0, checksum_result.stderr
    config = Path(temp) / '설정 폴더'
    config.mkdir()
    initial = '-- unrelated config\nprint("기존 설정 유지")\nreturn true\n'
    (config / 'init.lua').write_text(initial)
    installer = str(package / 'install.command')
    run('bash', installer, '--config-dir', str(config), '--no-open')
    first = (config / 'init.lua').read_text()
    assert first.count('-- BEGIN IWORK WORK PANEL') == 1 and first.endswith(initial)
    installed = config / 'iwork-work'
    for name in payload:
        assert (installed / name).read_bytes() == (ROOT / 'panel' / name).read_bytes()
    (installed / 'user-settings.json').write_text('{"custom":"사용자 프리셋"}')
    (installed / 'panel-state.json').write_text('{"visible":true}')
    run('bash', installer, '--config-dir', str(config), '--no-open')
    assert (config / 'init.lua').read_text() == first
    assert json.loads((installed / 'user-settings.json').read_text())['custom'] == '사용자 프리셋'
    assert json.loads((installed / 'panel-state.json').read_text())['visible'] is True
    assert len(list((config / '.iwork-work-backups').iterdir())) == 2
    run('bash', str(package / 'uninstall.command'), '--config-dir', str(config))
    assert (config / 'init.lua').read_text() == initial and not installed.exists()
    assert list((config / '.iwork-work-backups').glob('uninstall-*/panel/user-settings.json'))
    # Damaged managed blocks must not overwrite the user's init file.
    broken = '-- BEGIN IWORK WORK PANEL\nprint("do not modify")\n'
    (config / 'init.lua').write_text(broken)
    run('bash', installer, '--config-dir', str(config), '--no-open', good=False)
    assert (config / 'init.lua').read_text() == broken
    # A corrupt download must be rejected before writing configuration files.
    corrupt = Path(temp) / 'corrupt'
    shutil.copytree(package, corrupt)
    with (corrupt / 'panel/main.lua').open('a') as file:
        file.write('\n-- corrupt\n')
    run('bash', str(corrupt / 'install.command'), '--config-dir', str(Path(temp) / 'untouched'), '--no-open', good=False)
    assert not (Path(temp) / 'untouched').exists()
    fresh = Path(temp) / 'new-config'
    run('bash', installer, '--config-dir', str(fresh), '--no-open')
    assert (fresh / 'iwork-work/main.lua').exists()

print('PASS: offline HTML and nine local images, extracted ZIP checksums and executable modes, README links, runtime payload, JSON/JS/shell syntax, guide links, clean install, update, backup, settings preservation, uninstall, malformed block and corruption rejection')
print('ZIP SHA256:', hashlib.sha256(archive.read_bytes()).hexdigest())
