"""Blender -b --python scripts/prepare-purchased-betta.py -- SOURCE_DIR OUTPUT_DIR.
Simplify geometry without round-tripping the noncanonical C4D bind matrices.
Purchased inputs and generated GLBs stay private; source files are untouched.
"""
import sys,json,struct,copy,hashlib
from pathlib import Path
import bpy
import numpy as np

source,output=map(Path,sys.argv[sys.argv.index('--')+1:]);output.mkdir(parents=True,exist_ok=True)
DTYPES={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}
SIZES={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def load_glb(path):
 raw=path.read_bytes();length=struct.unpack_from('<I',raw,12)[0]
 return json.loads(raw[20:20+length]),bytearray(raw[28+length:])
def read_accessor(doc,raw,index):
 a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
 dtype=np.dtype(DTYPES[a['componentType']]);components=SIZES[a['type']]
 result=np.ndarray((a['count'],components),dtype=dtype,buffer=raw,
  offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',components*dtype.itemsize),dtype.itemsize)).copy()
 if a.get('normalized') and a['componentType']!=5126:
  result=result.astype(np.float32)/np.iinfo(dtype).max
 return result

def add_view(doc,raw,blob,target=None):
 raw.extend(b'\0'*((-len(raw))%4));view={'buffer':0,'byteOffset':len(raw),'byteLength':len(blob)}
 if target:view['target']=target
 doc['bufferViews'].append(view);raw.extend(blob)
 return len(doc['bufferViews'])-1

def add_accessor(doc,raw,array,kind,component=5126,target=34962,positions=False):
 array=np.asarray(array,dtype=DTYPES[component]);view=add_view(doc,raw,array.tobytes(),target)
 accessor={'bufferView':view,'componentType':component,'count':len(array),'type':kind}
 if positions:accessor.update(min=array.min(axis=0).tolist(),max=array.max(axis=0).tolist())
 doc['accessors'].append(accessor);return len(doc['accessors'])-1

def compact(doc,raw):
 used=set()
 for mesh in doc['meshes']:
  for p in mesh['primitives']:
   used.update(p['attributes'].values());used.add(p['indices'])
 for skin in doc.get('skins',[]):
  if 'inverseBindMatrices' in skin:used.add(skin['inverseBindMatrices'])
 for animation in doc.get('animations',[]):
  for sampler in animation['samplers']:used.update([sampler['input'],sampler['output']])
 mapping={old:new for new,old in enumerate(sorted(used))}
 doc['accessors']=[doc['accessors'][old] for old in sorted(used)]
 for mesh in doc['meshes']:
  for p in mesh['primitives']:
   p['attributes']={key:mapping[value] for key,value in p['attributes'].items()};p['indices']=mapping[p['indices']]
 for skin in doc.get('skins',[]):
  if 'inverseBindMatrices' in skin:skin['inverseBindMatrices']=mapping[skin['inverseBindMatrices']]
 for animation in doc.get('animations',[]):
  for sampler in animation['samplers']:
   sampler['input']=mapping[sampler['input']];sampler['output']=mapping[sampler['output']]
 views={a['bufferView'] for a in doc['accessors']}|{im['bufferView'] for im in doc.get('images',[]) if 'bufferView' in im}
 new_raw=bytearray();new_views=[];remap={}
 for old in sorted(views):
  view=copy.deepcopy(doc['bufferViews'][old]);start=view.get('byteOffset',0)
  new_raw.extend(b'\0'*((-len(new_raw))%4));view['byteOffset']=len(new_raw);view['buffer']=0
  new_raw.extend(raw[start:start+view['byteLength']]);remap[old]=len(new_views);new_views.append(view)
 for accessor in doc['accessors']:accessor['bufferView']=remap[accessor['bufferView']]
 for im in doc.get('images',[]):
  if 'bufferView' in im:im['bufferView']=remap[im['bufferView']]
 doc['bufferViews']=new_views;doc['buffers']=[{'byteLength':len(new_raw)}];doc['scene']=0
 return new_raw

def save_glb(path,doc,raw):
 # Both body variants share the same maps. External, content-addressed images
 # let Godot import and bundle each texture once instead of duplicating it.
 textures=output/'textures';textures.mkdir(exist_ok=True)
 for image in doc.get('images',[]):
  if 'bufferView' not in image:continue
  view=doc['bufferViews'][image.pop('bufferView')];start=view.get('byteOffset',0);blob=bytes(raw[start:start+view['byteLength']])
  suffix='.png' if image.get('mimeType')=='image/png' else '.jpg';name='map_'+hashlib.sha256(blob).hexdigest()[:20]+suffix
  target=textures/name
  if not target.exists():target.write_bytes(blob)
  image['uri']='textures/'+name
 raw=compact(doc,raw);encoded=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode()
 encoded+=b' '*((-len(encoded))%4);raw.extend(b'\0'*((-len(raw))%4))
 data=struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(raw))+struct.pack('<I4s',len(encoded),b'JSON')+encoded+struct.pack('<I4s',len(raw),b'BIN\0')+raw
 temporary=path.with_suffix('.tmp');temporary.write_bytes(data);temporary.replace(path)

shared_doc,shared_raw=load_glb(source/'split_tail.glb')
reports=[]
for model in ['split_tail','big_tail']:
 doc,raw=load_glb(source/(model+'.glb'))
 if model=='big_tail':
  doc['materials']=copy.deepcopy(shared_doc['materials']);doc['textures']=copy.deepcopy(shared_doc['textures']);doc['samplers']=copy.deepcopy(shared_doc.get('samplers',[]));doc['images']=copy.deepcopy(shared_doc['images'])
  for image in doc['images']:
   view=shared_doc['bufferViews'][image['bufferView']];start=view.get('byteOffset',0)
   image['bufferView']=add_view(doc,raw,shared_raw[start:start+view['byteLength']])
  for mesh in doc['meshes']:
   name=mesh['name'].lower();material=1 if 'glass' in name else 0 if 'eye' in name else 3 if 'mouth' in name else 2
   for p in mesh['primitives']:p['material']=material
 stats={'model':model,'before_triangles':0,'after_triangles':0}
 for mesh in doc['meshes']:
  for primitive in mesh['primitives']:
   attributes=primitive['attributes'];pos=read_accessor(doc,raw,attributes['POSITION']);normal=read_accessor(doc,raw,attributes['NORMAL']);uv=read_accessor(doc,raw,attributes['TEXCOORD_0']);joints=read_accessor(doc,raw,attributes['JOINTS_0']);weights=read_accessor(doc,raw,attributes['WEIGHTS_0']);indices=read_accessor(doc,raw,primitive['indices']).reshape(-1)
   rows=np.concatenate([pos,normal,uv,joints,weights],axis=1).astype(np.float32)
   _,keep,inverse=np.unique(rows,axis=0,return_index=True,return_inverse=True)
   pos=pos[keep];uv=uv[keep];joints=joints[keep];weights=weights[keep];faces=inverse[indices].reshape(-1,3)
   bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
   data=bpy.data.meshes.new('Private geometry');data.from_pydata(pos.tolist(),[],faces.tolist());data.update()
   obj=bpy.data.objects.new('Private geometry',data);bpy.context.collection.objects.link(obj);bpy.context.view_layer.objects.active=obj;obj.select_set(True)
   layer=data.uv_layers.new()
   for loop in data.loops:layer.data[loop.index].uv=uv[loop.vertex_index]
   groups=[obj.vertex_groups.new(name='joint_%d'%i) for i in range(int(joints.max())+1)]
   for i in range(len(pos)):
    for j,w in zip(joints[i],weights[i]):
     if w>0:groups[int(j)].add([i],float(w),'REPLACE')
   count=len(faces);stats['before_triangles']+=count;name=mesh.get('name','').lower()
   target=18000 if 'main-body' in name or 'main-fish' in name else 3000 if 'mouth' in name else 6500
   if 'eye' in name:target=700
   if count>target:
    modifier=obj.modifiers.new('Rest geometry reduction','DECIMATE');modifier.ratio=target/count;modifier.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=modifier.name)
   data=obj.data
   for polygon in data.polygons:polygon.use_smooth=True
   data.update();data.calc_loop_triangles();layer=data.uv_layers.active
   out_pos=[];out_normal=[];out_uv=[];out_joints=[];out_weights=[];out_indices=[];seen={}
   for triangle in data.loop_triangles:
    for loop_index in triangle.loops:
     loop=data.loops[loop_index];v=data.vertices[loop.vertex_index];tex=tuple(layer.data[loop_index].uv);key=(loop.vertex_index,tex)
     if key not in seen:
      seen[key]=len(out_pos);out_pos.append(tuple(v.co));out_normal.append(tuple(v.normal));out_uv.append(tex)
      influences=sorted([(g.group,g.weight) for g in v.groups],key=lambda x:-x[1])[:4];total=sum(w for j,w in influences) or 1.0
      out_joints.append([j for j,w in influences]+[0]*(4-len(influences)));out_weights.append([w/total for j,w in influences]+[0.0]*(4-len(influences)))
     out_indices.append(seen[key])
   primitive['attributes']={
    'POSITION':add_accessor(doc,raw,out_pos,'VEC3',positions=True),
    'NORMAL':add_accessor(doc,raw,out_normal,'VEC3'),
    'TEXCOORD_0':add_accessor(doc,raw,out_uv,'VEC2'),
    'JOINTS_0':add_accessor(doc,raw,out_joints,'VEC4',5123),
    'WEIGHTS_0':add_accessor(doc,raw,out_weights,'VEC4')}
   primitive['indices']=add_accessor(doc,raw,out_indices,'SCALAR',5125,34963)
   stats['after_triangles']+=len(out_indices)//3
   print(model,mesh.get('name'),count,'->',len(out_indices)//3,flush=True)
 save_glb(output/(model+'_mobile.glb'),doc,raw);reports.append(stats);print('MOBILE MODEL',stats,flush=True)
(output/'preparation.json').write_text(json.dumps(reports,indent=2))
