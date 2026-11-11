"""Archive the authorized project handoff with installed 7-Zip; no code execution from inputs."""
from pathlib import Path
import hashlib
import json
import subprocess
ROOT=Path(__file__).resolve().parents[1]
SEVEN=Path('C:/Program Files/7-Zip/7z.exe')
OUT=ROOT/'artifacts/watery-project-handoff.7z'
LIST=ROOT/'artifacts/handoff-files.txt'
REPORT=ROOT/'artifacts/handoff-archive.json'
EXCLUDE={'.git','target','node_modules','.venv','venv','__pycache__','.pytest_cache','.mypy_cache','.ruff_cache','.sharrowkin','.idea','.vscode'}
files=[]
for p in ROOT.rglob('*'):
    rel=p.relative_to(ROOT)
    if any(part in EXCLUDE for part in rel.parts): continue
    if not p.is_file() or p in (OUT,LIST,REPORT): continue
    if p.name=='.env' or p.name.startswith('.env.') and p.name!='.env.example': continue
    if p.suffix.lower() in ('.pem','.key','.pfx') or p.name in ('id_rsa','id_ed25519'): continue
    files.append(rel.as_posix())
files.sort()
if OUT.exists(): raise SystemExit('Archive already exists; inspect before replacing')
LIST.write_text('\n'.join(files)+'\n',encoding='utf-8')
subprocess.run([str(SEVEN),'a','-t7z','-mx=3','-scsUTF-8',str(OUT),'@'+str(LIST)],cwd=ROOT,check=True)
subprocess.run([str(SEVEN),'t',str(OUT)],cwd=ROOT,check=True)
report={'archive':OUT.name,'files':len(files),'source_bytes':sum((ROOT/f).stat().st_size for f in files),'archive_bytes':OUT.stat().st_size,'sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),'integrity':'7z t passed','excluded':'build caches, IDE history/config, credentials, archive itself'}
REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
