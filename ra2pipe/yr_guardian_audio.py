"""Complete the scoped Guardian GI candidate with original YR speech/weapon PCM."""
import argparse
import hashlib
import io
import json
import struct
import wave
from pathlib import Path
from yr_voice_build import decode_mono, read_ini


def build(candidate, pack='yr_allied', namespace='yr_ggi'):
    if not all(c.isalnum() or c == '_' for c in pack + namespace):
        raise ValueError('Unsafe output identifier')
    source = candidate / 'input'
    project = candidate / 'project'
    manifest_path = project / 'data' / (pack + '.json')
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    sounds = {name.lower(): spec for name, spec in read_ini(source / 'soundmd.ini').items()}
    idx, bag = (source / 'audio.idx').read_bytes(), (source / 'audio.bag').read_bytes()
    if len(idx) < 12 or idx[:4] != b'GABA':
        raise ValueError('Invalid audio index')
    count = struct.unpack_from('<I', idx, 8)[0]
    if len(idx) != 12 + 36 * count:
        raise ValueError('Truncated audio index')
    records = {}
    for i in range(count):
        name, offset, length, rate, flags, chunk = struct.unpack_from('<16s5I', idx, 12 + 36 * i)
        records[name.split(b'\0')[0].decode('ascii').lower()] = (offset, length, rate, flags, chunk)
    files, specs, entries = {}, {}, {}
    for sound_id in json.loads((source / 'sound_ids.json').read_text()):
        spec = sounds[sound_id.lower()]
        tokens = [token.lstrip('$#').lower() for token in spec['Sounds'].split()]
        if not tokens:
            raise ValueError(f'Empty sound {sound_id}')
        for token in tokens:
            if token in files:
                continue
            if not all(c in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in token):
                raise ValueError('Unsafe audio token')
            offset, length, rate, flags, chunk = records[token]
            if offset + length > len(bag) or not 8000 <= rate <= 96000:
                raise ValueError(f'Invalid audio range {token}')
            pcm = decode_mono(bag[offset:offset + length], flags, chunk or 512)
            if not pcm or not any(pcm):
                raise ValueError(f'Empty audio {token}')
            data = io.BytesIO()
            with wave.open(data, 'wb') as wav:
                wav.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
                wav.writeframes(pcm)
            files[token] = data.getvalue()
            entries[namespace + '_' + token] = {'file': f'{namespace}/{token}.wav', 'sampleRate': rate,
                'channels': 1, 'frames': len(pcm) // 2, 'durMs': round(len(pcm) / 2 / rate * 1000),
                'bytes': len(files[token]), 'sha256': hashlib.sha256(files[token]).hexdigest()}
        specs['YR_' + sound_id] = {'sounds': [namespace + '_' + token for token in tokens],
            'volume': float(spec.get('Volume', 1)), 'range': float(spec.get('Range', 10)), 'type': spec.get('Type', '')}
    target = project / 'assets/ra2/sfx' / namespace
    target.mkdir(parents=True, exist_ok=True)
    for token, data in files.items():
        (target / (token + '.wav')).write_bytes(data)
    manifest['sounds'] = {'specs': specs, 'entries': entries}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'sounds': len(specs), 'samples': len(files), 'bytes': sum(map(len, files.values()))}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('candidate', type=Path)
    parser.add_argument('--pack', default='yr_allied')
    parser.add_argument('--namespace', default='yr_ggi')
    args = parser.parse_args()
    build(args.candidate, args.pack, args.namespace)
