#!/usr/bin/env python3
"""Build only reviewed runtime files; never copy a development directory wholesale."""
from pathlib import Path
import hashlib
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def build():
    version = (ROOT / 'VERSION').read_text().strip()
    folder = f'iwork-work-panel-{version}'
    dest = ROOT / 'dist' / folder
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    files = ['README.md', '설치 안내.html', 'LICENSE', 'CHANGELOG.md', 'VERSION', 'payload-files.txt',
             'install.command', 'uninstall.command', 'docs/VERIFICATION.md', 'docs/panel.png']
    files += ['docs/install/' + name for name in [
        '01-hammerspoon-download.png', '02-access-title.png', '02-access-toggle.png',
        '03-assets.png', '04-install-folder.png', '05-hammerspoon-app.png',
        '06-panel.png', '07-automation.png', '08-help.png']]
    files += ['panel/' + name for name in (ROOT / 'payload-files.txt').read_text().splitlines()]
    sums = []
    for name in files:
        path = ROOT / name
        target = dest / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        if name.endswith('.command'):
            target.chmod(0o755)
        sums.append(f'{hashlib.sha256(target.read_bytes()).hexdigest()}  {name}')
    (dest / 'SHA256SUMS').write_text('\n'.join(sums) + '\n')
    archive = ROOT / 'dist' / (folder + '.zip')
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as output:
        for file in sorted(dest.rglob('*')):
            if file.is_file():
                output.write(file, Path(folder) / file.relative_to(dest))
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    checksum = ROOT / 'dist' / (folder + '.zip.sha256')
    checksum.write_text(f'{digest}  {archive.name}\n')
    return dest, archive


if __name__ == '__main__':
    _, archive = build()
    print(archive)
