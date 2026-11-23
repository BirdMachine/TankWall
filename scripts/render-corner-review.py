#!/usr/bin/env python3
"""Render a square review without changing the app's portrait project settings.

Requires a graphical display (software OpenGL is fine) and imported vendor model.
Example: python3 scripts/render-corner-review.py --output /tmp/corners.avi
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1] / 'godot_project')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--label', default='NIGHTFLIGHT')
    parser.add_argument('--script', default='CornerShowcase.gd')
    args = parser.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='tankwall-review-') as temporary:
        project = Path(temporary) / 'project'
        shutil.copytree(args.project, project, ignore=shutil.ignore_patterns('.godot', 'build'))
        config = project / 'project.godot'
        text = config.read_text().replace('viewport_width=1080', 'viewport_width=720')
        text = text.replace('viewport_height=2400', 'viewport_height=720')
        config.write_text(text)
        subprocess.run([args.godot, '--headless', '--editor', '--path', str(project), '--quit'], check=True)
        subprocess.run([args.godot, '--path', str(project), '--fixed-fps', '30',
                        '--resolution', '720x720', '--write-movie', str(output),
                        '--script', 'res://scripts/' + args.script, '--', '--label=' + args.label], check=True)


if __name__ == '__main__':
    main()
