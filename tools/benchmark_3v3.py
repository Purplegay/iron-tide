"""Isolated, no-window two-match 3v3 CPU soak. Does not touch player saves.

python tools/benchmark_3v3.py --godot PATH_TO_GODOT --output NEW_REPORT_DIRECTORY
Add --profile for intrusive inclusive function timers (not comparable to clean P95).
Artifacts and checkpoints are retained; this tool never cleans another directory.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--profile', action='store_true')
    args = parser.parse_args()
    if os.name != 'nt':
        parser.error('This runner uses Windows junctions and CREATE_NO_WINDOW.')
    source = Path(__file__).resolve().parents[1] / 'iron_tide'
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    project = output / 'project'
    project.mkdir()
    # Copy mutable source before inserting test-only autopilot/instrumentation.
    shutil.copytree(source / 'scripts', project / 'scripts')
    for name in ['project.godot', 'icon.svg', 'icon.svg.import']:
        shutil.copy2(source / name, project / name)
    for name in ['assets', 'data', 'shaders', 'scenes', 'tests', '.godot']:
        link = str(project / name).replace("'", "''")
        target = str(source / name).replace("'", "''")
        subprocess.run(['powershell', '-NoProfile', '-Command',
                        f"New-Item -ItemType Junction -Path '{link}' -Target '{target}' | Out-Null"],
                       creationflags=subprocess.CREATE_NO_WINDOW, check=True)
    fingerprint = {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in sorted((project / 'scripts').rglob('*.gd'))}
    (output / 'source-sha256.json').write_text(json.dumps(fingerprint, indent=2), 'utf8')
    settings = project / 'project.godot'
    settings.write_text(settings.read_text('utf8').replace(
        '[application]', '[application]\nconfig/use_custom_user_dir=true\n'
        'config/custom_user_dir_name="CodexIronTideValidation/3v3"'), 'utf8')
    shutil.copy2(Path(__file__).with_name('benchmark_3v3.gd'), project / 'soak.gd')
    (project / 'soak.tscn').write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" '
        'path="res://soak.gd" id="1"]\n[node name="Soak" type="Node"]\n'
        'script=ExtResource("1")\n', 'utf8')
    (project / 'timer.gd').write_text('''extends RefCounted
static var costs:Dictionary={}
static var calls:Dictionary={}
var key:String
var begin:int
func _init(k:String):
 key=k
 begin=Time.get_ticks_usec()
func _notification(what):
 if what==NOTIFICATION_PREDELETE:
  costs[key]=int(costs.get(key,0))+Time.get_ticks_usec()-begin
  calls[key]=int(calls.get(key,0))+1
''', 'utf8')
    request = project / 'scripts/autoload/battle_request.gd'
    text = request.read_text('utf8')
    signature = 'func is_ai_house(side: String) -> bool:\n'
    if text.count(signature) != 1:
        raise RuntimeError('Autopilot hook changed; refusing unsafe source patch.')
    request.write_text(text.replace(signature, signature +
                                   '\tif side=="ally": return true # isolated test only\n'), 'utf8')
    names = {'unit': ['_physics_process', '_process_combat', '_refresh_target', '_move_toward', '_tick_skills'],
             'house_ai': ['_process', '_manage_base', 'building_site'],
             'building': ['_process', '_acquire_target'], 'battle': ['_process', 'build_spot_ok'],
             'fog_of_war': ['rebuild'], 'minimap': ['_draw'], 'path_service': ['find_path', '_build_zones'],
             'ai_unit_dispatch': ['pump'], 'ai_base_access': ['tick'], 'local_traffic': ['apply'],
             'air_relief': ['tick'], 'skirmish_tactics': ['attack_position', 'base_threat'],
             'skirmish_operations': ['tick', 'unit_decision']}
    if args.profile:
        for path in (project / 'scripts').rglob('*.gd'):
            if path.stem not in names:
                continue
            lines = []
            for line in path.read_text('utf8').splitlines(keepends=True):
                lines.append(line)
                match = re.match(r'^(?:static )?func (\w+)\(.*\).*:\s*$', line)
                if match and match[1] in names[path.stem]:
                    lines.append('\tvar _probe=preload("res://timer.gd").new("' +
                                 path.stem + '.' + match[1] + '")\n')
            path.write_text(''.join(lines), 'utf8')
    profile = output / 'profile'
    profile.mkdir()
    env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile), IRON_OUT=str(output))
    with (output / 'log').open('wb') as log:
        result = subprocess.run([str(args.godot.resolve()), '--headless', '--path', str(project),
                                 'res://soak.tscn'], env=env, stdout=log, stderr=subprocess.STDOUT,
                                creationflags=subprocess.CREATE_NO_WINDOW, timeout=2100)
    print('exit:', result.returncode, 'report:', output / 'result.json')
    if result.returncode == 0:
        report = json.loads((output / 'result.json').read_text('utf8'))
        if set(report) != {'0', '1'} or any(not game['windows'] for game in report.values()):
            raise RuntimeError('Both matches must produce frame samples.')
        log_text = (output / 'log').read_text('utf8', errors='replace')
        if 'SCRIPT ERROR:' in log_text or 'Parse Error:' in log_text:
            raise RuntimeError('Godot reported a script error; inspect the retained log.')
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
