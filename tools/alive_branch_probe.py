"""Count survival-check callers and short-circuit outcomes in an isolated soak."""
import json
import re


def instrument(project, output):
    points = []
    patterns = [
        (re.compile(r'\b([\w.]+)\.actor_alive\('), 'world'),
        (re.compile(r'(?<![\w.])actor_alive\('), 'self'),
        (re.compile(r'\bAlliedAbilities\.alive\('), 'allied'),
    ]
    for path in sorted((project / 'scripts').rglob('*.gd')):
        function = ''
        result = []
        for number, line in enumerate(path.read_text('utf8').splitlines(keepends=True), 1):
            definition = re.match(r'^(?:static )?func (\w+)\(', line)
            if definition:
                function = definition[1]
                result.append(line)
                continue
            if line.lstrip().startswith('#'):
                result.append(line)
                continue
            for pattern, kind in patterns:
                if kind == 'self' and path.name != 'battle.gd':
                    continue
                def replace(match):
                    key = len(points)
                    points.append({'id': key, 'source': str(path.relative_to(project)),
                                   'line': number, 'function': function, 'expression': line.strip()})
                    if kind == 'allied':
                        return f'preload("res://alive_branch_probe.gd").allied({key},'
                    owner = match[1] if kind == 'world' else 'self'
                    return f'preload("res://alive_branch_probe.gd").world_alive({key},{owner},'
                line = pattern.sub(replace, line)
            result.append(line)
        path.write_text(''.join(result), 'utf8')
    (output / 'alive-sites.json').write_text(json.dumps(points, indent=2), 'utf8')
    (project / 'alive_branch_probe.gd').write_text('''extends RefCounted
static var rows:Dictionary={}
static func record(site:int,actor,result:bool)->void:
 var row:Array=rows.get_or_add(site,[0,0,0,0,0,0,0,0])
 row[0]+=1
 if not is_instance_valid(actor):row[1]+=1;return
 if actor is Unit:row[2]+=1
 elif actor is Building:row[3]+=1
 else:row[4]+=1
 if actor.is_queued_for_deletion():row[5]+=1
 elif actor.hp<=0:row[6]+=1
 elif actor._dead:row[7]+=1
 assert(result==(not actor.is_queued_for_deletion() and actor.hp>0 and not actor._dead))
static func world_alive(site:int,world,actor)->bool:
 var result:bool=world.actor_alive(actor)
 record(site,actor,result)
 return result
static func allied(site:int,actor)->bool:
 var result:bool=AlliedAbilities.alive(actor)
 record(site,actor,result)
 return result
''', 'utf8')
    soak = project / 'soak.gd'
    script = soak.read_text('utf8')
    start = '\tvar begin := Time.get_ticks_usec()'
    end = '\tvar elapsed := (Time.get_ticks_usec()-begin)/1000000.0'
    assert script.count(start) == 1 and script.count(end) == 1
    script = script.replace(start, '\tpreload("res://alive_branch_probe.gd").rows.clear()\n'+start)
    script = script.replace(end, end+'\n\tFileAccess.open(out.path_join("alive-branches.json"),FileAccess.WRITE).store_string(JSON.stringify(preload("res://alive_branch_probe.gd").rows))')
    soak.write_text(script, 'utf8')


def summarize(output):
    sites = json.loads((output / 'alive-sites.json').read_text('utf8'))
    rows = json.loads((output / 'alive-branches.json').read_text('utf8'))
    labels = ['calls', 'invalid', 'unit', 'building', 'other', 'queued', 'hp_zero', 'dead_flag']
    for site in sites:
        site.update(zip(labels, rows.get(str(site['id']), [0]*len(labels))))
    sites.sort(key=lambda row: row['calls'], reverse=True)
    (output / 'alive-ranking.json').write_text(json.dumps(sites, indent=2, ensure_ascii=False), 'utf8')
