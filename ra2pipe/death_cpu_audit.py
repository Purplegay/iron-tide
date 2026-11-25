"""Read-only byte checks against the installed YR executable, no game execution."""
import hashlib
import json
import struct
import sys
from pathlib import Path

binary = Path(sys.argv[1]).read_bytes()
digest = hashlib.sha256(binary).hexdigest()
if digest != '3e81a61775d2745d1dabe397325ef663cd994ffc194da4e998e3bf5d2d308600':
    raise SystemExit('Unsupported gamemd.exe; re-audit addresses before using findings')
pe = struct.unpack_from('<I', binary, 0x3c)[0]
base = struct.unpack_from('<I', binary, pe + 52)[0]
optional = struct.unpack_from('<H', binary, pe + 20)[0]
sections = [struct.unpack_from('<4I', binary, pe + 24 + optional + n * 40 + 8)
            for n in range(struct.unpack_from('<H', binary, pe + 6)[0])]

def read(address, size):
    for _, rva, raw_size, offset in sections:
        if rva <= address - base and address - base + size <= rva + raw_size:
            return binary[offset + address - base - rva:offset + address - base - rva + size]
    raise ValueError(hex(address))

checks = [
    (0x710B00, '33db', 'type constructor zeroes EBX'),
    (0x71145A, '889ecd0c0000', 'Crewed engine default is false'),
    (0x451348, '8a81cd0c0000', 'building crew requires type Crewed'),
    (0x451395, '8a87e3060000', 'captured flag read'),
    (0x45139F, '03f6', 'captured divisor doubles'),
    (0x4513A6, 'ff90b8000000', 'crew count calls type GetRefund'),
    (0x4513AC, '99f7fe', 'integer division'),
    (0x4513BC, '83f805', 'maximum five'),
    (0x7F4F90, '601f7100', 'type GetRefund vtable points to 711F60'),
    (0x711F6C, 'dd8038170000', 'GetRefund reads RefundPercent'),
    (0x44EB31, '83f819', 'construction yard engineer threshold 25/100'),
    (0x44EB3C, '83b9b80e000007', 'engineer only for BuildingType factory'),
    (0x44EB4C, '8b82700f0000', 'Engineer rules pointer'),
    (0x707DAF, '83f80f', 'armed crew technician threshold 15/100'),
    (0x442DBD, '8b8740050000', 'C4AppliedBy affects ejection random bound, not sale flag'),
    (0x442DC5, 'c744241802000000', 'normal random bound 2'),
    (0x442DCF, 'c744241801000000', 'C4 random bound 1'),
    (0x442DDF, '8344241806', 'captured random bound plus six'),
    (0x6F3958, '8a90cd0c0000', 'vehicle crew count reads Crewed'),
    (0x6F3962, '0f95c1', 'vehicle crew count returns zero or one'),
    (0x7114A8, '889e150d0000', 'Explodes constructor default false'),
    (0x7114B4, 'c7861c0d00000000803f', 'DeathWeaponDamageModifier constructor default 1.0'),
    (0x70258F, '8a88150d0000', 'lethal techno damage checks Explodes'),
    (0x70D6A0, '8b88180d0000', 'death explosion prefers explicit DeathWeapon'),
    (0x70D6F1, 'd8881c0d0000', 'weapon damage uses DeathWeaponDamageModifier'),
    (0x70D713, 'db80a0000000', 'unarmed default explosion reads type Strength'),
    (0x7E1738, '000000000000e03f', 'unarmed default explosion strength multiplier 0.5'),
]
results = []
for address, expected, meaning in checks:
    actual = read(address, len(bytes.fromhex(expected))).hex()
    results.append({'address': hex(address), 'meaning': meaning, 'expected': expected,
                    'actual': actual, 'passed': actual == expected})
report = {'sha256': digest, 'checks': results,
          'boundary': 'Pinned instructions establish the listed gates only; continuous exits, collision and visual physics are Godot adaptations. House discounts and neutral/campaign special cases are not engine emulation.'}
if len(sys.argv) > 2:
    Path(sys.argv[2]).write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'checks': len(results), 'failed': [r for r in results if not r['passed']]}))
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
