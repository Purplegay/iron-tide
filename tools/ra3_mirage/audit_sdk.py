"""Audit official SDK definitions separately from shipped IronTide resources.

No archive extraction, network access, or fallback to game/demo inputs. Missing
native media is an explicit incomplete result, not evidence of integration.
"""
import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from xml.etree import ElementTree as ET

NS = {"s": "uri:ea.com:eala:asset"}
UNIT = "AlliedAntiVehicleVehicleTech3"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def record(element):
    """Preserve raw values, conditions, expressions and independent timelines."""
    return {"type": element.tag.rsplit("}", 1)[-1],
            "attributes": dict(element.attrib),
            "text": (element.text or "").strip(),
            "children": [record(child) for child in element]}


def resolve_audio(event, definitions, stack=()):
    if event in stack:
        raise ValueError("Audio reference cycle: " + " -> ".join((*stack, event)))
    if event not in definitions:
        return {"clips": [], "unresolved_events": [event]}
    node = definitions[event]
    clips = [(n.text or "").strip() for n in node.findall(".//s:Sound", NS)]
    missing = []
    for child in node.findall(".//s:Subsound", NS):
        result = resolve_audio((child.text or "").strip(), definitions, (*stack, event))
        clips.extend(result["clips"])
        missing.extend(result["unresolved_events"])
    return {"clips": sorted(set(filter(None, clips))), "unresolved_events": sorted(set(missing))}


def media_presence(names, files, extensions):
    result = {}
    for name in sorted(set(names)):
        matches = [str(p) for p in files if p.stem.casefold() == name.casefold()
                   and p.suffix.casefold() in extensions]
        result[name] = {"present": bool(matches), "paths": sorted(matches)}
    return result


def audio_graph(events, definitions):
    """Retain mixer, loop, pitch and delay metadata, including base events."""
    found = {}
    pending = list(events)
    while pending:
        name = pending.pop()
        if name in found or name not in definitions:
            continue
        node = definitions[name]
        found[name] = record(node)
        pending.extend((n.text or "").strip() for n in node.findall(".//s:Subsound", NS))
        parent = node.get("inheritFrom", "").split(":")[-1]
        if parent:
            pending.append(parent)
    return dict(sorted(found.items()))


def audit(sdk, repo):
    sources = {}

    def read(relative):
        path = sdk / relative
        sources[relative] = sha(path)
        return ET.parse(path).getroot()

    unit_root = read(f"SAGEXML/Allied/Units/{UNIT}.xml")
    unit = unit_root.find("s:GameObject", NS)
    collapse_root = read(f"SAGEXML/Allied/Props/{UNIT}_Collapse.xml")
    collapse = collapse_root.find("s:GameObject", NS)
    base = read("SAGEXML/BaseObjects/BaseCollapsingObject.xml")
    ocls = read("SAGEXML/GlobalData/ObjectCreationLists.xml")
    death_ocl = unit.find(".//s:CreateObjectDie", NS).get("CreationList")
    ocl = ocls.find(f"s:ObjectCreationList[@id='{death_ocl}']", NS)
    weapons = read("SAGEXML/GlobalData/Weapon.xml")
    weapon_rows = [w for w in weapons if w.get("id", "").startswith(UNIT)]
    scatter = read(f"SAGEXML/Allied/Props/{UNIT}CannonNode.xml")
    definitions = {}
    for name in ["Voice.xml", "Voice_RetailOnly.xml", "SoundEffects.xml", "BaseSoundEffect.xml"]:
        for node in read("SAGEXML/Sounds/" + name):
            if node.get("id") and node.tag.rsplit("}", 1)[-1] in {"AudioEvent", "Multisound"}:
                definitions[node.get("id")] = node
    audio_bindings = []
    # Retain the containing condition to distinguish USER_6 overrides and loops.
    for container in unit.iter():
        for child in container:
            event = child.get("Sound") or child.get("EnterStateSound")
            if event:
                audio_bindings.append({"context": container.tag.rsplit("}", 1)[-1],
                                       "condition": dict(container.attrib), **record(child), "event": event})
    for weapon in weapon_rows:
        if weapon.get("FireSound"):
            audio_bindings.append({"context": weapon.get("id"), "event": weapon.get("FireSound")})
    events = {b["event"]: resolve_audio(b["event"], definitions) for b in audio_bindings}
    clips = [clip for event in events.values() for clip in event["clips"]]
    # Only loose, usable media under the selected SDK. XML/cache IDs are not audio.
    files = [p.relative_to(sdk) for directory in [sdk / "Art", sdk / "Audio"]
             for p in directory.rglob("*") if p.is_file()]
    audio_files = media_presence(clips, files, {".wav", ".ogg", ".mp3", ".snr"})
    art_refs = sorted({n.get("source")[4:] for root in [unit_root, collapse_root]
                       for n in root.findall(".//s:Include", NS)
                       if n.get("source", "").startswith("ART:")})
    art = {name: sorted(str(p) for p in files if p.name.casefold() == name.casefold()) for name in art_refs}
    animations = [record(n) for n in unit.findall(".//s:AnimationState", NS)]
    game = repo / "iron_tide"
    errors = []
    visuals = json.loads((game / "data/ra3_mirage_visuals.json").read_text(encoding="utf-8"))
    for path, expected in visuals["source_sha256"].items():
        if sha(sdk / path) != expected:
            errors.append("SDK visual source changed: " + path)
    # Rebuild only XML-derived data, never original game/demo geometry.
    with tempfile.TemporaryDirectory(prefix="irontide-sdk-audit-") as temporary:
        generated = Path(temporary) / "visuals.json"
        subprocess.run([sys.executable, str(repo / "tools/ra3_mirage/extract_visual_rules.py"),
                        "--sdk", str(sdk), "--output", str(generated)], check=True,
                       capture_output=True, text=True)
        if json.loads(generated.read_text(encoding="utf-8")) != visuals:
            errors.append("Runtime visual data differs from SDK regeneration")
    presentation = game / "assets/ra3/mirage/presentation"
    provenance = json.loads((presentation / "presentation_provenance.json").read_text(encoding="utf-8"))
    for item in provenance["records"]:
        path = presentation / item["output"]
        if not path.is_file() or sha(path) != item["output_sha256"]:
            errors.append("Runtime presentation file missing/changed: " + item["output"])
    code = [*game.glob("scripts/units/ra3_*.gd"), game / "scripts/world/vehicle_tracks.gd"]
    resource_refs = set()
    for path in code:
        contents = path.read_text(encoding="utf-8")
        if "refs/ra3-" in contents:
            errors.append("Runtime depends on local reference inputs: " + path.name)
        resource_refs.update(re.findall(r'res://[^"\s]+\.(?:json|png|gdshader)', contents))
    for reference in sorted(resource_refs):
        if not (game / reference[6:]).is_file():
            errors.append("Missing runtime resource: " + reference)
    unresolved = sorted({name for event in events.values() for name in event["unresolved_events"]})
    native_missing = bool(unresolved) or any(not v["present"] for v in audio_files.values()) or any(not v for v in art.values())
    return {
        "schema": 1, "scope": "RA3 Mirage integration closeout; not the entire RA3 roster",
        "source_policy": "Official SDK XML and SDK loose media only; existing runtime resources verified without re-extraction",
        "status": "runtime_validation_failed" if errors else "native_media_incomplete" if native_missing else "sdk_inputs_present_not_runtime_acceptance",
        "source_sha256": sources,
        "audio": {"bindings": audio_bindings, "events": events, "sdk_media": audio_files,
                  "definitions": audio_graph(events, definitions), "unresolved_events": unresolved,
                  "runtime": "RA2 generic vehicle voices and weapon report remain; native audio not integrated"},
        "art_includes": art,
        "animation_states": animations,
        "death": {"creation_list": record(ocl), "collapse": record(collapse), "base": record(base),
                  "runtime": "generic impact; native COL rigid debris and burnt materials not integrated",
                  "timeline_note": "Draw lifetime, LifetimeUpdate and SlowDeath are separate modules; do not add them into a fabricated single duration"},
        "weapons": [record(w) for w in weapon_rows], "scatter_nodes": record(scatter),
        "disguise": record(unit.find(".//s:SpecialDisguiseUpdate", NS)),
        "runtime": {"errors": errors, "sdk_visual_regeneration_matches": not any("visual" in e for e in errors),
                    "presentation_files_verified": len(provenance["records"]),
                    "literal_resource_references_checked": sorted(resource_refs),
                    "visual_acceptance": "pending_user_visual_confirmation"},
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", type=Path, required=True)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--require-native-media", action="store_true",
                        help="Return exit 2 when SDK does not supply referenced media")
    args = parser.parse_args()
    result = audit(args.sdk.resolve(), args.repo.resolve())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    audio = result["audio"]["sdk_media"]
    print(json.dumps({"status": result["status"], "audio_clips": len(audio),
                      "missing_audio": sum(not v["present"] for v in audio.values()),
                      "missing_art_includes": sum(not v for v in result["art_includes"].values()),
                      "runtime_errors": result["runtime"]["errors"]}, ensure_ascii=False))
    if result["runtime"]["errors"]:
        return 1
    if args.require_native_media and result["status"] == "native_media_incomplete":
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
