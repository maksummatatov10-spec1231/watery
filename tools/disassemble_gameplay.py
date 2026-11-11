"""Recover missing Watery gameplay bytecode locally; never execute the mod."""
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
JAR = ROOT / 'watery-1.2.2.jar'
JAVAP = Path('C:/Users/Jonn Konnor/AppData/Local/Programs/Eclipse Adoptium/jdk-25.0.3.9-hotspot/bin/javap.exe')
OUT = ROOT / 'reference/bytecode'
if not JAVAP.is_file():
    raise SystemExit('JDK javap not found at configured location')
with zipfile.ZipFile(JAR) as archive:
    names = sorted(n[:-6].replace('/', '.') for n in archive.namelist()
        if n.endswith('.class') and n.startswith('me/blue/')
        and not any('/' + part + '/' in n for part in ('vk', 'vista', 'gui', 'sfy', 'shader', 'shaders')))
count = 0
for name in names:
    target = OUT / (name + '.txt')
    if target.exists():
        continue
    result = subprocess.run([str(JAVAP), '-classpath', str(JAR), '-p', '-c', '-constants', name],
        capture_output=True, text=True, encoding='utf-8', errors='replace', check=True)
    target.write_text(result.stdout, encoding='utf-8', newline='\n')
    count += 1
print(f'Preserved existing listings; disassembled {count} additional gameplay classes')
