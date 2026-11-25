"""Summarize the bounded bridge diagnostics in a battle's exported JSON log."""
import argparse
import json
from pathlib import Path


def summarize(path):
    data = json.loads(path.read_text('utf8'))
    bridges, waiting, ai_counts = {}, {}, set()
    visits = 0
    for window in data['windows']:
        ai_counts.add(window['ai_count'])
        traffic = window.get('bridge_traffic', {})
        visits += traffic.get('sampled_actor_visits', 0)
        for row in traffic.get('bridges', []):
            total = bridges.setdefault(row['bridge'], {
                'bridge': row['bridge'], 'rect': row['rect'], 'events': {},
                'sampled_actor_visits': 0, 'max_no_progress_s': 0.0,
                'busy_reasons': {}, 'peak_waiter': {}})
            total['sampled_actor_visits'] += row['sampled_actor_visits']
            if row['max_no_progress_s'] > total['max_no_progress_s']:
                total['peak_waiter'] = row.get('peak_waiter', {})
            total['max_no_progress_s'] = max(total['max_no_progress_s'], row['max_no_progress_s'])
            for reason, count in row.get('busy_reasons', {}).items():
                total['busy_reasons'][reason] = total['busy_reasons'].get(reason, 0) + count
            for kind, count in row['events'].items():
                total['events'][kind] = total['events'].get(kind, 0) + count
        for row in traffic.get('longest_waiting', []):
            if row['no_progress_s'] > waiting.get(row['unit'], {}).get('no_progress_s', -1):
                waiting[row['unit']] = row
    return {'source': str(path.resolve()), 'map': data['header']['map'],
            'observed_window_ai_counts': sorted(ai_counts),
            'sampled_actor_visits': visits,
            'bridges': sorted(bridges.values(), key=lambda row: -row['max_no_progress_s']),
            'longest_waiting': sorted(waiting.values(), key=lambda row: -row['no_progress_s'])[:20],
            'limitations': 'Movement intent and displacement samples are not proof of a collision deadlock. Durations use game seconds. Each window retains 20 current longest waits, one peak snapshot per bridge, and 48 sampled recent event details; event totals and first-matching busy reasons are exact. Older logs may lack reasons or peak snapshots.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = summarize(args.log)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False), 'utf8')
    print('map', result['map'], 'AI', result['observed_window_ai_counts'], 'samples', result['sampled_actor_visits'])
    for row in result['bridges']:
        print('bridge', row['bridge'], 'max no-progress', round(row['max_no_progress_s'], 2), 'events', row['events'])
        print('  busy reasons', row['busy_reasons'], 'peak', row['peak_waiter'])
    for row in result['longest_waiting'][:5]:
        print('waiting', row['type'], row['side'], 'bridge', row['bridge'], round(row['no_progress_s'], 2), 's', row['position'])
    print('report', args.output.resolve())


if __name__ == '__main__':
    main()
