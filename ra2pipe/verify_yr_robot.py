"""Independently verify robot PCM and scoped export references (Python 3.12)."""
import hashlib
import json
import struct
import sys
import wave
from pathlib import Path
from verify_yr_unit_voices import channel_pcm


def verify(candidate):
    project = candidate / 'project'
    pack = json.loads((project / 'data/yr_robot.json').read_text(encoding='utf-8'))
    idx = (candidate / 'input/audio.idx').read_bytes()
    bag = (candidate / 'input/audio.bag').read_bytes()
    records = {}
    for pos in range(12, len(idx), 36):
        name, *record = struct.unpack_from('<16s5I', idx, pos)
        records[name.split(b'\0')[0].decode().lower()] = record
    for entry in pack['sounds']['entries'].values():
        name = Path(entry['file']).stem
        offset, length, rate, flags, chunk = records[name]
        assert not flags & 1, 'Scoped exporter supports original mono sounds only'
        raw = bag[offset:offset + length]
        expected = raw if flags & 2 else b''.join(channel_pcm(raw[p:p + (chunk or 512)])
                                                   for p in range(0, length, chunk or 512))
        file = project / 'assets/ra2/sfx' / entry['file']
        assert hashlib.sha256(file.read_bytes()).hexdigest() == entry['sha256'], name
        with wave.open(str(file), 'rb') as wav:
            assert wav.getnchannels() == 1 and wav.getsampwidth() == 2 and wav.getframerate() == rate, name
            assert wav.getnframes() == entry['frames'], name
            assert wav.readframes(wav.getnframes()) == expected, name
    for spec in pack['sounds']['specs'].values():
        assert all(key in pack['sounds']['entries'] for key in spec['sounds'])
    for id, art in pack['art'].items():
        assert all((project / file.removeprefix('res://')).is_file() for file in art.values()), id
    unit, center = pack['units'][0], pack['buildings'][0]
    assert unit['id'] == 'ROBO' and unit['cost'] == 600 and unit['hp'] == 180
    assert center['id'] == 'GAROBO' and center['cost'] == 600 and center['power'] == -100
    assert pack['source_units']['ROBO']['extra']['Trainable'] == 'no'
    assert unit['build_time_multiplier'] == 1.3 and unit['move']['rot_units'] == 5
    audit = json.loads((candidate / 'source-audit.json').read_text())
    for name, fingerprint in audit['inputs'].items():
        assert hashlib.sha256((Path(audit['source']) / name).read_bytes()).hexdigest() == fingerprint['sha256'], name
    result = {'pcm_samples_verified': len(pack['sounds']['entries']), 'sound_sets': len(pack['sounds']['specs']),
              'pcm_matches_independent_audioop': True, 'original_inputs_unchanged': True,
              'original_archive_count': len(audit['inputs']), 'art_references_valid': True}
    (candidate / 'verification.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


if __name__ == '__main__':
    verify(Path(sys.argv[1]))
