"""Verify extracted resources against the supplied archive, not against generated expectations."""
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_JAR = 'd5b4e546ed6e7e3834a8a31ddfd3066500540adde53f723545ea5ebdf307d973'
jar = ROOT / 'watery-1.2.2.jar'
assert hashlib.sha256(jar.read_bytes()).hexdigest() == EXPECTED_JAR, 'Original JAR changed'
inventory = json.loads((ROOT / 'reference/jar-inventory.json').read_text(encoding='utf-8'))
with zipfile.ZipFile(jar) as z:
    originals = {i.filename for i in z.infolist() if not i.is_dir()}
    assert originals == {i['path'] for i in inventory}, 'Inventory incomplete'
    preserved = 0
    for item in inventory:
        data = z.read(item['path'])
        assert len(data) == item['bytes']
        assert hashlib.sha256(data).hexdigest() == item['sha256']
        if item['path'].endswith('.class') or item['path'].startswith('META-INF/'):
            continue
        copy = ROOT / 'reference/original' / item['path']
        assert copy.read_bytes() == data, f'Resource mismatch: {item["path"]}'
        preserved += 1
    metadata = json.loads(z.read('fabric.mod.json'))
    assert metadata['version'] == '1.2.2'
    assert metadata['license'] == 'GPL-3.0-only'
print(f'PASS: original JAR SHA256 unchanged; {len(inventory)} inventory entries verified; {preserved} resources byte-identical.')
