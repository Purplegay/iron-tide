# Frozen v0.30.46 function: independent before-change oracle.
extends Unit
func _weapon_uses_hull() -> bool:
	# Native RA3 fixed hardpoint is independent of the legacy RA2 data marker.
	if Ra3Mirage.handles(self) or (unit_id == "R3APOC" and special.get("soviet_mode", false)): return true
	if unit_id in ["R3HARBINGER", "ZEP"] or (unit_id == "SCHP" and _deployed): return false
	if is_air or unit_id in ["DLPH", "SUB"]:
		return true
	return data.get("ra2", false) == true and not weapon.is_empty() \
		and not is_air and not is_naval and not is_harvester and _mv("turret", false) != true
