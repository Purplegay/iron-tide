"""Independent PCM oracle for a complete exported YR voice candidate (Python 3.12)."""
import audioop
import hashlib
import json
import struct
import sys
import wave
from pathlib import Path


def channel_pcm(block):
    predictor, index, reserved = struct.unpack_from('<hBB', block)
    assert reserved == 0 and index <= 88
    # audioop consumes high nibble first; Westwood IMA consumes low nibble first.
    data = bytes((b >> 4) | ((b & 15) << 4) for b in block[4:])
    return struct.pack('<h', predictor) + audioop.adpcm2lin(data, 2, (predictor, index))[0]


def verify(candidate):
    source, project = candidate / 'input', candidate / 'project'
    manifest = json.loads((project / 'data/ra2/yr_unit_voices.json').read_text())
    idx, bag = (source / 'audio.idx').read_bytes(), (source / 'audio.bag').read_bytes()
    records = {}
    for pos in range(12, len(idx), 36):
        name, *record = struct.unpack_from('<16s5I', idx, pos)
        records[name.split(b'\0')[0].decode().lower()] = record
    stereo_tails = []
    for key, entry in manifest['entries'].items():
        token = key.removeprefix('yr_full_')
        offset, length, rate, flags, chunk = records[token]
        raw = bag[offset:offset + length]
        channels = 2 if flags & 1 else 1
        if flags & 2:
            expected = raw
        else:
            blocks = []
            for pos in range(0, length, chunk or 512):
                block = raw[pos:pos + (chunk or 512)]
                if channels == 1:
                    blocks.append(channel_pcm(block))
                else:
                    payloads = [block[c * 4:c * 4 + 4] + b''.join(
                        block[p + c * 4:p + c * 4 + 4] for p in range(8, len(block), 8)) for c in range(2)]
                    pcm = [channel_pcm(data) for data in payloads]
                    if len(pcm[0]) != len(pcm[1]):
                        stereo_tails.append({'sample': token, 'unpaired_samples': abs(len(pcm[0]) - len(pcm[1])) // 2})
                    samples = [struct.unpack('<' + str(len(data) // 2) + 'h', data) for data in pcm]
                    pairs = [value for pair in zip(*samples) for value in pair]
                    blocks.append(struct.pack('<' + str(len(pairs)) + 'h', *pairs))
            expected = b''.join(blocks)
        path = project / 'assets/ra2/sfx' / entry['file']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], token
        with wave.open(str(path), 'rb') as wav:
            assert wav.getnchannels() == channels and wav.getframerate() == rate and wav.getsampwidth() == 2, token
            assert wav.getnframes() == entry['frames'], token
            assert wav.readframes(wav.getnframes()) == expected, token
            assert audioop.max(expected, 2) > 0, token
    for voices in manifest['units'].values():
        for key in voices.values():
            assert all(sample in manifest['entries'] for sample in manifest['specs'][key]['sounds'])
    for uid, sound in {'TANY': 'tanyaprimeselect', 'GGI': 'guardiangiselect', 'FV': 'ifvselect',
                       'CMIN': 'chronominerselect', 'YURIPR': 'yuriprimeselect'}.items():
        assert manifest['units'][uid]['select'] == 'yr_full_' + sound
    result = {'verified_pcm_samples': len(manifest['entries']), 'all_pcm_equal_independent_audioop': True,
              'stereo_tail_complete_frames_only': stereo_tails, 'mapping_references_valid': True}
    (candidate / 'pcm-verification.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


if __name__ == '__main__':
    verify(Path(sys.argv[1]))
