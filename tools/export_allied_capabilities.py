"""Export scoped mechanics from a user supplied rulesmd.ini; no game assets bundled.

Usage: python tools/export_allied_capabilities.py <rulesmd.ini> <output.json>
The resulting file belongs in iron_tide/data/ra2/allied_capabilities.json (ignored).
"""
import hashlib
import json
import sys
from pathlib import Path


def extract(source):
    sections, current = {}, {}
    for line in source.decode("latin1").splitlines():
        line = line.split(";", 1)[0].strip()
        if line.startswith("[") and "]" in line:
            current = sections.setdefault(line[1:line.index("]")].upper(), {})
        elif "=" in line and not line.startswith("//"):
            key, value = line.split("=", 1)
            current[key.strip()] = value.strip()
    return sections


def build(source):
    sections = extract(source)
    units = "E1 GGI ENGINEER SPY GHOST TANY DOG ADOG SNIPE CLEG CCOMAND PTROOP FV MGTK DEST".split()
    buildings = "GACNST GAPOWR GAREFN GAOREP GAPILE GAWEAP GAAIRC GATECH GACSPH GAWEAT GASPYSAT".split()
    names = {"Comet", "SuperComet", "CometFragment", "SuperCometFragment", "MirageGunE"}
    for name in units:
        for key, value in sections[name].items():
            if key in ["Primary", "Secondary", "ElitePrimary", "EliteSecondary"] or key.startswith(("Weapon", "EliteWeapon")) and key[-1].isdigit():
                names.add(value)
    prefix = "YR_CAP_"
    def num(row, key, default=0):
        value = str(row.get(key, default))
        return float(value.rstrip("%")) / (100 if value.endswith("%") else 1)
    flag = lambda row, key: row.get(key, "no").lower() in ("yes", "true", "1")
    weapons, warheads, projectiles = {}, {}, {}
    armor = "none flak plate light medium heavy wood steel concrete special_1 special_2".split()
    for name in sorted(names):
        row = sections.get(name.upper())
        if not row or "Warhead" not in row:
            continue
        wh_id, pr_id = row["Warhead"], row["Projectile"]
        wh, pr = sections[wh_id.upper()], sections[pr_id.upper()]
        weapons[prefix + name] = dict(id=prefix + name, damage=num(row, "Damage"), rof=num(row, "ROF", 15),
            range=num(row, "Range"), min_range=num(row, "MinimumRange"), speed=num(row, "Speed"),
            burst=int(num(row, "Burst", 1)), projectile=prefix + pr_id, warhead=prefix + wh_id,
            report=row.get("Report", ""), anim=row.get("Anim", ""), ambient_damage=num(row, "AmbientDamage"), extra=row)
        verses = [float(v.strip().rstrip("%")) / 100 for v in wh.get("Verses", "100%," * 10 + "100%").split(",")]
        warheads[prefix + wh_id] = dict(id=prefix + wh_id, verses=dict(zip(armor, verses)),
            verses_raw=wh.get("Verses", ""), cell_spread=num(wh, "CellSpread"), percent_at_max=num(wh, "PercentAtMax", 1),
            prone_damage=num(wh, "ProneDamage", 0.5), inf_death=int(num(wh, "InfDeath")),
            anim_list=[v.strip() for v in wh.get("AnimList", "").split(",") if v.strip()], extra=wh)
        extra = pr.copy()
        if extra.get("ShrapnelWeapon"):
            extra["ShrapnelWeapon"] = prefix + extra["ShrapnelWeapon"]
        projectiles[prefix + pr_id] = dict(id=prefix + pr_id, aa=flag(pr, "AA"), image=pr.get("Image", "none"),
            inviso=flag(pr, "Inviso"), arcing=flag(pr, "Arcing"), shadow=flag(pr, "Shadow"), rot=num(pr, "ROT"), extra=extra)
    general_keys = "ChronoDistanceFactor ChronoTrigger ChronoMinimumDelay ChronoRangeMinimum SpyPowerBlackout SpyMoneyStealPercent C4Delay InfantryBlinkDisguiseTime".split()
    return dict(version=1, source_sha256=hashlib.sha256(source).hexdigest(),
        units={key: sections[key] for key in units}, buildings={key: sections[key] for key in buildings},
        general={key: sections["GENERAL"][key] for key in general_keys if key in sections["GENERAL"]},
        weapons=weapons, warheads=warheads, projectiles=projectiles)


if __name__ == "__main__":
    source, output = map(Path, sys.argv[1:])
    result = build(source.read_bytes())
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf8")
    print(f"Exported {len(result['weapons'])} weapons; source SHA256 {result['source_sha256']}")
