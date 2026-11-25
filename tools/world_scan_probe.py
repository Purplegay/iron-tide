"""Inject diagnostic loop counters into an isolated soak copy, never the live project."""
import json
import re


def instrument(project, output):
    points = []
    for path in sorted((project / 'scripts').rglob('*.gd')):
        lines = path.read_text('utf8').splitlines(keepends=True)
        result = []
        function = ''
        for index, line in enumerate(lines):
            definition = re.match(r'^(?:static )?func (\w+)\(', line)
            if definition:
                function = definition[1]
            loop = re.match(r'^([ \t]*)for \w+ in (.+):\s*$', line)
            if loop and re.search(r'\b(units|buildings|candidates|actors|targets|contacts|enemies|friends|obstacles|factories)\b|get_nodes_in_group|home_members|\.nearby\(', loop[2]):
                key = len(points)
                points.append({'id': key, 'source': str(path.relative_to(project)),
                               'line': index + 1, 'function': function, 'loop': line.strip()})
                body = next(row for row in lines[index + 1:] if row.strip() and not row.lstrip().startswith('#'))
                indent = re.match(r'[ \t]+', body).group()
                result.append(loop[1] + f'preload("res://scan_probe.gd").calls[{key}] += 1\n')
                result.append(line)
                result.append(indent + f'preload("res://scan_probe.gd").visits[{key}] += 1\n')
            else:
                result.append(line)
        path.write_text(''.join(result), 'utf8')
    (output / 'scan-points.json').write_text(json.dumps(points, indent=2), 'utf8')
    count = len(points)
    (project / 'scan_probe.gd').write_text(
        'extends RefCounted\nstatic var calls := ' + str([0] * count) +
        '\nstatic var visits := ' + str([0] * count) +
        '\nstatic func reset() -> void:\n\tcalls.fill(0)\n\tvisits.fill(0)\n', 'utf8')
    path = project / 'soak.gd'
    text = path.read_text('utf8')
    reset = '\tpreload("res://unit_call_probe.gd").take()\n'
    finish = '\tFileAccess.open(out.path_join("result.json")'
    if text.count(reset) != 1 or text.count(finish) != 1:
        raise RuntimeError('Scan probe measurement boundaries changed.')
    text = text.replace(reset, reset + '\tpreload("res://scan_probe.gd").reset()\n')
    text = text.replace(finish, '\tFileAccess.open(out.path_join("scan-counts.json"),FileAccess.WRITE).store_string(JSON.stringify({"calls":preload("res://scan_probe.gd").calls,"visits":preload("res://scan_probe.gd").visits}))\n' + finish)
    path.write_text(text, 'utf8')


def summarize(output):
    points = json.loads((output / 'scan-points.json').read_text('utf8'))
    counts = json.loads((output / 'scan-counts.json').read_text('utf8'))
    for point in points:
        point.update(calls=counts['calls'][point['id']], visits=counts['visits'][point['id']])
    points.sort(key=lambda point: point['visits'], reverse=True)
    (output / 'scan-ranking.json').write_text(json.dumps(points, indent=2), 'utf8')
