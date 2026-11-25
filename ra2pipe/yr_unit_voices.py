"""Build all original YR unit voice mappings, independently of playable unit rules.

Usage: python ra2pipe/yr_unit_voices.py <candidate created by yr_voices.mjs>
Only candidate/project receives output; publish reviewed assets separately.
"""
import argparse
import hashlib
import io
import json
import re
import struct
import wave
from pathlib import Path
from yr_voice_build import decode_mono, read_ini

VOICE_KEYS = {
    'voiceselect': 'select', 'voicemove': 'move', 'voiceattack': 'attack',
    'voicefeedback': 'feedback', 'voicespecialattack': 'special',
    'diesound': 'die', 'crushsound': 'crush', 'deploysound': 'deploy',
    'undeploysound': 'undeploy', 'voiceharvest': 'harvest', 'voiceenter': 'enter',
    'voicecapture': 'capture', 'voicecrashing': 'crashing', 'voicedeploy': 'deploy_command',
    'voicesecondaryweaponattack': 'secondary_attack',
    'voiceselectdeactivated': 'select_deactivated', 'voiceselectenslaved': 'select_enslaved',
}
# Same named prototypes in the legacy extension catalogue; no gameplay rule aliasing.
ALIASES = {'soviet_conscript': 'E2', 'soviet_tesla': 'TTNK', 'soviet_terror': 'DRON'}


def normalized_ini(path):
    return {name.lower(): {k.lower(): v for k, v in spec.items()}
            for name, spec in read_ini(path).items()}


def decode_pcm(raw, flags, block_size):
    if not flags & 1:
        return decode_mono(raw, flags, block_size)
    if flags & 2:
        if len(raw) % 4:
            raise ValueError('Truncated stereo PCM')
        return raw
    if not flags & 8 or block_size < 8:
        raise ValueError('Unsupported stereo format')
    output = bytearray()
    for start in range(0, len(raw), block_size):
        block = raw[start:start + block_size]
        if len(block) < 8:
            raise ValueError('Truncated stereo IMA channel group')
        channels = [bytearray(block[:4]), bytearray(block[4:8])]
        for pos in range(8, len(block), 8):
            channels[0].extend(block[pos:pos + 4])
            channels[1].extend(block[pos + 4:pos + 8])
        left, right = [decode_mono(data, flags & ~1, len(data)) for data in channels]
        # A short final IMA group can contain more left than right samples.
        # Emit only complete stereo frames; do not invent the missing channel.
        for pos in range(0, min(len(left), len(right)), 2):
            output.extend(left[pos:pos + 2])
            output.extend(right[pos:pos + 2])
    return bytes(output)


def build(candidate):
    candidate = candidate.resolve()
    repo = Path(__file__).resolve().parents[1]
    if candidate == repo or repo in candidate.parents:
        raise ValueError('Candidate must be outside repository')
    source, project = candidate / 'input', candidate / 'project'
    if project.exists():
        raise ValueError('Candidate project already exists; refusing overwrite')
    audit = json.loads((candidate / 'source-audit.json').read_text(encoding='utf-8'))
    if candidate == Path(audit['source']) or Path(audit['source']) in candidate.parents:
        raise ValueError('Candidate must be outside source game')
    for name, info in audit['files'].items():
        if Path(name).name != name or hashlib.sha256((source / name).read_bytes()).hexdigest() != info['sha256']:
            raise ValueError(f'Input fingerprint mismatch: {name}')
    rules, sounds = normalized_ini(source / 'rulesmd.ini'), normalized_ini(source / 'soundmd.ini')
    idx, bag = (source / 'audio.idx').read_bytes(), (source / 'audio.bag').read_bytes()
    if len(idx) < 12 or idx[:4] != b'GABA' or len(idx) != 12 + 36 * struct.unpack_from('<I', idx, 8)[0]:
        raise ValueError('Invalid audio index')
    records = {}
    for start in range(12, len(idx), 36):
        name, offset, length, rate, flags, chunk = struct.unpack_from('<16s5I', idx, start)
        token = name.split(b'\0')[0].decode('ascii').lower()
        if not re.fullmatch('[a-z0-9_-]+', token) or token in records:
            raise ValueError(f'Invalid or duplicate sample: {token}')
        if offset + length > len(bag) or not 8000 <= rate <= 96000:
            raise ValueError(f'Invalid sample range: {token}')
        records[token] = (offset, length, rate, flags, chunk)
    ids = sorted({uid for category in ['infantrytypes', 'vehicletypes', 'aircrafttypes']
                  for uid in rules[category].values()})
    units, specs, entries, files, mappings = {}, {}, {}, {}, {}
    silent_events = []
    for uid in ids:
        voices = {}
        for field, kind in VOICE_KEYS.items():
            sound_id = rules.get(uid.lower(), {}).get(field, '')
            if not sound_id:
                continue
            key = 'yr_full_' + sound_id.lower()
            if key not in specs:
                spec = sounds[sound_id.lower()]
                tokens = [t.lstrip('$#').lower() for t in spec.get('sounds', '').split()]
                if not tokens:
                    if float(spec.get('volume', 1)) == 0:
                        silent_events.append({'unit': uid, 'kind': kind, 'sound': sound_id})
                        continue # Original intentional silence, not a missing sample.
                    raise ValueError(f'Empty sound: {sound_id}')
                for token in tokens:
                    if token in files:
                        continue
                    offset, length, rate, flags, chunk = records[token]
                    channels = 2 if flags & 1 else 1
                    pcm = decode_pcm(bag[offset:offset + length], flags, chunk or 512)
                    if not pcm or not any(pcm):
                        raise ValueError(f'Silent or empty sample: {token}')
                    buffer = io.BytesIO()
                    with wave.open(buffer, 'wb') as wav:
                        wav.setparams((channels, 2, rate, 0, 'NONE', 'not compressed'))
                        wav.writeframes(pcm)
                    files[token] = buffer.getvalue()
                    entries['yr_full_' + token] = {
                        'file': f'yr_full/{token}.wav', 'sampleRate': rate, 'channels': channels,
                        'frames': len(pcm) // (2 * channels), 'durMs': round(len(pcm) / (2 * channels) / rate * 1000),
                        'bytes': len(files[token]), 'sha256': hashlib.sha256(files[token]).hexdigest(),
                    }
                specs[key] = {'sounds': ['yr_full_' + t for t in tokens],
                              'volume': float(spec.get('volume', 1)), 'range': float(spec.get('range', 10)),
                              'type': spec.get('type', ''), 'source_sound': sound_id}
            voices[kind] = key
        if voices:
            units[uid] = voices
        mappings[uid] = {field: rules.get(uid.lower(), {}).get(field, '') for field in VOICE_KEYS}
    for alias, uid in ALIASES.items():
        units[alias] = dict(units[uid])
    manifest = {'version': 1, 'source': 'Local installed Yuri Revenge rulesmd/soundmd/audio',
                'source_files': audit['files'], 'units': units, 'specs': specs, 'entries': entries,
                'aliases': ALIASES, 'original_mappings': mappings, 'silent_events': silent_events,
                'note': 'Audio only. Non-playable units are reserved mappings, not unlocked units.'}
    # No output until every referenced sample and mapping has been validated.
    target = project / 'assets/ra2/sfx/yr_full'
    target.mkdir(parents=True)
    for token, contents in files.items():
        (target / (token + '.wav')).write_bytes(contents)
    (project / 'data/ra2').mkdir(parents=True)
    (project / 'data/ra2/yr_unit_voices.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    summary = {'source_unit_definitions': len(ids), 'units_with_audio': len(units) - len(ALIASES),
               'aliases': ALIASES, 'voice_sets': len(specs), 'samples': len(files), 'silent_events': len(silent_events),
               'bytes': sum(map(len, files.values()))}
    (candidate / 'build-result.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(summary))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('candidate', type=Path)
    build(parser.parse_args().candidate)
