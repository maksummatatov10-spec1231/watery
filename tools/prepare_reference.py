"""Preserve local reference material without executing any code from the JAR."""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'reference'
OUT.mkdir(exist_ok=True)
jar = ROOT / 'watery-1.2.2.jar'
manifest = []
with zipfile.ZipFile(jar) as z:
    for info in z.infolist():
        if info.is_dir():
            continue
        name = PurePosixPath(info.filename)
        if name.is_absolute() or '..' in name.parts or ':' in info.filename or '\\' in info.filename:
            raise ValueError('Unsafe archive path')
        data = z.read(info)
        manifest.append({'path': info.filename, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        if not info.filename.endswith('.class') and not info.filename.startswith('META-INF/'):
            target = OUT / 'original' / Path(*name.parts)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    (OUT / 'jar-inventory.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8', newline='\n')
    classes = [x.filename[:-6].replace('/', '.') for x in z.infolist() if x.filename.endswith('.class') and (x.filename.startswith('me/blue/client/water/') or x.filename in ['me/blue/RealisticWater.class', 'me/blue/ModContent.class'])]
java_bin = Path('C:/Users/Jonn Konnor/AppData/Local/Programs/Eclipse Adoptium/jdk-25.0.3.9-hotspot/bin')
javap = java_bin / 'javap.exe'
print('JDK25 javap exists:', javap.exists())
if javap.exists():
    dest = OUT / 'bytecode'
    dest.mkdir(exist_ok=True)
    for cls in classes:
        result = subprocess.run([str(javap), '-classpath', str(jar), '-p', '-c', '-constants', cls], capture_output=True, text=True, encoding='utf-8', errors='replace')
        if result.returncode:
            raise RuntimeError(result.stderr)
        (dest / (cls + '.txt')).write_text(result.stdout, encoding='utf-8', newline='\n')
    print('Disassembled classes:', len(classes))
print('Inventoried files:', len(manifest))
print('Preserved original non-class resources; no game installation changed.')
for base in [Path(os.environ['LOCALAPPDATA']) / 'Programs', Path(os.environ['LOCALAPPDATA']), Path(os.environ['APPDATA'])]:
    print('\nHorizon-named directories in', base)
    for p in base.iterdir():
        if 'horizon' in p.name.lower():
            print(p)
            if p.is_dir():
                for child in list(p.iterdir())[:25]:
                    print(' ', child.name)
