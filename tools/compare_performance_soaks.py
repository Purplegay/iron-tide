"""Compare isolated, matched 60- or 120-second runs from the same checkpoint."""
import argparse
import json
from pathlib import Path


def read(run, name):
    return json.loads((run / name).read_text('utf8'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('before', type=Path)
    parser.add_argument('after', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    results = [read(path, 'result.json') for path in [args.before, args.after]]
    environments = [read(path, 'environment.json') for path in [args.before, args.after]]
    for result, env, path in zip(results, environments, [args.before, args.after]):
        if not result['completed'] or env['seconds'] not in (60, 120) or env['profile'] or env.get('scan_loops', False) or env.get('unit_work', False):
            raise ValueError('Require completed, non-profiled 60- or 120-second runs: ' + str(path))
        if read(path, 'source-audit.json')['changed_during_run']:
            raise ValueError('Source drift during run: ' + str(path))
        if 'SCRIPT ERROR:' in (path / 'log').read_text('utf8', errors='replace'):
            raise ValueError('Script errors in run: ' + str(path))
    for key in ['seconds', 'save_sha256', 'speed', 'ai_count', 'seed', 'renderer', 'ai_rng']:
        if environments[0].get(key) != environments[1].get(key):
            raise ValueError('Unmatched comparison setting: ' + key)
    if not environments[0]['save_sha256'] or results[0]['initial_state'] != results[1]['initial_state']:
        raise ValueError('Both variants must start from the same checkpoint and population.')
    rows = []
    for result in results:
        rows.append({'wall_s': result['wall'], 'advanced_sim_s': result['sim'],
                     'effective_speed': result['sim'] / result['wall'],
                     'frames': result['frame_stats'], 'logic_steps': result['logic_stats'],
                     'peak_units': result['peak_units'], 'load_ms': result['load_ms']})
    before, after = rows
    hashes = [read(path, 'source-sha256.json') for path in [args.before, args.after]]
    changes = [key for key in sorted(set(hashes[0]) | set(hashes[1])) if hashes[0].get(key) != hashes[1].get(key)]
    report = {'checkpoint_sha256': environments[0]['save_sha256'], 'initial_state': results[0]['initial_state'],
              'selected_speed': environments[0]['speed'], 'duration_wall_seconds': environments[0]['seconds'], 'before': before, 'after': after,
              'mean_frame_change_percent': (after['frames']['mean_ms'] / before['frames']['mean_ms'] - 1) * 100,
              'p95_frame_change_percent': (after['frames']['p95_ms'] / before['frames']['p95_ms'] - 1) * 100,
              'effective_speed_change_percent': (after['effective_speed'] / before['effective_speed'] - 1) * 100,
              'changed_sources': changes,
              'limitations': 'Headless CPU frame intervals, not displayed GPU FPS. Logic timing excludes later physics-server work and process/render callbacks. Same start does not imply identical subsequent AI trajectories. Background machine load is not controlled.'}
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False), 'utf8')
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()
