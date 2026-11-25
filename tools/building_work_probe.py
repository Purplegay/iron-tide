"""Diagnostic-only probes installed in the soak's isolated source copy."""
import re


def instrument(project):
    path = project / 'scripts/buildings/building.gd'
    text = path.read_text('utf8')
    functions = {
        '_process', '_tick_anim_state', '_animation_draw_needed', '_anim_kinds',
        '_base_anim_state', '_layer_visible', '_tick_superweapon',
        '_process_building_repair', '_tick_construction_free_unit',
        'unit_prereqs_ok', 'production_work_rate', '_valid_weapon_target',
        '_acquire_target', '_refresh_power_warning', '_process_repair',
        '_tick_unit_queues', '_tick_unit_queue', '_door_fraction',
        '_door_open_seconds', 'unloading_miner', 'is_operational',
    }
    lines = []
    found = set()
    for line in text.splitlines(keepends=True):
        lines.append(line)
        match = re.match(r'^func (\w+)\(.*\).*:\s*$', line)
        if match and match[1] in functions:
            name = match[1]
            found.add(name)
            lines.append('\tvar _building_probe=preload("res://timer.gd").enter("building.' + name + '")\n')
            if name == '_process':
                lines.append('\tvar _building_type_probe=preload("res://timer.gd").enter("building.type."+building_id)\n')
    if found != functions:
        raise RuntimeError('Building probe signatures changed: ' + str(functions - found))
    text = ''.join(lines)
    start = text.index('func _process(')
    end = text.index('\nfunc ', start + 1)
    body = text[start:end]
    markers = [
        ('\tif special.has("tesla_pulse"):', 'status'),
        ('\tif special.has("hero_escort_queue"):', 'effects'),
        ('\tif not superweapon.is_empty() or special.has("sw_discharge_age"):_tick_superweapon(delta)', 'superweapon_power'),
        ('\tif not _dead and not _ra2_anim.is_empty():', 'animation'),
        ('\tif selected or hovered:', 'health_construction'),
        ('\tif not str(special.get("construction_free_unit", "")).is_empty():_tick_construction_free_unit(delta)', 'economy_production'),
        ('\tif building_id=="R3REAPERTURRET":', 'combat'),
    ]
    for index, (marker, label) in enumerate(markers):
        if body.count(marker) != 1:
            raise RuntimeError('Building phase marker changed: ' + marker)
        prefix = '\tvar _building_phase = ' if index == 0 else '\t_building_phase = null\n\t_building_phase = '
        body = body.replace(marker, prefix + 'preload("res://timer.gd").enter("building.phase_' + label + '")\n' + marker)
    path.write_text(text[:start] + body + text[end:], 'utf8')
