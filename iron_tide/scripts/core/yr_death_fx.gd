extends Node2D
## Original SHP media and rates; ballistic paths are a bounded Godot adaptation.
const Rules = preload("res://scripts/core/yr_death_rules.gd")
var world
var art: Dictionary = {}
var texture: Texture2D
var age := 0.0
var frame := 0
var velocity := Vector2.ZERO
var lift := 0.0
var vertical_speed := 0.0
var debris := false
var expiry := ""
var fps := 15.0
var playback: Array[int] = []
static var visual_rng := RandomNumberGenerator.new()
const IDLE_LIMIT := 64
var retiring := false

func retire() -> void:
	if retiring: return
	retiring = true
	set_process(false)
	hide()
	remove_from_group("yr_death_effects")
	park.call_deferred()

func park() -> void:
	if is_queued_for_deletion() or not is_instance_valid(world) or world.is_queued_for_deletion():
		queue_free(); return
	var idle = world.get_node_or_null("__IdleDeathEffects")
	if idle == null:
		idle = Node.new()
		idle.name = "__IdleDeathEffects"
		world.add_child(idle)
	if idle.get_child_count() >= IDLE_LIMIT:
		queue_free(); return
	reparent(idle,false)
	texture = null
	art = {}
	playback.clear()

static func play(world, point: Vector2, id: String, flying := false):
	var entry: Dictionary = Rules.data().animations.get(id.to_upper(), {})
	if entry.is_empty() or world == null: return null
	var idle = world.get_node_or_null("__IdleDeathEffects")
	var fx
	if idle != null and idle.get_child_count() > 0:
		fx = idle.get_child(-1)
		idle.remove_child(fx)
		fx.retiring = false
		fx.age = 0.0
		fx.lift = 0.0
		fx.vertical_speed = 0.0
		fx.velocity = Vector2.ZERO
		fx.expiry = ""
		fx.transform = Transform2D.IDENTITY
		fx.set_process(true)
	else:
		fx = load("res://scripts/core/yr_death_fx.gd").new()
	fx.world = world; fx.art = entry
	fx.texture = load("res://assets/ra2/death/" + id.to_upper() + ".png")
	fx.position = point; fx.debris = flying; fx.fps = maxf(1.0, float(entry.fps))
	var raw: Dictionary = entry.raw
	var count := int(entry.count)
	if Rules.flag(raw, "isflamingguy"):
		# 8 directional running strips, then shared collapse/burn-out, no shadow half.
		var run := int(raw.get("runningframes", 6))
		var facing := visual_rng.randi_range(0, 7)
		fx.playback.assign(range(facing * run, (facing + 1) * run))
		fx.playback.append_array(range(run * 8, count))
	else:
		var begin := clampi(int(raw.get("loopstart", 0)), 0, count - 1)
		var end := clampi(int(raw.get("loopend", count - 1)), begin, count - 1)
		fx.playback.assign(range(0, begin))
		for i in clampi(int(raw.get("loopcount", 1)), 1, 32): fx.playback.append_array(range(begin, end + 1))
		fx.playback.append_array(range(end + 1, count))
	fx.frame = fx.playback[0]
	fx.z_as_relative = false; fx.z_index = DepthLayers.FX
	if flying:
		# Native velocities are leptons/tick; this game uses 55 px/cell, 15 ticks/s.
		var units := 55.0 / 256.0 * 15.0
		fx.velocity = Vector2.from_angle(visual_rng.randf_range(0.0, TAU)) * visual_rng.randf_range(0.35, 1.0) * float(raw.get("maxxyvel", 25)) * units
		fx.vertical_speed = float(raw.get("minzvel", 20)) * units
		fx.lift = 12.0
		fx.expiry = str(raw.get("expireanim", "")).to_upper()
		var rates := str(raw.get("randomrate", "220,600")).split(",")
		fx.fps = visual_rng.randf_range(float(rates[0]), float(rates[-1])) / 60.0
	world.effects_root.add_child(fx)
	fx.add_to_group("yr_death_effects")
	fx.visible = world.position_visible_to("ally", point)
	if fx.visible and not flying and not str(entry.sound).is_empty(): Ra2Sfx.play(str(entry.sound), point)
	return fx

static func destroyed(actor, point := Vector2.INF) -> bool:
	var world = actor.battle if actor is Building else actor._battle_world()
	var id: String = actor.building_id if actor is Building else actor.unit_id
	var row := Rules.type_data(id)
	if row.is_empty() or row.native_category == "InfantryTypes": return false
	var explosions := Rules.names(row, "explosion")
	var played := false
	if not explosions.is_empty():
		var fx = play(world, point if point.is_finite() else actor.global_position, explosions[visual_rng.randi_range(0, explosions.size()-1)])
		played = fx != null
		if played and actor is Unit and actor.is_air:
			fx.lift = actor._visual_lift()
	# Destruction debris now has saved physics/damage records in yr_vehicle_debris.
	return played

func _process(delta: float) -> void:
	if not is_instance_valid(world): queue_free(); return
	if world.paused or world.ended: return
	age += delta
	var count := int(art.count)
	if debris:
		position += velocity * delta
		vertical_speed -= 160.0 * delta
		lift += vertical_speed * delta
		if lift <= 0.0 or age >= 5.0:
			if not expiry.is_empty(): play(world, position, expiry)
			retire(); return
		frame = posmod(int(age * fps), count)
	else:
		var phase := int(age * fps)
		if phase >= playback.size(): retire(); return
		frame = playback[phase]
	visible = world.position_visible_to("ally", position)
	queue_redraw()

func _draw() -> void:
	if texture == null or frame >= art.rects.size(): return
	Iso.begin(self)
	var rect: Dictionary = art.rects[frame]
	var size := Vector2(float(art.cell[0]), float(art.cell[1]))
	draw_texture_rect_region(texture, Rect2(-size * 0.5 - Vector2(0, lift), size), Rect2(float(rect.x), float(rect.y), float(rect.w), float(rect.h)))
