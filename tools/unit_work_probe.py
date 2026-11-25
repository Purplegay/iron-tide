"""Attribute synchronous unit work to actors, with exact calls/iterations and sampled self CPU."""
import json
import re
from pathlib import Path


def colon(text):
    depth = 0
    quote = None
    escape = False
    for index, char in enumerate(text):
        if quote:
            if escape:
                escape = False
            elif char == chr(92):
                escape = True
            elif char == quote:
                quote = None
        elif char in ('"', "'"):
            quote = char
        elif char in '([{':
            depth += 1
        elif char in ')]}':
            depth -= 1
        elif char == ':' and depth == 0:
            return index
    return -1


def instrument(project, output, timing_only=False):
    points = []
    skipped = []

    def point(kind, path, line, function, source):
        key = len(points)
        points.append({'id':key,'kind':kind,'source':str(path.relative_to(project)),
                       'line':line,'function':function,'code':source.strip()})
        return key

    for path in sorted((project / 'scripts').rglob('*.gd')):
        original = path.read_text('utf8').splitlines()
        result = []
        function = ''
        indents = [re.match(r'[ \t]+', row).group() for row in original if row.strip() and re.match(r'[ \t]+',row)]
        step = '\t' if any('\t' in indent for indent in indents) else ' ' * min([len(x) for x in indents] or [1])
        for index, source in enumerate(original):
            line = source
            signature = re.match(r'^(?:static )?func (\w+)\(', line)
            if signature:
                function = signature[1]
                timed = (path.stem == 'unit' and function in ['_physics_process','_process_combat','_refresh_target','_tick_skills','_advance_firing','_move_water_safe','_recompute_bonuses','_process_repair','_process_harvester']) or (path.stem == 'path_service' and function in ['find_path','_build_zones','_build_window','_nearest_walkable']) or (path.stem == 'vehicle_passages' and function == 'route') or (path.stem in ['open_topped','progression_expansion','unit_logistics'] and function == 'tick') or (path.stem == 'allied_abilities' and function == 'tick_actor')
                if timing_only and not timed:
                    result.append(line);continue
                end = colon(line)
                if end < 0:
                    skipped.append({'source':str(path.relative_to(project)),'line':index+1,'reason':'multiline signature'})
                    result.append(line);continue
                key = point('function',path,index+1,function,source)
                body = line[end+1:].strip()
                result.append(line[:end+1])
                if path.stem == 'unit' and function == '_physics_process':
                    result.append(step+'var _unit_work_update = preload("res://unit_work_probe.gd").begin(self)')
                result.append(step+f'var _unit_work_call = preload("res://unit_work_probe.gd").call_point({key})')
                if body and not body.startswith('#'):
                    result.append(step+body)
                continue
            if timing_only:
                result.append(line);continue
            # Anonymous callbacks count each actual predicate/comparison invocation.
            # This includes callbacks on single-line for bodies.
            matches = list(re.finditer(r'\bfunc\s*\([^)]*\)\s*(?:->[^:]+)?:',line))
            for match in reversed(matches):
                if line.lstrip().startswith('#'):
                    continue
                key = point('callback',path,index+1,function,source)
                tail = line[match.end():]
                if tail.strip() and not tail.lstrip().startswith('#'):
                    line = line[:match.end()] + f' preload("res://unit_work_probe.gd").iteration({key});' + tail
                else:
                    body = next(row for row in original[index+1:] if row.strip() and not row.lstrip().startswith('#'))
                    indent = re.match(r'[ \t]+',body).group()
                    line += '\n'+indent+f'preload("res://unit_work_probe.gd").iteration({key})'
            loop = re.match(r'^([ \t]*)(?:for \w+(?::\s*\w+)? in |while )',line)
            if loop:
                end = colon(line[loop.end():]) + loop.end()
                if end < loop.end():
                    skipped.append({'source':str(path.relative_to(project)),'line':index+1,'reason':'multiline loop'})
                    result.append(line);continue
                key = point('loop',path,index+1,function,source)
                result.append(loop[1]+f'preload("res://unit_work_probe.gd").loop_entry({key})')
                body = line[end+1:].strip()
                result.append(line[:end+1])
                result.append(loop[1]+step+f'preload("res://unit_work_probe.gd").iteration({key})')
                if body and not body.startswith('#'):result.append(loop[1]+step+body)
            else:
                result.append(line)
        path.write_text('\n'.join(result)+'\n','utf8')
    unit = project / 'scripts/units/unit.gd'
    text = unit.read_text('utf8')
    start = text.index('func _physics_process(')
    end = text.index('\nfunc ',start+1)
    body = text[start:end]
    markers = [
        ('\tif special.has(Furnace.STANCE)','status'),
        ('\tif embarked_in != null:','embarked'),
        ('\tAlliedAbilities.tick_actor(self, delta)','abilities'),
        ('\t_drive_heading = NAN','timers'),
        ('\t_tick_skills(delta)','skills_target'),
        ('\tif logistics.tick(delta):','movement_combat'),
        ('\t# Turn on arrival','turn_fire'),
        ('\tvar moving := velocity.length() > 4.0','redraw')]
    for marker,label in markers:
        pattern = re.compile(r'(?m)^'+re.escape(marker))
        if len(pattern.findall(body))!=1:raise RuntimeError('Unit phase marker changed: '+marker)
        body=pattern.sub(lambda match: '\tpreload("res://unit_work_probe.gd").phase("'+label+'")\n'+match.group(),body)
    unit.write_text(text[:start]+body+text[end:],'utf8')
    hot = [p['id'] for p in points if p['kind']=='function' and (
        ('path_service.gd' in p['source'] and p['function'] in ['find_path','_build_zones','_build_window','_nearest_walkable']) or
        ('vehicle_passages.gd' in p['source'] and p['function']=='route') or
        ('open_topped.gd' in p['source'] and p['function']=='tick'))]
    if timing_only: hot = [p['id'] for p in points if p['kind']=='function' and p['function']!='_physics_process']
    probe=Path(__file__).with_suffix('.gd').read_text('utf8').replace('const HOT_POINTS := {}','const HOT_POINTS := {'+','.join(str(key)+':true' for key in hot)+'}')
    (project/'unit_work_probe.gd').write_text(probe,'utf8')
    path=project/'soak.gd';text=path.read_text('utf8')
    marker='\tpreload("res://unit_call_probe.gd").take()\n'
    text=text.replace(marker,marker+'\tpreload("res://unit_work_probe.gd").start()\n')
    marker='\tFileAccess.open(out.path_join("result.json")'
    text=text.replace(marker,'\tFileAccess.open(out.path_join("unit-work.json"),FileAccess.WRITE).store_string(JSON.stringify(preload("res://unit_work_probe.gd").stop()))\n'+marker)
    path.write_text(text,'utf8')
    (output/'unit-work-points.json').write_text(json.dumps({'mode':'timers' if timing_only else 'counts','points':points,'skipped':skipped},indent=2),'utf8')
