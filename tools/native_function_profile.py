"""Parse Godot local debugger accumulated timings, excluding loading and saving.

Called by performance_soak.py --native-profile, or run with a soak output path.
Times are diagnostic CPU elapsed estimates, not release frame-time measurements.
"""
import json
from pathlib import Path
import re
import sys


def append_ranking(lines, title, rows):
    lines.extend(['', '## '+title, '',
                  '| Function | Calls | Self ms | Inclusive ms | Self share | Mean self us |',
                  '| --- | ---: | ---: | ---: | ---: | ---: |'])
    for row in rows:
        label = row['source'].removeprefix('res://') + ':' + str(row['line']) + ' ' + row['function']
        lines.append(f"| {label} | {row['calls']} | {row['self_ms']:.3f} | {row['inclusive_ms']:.3f} | {row['gameplay_self_percent']:.2f}% | {row['mean_self_us']:.3f} |")


def summarize(output: Path):
    log = (output / 'log').read_text('utf8', errors='replace')
    begin = 'IRON_FUNCTION_PROFILE_END_BEGIN'
    end = 'IRON_FUNCTION_PROFILE_END_DONE'
    if log.count(begin) != 1 or log.count(end) != 1:
        raise RuntimeError('Missing or ambiguous native profiler completion markers')
    block = log.split(begin, 1)[1].split(end, 1)[0]
    total = re.search(r'ACCUMULATED: total: ([\d.eE+-]+)', block)
    pattern = re.compile(
        r'^(\d+):(.+)\n\s*total: ([\d.eE+-]+)/[^\n]*?'
        r'self: ([\d.eE+-]+)/[^\n]*?tcalls: (\d+)', re.MULTILINE)
    rows = []
    for index, signature, inclusive, own, calls in pattern.findall(block):
        calls = int(calls)
        self_ms, inclusive_ms = float(own)*1000, float(inclusive)*1000
        parts = signature.rsplit('::', 2)
        source = parts[0]
        category = 'gameplay'
        if not source.startswith('res://scripts/'):
            category = 'harness'
        elif source.endswith('/battle_call_counters.gd'):
            category = 'diagnostics'
        rows.append({'index': int(index), 'signature': signature,
                     'source': source, 'category': category,
                     'line': int(parts[1]) if len(parts) == 3 and parts[1].isdigit() else None,
                     'function': parts[-1], 'calls': calls,
                     'self_ms': self_ms, 'inclusive_ms': inclusive_ms,
                     'mean_self_us': self_ms*1000/calls if calls else 0,
                     'mean_inclusive_us': inclusive_ms*1000/calls if calls else 0})
    if not total or not rows or len(rows) >= 32768:
        raise RuntimeError('Missing native timings or engine profile capacity reached')
    if [row['index'] for row in rows] != list(range(len(rows))):
        raise RuntimeError('Function profile rows were truncated')
    if any(row['self_ms'] < 0 or row['inclusive_ms']+.02 < row['self_ms'] for row in rows):
        raise RuntimeError('Invalid self/inclusive timing')
    if abs(sum(row['self_ms'] for row in rows)-float(total[1])*1000) > max(.02, len(rows)*.001):
        raise RuntimeError('Function self times do not reconcile with engine total')
    gameplay = [row for row in rows if row['category'] == 'gameplay']
    gameplay_self_ms = sum(row['self_ms'] for row in gameplay)
    for row in gameplay:
        row['gameplay_self_percent'] = row['self_ms']*100/gameplay_self_ms if gameplay_self_ms else 0.0
    executed = [row for row in gameplay if row['calls'] > 0]
    measured = json.loads((output / 'result.json').read_text('utf8'))
    renderer = measured.get('graphics', {}).get('display', 'headless')
    report = {'scope': 'All executed GDScript functions during the measured interval; loading/saving excluded',
              'profiling_renderer': renderer,
              'limitations': [f'Debug/{renderer} profiling; not release P95 or GPU timing',
                              'Unexecuted functions have no workload evidence',
                              'Native engine and GDExtension callees are not individually enumerated; inspect surrounding script inclusive time',
                              'Function line numbers refer to the isolated instrumented project',
                              'Self follows Godot profiler accounting and can exclude native extension calls; moving work to C is not equivalent to eliminating its CPU cost',
                              'Inclusive times overlap; do not sum them',
                              'Harness coroutine timing can include pre-window work; excluded from gameplay ranking',
                              'Existing diagnostic helpers remain visible and separately classified'],
              'wall_seconds': measured['wall'], 'simulation_seconds': measured['sim'],
              'initial_state': measured['initial_state'], 'listed_functions': len(rows),
              'executed_functions': sum(row['calls'] > 0 for row in rows),
              'executed_gameplay_functions': sum(row['calls'] > 0 and row['category'] == 'gameplay' for row in rows),
              'script_self_ms': float(total[1])*1000,
              'gameplay_self_ms': gameplay_self_ms,
              'diagnostics_self_ms': sum(row['self_ms'] for row in rows if row['category'] == 'diagnostics'),
              'top10_gameplay': sorted(executed, key=lambda row: row['self_ms'], reverse=True)[:10],
              'top10_gameplay_inclusive': sorted(executed, key=lambda row: row['inclusive_ms'], reverse=True)[:10],
              'rows_by_self': sorted(rows, key=lambda row: row['self_ms'], reverse=True)}
    (output / 'functions.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), 'utf8')
    lines = ['# Function CPU profile', '',
             f"Measured {measured['wall']:.3f} wall seconds / {measured['sim']:.3f} simulated seconds.",
             f"Executed {report['executed_gameplay_functions']} gameplay functions; {len(rows)} loaded function rows retained.", '',
             'Self share uses gameplay script self time only; it is not a share of full-frame CPU or GPU time.',
             f'Inclusive times overlap. Diagnostic {renderer} timing is not release frame P95.']
    append_ranking(lines, 'Top 10 by self time', report['top10_gameplay'])
    append_ranking(lines, 'Top 10 by inclusive time', report['top10_gameplay_inclusive'])
    lines.extend(['', 'Full loaded function inventory and zero-call entries: `functions.json`.',
                  'End checkpoint: `end.itsave`; hash and input lineage: `checkpoint.json`.',
                  'The checkpoint is a reusable candidate, not proven to be more CPU intensive.',
                  '', 'Limitations:', *['- '+item for item in report['limitations']]])
    (output / 'functions.md').write_text('\n'.join(lines)+'\n', 'utf8')
    print('native function profile:', len(rows), 'functions;', output / 'functions.json')
    return report


if __name__ == '__main__':
    summarize(Path(sys.argv[1]).resolve())
