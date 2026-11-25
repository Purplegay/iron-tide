"""Isolated six-AI wall-clock CPU soak with per-unit behavior counts. Does not touch player saves.

python tools/performance_soak.py --godot PATH_TO_GODOT --output NEW_REPORT_DIRECTORY --save MINUTE_3_SAVE
Prepare that checkpoint once with --seconds 180 and no --save; reuse its end.itsave.
Add --profile for detailed sampled inclusive CPU timers; compare clean runs separately.
Add --native-profile with a debug-capable engine for every executed GDScript
function's call count, self time and inclusive time in functions.json. Loading
and checkpoint saving are outside the measured window. Frame tables are muted
until the final accumulated export; this mode is not a release P95 benchmark.
Add --host-cpu for read-only host/benchmark CPU telemetry aligned to the measured window.
Use --isolated-desktop on Windows for real graphics on a private desktop that is
never activated. --render-size requests the client size; result.graphics records
the actual size, which Windows may constrain. --hide-effects is a diagnostic
draw-only comparison, never a production optimization or a gameplay disable.
Use --engine-phases separately to record physics/process/draw boundaries and
engine monitors in engine-phases.json. Headless renderers may emit no draw
signals; the remaining intervals must not be labeled GPU or native self time.
Use --save SLOT1 --preserve-player --mirror-player-growth --player-actions to
mirror saved talents/W/passive ranks to the five AI and exercise player orders.
AI ownership, difficulty stats and economy remain unchanged; supported Auto W
triggers run normally. Manual-only cards are equipped but are not auto-cast.
Artifacts and checkpoints are retained; this tool never cleans another directory.
"""
import argparse
from contextlib import nullcontext
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
    parser.add_argument('--release-template', action='store_true', help='Run an unpacked release template beside the isolated project')
    parser.add_argument('--isolated-desktop', action='store_true', help='Windows graphics on a private desktop that is never activated; includes render timing and CPU telemetry')
    parser.add_argument('--render-size', default='1600x900', help='Isolated desktop client size, e.g. 3840x2160; report records actual size')
    parser.add_argument('--hide-effects', action='store_true', help='Graphical diagnostic only: hide effects/projectile roots while keeping their logic running')
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--profile', action='store_true')
    parser.add_argument('--native-profile', action='store_true', help='Godot debugger timings for every executed GDScript function; diagnostic only')
    parser.add_argument('--frame-only', action='store_true', help='Measure frame intervals without injected unit counters, phase callbacks or viewport CPU/GPU timing queries; never compare this mode with diagnostic runs')
    parser.add_argument('--host-cpu', action='store_true', help='Record one-second host and benchmark CPU counters without WMI')
    parser.add_argument('--alive-branches', action='store_true', help='Diagnostic survival-check callsites and branch outcomes')
    parser.add_argument('--frame-profile', action='store_true', help='Diagnostic per-frame function/phase self CPU and loop counts; not a clean P95 run')
    parser.add_argument('--engine-phases', action='store_true', help='Diagnostic physics/process/draw wall-clock boundaries; not a clean P95 run')
    parser.add_argument('--preserve-player', action='store_true', help='Keep the saved player seat instead of adding diagnostic autopilot')
    parser.add_argument('--mirror-player-growth', action='store_true', help='Test-only: equip AI with checkpoint player talents, W and passive cards/ranks')
    parser.add_argument('--player-actions', action='store_true', help='Exercise real hover, box-selection and group move/attack dispatch during soak')
    parser.add_argument('--traffic-snapshot', action='store_true', help='Diagnostic movement/path snapshots every five simulation seconds; not a clean P95 run')
    parser.add_argument('--building-profile', action='store_true', help='Diagnostic building phases, types and selected subcalls; not a clean P95 run')
    parser.add_argument('--unit-work-timing-only', action='store_true', help='With --unit-work, time selected hotspots without deep loop/function counters')
    parser.add_argument('--unit-work', action='store_true', help='Exact unit-attributed call and loop counts with sampled nested timings')
    parser.add_argument('--scan-loops', action='store_true', help='Diagnostic exact broad-loop counts; excluded from performance comparisons')
    parser.add_argument('--seconds', type=float, default=60)
    parser.add_argument('--fixed-workload', action='store_true', help='Fixed 30 render / 15 physics steps per simulated second, pacing tier 3; CPU comparison only, separate from wall-clock/live P95')
    parser.add_argument('--speed', type=float, default=1)
    parser.add_argument('--save', type=Path)
    parser.add_argument('--meta', type=Path, help='Copy a frozen player meta profile into the isolated user directory, including cosmetics')
    parser.add_argument('--expect-map', help='Assert the loaded map ID, including when reusing a checkpoint')
    parser.add_argument('--source', type=Path, help='Explicit frozen source project for before/after comparisons')
    args = parser.parse_args()
    if args.frame_only and (args.profile or args.native_profile or args.frame_profile or args.engine_phases or args.alive_branches or args.building_profile or args.unit_work or args.scan_loops or args.traffic_snapshot or args.fixed_workload):
        parser.error('--frame-only cannot be combined with profiling or fixed-workload modes.')
    if args.hide_effects and not args.isolated_desktop:
        parser.error('--hide-effects requires --isolated-desktop')
    if not re.fullmatch(r'[1-9][0-9]{2,3}x[1-9][0-9]{2,3}', args.render_size):
        parser.error('--render-size must be WIDTHxHEIGHT')
    if args.engine_phases and (args.profile or args.native_profile or args.frame_profile or args.alive_branches or args.building_profile or args.unit_work or args.scan_loops or args.traffic_snapshot or args.fixed_workload):
        parser.error('--engine-phases is a standalone diagnostic; do not combine probes or fixed workload.')
    if args.release_template and args.native_profile:
        parser.error('Native profiling requires a debug-capable executable, not a release template.')
    if args.fixed_workload and args.native_profile:
        parser.error('Fixed workload is a clean CPU comparison, not a native profiling mode.')
    if args.alive_branches and (args.native_profile or args.profile or args.frame_profile or args.building_profile or args.unit_work or args.scan_loops or args.traffic_snapshot):
        parser.error('--alive-branches is a standalone diagnostic; do not combine probes.')
    if args.native_profile and (args.profile or args.frame_profile or args.building_profile or args.unit_work or args.scan_loops or args.traffic_snapshot):
        parser.error('--native-profile is a standalone diagnostic; do not combine probes.')
    if args.frame_profile and (args.profile or args.building_profile or args.unit_work or args.scan_loops or args.traffic_snapshot):
        parser.error('--frame-profile is a standalone diagnostic; do not combine probes.')
    if args.seconds < 30 or not 0 < args.speed <= 3:
        parser.error('Use at least 30 wall seconds and a speed greater than zero, at most 3x.')
    if args.unit_work_timing_only and not args.unit_work:
        parser.error('--unit-work-timing-only requires --unit-work')
    if args.building_profile and (args.profile or args.scan_loops or args.unit_work):
        parser.error('--building-profile is a standalone diagnostic; do not combine probes.')
    if args.unit_work and (args.profile or args.scan_loops):
        parser.error('--unit-work is a standalone diagnostic; do not combine probes.')
    if args.save and not args.save.is_file():
        parser.error('Save source must exist.')
    if args.meta and not args.meta.is_file():
        parser.error('Meta profile source must exist.')
    if args.mirror_player_growth and not args.save:
        parser.error('--mirror-player-growth requires a saved player combat context via --save.')
    if args.player_actions and not args.preserve_player:
        parser.error('--player-actions requires --preserve-player to avoid competing with autopilot.')
    if os.name != 'nt':
        parser.error('This runner uses Windows junctions and CREATE_NO_WINDOW.')
    source = args.source.resolve() if args.source else Path(__file__).resolve().parents[1] / 'iron_tide'
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    project = output / 'project'
    project.mkdir()
    # Copy mutable source before inserting test-only autopilot/instrumentation.
    shutil.copytree(source / 'scripts', project / 'scripts')
    for name in ['project.godot', 'icon.svg', 'icon.svg.import']:
        shutil.copy2(source / name, project / name)
    if (source / 'icon.ico').is_file():
        shutil.copy2(source / 'icon.ico', project / 'icon.ico')
    # Freeze authored configuration too: another task can be editing the live project.
    for name in ['data', 'shaders', 'scenes']:
        shutil.copytree(source / name, project / name)
    for name in ['assets', 'tests']:
        link = str(project / name).replace("'", "''")
        target = str(source / name).replace("'", "''")
        subprocess.run(['powershell', '-NoProfile', '-Command',
                        f"New-Item -ItemType Junction -Path '{link}' -Target '{target}' | Out-Null"],
                       creationflags=subprocess.CREATE_NO_WINDOW, check=True)
    (project / '.godot').mkdir()
    for name in ['global_script_class_cache.cfg', 'uid_cache.bin']:
        shutil.copy2(source / '.godot' / name, project / '.godot' / name)
    subprocess.run(['powershell', '-NoProfile', '-Command',
                    f"New-Item -ItemType Junction -Path '{project / '.godot/imported'}' -Target '{source / '.godot/imported'}' | Out-Null"],
                   creationflags=subprocess.CREATE_NO_WINDOW, check=True)
    # Native extension descriptors/libraries and their build sources live next
    # to scripts too. Audit the bytes actually copied, not only GDScript files.
    fingerprint = {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in sorted((project / 'scripts').rglob('*')) if p.is_file()}
    fingerprint['project.godot'] = hashlib.sha256((source / 'project.godot').read_bytes()).hexdigest()
    for directory in ['data', 'shaders', 'scenes']:
        fingerprint.update({str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest()
                            for p in sorted((project / directory).rglob('*')) if p.is_file()})
    (output / 'source-sha256.json').write_text(json.dumps(fingerprint, indent=2), 'utf8')
    settings = project / 'project.godot'
    isolated_settings = re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n', '', settings.read_text('utf8'), flags=re.MULTILINE)
    settings.write_text(isolated_settings.replace(
        '[application]', '[application]\nconfig/use_custom_user_dir=true\n'
        'config/custom_user_dir_name="CodexIronTideValidation/3v3"'), 'utf8')
    shutil.copy2(Path(__file__).with_name('performance_soak.gd'), project / 'soak.gd')
    if args.fixed_workload:
        pacing = project / 'scripts/world/battle_frame_pacing.gd'
        pacing_text = pacing.read_text('utf8')
        hook = 'func observe_frame(duration_us: int) -> void:\n'
        assert pacing_text.count(hook) == 1
        pacing.write_text(pacing_text.replace(hook, hook+'\ttier = 3 # Isolated fixed-work benchmark, never promoted.\n\treturn\n'), 'utf8')
    (project / 'soak.tscn').write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" '
        'path="res://soak.gd" id="1"]\n[node name="Soak" type="Node"]\n'
        'script=ExtResource("1")\n', 'utf8')
    (project / 'timer.gd').write_text(Path(__file__).with_name('sampled_call_probe.gd').read_text('utf8'), 'utf8')
    request = project / 'scripts/autoload/battle_request.gd'
    text = request.read_text('utf8')
    signature = 'func is_ai_house(side: String) -> bool:\n'
    if text.count(signature) != 1:
        raise RuntimeError('Autopilot hook changed; refusing unsafe source patch.')
    if not args.preserve_player:
        request.write_text(text.replace(signature, signature +
                                       '\tif side=="ally": return true # isolated test only\n'), 'utf8')
    if args.mirror_player_growth:
        import soak_player_growth
        soak_player_growth.patch(project)
    if args.player_actions:
        shutil.copy2(Path(__file__).with_name('soak_player_actions.gd'), project / 'soak_player_actions.gd')
        soak = project / 'soak.gd'
        script = soak.read_text('utf8')
        script = script.replace('\t\tvar now := Time.get_ticks_usec()', '\t\tpreload("res://soak_player_actions.gd").tick(world)\n\t\tvar now := Time.get_ticks_usec()')
        script = script.replace('\tresult.initial_state=initial_state', '\tresult.player_actions=preload("res://soak_player_actions.gd").counts\n\tresult.initial_state=initial_state')
        soak.write_text(script, 'utf8')
    names = {'unit': ['_physics_process', '_process_combat', '_refresh_target', '_move_toward', '_tick_skills'],
             'house_ai': ['_process', '_manage_base', 'building_site'],
             'building': ['_process', '_acquire_target'], 'battle': ['_process', 'build_spot_ok'],
             'fog_of_war': ['rebuild'], 'minimap': ['_draw'], 'path_service': ['find_path', '_build_zones'],
             'ai_unit_dispatch': ['pump'], 'ai_base_access': ['tick'], 'local_traffic': ['apply'],
             'air_relief': ['tick'], 'skirmish_tactics': ['attack_position', 'base_threat'],
             'skirmish_operations': ['tick', 'unit_decision']}
    names.update({
        'unit': names['unit'] + ['_idle_move', '_move_water_safe', '_automatic_target_allowed', '_weapon_for_target', '_weapon_domain_valid', '_weapon_target_valid', 'attack_domain_valid', '_try_fire_ready', '_tick_buffs', '_recompute_bonuses', '_limit_turn', '_crush_tick', 'decorate_tick', '_draw_ra2_sprite', '_process_harvester'],
        'building': names['building'] + ['unit_prereqs_ok', '_spawn_point', '_tick_anim_state', '_anim_kinds', '_tick_superweapon', '_valid_weapon_target'],
        'battle': names['battle'] + ['owned_building_ids', 'hero_limit_reason', '_update_power', 'refresh_wall_cells', '_place_building', 'spawn_unit'],
        'allied_abilities': ['tick_actor', 'effective_weapon'],
        'fog_of_war': ['vision_radius', '_stamp_one', '_hold_building', '_merge_foundation_masks', 'rebuild', '_upload_mask', '_advance_visual', '_hold_vacated_scouts', '_apply_live_masks', '_publish_combat_sight', '_sync_mask'],
        'ra2_art': ['art', '_load'], 'shp_detail': ['page_texture'],
        'production_exit': ['point'], 'skirmish_micro': ['tick'],
        'path_service': names['path_service'] + ['rebuild', '_fill_cost', '_refresh_water_cost', 'near_deck', 'in_naval_water'],
    })
    if args.unit_work:
        import unit_work_probe
        unit_work_probe.instrument(project, output, args.unit_work_timing_only)
    if args.scan_loops:
        import world_scan_probe
        world_scan_probe.instrument(project, output)
    if args.building_profile:
        import building_work_probe
        building_work_probe.instrument(project)
    if args.profile:
        for path in (project / 'scripts').rglob('*.gd'):
            lines = []
            source_lines = path.read_text('utf8').splitlines(keepends=True)
            for index, line in enumerate(source_lines):
                lines.append(line)
                match = re.match(r'^(?:static )?func (\w+)\(.*\).*:\s*$', line)
                if match and (match[1] in ['_process', '_physics_process', '_draw'] or path.stem in ['unit','unit_flight','vehicle_tracks','yr_signature_finish','tank_finish'] or match[1] in names.get(path.stem, [])):
                    body = next(row for row in source_lines[index + 1:] if row.strip())
                    indent = re.match(r'[ \t]+', body).group()
                    lines.append(indent + 'var _probe=preload("res://timer.gd").enter("' +
                                 path.stem + '.' + match[1] + '")\n')
            path.write_text(''.join(lines), 'utf8')
        fog = project / 'scripts/world/fog_of_war.gd'
        text = fog.read_text('utf8')
        markers = [
            ('\trebuild_count += 1', 'reset_held'),
            ('\tSupportSystems.apply_intelligence(self)', 'intelligence'),
            ('\tif battle.units.size() >= 128: _begin_live_masks()', 'collect_scouts'),
            ('\tfor shot in firing_positions.values():', 'raster_dispatch'),
            ('\tvar remaining := SCOUT_SIGHT_SECONDS', 'vacated'),
            ('\t_scouts = scouts', 'raster_wait_apply'),
        ]
        for index, (marker, label) in enumerate(markers):
            if text.count(marker) != 1:
                raise RuntimeError('Fog phase marker changed: ' + marker)
            begin = '\tvar _phase = ' if index == 0 else '\t_phase = null\n\t_phase = '
            text = text.replace(marker, begin + 'preload("res://timer.gd").enter("fog_of_war.phase_' + label + '")\n' + marker)
        fog.write_text(text, 'utf8')
        unit = project / 'scripts/units/unit.gd'
        text = unit.read_text('utf8')
        start = text.index('func _physics_process(')
        end = text.index('\nfunc ', start + 1)
        body = text[start:end]
        markers = [
            ('\tif special.has(Furnace.STANCE)', 'status'),
            ('\tif embarked_in != null:', 'embarked'),
            ('\tAlliedAbilities.tick_actor(self, delta)', 'abilities'),
            ('\t_drive_heading = NAN', 'timers'),
            ('\t_tick_skills(delta)', 'skills_target'),
            ('\tif logistics.tick(delta):', 'movement_combat'),
            ('\t# Turn on arrival', 'turn_fire'),
            ('\tvar moving := velocity.length() > 4.0', 'redraw'),
        ]
        for index, (marker, label) in enumerate(markers):
            if body.count(marker) != 1:
                raise RuntimeError('Unit phase marker changed: ' + marker)
            begin = '\tvar _phase = ' if index == 0 else '\t_phase = null\n\t_phase = '
            body = body.replace(marker, begin + 'preload("res://timer.gd").enter("unit.phase_' + label + '")\n' + marker)
        unit.write_text(text[:start] + body + text[end:], 'utf8')
    if args.traffic_snapshot:
        shutil.copy2(Path(__file__).with_name('traffic_snapshot_probe.gd'), project/'traffic_snapshot_probe.gd')
        ai_file = project/'scripts/world/house_ai.gd'
        ai_text = ai_file.read_text('utf8')
        for function in ['run_decisions','_manage_base','_form_wave','dispatch_attacker']:
            line = next(line for line in ai_text.splitlines(keepends=True) if line.startswith('func '+function+'('))
            ai_text = ai_text.replace(line, line+'\tpreload("res://traffic_snapshot_probe.gd").hit(house_id,"'+function+'")\n')
        ai_file.write_text(ai_text,'utf8')
        dispatch_file = project/'scripts/world/ai_unit_dispatch.gd'
        dispatch_text = dispatch_file.read_text('utf8')
        marker = '\t\t\t\tgoal = world.resolve_move_slot(unit,goal,used,order.spacing)'
        assert dispatch_text.count(marker)==1
        dispatch_text = dispatch_text.replace(marker,marker+'\n\t\t\tpreload("res://traffic_snapshot_probe.gd").route(world,unit,order.point,goal)')
        dispatch_file.write_text(dispatch_text,'utf8')
        soak_file = project/'soak.gd'
        text = soak_file.read_text('utf8')
        text = text.replace('\tvar begin := Time.get_ticks_usec()', '\tpreload("res://traffic_snapshot_probe.gd").sample(world,0.0,out)\n\tvar begin := Time.get_ticks_usec()')
        text = text.replace('\t\tvar now := Time.get_ticks_usec()', '\t\tpreload("res://traffic_snapshot_probe.gd").sample(world,world.fog.sight_clock-sim_begin,out)\n\t\tvar now := Time.get_ticks_usec()')
        soak_file.write_text(text,'utf8')
    if args.alive_branches:
        import alive_branch_probe
        alive_branch_probe.instrument(project, output)
    if args.frame_profile:
        import frame_work_probe
        frame_work_probe.instrument(project, output)
    if args.engine_phases:
        shutil.copy2(Path(__file__).with_name('engine_phase_probe.gd'), project / 'engine_phase_probe.gd')
        soak_file = project / 'soak.gd'
        text = soak_file.read_text('utf8')
        start = '\tvar begin := Time.get_ticks_usec()'
        finish = '\tvar elapsed := (Time.get_ticks_usec()-begin)/1000000.0'
        if text.count(start) != 1 or text.count(finish) != 1:
            raise RuntimeError('Engine phase probe boundary changed')
        text = text.replace(start, '\tvar engine_phases = preload("res://engine_phase_probe.gd").new()\n\tadd_child(engine_phases)\n\tengine_phases.start()\n' + start)
        text = text.replace(finish, finish + '\n\tengine_phases.finish(out)')
        soak_file.write_text(text, 'utf8')
    shutil.copy2(Path(__file__).with_name('unit_call_probe.gd'), project / 'unit_call_probe.gd')
    unit = project / 'scripts/units/unit.gd'
    # This seven-slot per-actor probe tracks only the original Unit entrypoints.
    # New global profiling points have independent indices and JSON counters.
    if not args.frame_only:
        unit.write_text(re.sub(r'(\tvar _call_log_scope = .*?\.enter\(([0-6])\)\n)',
                               r'\1\tpreload("res://unit_call_probe.gd").hit(self,\2)\n', unit.read_text('utf8')), 'utf8')
    instrumented = list((project / 'scripts').rglob('*.gd')) + list(project.glob('*.gd'))
    (output / 'instrumented-sha256.json').write_text(json.dumps({
        str(path.relative_to(project)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(instrumented)}, indent=2), 'utf8')
    (output / 'environment.json').write_text(json.dumps({
        'source': str(source), 'project': str(project), 'godot': str(args.godot.resolve()),
        'godot_sha256': hashlib.sha256(args.godot.read_bytes()).hexdigest(), 'release_template': args.release_template,
        'renderer': 'windows-private-desktop' if args.isolated_desktop else 'headless', 'render_size': args.render_size if args.isolated_desktop else None, 'hide_effects': args.hide_effects, 'seconds': args.seconds, 'speed': args.speed, 'seed': 713, 'fixed_workload': args.fixed_workload, 'fixed_fps': 30 if args.fixed_workload else None, 'fixed_pacing_tier': 3 if args.fixed_workload else None, 'frame_profile': args.frame_profile, 'native_profile': args.native_profile, 'alive_branches': args.alive_branches,
        'ai_count': 'saved AI count' if args.preserve_player else 6, 'preserve_player': args.preserve_player, 'traffic_snapshot': args.traffic_snapshot, 'expected_map': args.expect_map, 'unit_probe': 'exact counts, no per-unit timing', 'profile': args.profile or args.building_profile, 'building_profile': args.building_profile, 'scan_loops': args.scan_loops, 'unit_work': args.unit_work, 'unit_work_timing_only': args.unit_work_timing_only,
        'save': str(args.save.resolve()) if args.save else None,
        'mirror_player_growth': args.mirror_player_growth,
        'player_actions': args.player_actions,
        'save_sha256': hashlib.sha256(args.save.read_bytes()).hexdigest() if args.save else None,
        'meta': str(args.meta.resolve()) if args.meta else None,
        'meta_sha256': hashlib.sha256(args.meta.read_bytes()).hexdigest() if args.meta else None,
        'ai_rng': 'Diagnostic seed 713 + side hash, reset identically after loading in both variants',
        'source_hashes': 'source-sha256.json', 'host_cpu': args.host_cpu or args.isolated_desktop, 'engine_phases': args.engine_phases, 'frame_only': args.frame_only, 'database': 'none', 'unit_points': [] if args.frame_only else ['physics_update','combat','target_refresh','movement','skill_refresh','stuck_check','draw']}, indent=2), 'utf8')
    profile = output / 'profile'
    profile.mkdir()
    if args.meta:
        meta_dir = profile / 'CodexIronTideValidation/3v3'
        meta_dir.mkdir(parents=True)
        shutil.copy2(args.meta, meta_dir / 'iron_tide_meta.json')
    env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile), IRON_OUT=str(output), IRON_SECONDS=str(args.seconds), IRON_SPEED=str(args.speed), IRON_SAVE=str(args.save.resolve()) if args.save else '', IRON_EXPECT_MAP=args.expect_map or '', IRON_PRESERVE_PLAYER='1' if args.preserve_player else '0')
    env['IRON_NATIVE_PROFILE'] = '1' if args.native_profile else '0'
    env['IRON_FRAME_ONLY'] = '1' if args.frame_only else '0'
    env['IRON_FIXED_WORKLOAD'] = '1' if args.fixed_workload else '0'
    env['IRON_ISOLATED_DESKTOP'] = '1' if args.isolated_desktop else '0'
    env['IRON_HIDE_EFFECTS'] = '1' if args.hide_effects else '0'
    # The shipping build leaves the diagnostic call log off; probes opt in so that
    # result.json keeps its bridge-traffic report and performance_calls export.
    # An explicit IRON_TIDE_CALL_LOG in the caller's environment still wins, so a
    # probe can measure the shipping path with the scaffolding switched off.
    env.setdefault('IRON_TIDE_CALL_LOG', '1')
    debugger_args = ['--debug', '--ignore-error-breaks'] if args.native_profile else []
    command = [str(args.godot.resolve()), '--headless', *debugger_args, '--path', str(project), 'res://soak.tscn']
    run_cwd = None
    if args.release_template:
        runtime_executable = project / 'GodotRelease.exe'
        shutil.copy2(args.godot.resolve(), runtime_executable)
        (project / 'override.cfg').write_text('[application]\nrun/main_scene="res://soak.tscn"\n', 'utf8')
        command = [str(runtime_executable), '--headless']
        run_cwd = project
    if args.fixed_workload:
        command.extend(['--fixed-fps','30'])
    if args.isolated_desktop:
        command.remove('--headless')
        command.extend(['--windowed', '--resolution', args.render_size, '--audio-driver', 'Dummy',
                        '--log-file', str(output / 'log'), '--', '--keep-display'])
    with (nullcontext(None) if args.isolated_desktop else (output / 'log').open('wb')) as log:
        timeout = args.seconds*(10 if args.fixed_workload else 1)+180
        if args.isolated_desktop:
            import windows_isolated_desktop
            desktop = windows_isolated_desktop.run(command, run_cwd or project, env, timeout)
            (output / 'desktop.json').write_text(json.dumps(desktop, indent=2), 'utf8')
            result = subprocess.CompletedProcess(command, desktop['returncode'])
        elif args.host_cpu:
            import host_cpu_monitor
            result = host_cpu_monitor.run(command, output, timeout, cwd=run_cwd, env=env, stdout=log,
                                          stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        else:
            result = subprocess.run(command, cwd=run_cwd, env=env, stdout=log, stderr=subprocess.STDOUT,
                                    creationflags=subprocess.CREATE_NO_WINDOW, timeout=timeout)
    print('exit:', result.returncode, 'report:', output / 'result.json')
    if result.returncode == 0:
        if args.scan_loops:
            world_scan_probe.summarize(output)
        report = json.loads((output / 'result.json').read_text('utf8'))
        if args.meta:
            expected_meta = json.loads(args.meta.read_text('utf8'))
            for source_key, report_key in [('unit_cosmetics', 'cosmetics'), ('attachment_positions', 'attachment_positions')]:
                if report['meta_profile'][report_key] != expected_meta.get(source_key, {}):
                    raise RuntimeError(f'Isolated meta profile mismatch: {source_key}')
        if args.mirror_player_growth:
            for key in ['player_growth', 'player_growth_final']:
                if report[key]['errors']:
                    raise RuntimeError(f'AI growth audit failed: {key}: {report[key]["errors"]}')
        if args.player_actions and (report['player_actions']['box'] < 1 or report['player_actions']['move'] < 1 or report['player_actions']['selected_peak'] < 2):
            raise RuntimeError('Player action workload did not exercise group selection and movement.')
        expected_ai = report['initial_state']['ai_count'] if args.preserve_player else 6
        if not report['completed'] or report['ai_count'] != expected_ai or report['speed'] != args.speed:
            raise RuntimeError('Requested soak conditions were not met.')
        if args.fixed_workload:
            if report['frame_stats']['frames'] != round(args.seconds*30) or abs(report['sim']-args.seconds*args.speed)>0.1:
                raise RuntimeError('Fixed frame/simulation workload was not completed.')
        checkpoint = output / 'end.itsave'
        if not checkpoint.is_file():
            raise RuntimeError('Soak ended without a reusable checkpoint.')
        (output / 'checkpoint.json').write_text(json.dumps({
            'path': str(checkpoint), 'sha256': hashlib.sha256(checkpoint.read_bytes()).hexdigest(),
            'measured_wall_seconds': report['wall'], 'advanced_sim_seconds': report['sim'],
            'initial_state': report.get('initial_state'), 'ai_count': report['ai_count'],
            'selected_speed': report['speed'], 'source_hashes': 'source-sha256.json',
            'prior_checkpoint': str(args.save.resolve()) if args.save else None,
            'purpose': 'Reload this exact file for paired equal-duration comparisons; wall time and game time are distinct.'
        }, indent=2), 'utf8')
        drift = [p for p, digest in fingerprint.items() if hashlib.sha256((source / p).read_bytes()).hexdigest() != digest]
        (output / 'source-audit.json').write_text(json.dumps({'changed_during_run': drift}, indent=2), 'utf8')
        log_text = (output / 'log').read_text('utf8', errors='replace')
        if 'SCRIPT ERROR:' in log_text or 'Parse Error:' in log_text:
            raise RuntimeError('Godot reported a script error; inspect the retained log.')
        if args.native_profile:
            import native_function_profile
            native_function_profile.summarize(output)
        if args.alive_branches:
            alive_branch_probe.summarize(output)
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
