"""Measure an exported Windows package with isolated saves and the same six-AI soak.

No package resources are rewritten. A test-only BattleRequest script replacement
enables the player's AI seat before loading, matching performance_soak.py.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--engine', type=Path, help='Optional editor-engine control using the same exported PCK')
    parser.add_argument('--seconds', type=float, default=60)
    args = parser.parse_args()
    if os.name != 'nt' or args.seconds <= 0:
        parser.error('Windows and positive seconds required')
    package, out = args.package.resolve(), args.output.resolve()
    manifest = json.loads((package/'build-manifest.json').read_text('utf8'))
    names = ['IronTide.exe', 'IronTide.pck']
    original_hashes = {name: digest(package/name) for name in names}
    assert all(original_hashes[name] == manifest['files'][name] for name in names)
    source = Path(manifest['source'])
    source_request = source/'scripts/autoload/battle_request.gd'
    source_manifest = package.parents[1]/'source-sha256.json'
    assert digest(source_manifest) == manifest['source_manifest_sha256']
    source_hashes = json.loads(source_manifest.read_text('utf8'))
    assert digest(source_request) == source_hashes['scripts/autoload/battle_request.gd']
    out.mkdir(parents=True, exist_ok=False)
    runtime = out/'package'
    runtime.mkdir()
    for name in names:
        shutil.copy2(package/name, runtime/name)
        assert digest(runtime/name) == original_hashes[name]

    request = source_request.read_text('utf8')
    hook = 'func is_ai_house(side: String) -> bool:\n'
    assert request.count(hook) == 1
    request = request.replace(hook, hook+'\tif side=="ally": return true # isolated test only\n')
    request_path = out/'autopilot_request.gd'
    request_path.write_text(request, 'utf8')
    probe = Path(__file__).with_name('performance_soak.gd').read_text('utf8')
    probe = probe.replace('const TimerProbe=preload("res://timer.gd")\n', '')
    for line in ['\tTimerProbe.costs.clear()\n', '\tTimerProbe.calls.clear()\n', '\tTimerProbe.samples.clear()\n',
                 '\t\t\tTimerProbe.costs.clear()\n', '\t\t\tTimerProbe.calls.clear()\n', '\t\t\tTimerProbe.samples.clear()\n',
                 '\tpreload("res://unit_call_probe.gd").take()\n']:
        # Match complete lines; do not consume a suffix of a deeper indentation.
        probe = ''.join(row for row in probe.splitlines(keepends=True) if row != line)
    probe = probe.replace('preload("res://unit_call_probe.gd").take()', '[]')
    for field in ['costs', 'calls', 'samples']:
        probe = probe.replace('TimerProbe.'+field+'.duplicate()', '{}')
    probe = probe.replace('OS.get_user_data_dir().contains("CodexIronTideValidation")', 'OS.get_user_data_dir().begins_with(OS.get_environment("APPDATA").replace("\\\\","/"))')
    hook = 'func run():\n'
    assert probe.count(hook) == 1 and 'TimerProbe' not in probe and 'unit_call_probe' not in probe
    probe = probe.replace(hook, hook+'\tvar autopilot=load(OS.get_environment("IRON_AI_SCRIPT"))\n'
                          '\tif autopilot==null:\n\t\tget_tree().quit(2);return\n'
                          '\tBattleRequest.set_script(autopilot)\n'
                          '\tif not BattleRequest.is_ai_house("ally"):\n\t\tget_tree().quit(2);return\n')
    probe = probe.replace('\tresult.initial_state=initial_state\n', '\tresult.initial_state=initial_state\n'
                          '\tresult.runtime={"editor":OS.has_feature("editor"),"engine":Engine.get_version_info().string,"per_unit_probe":false,"rules_mode":BattleRequest.rules_mode,"extensions_enabled":BattleRequest.extensions_enabled()}\n')
    probe_path = out/'probe.tscn'
    probe_path.write_text('[gd_scene load_steps=2 format=3]\n[sub_resource type="GDScript" id="1"]\nscript/source = '
                          +json.dumps(probe, ensure_ascii=False)+'\n[node name="PackageSoak" type="Node"]\nscript=SubResource("1")\n', 'utf8')
    override = runtime/'override.cfg'
    override.write_text('[application]\nrun/main_scene="'+probe_path.as_posix()+'"\n', 'utf8')
    executable = args.engine.resolve() if args.engine else runtime/'IronTide.exe'
    command = [str(executable), '--headless']
    if args.engine:
        command += ['--path', str(runtime), '--main-pack', str(runtime/'IronTide.pck')]
    env = dict(os.environ, APPDATA=str(out/'profile'), LOCALAPPDATA=str(out/'profile'), IRON_OUT=str(out),
               IRON_SECONDS=str(args.seconds), IRON_SPEED='1', IRON_SAVE=str(args.save.resolve()),
               IRON_EXPECT_MAP='yr_isleland', IRON_AI_SCRIPT=str(request_path))
    env.pop('IRON_TIDE_CALL_LOG', None)
    evidence = {'package':str(package), 'package_hashes':original_hashes, 'executable':str(executable),
                'executable_sha256':digest(executable), 'checkpoint_sha256':digest(args.save), 'seconds':args.seconds,
                'speed':1, 'ai_count':6, 'map':'yr_isleland', 'renderer':'headless', 'profile':str(out/'profile'),
                'per_unit_probe':False, 'database':'none', 'probe_sha256':digest(probe_path),
                'ai_override_sha256':digest(request_path), 'ai_override_source_sha256':digest(source_request),
                'ai_override':'Same source as packaged BattleRequest, only is_ai_house(ally)=true; replaced before save load.',
                'limitations':'Headless CPU timings, not displayed GPU FPS. No extra per-unit call probe; compare with the same harness only.'}
    (out/'environment.json').write_text(json.dumps(evidence, indent=2), 'utf8')
    try:
        with (out/'log').open('wb') as stream:
            result = subprocess.run(command, cwd=runtime, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                    creationflags=subprocess.CREATE_NO_WINDOW, timeout=args.seconds+180)
        log = (out/'log').read_text('utf8', errors='replace')
        errors = [line for line in log.splitlines() if line.startswith(('SCRIPT ERROR:', 'ERROR:', 'FAIL '))]
        print('exit', result.returncode, 'errors', errors[:5], flush=True)
        assert result.returncode == 0 and not errors
        measured = json.loads((out/'result.json').read_text('utf8'))
        assert measured['completed'] and measured['ai_count']==6 and measured['speed']==1
        assert measured['initial_state']['map']=='yr_isleland'
        assert measured['runtime']['editor'] == bool(args.engine)
        assert (out/'end.itsave').is_file()
        assert all(digest(package/name)==original_hashes[name] and digest(runtime/name)==original_hashes[name] for name in names)
        (out/'source-audit.json').write_text(json.dumps({'package_unchanged':True, 'runtime_unchanged':True}), 'utf8')
        print('p95', measured['frame_stats']['p95_ms'], 'logic95', measured['logic_stats']['p95_ms'],
              'speed', measured['sim']/measured['wall'], 'output', out, flush=True)
    finally:
        override.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
