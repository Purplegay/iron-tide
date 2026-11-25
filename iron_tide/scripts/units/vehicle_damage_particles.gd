extends RefCounted

const Rules = preload("res://scripts/world/special_rules.gd")
const DeathRules = preload("res://scripts/core/yr_death_rules.gd")
static var yellow := str(Rules.data().lighting.conditionyellow).trim_suffix("%").to_float() / 100.0
static var red := str(Rules.data().lighting.conditionred).trim_suffix("%").to_float() / 100.0

# YR uses the same pair of particle systems on the Kirov and surface warships.
static func configured(unit) -> bool:
	if unit.unit_id != "ZEP" and not unit.is_naval: return false
	var systems := DeathRules.names(DeathRules.type_data(unit.unit_id), "damageparticlesystems")
	return "SPARKSYS" in systems and "SMALLGREYSSYS" in systems

static func stage(unit) -> int:
	if not unit._has_damage_particles or unit._dead or unit.hp <= 0.0 or unit.hp > unit.max_hp * yellow: return 0
	return 2 if unit.hp <= unit.max_hp * red else 1

static func draw(unit) -> void:
	var severity := stage(unit)
	if severity == 0 or not unit._body_bounds.has_area(): return
	var smoke := RA2Art.fx("SGRYSMK1")
	if smoke.is_empty(): return
	var bounds: Rect2 = unit._body_bounds
	var forward := Iso.dir(Vector2.RIGHT.rotated(unit.hull_angle)).normalized()
	var time: float = unit._anim + float(unit._seed % 53) * 0.1
	for vent in severity:
		var offset := forward * (-0.23 if vent == 0 else 0.16) * bounds.size
		var origin := bounds.get_center() + offset - Vector2(0.0, bounds.size.y * 0.16)
		var count := 7 if severity == 2 else 4
		for i in count:
			var progress := fposmod(time * 0.45 + float(i) / count + vent * 0.23, 1.0)
			var frame := mini(int(progress * smoke.count), int(smoke.count) - 1)
			var drift := Vector2((8.0 + 4.0 * sin(time + i)) * progress, -progress * (54.0 if severity == 2 else 32.0))
			var size: Vector2 = smoke.cell * lerpf(0.85, 1.65, progress)
			var shade := lerpf(0.50 if severity == 2 else 0.80, 1.0, progress)
			unit.draw_texture_rect_region(smoke.tex, Rect2(origin + drift - size * 0.5, size),
				RA2Art.fx_rect(smoke, frame), Color(shade, shade, shade, 0.78 * (1.0 - progress * 0.75)))
		var flash := fposmod(time * 1.7 + vent * 0.41, 1.0)
		if flash < 0.32:
			for n in 3:
				var direction := Vector2.from_angle(-PI * (0.2 + 0.3 * n))
				var tip := origin + direction * (3.0 + flash * 30.0)
				unit.draw_line(tip - direction * 3.0, tip, Color(1, 0.9 - flash, 0.52, 1.0 - flash), 1.4)
