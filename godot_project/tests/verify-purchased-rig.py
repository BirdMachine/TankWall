#!/usr/bin/env python3
"""Check optional private inputs: topology may change, authored rigs may not."""
import json,struct
from pathlib import Path
root=Path(__file__).resolve().parents[2]
source=root/'assets/private/gusai/source'
models=root/'godot_project/assets/models/gusai_betta'
sizes={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
components={5120:1,5121:1,5122:2,5123:2,5125:4,5126:4}
def load(path):
 raw=path.read_bytes();n=struct.unpack_from('<I',raw,12)[0]
 return json.loads(raw[20:20+n]),raw[28+n:]
def payload(doc,raw,index):
 a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
 element=sizes[a['type']]*components[a['componentType']]
 stride=v.get('byteStride',element);start=v.get('byteOffset',0)+a.get('byteOffset',0)
 return a['type'],a['componentType'],a['count'],b''.join(raw[start+i*stride:start+i*stride+element] for i in range(a['count']))
if not (source/'split_tail.glb').exists():
 print('Private purchased-rig verification skipped: licensed input not installed.')
 raise SystemExit(0)
for kind in ['split_tail','big_tail']:
 a,ab=load(source/(kind+'.glb'));b,bb=load(models/(kind+'_mobile.glb'))
 assert a['nodes']==b['nodes'], 'Skeleton node hierarchy changed'
 assert len(a['skins'])==len(b['skins'])
 for old,new in zip(a['skins'],b['skins']):
  assert old['joints']==new['joints'], 'Skin joint palette changed'
  assert payload(a,ab,old['inverseBindMatrices'])==payload(b,bb,new['inverseBindMatrices']), 'Bind transforms changed'
 assert len(a['animations'])==len(b['animations'])
 for old,new in zip(a['animations'],b['animations']):
  assert old['channels']==new['channels'], 'Animation target changed'
  for x,y in zip(old['samplers'],new['samplers']):
   for key in ['input','output']:assert payload(a,ab,x[key])==payload(b,bb,y[key]), 'Animation keys changed'
 triangles=sum(b['accessors'][p['indices']]['count']//3 for mesh in b['meshes'] for p in mesh['primitives'])
 assert triangles<60000, 'Mobile model exceeds the geometry budget'
 print(kind+': exact authored hierarchy, bind matrices and animation keys preserved; '+str(triangles)+' triangles')
