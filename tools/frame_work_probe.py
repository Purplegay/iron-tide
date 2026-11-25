"""Attach function/phase CPU and loop counters to individual measured frames.

Only modifies the isolated soak project. Self time excludes instrumented nested
scopes and measured nested scope bookkeeping, and includes uninstrumented callees.
Dispatch/timestamp overhead remains; this is not a clean frame-time measurement.
"""
from pathlib import Path
import re
import shutil
import json


def instrument(project: Path, output: Path):
    original_unit = (project/'scripts/units/unit.gd').read_text('utf8')
    shutil.copy2(Path(__file__).with_suffix('.gd'), project/'frame_work_probe.gd')
    counter=project/'scripts/world/battle_call_counters.gd'
    source=counter.read_text('utf8')
    points=re.findall(r'\{"name":"([^"]+)"', source.split('static var owner')[0])
    extra={
        'unit':['_draw_pose','_draw_ra2_sprite','_draw_buffs','_draw_selection','_recompute_bonuses','_recompute_base_bonuses','_advance_firing','_loadout_weapon_for_target','_move_water_safe','_idle_move','_avoid_obstacles','_process_harvester','_process_repair','decorate_tick','_limit_turn','_crush_tick','_weapon_for_target','_refresh_weapon_derived'],
        'open_topped':['weapon','command_range','search_bound'],
        'progression_expansion':['tick'], 'allied_abilities':['tick_actor','draw_status'],
        'expansion_cards':['tick'], 'expansion_talents':['tick'], 'expansion_heroes':['tick'],
        'unit_expansion_idle':['try_tick'], 'faction_cards':['tick'],
        'infantry_idle':['tick'], 'expansion_visual':['draw'],
        'auto_w':['enabled','card_id','contacts','firing_soon'],
        'unit_skill_layout':['index','equippable'],
        'expansion_rules':['rank','talent_rank','value'],
        'unit_status':['append_native','normalize'],
        'ra2_art':['draw_sprite'], 'shp_detail':['draw'],
        'ra3_gunship_shell':['advance','path','geometry','point_at'],
        'ra3_gunship_impact':['_sample','projected_extent'],
        'ra3_expansion_model':['_sample','_sample_gunship','bone_world','_update_contrails'],
        'ra3_gunship_flight':['tick'], 'ra3_gunship_mounts':['tick','choose'],
        'battle_cursor':['sample_pointer','resolve'],
        'battle':['_apply_selection','_pick_at','_pick_enemy_at','_command_move','_assign_move_slots','_issue_move_slots','force_attack'],
        'fog_of_war':['_merge_foundation_masks','vision_radius'],
        'building':['_tick_anim_state','_animation_draw_needed','_tick_superweapon'],
        'unit_flight':['process_combat','travel','altitude'],
        'grizzly_visual_refresh':['eligible','refresh','rigid_vehicle'],
        'vehicle_tracks':['sample'], 'tank_finish':['tick'], 'yr_signature_finish':['tick'],
        'tnkd_exoframe':['tick'], 'tesla_reserve':['tick'],
        'furnace_legend':['tick'], 'domain_cards':['tick'],
        'electric_cards':['tick'], 'tank_hero':['tick'],
        'soviet_specials':['tick_actor'], 'naval_contact':['tick'],
    }
    extra['unit'].extend(['buff_entries','_steer_dir','_ramped_speed','_align_drive_velocity',
                          '_automatic_target_allowed','_weapon_uses_hull','_domain_ok',
                          '_tick_hero_self_heal','_rock_update'])
    coverage=[]
    locations={}
    for path in (project/'scripts').rglob('*.gd'):
        text=path.read_text('utf8');lines=text.splitlines(keepends=True);result=[]
        current_function = None
        for i,line in enumerate(lines):
            result.append(line)
            declaration=re.match(r'^(?:static )?func (\w+)\(',line)
            if declaration:
                current_function={'source':'res://'+path.relative_to(project).as_posix(),
                                  'function':declaration[1],'line':i+1}
            match=re.match(r'\tvar _call_log_scope = .*\.enter\((\d+)\)',line)
            if match:
                name=points[int(match[1])]
                result.append(f'\tvar _frame_work_scope=preload("res://frame_work_probe.gd").enter("{name}")\n')
                coverage.append(name)
                locations[name]=current_function
            match=re.match(r'^(?:static )?func (\w+)\(.*\).*:\s*$',line)
            if match and match[1] in extra.get(path.stem,[]):
                # Functions already covered by persistent counters have their own scope.
                following=lines[i+1] if i+1<len(lines) else ''
                if '_call_log_scope' not in following:
                    name=path.stem+'.'+match[1]
                    result.append(f'\tvar _frame_work_scope=preload("res://frame_work_probe.gd").enter("{name}")\n')
                    coverage.append(name)
                    locations[name]=current_function
        path.write_text(''.join(result),'utf8')
    text=counter.read_text('utf8')
    needle='static func iterations(index: int, count: int) -> void:\n'
    assert text.count(needle)==1
    text=text.replace(needle,needle+'\tpreload("res://frame_work_probe.gd").iterations(POINTS[index].name,count)\n')
    counter.write_text(text,'utf8')
    unit=project/'scripts/units/unit.gd';text=unit.read_text('utf8')
    start=text.index('func _physics_process(');end=text.index('\nfunc ',start+1);body=text[start:end]
    markers=[('\tmotion_pose.capture(self)','entry'),('\tif special.has(Furnace.STANCE)','status'),
             ('\tif tank_finish!=null:','status_cosmetics'),
             ('\t# A cached moving pose','status_pose'),
             ('\tif idle_pose != null:','status_idle_naval'),
             ('\t# GM targets suppress orders','status_special_flight'),
             ('\tif not _dead and data.has("self_repair")','status_repair_death'),
             ('\tif embarked_in != null:','embarked'),('\tAlliedAbilities.tick_actor(self, delta)','abilities'),
             ('\t_drive_heading = NAN','timers'),('\t_tick_skills(delta)\n','skills_target'),
             ('\tif logistics.tick(delta):','movement_combat'),('\t# Turn on arrival','turn_fire'),
             ('\tvar moving := velocity.length() > 4.0','redraw')]
    for i,(marker,label) in enumerate(markers):
        assert body.count(marker)==1,marker
        prefix='\tvar _frame_phase = ' if i==0 else '\t_frame_phase = null\n\t_frame_phase = '
        body=body.replace(marker,prefix+f'preload("res://frame_work_probe.gd").enter("unit.phase_{label}")\n'+marker)
        coverage.append('unit.phase_'+label)
        original_position=original_unit.index(marker,original_unit.index('func _physics_process('))
        locations['unit.phase_'+label]={'source':'res://scripts/units/unit.gd',
                                       'function':'_physics_process','line':original_unit[:original_position].count('\n')+1}
    unit.write_text(text[:start]+body+text[end:],'utf8')
    soak=project/'soak.gd';text=soak.read_text('utf8')
    text=text.replace('\tvar begin := Time.get_ticks_usec()','\tpreload("res://frame_work_probe.gd").start()\n\tvar begin := Time.get_ticks_usec()')
    text=text.replace('traced_frames.append({"frame_ms":frame_ms,','traced_frames.append({"frame_index":traced_frames.size(),"work":preload("res://frame_work_probe.gd").take(),"frame_ms":frame_ms,')
    soak.write_text(text,'utf8')
    (output/'frame-work-points.json').write_text(json.dumps({'coverage':coverage,'locations':locations,'columns':['calls','inclusive_us','self_us','max_inclusive_us','iterations'],'scope':'main-thread synchronous instrumented scopes; exact calls/declared loop counts; self includes uninstrumented callees; measured nested scope bookkeeping is subtracted, dispatch/timestamp overhead remains; never compare diagnostic P95 to clean runs'},indent=2),'utf8')

