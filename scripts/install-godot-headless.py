#!/usr/bin/env python3
"""Install latest stable Godot 4 Linux editor + matching export templates in Codespaces."""
from __future__ import annotations
import json, re, shutil, stat, tempfile, urllib.request, zipfile
from pathlib import Path

BIN = Path.home() / '.local/bin/godot'
TEMPLATES_ROOT = Path.home() / '.local/share/godot/export_templates'
API = 'https://api.github.com/repos/godotengine/godot-builds/releases'


def fetch_json(url: str):
    req = urllib.request.Request(url, headers={'User-Agent': 'tankwall-codespaces-setup'})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def download(url: str, dest: Path):
    print(f'Downloading {url}')
    req = urllib.request.Request(url, headers={'User-Agent': 'tankwall-codespaces-setup'})
    with urllib.request.urlopen(req, timeout=600) as r, dest.open('wb') as f:
        shutil.copyfileobj(r, f)


def pick_release():
    for rel in fetch_json(API):
        tag = rel.get('tag_name', '')
        if rel.get('prerelease') or rel.get('draft') or not re.match(r'^4\.', tag):
            continue
        assets = rel.get('assets', [])
        editor = next((a for a in assets if 'linux.x86_64.zip' in a['name'] and 'mono' not in a['name']), None)
        templates = next((a for a in assets if a['name'].endswith('_export_templates.tpz')), None)
        if editor and templates:
            return tag, editor['browser_download_url'], templates['browser_download_url']
    raise RuntimeError('Could not find stable Godot 4 editor/export templates')


def main():
    BIN.parent.mkdir(parents=True, exist_ok=True)
    tag, editor_url, templates_url = pick_release()
    download_version = tag.lstrip('v')
    godot_version = download_version.replace('-stable', '.stable')

    if not BIN.exists():
        print(f'Installing Godot {download_version}')
        with tempfile.TemporaryDirectory() as td_name:
            td = Path(td_name)
            editor_zip = td / 'godot.zip'
            download(editor_url, editor_zip)
            with zipfile.ZipFile(editor_zip) as z:
                z.extractall(td / 'editor')
            exe = next((p for p in (td / 'editor').iterdir() if p.is_file() and 'Godot' in p.name), None)
            if exe is None:
                raise RuntimeError('Could not find Godot executable in release zip')
            shutil.copy2(exe, BIN)
            BIN.chmod(BIN.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    else:
        print(f'Godot already installed at {BIN}')

    dest = TEMPLATES_ROOT / godot_version
    debug_apk = dest / 'android_debug.apk'
    release_apk = dest / 'android_release.apk'
    if not (debug_apk.exists() and release_apk.exists()):
        print(f'Installing matching export templates to {dest}')
        with tempfile.TemporaryDirectory() as td_name:
            td = Path(td_name)
            templates_zip = td / 'templates.tpz'
            download(templates_url, templates_zip)
            dest.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(templates_zip) as z:
                for member in z.infolist():
                    name = member.filename
                    if not name.startswith('templates/') or name.endswith('/'):
                        continue
                    member.filename = name.removeprefix('templates/')
                    z.extract(member, dest)
    else:
        print(f'Export templates already installed at {dest}')

    print(f'Godot binary: {BIN}')
    print(f'Export templates: {dest}')


if __name__ == '__main__':
    main()
