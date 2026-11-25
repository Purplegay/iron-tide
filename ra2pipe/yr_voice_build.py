"""Import only changed unit speech from Vector's YR voice pack; never import rules.

Usage: python ra2pipe/yr_voice_build.py <folder containing audio.bag/idx and rules/sound.ini>
Optional --project points to an isolated Godot project for validation.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import struct
import wave

STEPS = [7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767]
ADJUST = [-1,-1,-1,-1,2,4,6,8]
VOICE_KEYS = {"VoiceSelect":"select", "VoiceMove":"move", "VoiceAttack":"attack",
              "VoiceFeedback":"feedback", "VoiceSpecialAttack":"special",
              "DeploySound":"deploy", "UndeploySound":"undeploy"}


def read_ini(path):
    sections, current = {}, None
    for raw in path.read_text(encoding="latin1").splitlines():
        line = raw.split(";", 1)[0].strip()
        if line.startswith("[") and line.endswith("]"):
            current = sections.setdefault(line[1:-1], {})
        elif current is not None and "=" in line:
            key, value = line.split("=", 1)
            current[key.strip()] = value.strip()
    return sections


def decode_mono(raw, flags, block_size):
    if flags & 1:
        raise ValueError("Speech importer only accepts mono audio")
    if flags & 2:
        if len(raw) % 2:
            raise ValueError("Truncated PCM16 data")
        return raw
    if not flags & 8 or block_size < 4:
        raise ValueError("Unsupported audio format")
    samples = []
    for start in range(0, len(raw), block_size):
        block = raw[start:start + block_size]
        if len(block) < 4:
            raise ValueError("Truncated IMA block")
        predictor, index, reserved = struct.unpack_from("<hBB", block)
        if index > 88 or reserved != 0:
            raise ValueError("Invalid IMA header")
        samples.append(predictor)
        for byte in block[4:]:
            for nibble in (byte & 15, byte >> 4):
                step = STEPS[index]
                delta = step >> 3
                if nibble & 1: delta += step >> 2
                if nibble & 2: delta += step >> 1
                if nibble & 4: delta += step
                predictor = max(-32768, min(32767, predictor + (-delta if nibble & 8 else delta)))
                index = max(0, min(88, index + ADJUST[nibble & 7]))
                samples.append(predictor)
    return struct.pack(f"<{len(samples)}h", *samples)


def build(source, project):
    rules, sounds = read_ini(source / "rules.ini"), read_ini(source / "sound.ini")
    idx, bag = (source / "audio.idx").read_bytes(), (source / "audio.bag").read_bytes()
    if idx[:4] != b"GABA" or len(idx) < 12:
        raise ValueError("Invalid audio.idx")
    count = struct.unpack_from("<I", idx, 8)[0]
    if len(idx) != 12 + count * 36:
        raise ValueError("Invalid audio.idx size")
    records = {}
    for i in range(count):
        name, offset, length, rate, flags, chunk = struct.unpack_from("<16s5I", idx, 12 + i * 36)
        name = name.split(b"\0", 1)[0].decode("ascii").lower()
        if not name or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in name):
            raise ValueError("Unsafe sample name")
        if offset + length > len(bag) or not 8000 <= rate <= 96000:
            raise ValueError(f"Invalid sample range: {name}")
        records[name] = (offset, length, rate, flags, chunk)
    units = json.loads((project / "data/ra2_allied.json").read_text(encoding="utf-8"))["units"]
    overrides, specs, entries, files = {}, {}, {}, {}
    for unit in units:
        for ini_key, kind in VOICE_KEYS.items():
            sound_id = rules.get(unit["id"], {}).get(ini_key, "")
            if not sound_id or sound_id == unit.get("voice", {}).get(kind, ""):
                continue
            spec = sounds[sound_id]
            tokens = [t.lstrip("$").lower() for t in spec["Sounds"].split()]
            if not tokens:
                raise ValueError(f"Empty speech: {sound_id}")
            for token in tokens:
                if token in files: continue
                offset, length, rate, flags, chunk = records[token]
                pcm = decode_mono(bag[offset:offset + length], flags, chunk or 512)
                if not pcm or not any(pcm):
                    raise ValueError(f"Empty or silent speech: {token}")
                output = io.BytesIO()
                with wave.open(output, "wb") as wav:
                    wav.setparams((1, 2, rate, 0, "NONE", "not compressed"))
                    wav.writeframes(pcm)
                files[token] = output.getvalue()
                entries["yr_" + token] = {"file": f"yr/{token}.wav", "sampleRate": rate, "channels": 1,
                    "frames": len(pcm) // 2, "durMs": round(len(pcm) / 2 / rate * 1000),
                    "bytes": len(files[token]), "sha256": hashlib.sha256(files[token]).hexdigest()}
            key = "yr_" + sound_id
            specs[key] = {"sounds": ["yr_" + t for t in tokens], "volume": float(spec.get("Volume", 1)),
                          "range": float(spec.get("Range", 10)), "type": spec.get("Type", "")}
            overrides.setdefault(unit["id"], {})[kind] = key
    manifest = {"source": "Vector / CnCNet YR unit voice pack (2025-01-19)",
        "source_hashes": {name: hashlib.sha256((source / name).read_bytes()).hexdigest()
                          for name in ["audio.bag", "audio.idx", "rules.ini", "sound.ini"]},
        "units": overrides, "specs": specs, "entries": entries}
    # Validate the entire pack before writing; base rules and RA2 audio remain untouched.
    target = project / "assets/ra2/sfx/yr"
    target.mkdir(parents=True, exist_ok=True)
    for token, contents in files.items():
        (target / (token + ".wav")).write_bytes(contents)
    (project / "data/ra2/yr_voice_pack.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"units": list(overrides), "voice_sets": len(specs), "samples": len(files),
                      "bytes": sum(map(len, files.values()))}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1] / "iron_tide")
    args = parser.parse_args()
    build(args.source, args.project)
