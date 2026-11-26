#!/usr/bin/env python3
"""Install the matching official Android Gradle template for this Godot binary."""
from pathlib import Path
import os,re,shutil,subprocess,zipfile
root=Path(__file__).resolve().parents[1]
version=subprocess.check_output(['godot','--version'],text=True).strip()
match=re.match(r'(4\.\d+(?:\.\d+)?\.[a-z]+)',version)
if not match:raise RuntimeError('Unrecognized Godot version: '+version)
version=match[1]
data=Path(os.environ.get('XDG_DATA_HOME',Path.home()/'.local/share'))
archive=data/'godot/export_templates'/version/'android_source.zip'
android=root/'godot_project/android';build=android/'build';stamp=android/'.build_version'
android.mkdir(parents=True,exist_ok=True)
(android/'.gdignore').write_text('')
if not (build/'gradlew').exists() or not stamp.exists() or stamp.read_text().strip()!=version:
 build.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(archive) as z:z.extractall(build)
 stamp.write_text(version)
(build/'gradlew').chmod(0o755)
print('Android Gradle template ready:',version)

# Imported skin caches are not interchangeable across all engine versions.
# Preserve editor preferences while forcing the model/texture import for this engine.
cache=root/'godot_project/.godot'
cache_stamp=cache/'tamotank-import-engine'
if not cache_stamp.exists() or cache_stamp.read_text().strip()!=version:
 shutil.rmtree(cache/'imported',ignore_errors=True)
 shutil.rmtree(cache/'shader_cache',ignore_errors=True)
 cache.mkdir(exist_ok=True)
 cache_stamp.write_text(version)
 print('Model import cache prepared for:',version)
