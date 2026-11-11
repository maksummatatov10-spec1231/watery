"""Read-only inspection of the supplied archive and standard Horizon locations."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import zipfile

root = Path(__file__).resolve().parents[1]
jar = root / 'watery-1.2.2.jar'
with zipfile.ZipFile(jar) as z:
    entries = z.infolist()
    print('JAR SHA256:', hashlib.sha256(jar.read_bytes()).hexdigest())
    print('Entries:', len(entries), 'Uncompressed bytes:', sum(e.file_size for e in entries))
    for name in ['fabric.mod.json', 'watery.mixins.json', 'LICENSE_watery', 'assets/watery/lang/en_us.json']:
        print('\n===', name, '===')
        text = z.read(name).decode('utf-8')
        print(text[:4500] if name.startswith('LICENSE') else text)
    classes = [e.filename for e in entries if e.filename.endswith('.class')]
    print('\nCLASSES (excluding GUI/shader language internals):')
    for name in classes:
        if not any(x in name for x in ['/gui/', '/sfy/', '/shader/', '/shaders/']):
            print(name)
    print('\nCLASS COUNT:', len(classes))
    print('\nSHADER COUNT:', sum(e.filename.endswith(('.comp', '.glsl', '.frag', '.vert')) for e in entries))
print('\nTOOLS:')
for tool in ['cargo', 'rustc', 'java', 'javap', 'horizon-launcher', 'wsl', 'py']:
    print(tool, shutil.which(tool))
print('\nSTANDARD HORIZON LOCATIONS (names only, no settings or account data):')
for base in [Path(os.environ.get('APPDATA', '')) / 'horizon', Path(os.environ.get('LOCALAPPDATA', '')) / 'horizon', Path(os.environ.get('LOCALAPPDATA', '')) / 'Programs' / 'Horizon', Path.home() / '.cargo' / 'bin']:
    print(base, 'exists=', base.exists())
    if base.is_dir():
        for entry in list(base.iterdir())[:45]:
            print(' ', entry.name, '/' if entry.is_dir() else '')
