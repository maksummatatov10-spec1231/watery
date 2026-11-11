"""Build a deterministic, local DEVELOPMENT native package. Never publish it."""
import hashlib
import json
from pathlib import Path
import zipfile
ROOT=Path(__file__).resolve().parents[1]
REV=json.loads((ROOT/'reference/horizon-source.json').read_text(encoding='utf-8'))['commit']
PREFIX='mixins/watery/'
files={}
def put(path,data):
    if isinstance(data,str): data=data.encode('utf-8')
    if path in files: raise ValueError('Duplicate package path: '+path)
    files[path]=data
put('horizon-native.json',json.dumps(dict(schema=1,id='watery',version='1.2.2-dev',game='26.3',horizon=REV,mixins='5a64af938ec86b00d53d16a408aabc0038fb3e57'),indent=2)+'\n')
put(PREFIX+'horizon-mixin.toml',f'[mod]\nid="watery"\nversion="1.2.2-dev"\n[compatibility]\nhorizon_revision="{REV}"\n[api]\npath="api"\n')
put(PREFIX+'api/Cargo.toml',f'''[package]
name="mod-watery"
version="1.2.2-dev"
edition="2024"
license="GPL-3.0-only"
publish=false
[dependencies]
horizon-client={{git="https://github.com/horizon-rust/horizon",rev="{REV}"}}
watery-core={{path="core"}}
watery-gpu={{path="gpu"}}
wgpu={{version="=30.0.1",default-features=false,features=["std","wgsl"]}}
glam="0.30.9"
''')
put(PREFIX+'api/core/Cargo.toml','[package]\nname="watery-core"\nversion="0.1.0"\nedition="2024"\nlicense="GPL-3.0-only"\npublish=false\n')
put(PREFIX+'api/gpu/Cargo.toml','[package]\nname="watery-gpu"\nversion="0.1.0"\nedition="2024"\nlicense="GPL-3.0-only"\npublish=false\n[dependencies]\nwatery-core={path="../core"}\nwgpu={version="=30.0.1",default-features=false,features=["std","wgsl"]}\n')
for source,dest in [('native/src','api/src'),('src','api/core/src'),('gpu/src','api/gpu/src')]:
    for p in sorted((ROOT/source).rglob('*.rs')):
        text=p.read_text(encoding='utf-8').replace('../../generated/shaders/','../../data/shaders/')
        put(PREFIX+dest+'/'+p.relative_to(ROOT/source).as_posix(),text)
for p in sorted((ROOT/'generated/shaders').glob('*.wgsl')):
    put(PREFIX+'api/data/shaders/'+p.name,p.read_bytes())
put(PREFIX+'api/LICENSE',(ROOT/'reference/original/LICENSE_watery').read_bytes())
put(PREFIX+'api/NOTICE','Watery 1.2.2 original author: ItsBlueDD. GPL-3.0-only.\nModified Rust/Horizon development port, 2026-11-11.\nThis is NOT a full gameplay port. No warranty.\nAll required port sources are included. Original resources are preserved as reference data.\n')
put(PREFIX+'api/README.md',(ROOT/'reference/native-development.md').read_bytes())
# Preserve every resource verbatim as source data. Do not register incomplete
# gameplay blocks whose template flow would falsely substitute for Watery.
for p in sorted((ROOT/'reference/original/assets').rglob('*')):
    if p.is_file(): put(PREFIX+'api/data/original-assets/'+p.relative_to(ROOT/'reference/original/assets').as_posix(),p.read_bytes())
if len(files)>512 or sum(map(len,files.values()))>64*1024*1024: raise ValueError('Package exceeds host limits')
DEST=ROOT/'artifacts/watery-1.2.2-dev.hnmod'
DEST.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(DEST,'w',zipfile.ZIP_DEFLATED) as z:
    for name,data in sorted(files.items()):
        info=zipfile.ZipInfo(name,date_time=(2026,11,11,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
        z.writestr(info,data)
package_bytes=DEST.read_bytes()
# The launcher can install an unpacked .hnmod from a GitHub source archive when
# a release asset is unavailable; keep that source tree byte-identical too.
BUNDLE=ROOT/'native-bundle'
for name,data in sorted(files.items()):
    path=BUNDLE/name
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(data)
# Keep the historical root-level convenience path byte-identical; artifacts/ is canonical.
(ROOT/DEST.name).write_bytes(package_bytes)
report=dict(package=DEST.name,sha256=hashlib.sha256(package_bytes).hexdigest(),entries=len(files),expanded_bytes=sum(map(len,files.values())),horizon=REV,status='development; full gameplay parity NOT implemented')
(DEST.parent/'native-package.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(report,indent=2))
