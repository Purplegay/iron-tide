"""Rank measured work in the slowest frame intervals of a --frame-profile run."""
import argparse
import json
import math
from pathlib import Path


def summarize(frames, tail_fraction):
    if not frames or any('work' not in frame for frame in frames):
        raise ValueError('Requires nonempty frame-components.json from --frame-profile')
    errors = sum(frame['work'].get('scope_errors', 0) for frame in frames)
    negative = sum(row[2] < 0 for frame in frames for row in frame['work']['points'].values())
    if errors or negative:
        raise ValueError(f'Invalid scope accounting: {errors} errors, {negative} negative self-time rows')
    selected = sorted(frames, key=lambda frame: frame['frame_ms'], reverse=True)[:max(1, math.ceil(len(frames)*tail_fraction))]
    totals = {}
    for frame in selected:
        for name, row in frame['work']['points'].items():
            total = totals.setdefault(name, [0, 0, 0, 0, 0])
            for index in [0, 1, 2, 4]:
                total[index] += row[index]
            total[3] = max(total[3], row[3])
    points = []
    for name, row in totals.items():
        points.append({'name': name, 'calls': row[0], 'iterations': row[4],
                       'self_total_ms': row[2]/1000,
                       'inclusive_total_ms': row[1]/1000,
                       'self_ms_per_tail_frame': row[2]/1000/len(selected),
                       'inclusive_ms_per_tail_frame': row[1]/1000/len(selected),
                       'max_call_inclusive_ms': row[3]/1000})
    return {'frames': len(frames), 'tail_frames': len(selected), 'tail_fraction': tail_fraction,
            'scope_bookkeeping_ms': sum(frame['work'].get('scope_bookkeeping_us', 0) for frame in selected)/1000,
            'bookkeeping_adjusted': all('scope_bookkeeping_us' in frame['work'] for frame in selected),
            'scope_errors': errors, 'negative_self_rows': negative,
            'selected_frame_indices': [frame['frame_index'] for frame in selected],
            'logic_steps_in_tail': {str(count): sum(frame['logic_steps'] == count for frame in selected)
                                    for count in sorted({frame['logic_steps'] for frame in selected})},
            'points': sorted(points, key=lambda point: point['self_ms_per_tail_frame'], reverse=True),
            'limitations': 'New probes subtract measured nested scope bookkeeping; dispatch/timestamp overhead remains. Older probes include all diagnostic overhead. Self includes uninstrumented callees. Inclusive scopes overlap; do not sum them. Frame work is between probe observations. Use separate clean runs for P95 and simulation speed; headless is not GPU/display FPS.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--tail-fraction', type=float, default=0.05)
    args = parser.parse_args()
    if not 0 < args.tail_fraction <= 1:
        parser.error('--tail-fraction must be in (0, 1]')
    result = summarize(json.loads(args.input.read_text('utf8')), args.tail_fraction)
    result['input'] = str(args.input.resolve())
    args.output.write_text(json.dumps(result, indent=2), 'utf8')
    for point in result['points'][:15]:
        print(f"{point['name']}: self {point['self_total_ms']:.3f} ms total / {point['self_ms_per_tail_frame']:.3f} ms/selected frame, inclusive {point['inclusive_total_ms']:.3f} ms, calls {point['calls']}, iterations {point['iterations']}")


if __name__ == '__main__':
    main()
