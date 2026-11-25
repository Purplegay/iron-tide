"""Read-only, SHA-pinned Uprising BeamSpecialAbilityUpdate static evidence.

This verifies instructions/bindings, not an executed SAGE simulation oracle.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

SHA = 'b1da83efd229570bab9de3a14e48b2d1e6128e302bd52384858fa8a413ae330b'


def audit(game, output):
    data = game.read_bytes()
    assert hashlib.sha256(data).hexdigest() == SHA, 'Wrong Uprising executable'
    pe = struct.unpack_from('<I', data, 0x3c)[0]
    count = struct.unpack_from('<H', data, pe+6)[0]
    optional = struct.unpack_from('<H', data, pe+20)[0]
    base = struct.unpack_from('<I', data, pe+52)[0]
    sections = [struct.unpack_from('<4I', data, pe+24+optional+i*40+8) for i in range(count)]

    def read(va, length):
        for _, rva, size, offset in sections:
            if rva <= va-base and va-base+length <= rva+size:
                start = offset+va-base-rva
                return data[start:start+length]
        raise ValueError(hex(va))

    checks = 0

    def expect(va, hex_bytes):
        nonlocal checks
        expected = bytes.fromhex(hex_bytes)
        assert read(va, len(expected)) == expected, hex(va)
        checks += 1

    assert struct.unpack('<I', read(0xc5bfa8, 4))[0] == 0x7a3d60
    assert struct.unpack('<I', read(0xc5be48, 4))[0] == 0x7ff8b0
    assert read(0xc341b4, 24).rstrip(b'\0') == b'BeamSpecialAbilityUpdate'
    checks += 3
    expect(0x7e0ea5, 'f30f10b020010000')  # SweepDistance
    expect(0x7e0eb0, 'f30f5935a882bf00')  # multiply .5
    assert struct.unpack('<f', read(0xbf82a8, 4))[0] == .5
    checks += 1
    expect(0x7e13db, '8b8f18010000c1e903f6c101')  # DIAGONAL_SWEEPING bit 3
    expect(0x7e141f, 'f30f5cf3')  # start.x -= forward.x * half sweep
    expect(0x7e1449, 'f30f58f3')  # end.x += forward.x * half sweep
    expect(0x772353, 'f30f5edf')  # elapsed frames / duration frames
    expect(0x77235b, 'f30f59c3f30f59cbf30f59d3f30f58c4f30f58cdf30f58d6')
    expect(0x7e0b65, '8bb1e000000033db3bf3741a')  # zero interval bypasses modulus
    for call, target in [(0x772386, 0x7679e0), (0x7e0bd8, 0x73c9e0), (0x7e0c51, 0x7dc6d0)]:
        assert read(call, 1) == b'\xe8'
        assert call+5+struct.unpack('<i', read(call+1, 4))[0] == target
        checks += 1
    ranges = {'endpoint_setup': (0x7e0c80, 0x7e14bc),
              'linear_interpolation': (0x772170, 0x7723ae),
              'per_laser_damage': (0x7e0b60, 0x7e0c7c),
              'disabled_owner_gate': (0x7eba60, 0x7ebab6)}
    report = {'source': str(game), 'sha256': SHA, 'checks': checks,
              'ranges': {name: {'start': hex(a), 'end_exclusive': hex(b),
                         'sha256': hashlib.sha256(read(a, b-a)).hexdigest()}
                         for name, (a, b) in ranges.items()},
              'findings': ['SweepDistance is total span, halved for endpoint construction.',
                           'Crisscross alternates lateral endpoints; diagonal shifts each start backward and end forward.',
                           'Active interpolation is start + (end-start) * elapsed/duration.',
                           'Zero DamageInterval fires once per laser record each active update.'],
              'limits': 'Static instruction evidence. First/last scheduler phase, terrain/3D collision and disabled-state mapping remain cross-engine adaptations.'}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'checks': checks, 'output': str(output)}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    audit(args.game, args.output)
