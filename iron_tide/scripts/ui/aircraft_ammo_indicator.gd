extends RefCounted
## Read-only projection of UnitLogistics; no separate timer or saved state.
const PIP := preload("res://assets/ra2/pips/ammo.png")
const PIP_SIZE := Vector2(6, 13)

static func state(unit) -> Dictionary:
	if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit._dead or unit.hp <= 0.0:
		return {}
	if unit.side != "ally" or not unit.is_air or unit.embarked_in != null or not unit.is_visible_in_tree(): return {}
	var logistics: UnitLogistics = unit.logistics
	if logistics.ammo_max <= 0: return {}
	var count := clampi(logistics.ammo, 0, logistics.ammo_max)
	var status: String = {"flying": "飞行", "returning": "返航", "parked": "待机"}.get(logistics.air_state, "")
	var progress := 0.0
	var rearming := logistics.air_state == "rearming" and count < logistics.ammo_max
	if preload("res://scripts/units/peregrine.gd").active(unit):
		progress=clampf(float(unit.special.peregrine.get("progress",0)),0,1)
		rearming=count<logistics.ammo_max
		var paused:bool=unit._stun_timer>0 or AlliedAbilities.frozen(unit) or unit.special.has("hero_wreck")
		status=("空中补弹暂停" if paused else "空中补弹 %d%%"%int(progress*100)) if rearming else "满弹待命"
		return {"ammo":count,"max":logistics.ammo_max,"status":status,"progress":progress,"rearming":rearming}
	if rearming:
		var seconds := maxf(0.01, float(GameData.ra2_general.get("aircraft", {}).get("reload_minutes", 0.3)) * 60.0)
		progress = clampf(logistics.reload_elapsed / seconds, 0.0, 1.0)
		var world = unit._battle_world()
		var home = logistics.home
		var blocked: bool = not is_instance_valid(home) or home.hp <= 0.0 or home.side != unit.side
		if not blocked: blocked = not home.is_operational() or (world != null and world.side_power_low(unit.side))
		status = "补弹暂停" if blocked else "补弹 %d%%" % int(progress * 100.0)
	elif logistics.air_state == "returning" and not is_instance_valid(logistics.home):
		status = "等待机场"
	elif count == 0 and logistics.air_state == "flying":
		status = "空弹"
	return {"ammo": count, "max": logistics.ammo_max, "status": status, "progress": progress, "rearming": rearming}


static func visible_pips(unit) -> int:
	if not is_instance_valid(unit) or not (unit.selected or unit.hovered): return 0
	var info := state(unit)
	if info.is_empty(): return 0
	return int(info.ammo)

static func screen_origin(unit, canvas: Node2D) -> Vector2:
	var camera := canvas.get_viewport().get_camera_2d()
	var zoom: float = camera.zoom.x if camera != null else 1.0
	var point := canvas.get_global_transform_with_canvas() * canvas.to_local(unit.presentation_position())
	var bar: Rect2 = unit.hp_bar_rect()
	return (point + Vector2(bar.position.x, bar.end.y) * zoom + Vector2(0.0, 3.0)).round()

static func paint(unit, canvas: Node2D) -> void:
	var count := visible_pips(unit)
	if count <= 0: return
	var origin := screen_origin(unit, canvas)
	canvas.draw_set_transform_matrix(canvas.get_global_transform_with_canvas().affine_inverse())
	var previous_filter := canvas.texture_filter
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in count:
		canvas.draw_texture(PIP, origin + Vector2(i * PIP_SIZE.x, 0))
	canvas.texture_filter = previous_filter
	Iso.begin(canvas)
