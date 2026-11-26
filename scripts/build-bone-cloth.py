#!/usr/bin/env python3
"""Build a pinned MIT Bone Cloth extension for desktop and optional Android ABIs.
No purchased fish data is read, downloaded or sent anywhere by this script.
"""
from pathlib import Path
import argparse, importlib.util, json, os, re, shutil, subprocess, sys
ROOT=Path(__file__).resolve().parents[1]
SOURCE_SHA='0fa3f9f8faeaac6e5d981f454a03329be522af3f'
NDK='28.1.13356709'
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source-dir',type=Path,default=ROOT/'build/vendor/bone-cloth')
p.add_argument('--android',action='store_true')
p.add_argument('--stage-only',action='store_true')
p.add_argument('--jobs',type=int,default=min(4,os.cpu_count() or 2))
args=p.parse_args();source=args.source_dir.resolve()
def run(command,**kwargs):
 subprocess.run([str(v) for v in command],check=True,**kwargs)
if not (source/'.git').exists():
 source.parent.mkdir(parents=True,exist_ok=True)
 run(['git','clone','--filter=blob:none','--no-checkout','https://github.com/pulppixel/godot-bone-cloth.git',source])
run(['git','fetch','--depth','1','origin',SOURCE_SHA],cwd=source)
run(['git','checkout','--detach',SOURCE_SHA],cwd=source)
run(['git','submodule','update','--init','--depth','1'],cwd=source)
# Include the API classes the pinned extension actually uses, rather than all
# engine classes. This keeps Android compilation practical and deterministic.
sys.path.insert(0,str(source/'godot-cpp'))
from binding_generator import camel_to_snake
api=json.loads((source/'godot-cpp/gdextension/extension_api-4-7.json').read_text())
headers=set()
for folder in [source/'src',source/'godot-cpp/src']:
 for f in folder.rglob('*'):
  if f.suffix in ('.cpp','.h'):
   headers.update(re.findall(r'godot_cpp/classes/([a-z0-9_]+)\.hpp',f.read_text()))
classes=sorted(c['name'] for c in api['classes'] if camel_to_snake(c['name']) in headers)
# EditorUndoRedoManager uses UndoRedo's enum without a direct source include.
classes=sorted(set(classes)|{'UndoRedo'})
profile=source/'tamotank-build-profile.json'
profile.write_text(json.dumps({'enabled_classes':classes},indent=2))
if not args.stage_only:
 targets=[('linux','x86_64','template_debug')]
 if args.android:targets += [('android','arm64','template_debug'),('android','x86_64','template_debug'),('android','arm64','template_release')]
 for platform,arch,target in targets:
  command=[sys.executable,'-m','SCons',f'platform={platform}',f'arch={arch}',f'target={target}',
   f'build_profile={profile}',f'-j{args.jobs}','debug_symbols=no','dev_build=no']
  if platform=='android':command += [f'ndk_version={NDK}','android_api_level=24']
  run(command,cwd=source)
addon=ROOT/'godot_project/addons/bone_cloth'
shutil.copytree(source/'project/addons/bone_cloth',addon,dirs_exist_ok=True)
extension=addon/'bone_cloth.gdextension';text=extension.read_text()
android_entries='''android.debug.arm64 = "bin/libbonecloth.android.template_debug.arm64.so"
android.release.arm64 = "bin/libbonecloth.android.template_release.arm64.so"
android.debug.x86_64 = "bin/libbonecloth.android.template_debug.x86_64.so"
'''
text=text.replace('[icons]',android_entries+'\n[icons]');extension.write_text(text)
# Package only the extension/code notices, not licences for unused upstream demos.
licences=ROOT/'godot_project/licenses';licences.mkdir(exist_ok=True)
notices=(source/'THIRD_PARTY_NOTICES.md').read_text().split('## VRoid Studio')[0]
(licences/'BoneCloth.txt').write_text((source/'LICENSE').read_text()+'\n'+notices)
(addon/'TAMOTANK_SOURCE.json').write_text(json.dumps({'repository':'https://github.com/pulppixel/godot-bone-cloth','commit':SOURCE_SHA,'android_ndk':NDK,'android_api':24,'extension_api':'4.7','profile_classes':classes},indent=2))
print('Bone Cloth staged:',SOURCE_SHA,'with',len(classes),'explicit API classes')
