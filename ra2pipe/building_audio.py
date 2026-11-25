"""Export the original building-placement sound from an audited local YR intake.

Usage: python ra2pipe/building_audio.py <export directory> <new candidate directory>
The source and live game are never modified; publish the reviewed candidate separately.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import wave

from yr_voice_build import decode_mono, read_ini


def build(source, output):
    source, output = source.resolve(), output.resolve()
    repo = Path(__file__).resolve().parents[1]
    if output.exists() or output.is_relative_to(repo) or output.is_relative_to(source):
        raise ValueError("Use a new candidate directory outside the source and project")
    audit = json.loads((source / "source-audit.json").read_text(encoding="utf-8"))
    inputs = source / "input"
    hashes = {}
    for name in ("rulesmd.ini", "soundmd.ini", "audio.idx", "audio.bag"):
        hashes[name] = hashlib.sha256((inputs / name).read_bytes()).hexdigest()
        if hashes[name] != audit["files"][name]["sha256"]:
            raise ValueError(f"Source changed since intake: {name}")
    rules, sounds = read_ini(inputs / "rulesmd.ini"), read_ini(inputs / "soundmd.ini")
    sound_id = rules["AudioVisual"]["BuildingSlam"]
    if sound_id != "PlaceBuilding" or rules["AudioVisual"]["BuildingDrop"] != sound_id:
        raise ValueError("Unexpected original building sound mapping")
    spec = sounds[sound_id]
    if spec["Sounds"].strip().lower() != "uplace":
        raise ValueError("Unexpected placement sample")
    idx, bag = (inputs / "audio.idx").read_bytes(), (inputs / "audio.bag").read_bytes()
    if len(idx) < 12 or idx[:4] != b"GABA":
        raise ValueError("Invalid audio index")
    count = struct.unpack_from("<I", idx, 8)[0]
    if len(idx) != 12 + count * 36:
        raise ValueError("Invalid index length")
    matches = []
    for i in range(count):
        name, offset, length, rate, flags, chunk = struct.unpack_from("<16s5I", idx, 12 + i * 36)
        if name.split(b"\0", 1)[0].lower() == b"uplace":
            matches.append((offset, length, rate, flags, chunk))
    if len(matches) != 1:
        raise ValueError("Placement sample must exist exactly once")
    offset, length, rate, flags, chunk = matches[0]
    if offset + length > len(bag) or not 8000 <= rate <= 96000:
        raise ValueError("Invalid sample bounds")
    pcm = decode_mono(bag[offset:offset + length], flags, chunk or 512)
    if not pcm or not any(pcm):
        raise ValueError("Silent placement sound")
    target = output / "project/assets/ra2/sfx/building/uplace.wav"
    target.parent.mkdir(parents=True)
    with wave.open(str(target), "wb") as wav:
        wav.setparams((1, 2, rate, 0, "NONE", "not compressed"))
        wav.writeframes(pcm)
    manifest = {
        "source": audit["source"], "source_hashes": hashes, "units": {},
        "specs": {sound_id: {"sounds": ["building_uplace"],
            "volume": float(spec.get("Volume", 1)), "range": float(spec.get("Range", 10))}},
        "entries": {"building_uplace": {"file": "building/uplace.wav", "sampleRate": rate,
            "channels": 1, "frames": len(pcm) // 2, "durMs": round(len(pcm) / 2 / rate * 1000),
            "bytes": target.stat().st_size, "sha256": hashlib.sha256(target.read_bytes()).hexdigest()}},
    }
    dest = output / "project/data/ra2/building_audio.json"
    dest.parent.mkdir(parents=True)
    dest.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest["entries"]))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    build(args.source, args.output)
