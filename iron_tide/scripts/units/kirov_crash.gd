extends RefCounted
## A falling hull is saved as a projectile, separate from the dead combat unit.
const UnitFlight = preload("res://scripts/units/unit_flight.gd")
const Rules = preload("res://scripts/core/yr_death_rules.gd")
const Blast = preload("res://scripts/core/yr_death_combat.gd")
const Debris = preload("res://scripts/core/yr_vehicle_debris.gd")
const Fx = preload("res://scripts/core/yr_death_fx.gd")

static func begin(unit) -> void:
	var world = unit._battle_world()
	if world == null: return
	var row := Rules.type_data("ZEP")
	var wreck := Projectile.new()
	var weapon: Dictionary = unit._weapon_for_target(null)
	wreck.owner_side = unit.side
	wreck.position = unit.position
	wreck.front_color = unit._col
	wreck.splinters = {"kirov_crash":true, "height":unit._visual_lift(), "start_height":unit._visual_lift(),
		"heading":unit.hull_angle, "radius":unit.radius, "age":0.0,
		"warhead":weapon.ra2_warhead, "damage":CombatMath.with_offense(float(weapon.damage),unit.bonuses) * float(row.get("deathweapondamagemodifier",1))}
	wreck.visible = world.position_visible_to("ally", wreck.position)
	world.projectiles_root.add_child(wreck)
	if world.position_visible_to("ally",wreck.position):
		Ra2Sfx.play(row.voicecrashing,wreck.position,true)
		Ra2Sfx.play(row.crashingsound,wreck.position)

static func tick(wreck, delta: float) -> void:
	var world = wreck.get_parent().get_parent()
	if wreck._detonated or wreck.is_queued_for_deletion() or world.paused or world.ended or world.get_tree().paused: return
	var state: Dictionary = wreck.splinters
	var row := Rules.type_data("ZEP")
	var speed := float(row.jumpjetcrash) * 2.0 * UnitFlight.TICKS * UnitFlight.HEIGHT_PIXEL
	var step := minf(delta, float(state.height) / speed)
	# Jumpjet crash behaviour: lose altitude in place and yaw six degrees each rule tick.
	state.heading = wrapf(float(state.heading) - deg_to_rad(6.0) * UnitFlight.TICKS * step,-PI,PI)
	state.age += step
	state.height = maxf(0.0, float(state.height) - speed * delta)
	wreck.visible = world.position_visible_to("ally", wreck.position)
	wreck.queue_redraw()
	if state.height > 0.0: return
	wreck._detonated = true
	# A wreck saved before weapon capture carries the original ordinary payload.
	var fallback: Dictionary = Rules.data().weapons[str(row.primary).to_upper()]
	var damage := float(state.get("damage",fallback.damage))
	var warhead := str(state.get("warhead",fallback.warhead))
	Blast.queue_blast(world,wreck.position,wreck.owner_side,damage,warhead,"",true)
	Debris.spawn_at(world,row,wreck.position,wreck.owner_side,0.0,false)
	if wreck.visible:
		Fx.play(world,wreck.position,Rules.names(row,"explosion").pick_random())
		var sound: String = preload("res://scripts/world/special_rules.gd").data().lighting.impactwatersound if world.in_water_world(wreck.position) else row.impactlandsound
		Ra2Sfx.play(sound,wreck.position)
	wreck.queue_free()

static func draw(wreck) -> void:
	var state: Dictionary = wreck.splinters
	var hull := RA2Art.art("ZEP")
	if hull.is_empty(): return
	var heading: float = state.heading
	var progress := 1.0 - float(state.height) / maxf(0.01, float(state.start_height))
	var facing := posmod(RA2Art.facing_index(heading,hull.facings) + int(hull.facing_offset), int(hull.facings))
	var rect := RA2Art.draw_rect(hull,state.radius,range(int(hull.facings)))
	var shadow := RA2Art.art("ZEP_shd")
	Iso.begin(wreck)
	if not shadow.is_empty():
		wreck.draw_texture_rect_region(shadow.tex,rect,RA2Art.src_rect(shadow,facing),Color(0,0,0,0.45))
	var bank := 0.55 * progress * Iso.dir(Vector2.from_angle(heading)).normalized().x
	var center := rect.get_center()
	var pose := Transform2D(bank,center - center.rotated(bank) + Vector2(0,-float(state.height)))
	wreck.draw_set_transform_matrix(Transform2D(Iso.eff_angle(),Iso.up(),0.0,Vector2.ZERO) * pose)
	wreck.material = HouseColor.material_for(wreck.front_color)
	RA2Art.begin_detail_draw(wreck)
	RA2Art.draw_sprite(wreck,hull,rect,RA2Art.src_rect(hull,facing),RA2Art.sprite_grade(hull))
	var fire := RA2Art.fx("FIRE01")
	if not fire.is_empty():
		var frame := posmod(int(float(state.age)*fire.fps),int(fire.count))
		wreck.draw_texture_rect_region(fire.tex,Rect2(center-Vector2(fire.cell.x*0.5,fire.cell.y*0.8),fire.cell),RA2Art.fx_rect(fire,frame))
