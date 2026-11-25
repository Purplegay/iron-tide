extends RefCounted
## RA3-style healing feedback. Only successful HP gains emit a short visual pulse.
## Metadata is transient: it never changes healing, charges, orders or save data.
const PULSE := &"healing_indicator_visual"
const DURATION := 1.15 # Bridges the existing 0.96s repair-depot ticks.
const Cooldown = preload("res://scripts/ui/attack_cooldown_indicator.gd")

static func eligible(unit) -> bool:
	if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit._dead or unit.hp <= 0.0:
		return false
	if unit.embarked_in != null or not unit.is_visible_in_tree(): return false
	var world = unit._battle_world()
	return world == null or world.actor_visible_to("ally", unit)

static func gained(unit, previous_hp: float) -> void:
	if unit.hp > previous_hp and eligible(unit): unit.set_meta(PULSE, DURATION)

static func tick(unit, delta: float) -> void:
	if not unit.has_meta(PULSE): return
	if not eligible(unit):
		unit.remove_meta(PULSE)
		return
	var world = unit._battle_world()
	if unit.get_tree().paused or (world != null and (world.paused or world.ended)): return
	var left := maxf(0.0, float(unit.get_meta(PULSE)) - maxf(0.0, delta))
	if left <= 0.0: unit.remove_meta(PULSE)
	else: unit.set_meta(PULSE, left)

static func alpha(unit) -> float:
	# No pulse means nothing to draw. Avoid another fog/concealment query for
	# every ordinary unit redraw when no successful heal has occurred.
	if not unit.has_meta(PULSE): return 0.0
	if not eligible(unit): return 0.0
	return clampf(float(unit.get_meta(PULSE, 0.0)) / 0.2, 0.0, 1.0)

static func screen_center(unit, canvas: Node2D) -> Vector2:
	# Keep the health bar's upper-right slot, above the attack-cooldown circle.
	return (Cooldown.screen_center(unit, canvas) + Vector2(0, -18)).round()

static func paint(unit, canvas: Node2D) -> void:
	var opacity := alpha(unit)
	if opacity <= 0.0: return
	var center := screen_center(unit, canvas)
	canvas.draw_set_transform_matrix(canvas.get_global_transform_with_canvas().affine_inverse())
	canvas.draw_circle(center, 8.0, Color(0.02, 0.08, 0.04, opacity * 0.88))
	var green := Color(0.35, 1.0, 0.48, opacity)
	canvas.draw_rect(Rect2(center + Vector2(-6, -2), Vector2(12, 4)), green)
	canvas.draw_rect(Rect2(center + Vector2(-2, -6), Vector2(4, 12)), green)
	Iso.begin(canvas)
