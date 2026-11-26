#!/usr/bin/env python3
"""Remove project resources from an existing same-engine private APK template.

This reuses an unchanged, previously source-built Android host/plugin while
Godot exports the current project. It does not copy the previous game's data.
The normal release/CI build continues to compile the host/plugin from source.
"""
import argparse, zipfile
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('input', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--strip-library', action='append', default=[], help='Project extension library basename to re-export, repeatable')
args = parser.parse_args()
assert args.input.resolve() != args.output.resolve()
with zipfile.ZipFile(args.input) as source, zipfile.ZipFile(args.output, 'w') as target:
    assert 'lib/arm64-v8a/libgodot_android.so' in source.namelist()
    for item in source.infolist():
        if item.filename.startswith('lib/') and Path(item.filename).name in args.strip_library:
            continue
        if item.filename.startswith('assets/') and not item.filename.startswith('assets/licenses/'):
            continue
        if item.filename.startswith('META-INF/') and item.filename.upper().endswith(('.RSA', '.SF', '.MF')):
            continue
        target.writestr(item, source.read(item))
print('Native shell prepared; original project resources removed:', args.output)
