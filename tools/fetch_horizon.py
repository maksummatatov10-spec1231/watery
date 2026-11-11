"""Fetch a pinned public Horizon source snapshot without executing its code."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'vendor' / 'horizon'
META = ROOT / 'reference' / 'horizon-source.json'
HEADERS = {'User-Agent': 'Watery-local-port', 'Accept': 'application/vnd.github+json'}

def fetch(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=180) as response:
        return response.read()

if DEST.exists() or META.exists():
    raise SystemExit('Source or metadata already exists; inspect before fetching again.')
commit = json.loads(fetch('https://api.github.com/repos/horizon-rust/horizon/commits/main'))['sha']
archive = ROOT / 'reference' / f'horizon-{commit}.zip'
data = fetch(f'https://codeload.github.com/horizon-rust/horizon/zip/{commit}')
archive.write_bytes(data)
with zipfile.ZipFile(archive) as z:
    entries = z.infolist()
    if sum(e.file_size for e in entries) > 2_000_000_000:
        raise SystemExit('Unexpectedly large archive')
    for entry in entries:
        parts = PurePosixPath(entry.filename).parts[1:]
        if not parts:
            continue
        if any(p in ('..', '.') or ':' in p or '\\' in p for p in parts):
            raise SystemExit('Unsafe archive path')
        target = DEST.joinpath(*parts)
        if entry.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            with z.open(entry) as src, target.open('xb') as dst:
                import shutil
                shutil.copyfileobj(src, dst)
META.write_text(json.dumps({'repository': 'https://github.com/horizon-rust/horizon', 'commit': commit,
                           'archive_sha256': hashlib.sha256(data).hexdigest(), 'archive_bytes': len(data)}, indent=2) + '\n', encoding='utf-8', newline='\n')
print(f'Fetched Horizon {commit}: {len(entries)} entries, {len(data)} archive bytes; no source executed.')
