#!/usr/bin/env python3
"""Stage a user's purchased GLB ZIP privately; no marketplace downloading."""
import argparse,zipfile
from pathlib import Path
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('archive',type=Path)
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
destination=root/'assets/private/gusai/source'
destination.mkdir(parents=True,exist_ok=True)
found=set()
with zipfile.ZipFile(args.archive) as z:
 for item in z.infolist():
  name=item.filename.lower()
  if not name.endswith('.glb'):continue
  kind='big_tail' if 'big tail' in name else 'split_tail' if 'seperate tail' in name or 'separate tail' in name else None
  if kind:
   (destination/(kind+'.glb')).write_bytes(z.read(item));found.add(kind)
if found!={'big_tail','split_tail'}:raise SystemExit('The ZIP must contain both purchased GLB fish exports.')
print('Purchased models staged privately:',destination)
print('Next: blender -b --python scripts/prepare-purchased-betta.py --',destination,root/'godot_project/assets/models/gusai_betta')
