"""Summarize retained CPU soak evidence without treating headless FPS as GPU FPS."""
import argparse
import json
from pathlib import Path
from statistics import median


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    args = parser.parse_args()
    root = args.run.resolve()
    result = json.loads((root / 'result.json').read_text('utf8'))
    functions = {}
    windows = []
    for path in root.glob('profile/**/performance_calls/*.jsonl'):
        for line in path.read_text('utf8').splitlines():
            row = json.loads(line)
            if 'functions' not in row:
                continue
            windows.append({key: row[key] for key in ['session_wall_s', 'frames', 'units', 'buildings']})
            for item in row['functions']:
                total = functions.setdefault(item['name'], {'name': item['name'], 'calls': 0, 'estimated_inclusive_ms': 0, 'sampled_max_ms': 0})
                total['calls'] += item['calls']
                total['estimated_inclusive_ms'] += item['estimated_inclusive_ms']
                total['sampled_max_ms'] = max(total['sampled_max_ms'], item['sampled_max_ms'])
    names = ['physics_update', 'combat', 'target_refresh', 'movement', 'skill_refresh', 'stuck_check', 'draw']
    actors = {}
    deep = {}
    for window in result['windows']:
        for unit in window['unit_behaviors']:
            total = actors.setdefault(str(unit['instance']), {'instance': unit['instance'], 'type': unit['type'], 'side': unit['side'], 'counts': [0] * len(names)})
            total['counts'] = [a + b for a, b in zip(total['counts'], unit['counts'])]
        for key, calls in window['calls'].items():
            total = deep.setdefault(key, {'name': key, 'calls': 0, 'samples': 0, 'sampled_us': 0})
            total['calls'] += calls
            total['samples'] += window.get('samples', {}).get(key, 0)
            total['sampled_us'] += window['costs'].get(key, 0)
    for row in deep.values():
        row['estimated_inclusive_ms'] = row['sampled_us'] * row['calls'] / max(1, row['samples']) / 1000
    for actor in actors.values():
        actor['behaviors'] = sorted([{'name': name, 'calls': count} for name, count in zip(names, actor.pop('counts'))], key=lambda row: row['calls'], reverse=True)
    summary = {key: value for key, value in result.items() if key != 'windows'}
    summary.update({'effective_speed': result['sim'] / result['wall'],
                    'median_window_p95_ms': median(row['p95'] for row in result['windows']),
                    'window_p95_range_ms': [min(row['p95'] for row in result['windows']), max(row['p95'] for row in result['windows'])],
                    'top_cpu': sorted(functions.values(), key=lambda row: row['estimated_inclusive_ms'], reverse=True),
                    'top_calls': sorted(functions.values(), key=lambda row: row['calls'], reverse=True),
                    'deep_cpu': sorted(deep.values(), key=lambda row: row['estimated_inclusive_ms'], reverse=True),
                    'windows': windows,
                    'limitations': 'Headless CPU frame intervals; inclusive sampled timings overlap. Per-unit counts include early returns. Diagnostic probes add overhead. AI trajectories vary with frame timing.'})
    (root / 'summary.json').write_text(json.dumps(summary, indent=2, ensure_ascii=False), 'utf8')
    (root / 'unit-behaviors.json').write_text(json.dumps(list(actors.values()), indent=2, ensure_ascii=False), 'utf8')
    print(json.dumps({key: summary[key] for key in ['wall', 'sim', 'effective_speed', 'load_ms', 'peak_units', 'median_window_p95_ms', 'window_p95_range_ms']}, indent=2))
    print('top CPU:', [(row['name'], round(row['estimated_inclusive_ms'])) for row in summary['top_cpu'][:10]])
    print('deep CPU:', [(row['name'], round(row['estimated_inclusive_ms']), row['samples']) for row in summary['deep_cpu'][:20]])


if __name__ == '__main__':
    main()
