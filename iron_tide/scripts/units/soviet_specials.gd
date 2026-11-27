extends RefCounted
## Soviet YR special weapons. Actor timers and area effects use the existing snapshot dictionaries.
const Rules = preload("res://scripts/core/yr_death_rules.gd")
const NativeRules = preload("res://scripts/world/special_rules.gd")
const Death = preload("res://scripts/core/yr_death_combat.gd")
const SILO_OFFSET := Vector2(0,-22) # artmd NAMISL PrimaryFirePixelOffset=0,44 projected at 2:1.
const HEIGHT_PIXEL := preload("res://scripts/units/unit_flight.gd").HEIGHT_PIXEL
const RadField=preload("res://scripts/world/radiation_field.gd")
const Growth=preload("res://scripts/units/radiation_growth.gd")
const CELL := Ra2Damage.PX_PER_CELL
const IRON_RADIUS := 1.4 * CELL
const TPS := 15.0

static func radiation_rules() -> Dictionary:
	return GameData.raw_docs["yr_soviet.json"].radiation

static func organic(target) -> bool:
	return target is Unit and (AlliedAbilities.infantry(target) or Rules.flag(Rules.type_data(target.unit_id), "organic"))

static func add_radiation(world, point: Vector2, cells: float, level: float, side: String, emitter=null, superweapon_scale := 1.0) -> void:
	var rules := radiation_rules()
	level = minf(level, rules.max_level)
	var duration: float = level * rules.duration / TPS
	if not world.allied_state.has("rad_sites"): world.allied_state.rad_sites = []
	for site in world.allied_state.rad_sites:
		# Keep boosted fallout separate so nearby Desolators cannot inherit its damage.
		if site.side == side and is_equal_approx(float(site.get("superweapon_scale", 1.0)), superweapon_scale) and site.point.distance_squared_to(point) < CELL * CELL * 0.25:
			site.left = maxf(site.left, duration)
			site.level = maxf(site.level, level)
			site.radius = maxf(site.radius, cells * CELL)
			site.base_radius = maxf(float(site.get("base_radius",site.radius)),cells*CELL)
			normalize_radiation_training(site)
			site.training_damage = maxf(float(site.get("training_damage",1.0)), Unit.Training.radiation_damage(emitter) if is_instance_valid(emitter) and emitter.unit_id == "DESO" else 1.0)
			Growth.register(site,emitter,cells*CELL)
			sync_radiation(world)
			return
	var site:={"point":point, "radius":cells * CELL, "level":level, "left":duration, "pulse":rules.interval, "side":side}
	site.base_radius=cells*CELL
	site.training_damage = Unit.Training.radiation_damage(emitter) if is_instance_valid(emitter) and emitter.unit_id == "DESO" else 1.0
	site.radiation_training_version=1
	site.superweapon_scale = superweapon_scale
	Growth.register(site,emitter,cells*CELL)
	world.allied_state.rad_sites.append(site)
	sync_radiation(world)

static func end_sampling(unit) -> void:
	Growth.clear(unit)

static func normalize_radiation_training(site:Dictionary) -> void:
	# Old fields stored +6% per level. Convert once to +0.6%, including saved live fields.
	if not site.has("radiation_training_version"):
		site.training_damage=1.0+clampf((float(site.get("training_damage",1.0))-1.0)*0.1,0.0,0.12)
		site.radiation_training_version=1
	site.training_damage=clampf(float(site.get("training_damage",1.0)),1.0,1.12)
	site.erase("samplers")

static func radiation_susceptible(unit) -> bool:
	if not unit is Unit or unit.embarked_in != null or unit.is_air_target() or unit.data.get("immune_to_radiation", false): return false
	var row := Rules.type_data(unit.unit_id)
	return not Rules.flag(row, "immunetoradiation") and not Rules.flag(row, "isimmunetoradiation")

static func tick_world(world, delta: float) -> void:
	if world.paused or world.ended or world.get_tree().paused: return
	var sites: Array = world.allied_state.get("rad_sites", [])
	for site in sites.duplicate():
		normalize_radiation_training(site)
		Growth.refresh(site)
		var rules := radiation_rules()
		var elapsed := minf(delta, site.left)
		var next: float = site.pulse
		while next <= elapsed:
			var damage_level: float = RadField.level_at(site,float(rules.duration)/TPS,float(rules.level_delay)/TPS,next)
			for unit in world.units.duplicate():
				if not world.actor_alive(unit) or not radiation_susceptible(unit): continue
				var reach: float = unit.position.distance_to(site.point) / site.radius
				if reach >= 1.0: continue
				var damage: float = ceilf(damage_level * (1.0 - reach)) * rules.factor * float(site.get("training_damage",1.0)) * float(site.get("superweapon_scale", 1.0))
				unit.receive_hit(damage * GameData.ra2_verse(rules.warhead, unit.ra2_armor), "radiation", {}, null, rules.warhead)
			next += float(rules.interval)
		site.pulse = next - elapsed
		site.left -= elapsed
		if site.left <= 0.0: sites.erase(site)
	if world.allied_state.has("rad_sites"):
		if sites.is_empty(): world.allied_state.erase("rad_sites")
		sync_radiation(world)
	var launches: Array = world.allied_state.get("soviet_nukes", [])
	for launch in launches.duplicate():
		var before: float = launch.left
		launch.left -= delta
		if launch.left > 0:
			if launch.has("rise") and launch.left>launch.fall and floori(before*TPS/4)!=floori(launch.left*TPS/4) and world.position_visible_to("ally",launch.origin):
				var pose := missile_pose(launch)
				if pose.lift < world.get_viewport_rect().size.y:
					var smoke = Ra2Fx.play(world.effects_root,pose.point,"NUKEPUFF")
					if smoke != null: smoke.draw_offset = SILO_OFFSET + Vector2.UP * float(pose.lift)
			continue
		launches.erase(launch)
		var payload: Dictionary = Rules.data().weapons.NUKEPAYLOAD
		if world.fog != null: world.fog.reveal_superweapon_impact(launch.point,Ra2Damage.cells(payload.warhead)*CELL)
		if world.position_visible_to("ally",launch.point): Ra2Fx.play(world.effects_root,launch.point,"NUKEBALL")
		var damage_scale: float = launch.get("damage_scale", 1.0)
		Death.queue_blast(world, launch.point, launch.side, float(payload.damage) * damage_scale, payload.warhead, str(payload.get("report","")))
		if not launch.get("no_radiation",false):add_radiation(world, launch.point, Ra2Damage.cells(payload.warhead), float(payload.radlevel), launch.side, null, damage_scale)
	if launches.is_empty(): world.allied_state.erase("soviet_nukes")

static func sync_radiation(world) -> void:
	var rules := radiation_rules()
	RadField.sync(world,float(rules.duration)/TPS,rules.max_level,float(rules.level_delay)/TPS)

# The vertical, non-homing nuke accelerates in native leptons each rule tick.
# Both stages meet at the carrier's detonation height above the target tile.
static func ascent_ticks(height: float, accel: float) -> int:
	return ceili(sqrt(2.0 * height / accel + 0.25) - 0.5)

static func launch_record(source, point: Vector2) -> Dictionary:
	var rules: Dictionary = GameData.raw_docs["yr_strategic_fx.json"].flight
	var up: Dictionary = rules[rules.NukeCarrier.projectile]
	var down: Dictionary = rules[Rules.data().weapons.NUKEPAYLOAD.projectile]
	var height := float(up.detonationaltitude)
	var up_time := ascent_ticks(height, float(up.acceleration)) / TPS
	var down_time := ascent_ticks(height, float(down.acceleration)) / TPS
	return {"origin":source.position,"point":point,"side":source.side,"house":source._col,"height":height,"rise":up_time,"fall":down_time,"left":up_time+down_time,"damage_scale":preload("res://scripts/rules/superweapon_damage.gd").nuke_multiplier(source.side)}

static func missile_pose(launch: Dictionary) -> Dictionary:
	if not launch.has("origin"):
		# Existing saves retain their old impact deadline and descent.
		return {"point":launch.point,"lift":170.0*float(launch.left),"image":"NKMSLDN","show":launch.left<=1.0}
	var rising: bool = launch.left > launch.fall
	var duration: float = launch.rise if rising else launch.fall
	var age: float = launch.rise+launch.fall-launch.left if rising else launch.fall-launch.left
	var ticks := clampf(age/duration,0,1)*duration*TPS
	var total := duration*TPS
	var fraction := ticks*(ticks+1.0)/(total*(total+1.0))
	var height: float = launch.height * (fraction if rising else 1.0-fraction)
	return {"point":launch.origin if rising else launch.point,"lift":height*HEIGHT_PIXEL,"image":"NKMSLUP" if rising else "NKMSLDN","show":true}

static func draw_missiles(canvas: Node2D, world) -> void:
	for launch in world.allied_state.get("soviet_nukes", []):
		var pose := missile_pose(launch)
		if not pose.show or not world.position_visible_to("ally",pose.point): continue
		var art := RA2Art.fx("SILO_MISSILES")
		if art.is_empty(): continue
		var rising: bool = pose.image=="NKMSLUP"
		var size: Vector2 = art.cell
		var foot := Iso.dir(pose.point) + Vector2.UP * float(pose.lift)
		if rising: foot += SILO_OFFSET
		var rect := Rect2(foot-Vector2(size.x*0.5,size.y),size)
		var frame := 0 if rising else 2
		canvas.draw_texture_rect_region(art.tex,rect,RA2Art.fx_rect(art,frame))
		var house: Color = launch.get("house",HouseColor.color_for_side(launch.side,"#ff5b4a"))
		canvas.draw_texture_rect_region(art.tex,rect,RA2Art.fx_rect(art,frame+1),house)

static func target_radius(type: String) -> float:
	match type:
		"IronCurtain": return IRON_RADIUS
		"MultiMissile": return Ra2Damage.cells(Rules.data().weapons.NUKEPAYLOAD.warhead) * CELL
	return 0.0

static func can_aim_at(source, point: Vector2) -> bool:
	var world = source.battle
	return Rect2(Vector2.ZERO,Vector2.ONE * world.map_size).has_point(point) and world.position_explored_by(source.side,point)

static func superweapon(source, point: Vector2) -> bool:
	var world = source.battle
	if source.sw_type().to_lower() != "spyplane" and not can_aim_at(source,point): return false
	if source.sw_type().to_lower() == "spyplane":
		var enter_x := 0.0 if point.x < world.map_size * 0.5 else float(world.map_size)
		var plane = world.spawn_unit("SPYP", source.side, Vector2(enter_x, point.y))
		if plane == null: return false
		plane.special.spy_point = point
		plane.special.spy_exit = Vector2(world.map_size - enter_x, point.y)
		plane.logistics.air_lift = 1.0
		return true
	if source.sw_type().to_lower() == "multimissile":
		if not world.allied_state.has("soviet_nukes"): world.allied_state.soviet_nukes = []
		world.allied_state.soviet_nukes.append(launch_record(source,point))
		return true
	var hit := false
	for target in world.units.duplicate() + world.buildings.duplicate():
		if not world.actor_alive(target) or (target is Unit and (target.embarked_in != null or target.is_air_target())): continue
		var dist: float = target.position.distance_to(point)
		if target is Building: dist -= target.footprint_clearance(target.position.direction_to(point))
		if dist > IRON_RADIUS: continue
		hit = true
		if organic(target):
			target.hp = 0
			target._die(source)
		else:
			target.special.iron_left = float(Rules.data().combat.ironcurtainduration) / TPS
			sync_tint(target)
			target.queue_redraw()
	if hit and world.position_visible_to("ally",point):
		Ra2Fx.play(world.effects_root,point,str(Rules.data().general.ironcurtaininvokeanim))
	return hit

## One native deflection animation per struck target; simultaneous hits still all lose their damage.
static func deflect_hit(actor, damage: float) -> void:
	if damage <= 0.0 or actor._dead: return
	var world = actor.battle if actor is Building else actor._battle_world()
	if world == null or not world.actor_visible_to("ally",actor): return
	var previous = actor.get_meta("iron_deflection") if actor.has_meta("iron_deflection") else null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion(): return
	var effect = Ra2Fx.play(world.effects_root, actor.art_center(), str(Rules.data().general.weaponnullifyanim))
	if effect != null:
		effect.tint.a = 0.5
		actor.set_meta("iron_deflection",effect)

static func fly_scout(plane, delta: float) -> void:
	var world = plane._battle_world()
	if delta <= 0.0 or world.paused or world.ended or world.get_tree().paused: return
	plane._anim += delta
	var exit_point: Vector2 = plane.special.spy_exit
	var start: Vector2 = plane.position
	plane.hull_angle = start.direction_to(exit_point).angle()
	plane.position = start.move_toward(exit_point, plane.move_speed * delta)
	var seen: bool = world.actor_visible_to("ally",plane)
	if seen: Ra2Sfx.start_attached_loop(plane,"SpyEngine","spy_engine_audio","SpyPlaneMoveLoop")
	var engine = plane.get_node_or_null("SpyEngine")
	if engine != null: engine.stream_paused = not seen
	if plane.special.has("spy_point"):
		var camera: Dictionary = plane.data.recon_camera
		var period := float(preload("res://scripts/world/special_rules.gd").data().lighting.spyplanecameraframes) / TPS
		var next: float = plane.special.get("spy_camera_delay",0.0)
		var flight_time := minf(delta,start.distance_to(exit_point)/maxf(1.0,plane.move_speed))
		while next <= flight_time:
			var photo: Vector2 = start.move_toward(exit_point,plane.move_speed * next)
			if photo.distance_to(plane.special.spy_point) <= float(camera.range):
				plane.special.spy_photo = photo
				if world.fog != null: world.fog._reveal(plane.side,photo,float(camera.radius))
				if plane.side=="ally" or world.position_visible_to("ally",photo):
					Effects.spawn_flash(photo,13,Color(0.90,0.96,1.0),RA2Art.art_dir(Vector2(0,-plane._visual_lift())))
					Ra2Sfx.play(str(camera.sound),photo)
			else: plane.special.erase("spy_photo")
			next += period
		plane.special.spy_camera_delay = next - flight_time
	if plane.position.is_equal_approx(exit_point):
		AlliedAbilities.consume(plane)
	else: plane.queue_redraw()

static func tick_actor(actor, delta: float) -> void:
	if actor.special.has("airstrike_mark"): _advance_mark(actor, delta)
	if actor.special.has("airstrike_left"):
		actor.special.airstrike_left -= delta
		if actor.special.airstrike_left <= 0: actor.special.erase("airstrike_left")
	if actor.special.has("iron_left"):
		actor.special.iron_left -= delta
		if actor.special.iron_left <= 0: actor.special.erase("iron_left")
		sync_tint(actor)
		actor.queue_redraw()
	if actor.special.has("ivan_bomb"):
		var bomb: Dictionary = actor.special.ivan_bomb
		bomb.left -= delta
		if bomb.left <= 0: remove_bomb(actor,true)
		elif actor.is_visible_in_tree(): Ra2Sfx.start_ivan_tick(actor)
		else: Ra2Sfx.stop_ivan_tick(actor)
		actor.queue_redraw()

static func sync_tint(actor) -> void:
	var color := Color.WHITE
	if actor.special.has("airstrike_mark"):
		var mark: Dictionary = actor.special.airstrike_mark
		var strength := lerpf(0.25,0.78,1.0-float(mark.left)/float(mark.duration))
		color = Color(1.0+strength,1.0-strength,1.0-strength)
	if actor.special.has("iron_left"):
		# IronCurtainColor=0. Preserve separate force-shield/completion self_modulate.
		var brightness := 0.28 + 0.18*cos(float(actor.special.iron_left)*TAU)
		color *= Color(brightness,brightness,brightness)
	color.a = actor.modulate.a
	actor.modulate = color

static func accepts_bomb(unit, target) -> bool:
	if not is_instance_valid(target) or not (target is Unit or target is Building): return false
	if unit.embarked_in != null or AlliedAbilities.frozen(unit) or not AlliedAbilities.alive(target): return false
	if target.special.has("bridge_span") and not target.special.get("bridge_repaired", false): return false
	var id: String = target.unit_id if target is Unit else target.building_id
	return not target.special.has("ivan_bomb") and GameData._ra2_flag(Rules.type_data(id).get("bombable","yes"))

static func remove_bomb(actor, explode: bool, damage_scale := 1.0) -> void:
	if not actor.special.has("ivan_bomb"): return
	var bomb: Dictionary = actor.special.ivan_bomb
	actor.special.erase("ivan_bomb")
	Ra2Sfx.stop_ivan_tick(actor)
	actor.queue_redraw()
	if explode:
		var world = actor.battle if actor is Building else actor._battle_world()
		preload("res://scripts/rules/field_commission.gd").detonated(world, actor, bomb)
		var point := preload("res://scripts/world/fog_of_war.gd").bomb_position(actor)
		if world.fog != null: world.fog.reveal_ivan_blast(bomb.side, point)
		if actor is Building and actor.special.has("bridge_span"):
			preload("res://scripts/world/civilian_sites.gd").break_bridge(actor)
		Death.queue_blast(world, point, bomb.side, float(Rules.data().combat.ivandamage) * damage_scale, str(Rules.data().combat.ivanwarhead))

static func bomb_frame(left: float, count: int) -> int:
	var combat: Dictionary = Rules.data().combat
	var elapsed := maxf(0.0,float(combat.ivantimeddelay)-left*TPS)
	var pairs := maxi(1,floori(count/2.0))
	var stage := mini(pairs-1,floori(elapsed*pairs/float(combat.ivantimeddelay)))
	return mini(count-1,2*stage + (floori(elapsed / maxi(1,int(combat.ivaniconflickerrate))) % 2))

static func draw_status(actor) -> void:
	var squid = actor.special.get("squid")
	var grip := actor.get_node_or_null("SquidGrip") as Sprite2D
	if AlliedAbilities.alive(squid):
		var art := RA2Art.fx(grip_image(actor, squid))
		if not art.is_empty():
			if grip == null:
				grip = Sprite2D.new()
				grip.name = "SquidGrip"
				grip.region_enabled = true
				grip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				actor.add_child(grip)
			var cell: Vector2 = art.cell
			# Use one closed-grip frame as a stable pivot. Fitting every animation
			# frame would cancel the natural movement as the arms open and close.
			var reference := RA2Art.visible_sprite_rect(art, Rect2(-cell * 0.5, cell), RA2Art.fx_rect(art, 14))
			var bounds: Rect2 = actor._body_bounds
			var scale_factor := bounds.size.length() * 0.9 / maxf(1.0, reference.size.length())
			var center := Iso.dir(actor._rest_art_center() - actor.global_position)
			grip.texture = art.tex
			grip.region_rect = RA2Art.fx_rect(art, grip_frame(actor.special.get("grip_age", 0.0), art))
			grip.transform = actor.body_draw_transform() * Transform2D(0, Vector2.ONE * scale_factor, 0, center - reference.get_center() * scale_factor)
			grip.material = HouseColor.material_for(squid._col,HouseColor.PaintMode.SQUID_GRIP)
			grip.show()
	elif grip != null:
		grip.hide()
	if actor.special.has("airstrike_mark"):
		var spotter = actor.special.airstrike_mark.spotter
		var world = actor.battle if actor is Building else actor._battle_world()
		if AlliedAbilities.alive(spotter) and world != null and world.actor_visible_to("ally", spotter) and world.actor_visible_to("ally",actor):
			var dot := Iso.dir(actor.art_center() - actor.global_position)
			if not actor.special.airstrike_mark.get("boris_independent",false):actor.draw_line(Iso.dir(spotter._weapon_muzzle() - actor.global_position), dot, Color.RED, 1.4, true)
			actor.draw_circle(dot, 2.4, Color.RED)
	if actor.special.has("ivan_bomb"):
		var left: float = actor.special.ivan_bomb.left
		var center := Iso.dir(actor.art_center() - actor.global_position)
		var label_at := center + Vector2(6, 5)
		var art := RA2Art.fx("BOMBCURS")
		if not art.is_empty():
			var size: Vector2 = art.cell
			actor.draw_texture_rect_region(art.tex, Rect2(center - size * 0.5, size), RA2Art.fx_rect(art, bomb_frame(left, art.count)))
			label_at.x += size.x * 0.5
		var seconds := ceili(left)
		var label := "%d秒" % seconds
		var color := Color.TOMATO if seconds <= 5 else Color.GOLD
		if actor is Building:
			actor.draw_string_outline(ThemeDB.fallback_font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
			actor.draw_string(ThemeDB.fallback_font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)

static func drop_radiation(unit) -> float:
	var gun: Dictionary = unit.data.deployed_weapon
	var raw := GameData.ra2_weapon(gun.ra2_weapon_id)
	add_radiation(unit._battle_world(), unit.position, (float(gun.range)+float(unit.special.get("hero_range_aura",0))) / CELL, float(raw.extra.RadLevel), unit.side,unit)
	Ra2Sfx.play_weapon(gun, unit.position)
	var rules := radiation_rules()
	var duration: float = float(raw.extra.RadLevel) * rules.duration
	var interval: float = duration - rules.level_delay
	if not unit.special.has("rad_deployed_fired"): interval -= floorf(duration / 4.0)
	unit.special.rad_deployed_fired = true
	return maxf(1.0, interval) / TPS

static func squid_target(target) -> bool:
	if not target is Unit or not target.is_naval or target.embarked_in != null: return false
	if target.is_amphibious:
		var world = target._battle_world()
		if world == null or not world.in_water_world(target.position): return false
	if organic(target): return true
	return not AlliedAbilities.alive(target.special.get("squid")) and str(AlliedAbilities.source(target).get("Parasiteable","yes")).to_lower() != "no"

static func shoot(unit, target, weapon: Dictionary) -> bool:
	match unit.unit_id:
		"DTRUCK", "TERROR":
			unit.hp = 0.0
			unit._die()
			return true
		"IVAN", "CIVAN":
			if not target is ForceFirePoint and accepts_bomb(unit,target):
				target.special.ivan_bomb = {"side":unit.side, "left":Unit.Training.fuse(unit, float(Rules.data().combat.ivantimeddelay) / TPS)}
				target.special.ivan_bomb.owner = unit
				target.special.ivan_bomb.duration = target.special.ivan_bomb.left
				preload("res://scripts/rules/field_commission.gd").stamp_bomb(unit, target, target.special.ivan_bomb)
				Ra2Sfx.play("CrazyIvanAttack",target.position)
				target.queue_redraw()
				target.queue_redraw()
			return true
		"BORIS":
			if boris_airstrike_target(unit, target):
				designate(unit,target)
				return true
		"SQD":
			if squid_target(target) and not organic(target):
				if NavalContact.underwater_type(target): NavalContact.surface(target)
				target.special.squid = unit
				unit.global_position=target.global_position
				unit.set_stowed(target)
				target.special.squeeze = squid_grip_seconds()
				grip_rock(target)
				target.queue_redraw()
				return true
	return false

static func release_squid(host, forced_off := false) -> void:
	var squid = host.special.get("squid")
	host.special.erase("squid")
	host.special.erase("squeeze")
	host.special.erase("squid_rock_side")
	host.special.erase("grip_age")
	host.special.erase("squid_suppression")
	host.queue_redraw()
	if AlliedAbilities.alive(squid) and squid.embarked_in == host:
		var exit: Vector2 = host.position
		var world = squid._battle_world()
		if world != null:
			var spacing := maxf(CELL, host.radius + squid.radius + 3.0)
			# A docked ship is inside the yard footprint. Search from the berth to open water.
			var rings := 4 if host.repairing else 1
			for ring in range(1,rings+1):
				for i in 8:
					var point: Vector2 = host.position + Vector2.from_angle(host.hull_angle + PI + i * TAU / 8.0) * spacing * ring
					if preload("res://scripts/world/chronoshift.gd").landing_clear(world, squid, point, []):
						exit = point
						break
				if exit != host.position: break
		if exit == host.position and world != null and world.on_water(host.position):
			AlliedAbilities.consume(squid)
			return
		squid.set_stowed(null)
		squid.position = exit
		squid._last_water_pos = exit
		squid.order_stop()
		squid._cd_timer = 0.0
		if forced_off:
			squid.stun(10.0)
			squid.special.dive_remaining = 10.0

static func host_sinking(host, killer) -> void:
	var squid = host.special.get("squid")
	var dies_with_host: bool = AlliedAbilities.alive(squid) and not squid.special.has("iron_left") and (not is_same(killer,squid) or float(host.special.get("squid_suppression",0.0)) > 0.0)
	if dies_with_host:
		host.special.erase("squid")
		AlliedAbilities.consume(squid)
	release_squid(host)

static func external_grip_hit(host, amount: float) -> void:
	var squid = host.special.get("squid")
	if not AlliedAbilities.alive(squid): return
	var threshold := float(AlliedAbilities.source(squid).get("SuppressionThreshold",250))
	host.special.squid_suppression = 2.0 * amount / TPS if amount > threshold else 0.0

static func grip_rock(host) -> void:
	var side := -float(host.special.get("squid_rock_side", -1.0))
	host.special.squid_rock_side = side
	host.rock_sideways(side)

static func squid_grip_seconds() -> float:
	return (Ra2Damage.ROCK_TICKS + 2.0) / TPS

static func culls_ship(host, squid) -> bool:
	var lighting: Dictionary = preload("res://scripts/world/special_rules.gd").data().lighting
	var key := "conditionyellow" if squid.veteran_level >= 2 else "conditionred"
	var threshold := str(lighting[key]).trim_suffix("%").to_float() / 100.0
	return host.hp <= host.max_hp * threshold

static func grip_image(host, squid) -> String:
	var gun: Dictionary = squid._weapon_for_target(host)
	# On the original isometric sheets NE/SW wrap a vertical hull and
	# NW/SE wrap a horizontal hull. Convert screen heading to sheet heading.
	var heading := Iso.dir(Vector2.from_angle(host.hull_angle)).rotated(PI / 4.0)
	return Ra2Fx.pick_directional(GameData.ra2_muzzle_anims(gun.ra2_weapon_id), heading)

static func grip_frame(age: float, art: Dictionary) -> int:
	# art(md).ini SQDG_*: LoopStart=9, LoopEnd=19, LoopCount=8.
	const START := 9
	const END := 19
	const LOOPS := 8
	const SPAN := END - START + 1
	var frame := floori(age * float(art.fps)) % (int(art.count) + (LOOPS - 1) * SPAN)
	if frame < START: return frame
	if frame < START + LOOPS * SPAN: return START + (frame - START) % SPAN
	return frame - (LOOPS - 1) * SPAN

static func squeeze(host, delta: float) -> void:
	var squid = host.special.get("squid")
	if not AlliedAbilities.alive(squid):
		release_squid(host)
		return
	squid.position = host.position
	host.velocity = Vector2.ZERO
	host.queue_redraw()
	host.special.grip_age = float(host.special.get("grip_age", 0.0)) + delta
	if host.special.has("squid_suppression"):
		host.special.squid_suppression = maxf(0.0, float(host.special.squid_suppression) - delta)
	host.special.squeeze -= delta
	while host.special.has("squeeze") and host.special.squeeze <= 0.0:
		host.special.squeeze += squid_grip_seconds()
		grip_rock(host)
		var gun: Dictionary = squid._weapon_for_target(host)
		host.receive_hit(CombatMath.full_damage(gun, host.armor, squid.bonuses, null, host.ra2_armor), "melee", squid.bonuses, squid, gun.ra2_warhead)


static func boris_airstrike_target(unit, target) -> bool:
	return unit.unit_id == "BORIS" and is_instance_valid(target) and target is Building and not target.is_explosive_barrel()


static func designate(unit, target) -> void:
	if preload("res://scripts/units/boris_sortie.gd").rank(unit)>=0 and preload("res://scripts/units/boris_sortie.gd").occupied(unit):return
	if target.special.has("airstrike_mark") or target.special.has("airstrike_left"): return
	# The Flare hit starts the sortie. ROF controls subsequent shots, not a dispatch countdown.
	var duration := float(unit.data.special_weapon.cooldown)
	var mark := {"spotter":unit, "left":duration, "duration":duration, "jets":[]}
	target.special.airstrike_mark = mark
	preload("res://scripts/units/boris_radio.gd").started(unit)
	_dispatch_migs(unit,target,mark.jets)
	if preload("res://scripts/units/boris_sortie.gd").independent(unit):mark.boris_independent=true;mark.boris_side=unit.side
	sync_tint(target)
	target.queue_redraw()

# An active AirstrikeClass reassigns its existing flight when a new structure is marked.
static func redirect_wing(previous) -> bool:
	var mark: Dictionary = previous.special.get("airstrike_mark",{})
	if mark.get("boris_independent",false):return false
	var spotter = mark.get("spotter")
	if not AlliedAbilities.alive(spotter) or spotter.embarked_in != null or not spotter.attack_ordered: return false
	var next = spotter.attack_target
	if not AlliedAbilities.alive(next) or not boris_airstrike_target(spotter, next) or next == previous or next.special.has("airstrike_mark"): return false
	if not spotter._weapon_target_valid(next): return false
	var redirected := false
	for jet in mark.get("jets",[]):
		if AlliedAbilities.alive(jet) and not jet.special.strike_run.outbound:
			jet.special.strike_run.target = next
			redirected = true
	if redirected:
		previous.special.erase("airstrike_mark")
		previous.special.erase("airstrike_left")
		sync_tint(previous)
		previous.queue_redraw()
		next.special.airstrike_mark = mark
		sync_tint(next)
		next.queue_redraw()
	return redirected

static func _advance_mark(target, delta: float) -> void:
	var mark: Dictionary = target.special.airstrike_mark
	var unit = mark.spotter
	var locked: bool = AlliedAbilities.alive(unit) and unit.attack_target == target and unit.embarked_in == null and unit._weapon_target_valid(target)
	if mark.get("boris_independent",false):locked=preload("res://scripts/units/boris_sortie.gd").mark_locked(unit,target,mark)
	if locked and mark.has("jets"):
		locked = false
		for jet in mark.jets:
			if AlliedAbilities.alive(jet) and not jet.special.strike_run.outbound and is_same(jet.special.strike_run.target,target):
				locked = true
				break
	if not locked:
		if redirect_wing(target): return
		if AlliedAbilities.alive(unit): unit.queue_redraw()
		target.special.erase("airstrike_mark")
		sync_tint(target)
		if not mark.get("boris_independent",false) and mark.has("jets") and AlliedAbilities.alive(unit) and unit.attack_target == target:
			if unit.attack_ordered: unit._finish_target_order()
			else: unit.attack_target = null
	else:
		mark.left = maxf(0.0, mark.left - delta)
		sync_tint(target)
		if mark.left <= 0 and not mark.has("jets"):
			mark.jets = []
			_dispatch_migs(unit, target, mark.jets)
	target.queue_redraw()

static func set_airstrike_reload(unit, seconds: float) -> void:
	unit.special.airstrike_cd = seconds
	unit.special.airstrike_duration = seconds

static func advance_sortie_reload(unit, delta: float) -> void:
	if unit.special.has("airstrike_wing"):
		for jet in unit.special.airstrike_wing:
			if AlliedAbilities.alive(jet): return
		unit.special.erase("airstrike_wing")
		# Last aircraft left the map or was shot down. Recharge starts on this tick.
		var row := Rules.type_data("BORIS")
		set_airstrike_reload(unit,float(row.eliteairstrikerechargetime if unit.veteran_level >= 2 else row.airstrikerechargetime)/TPS / Unit.Training.boris_reload_scale(unit))
		return
	unit.special.airstrike_cd = maxf(0.0, float(unit.special.get("airstrike_cd",0.0)) - delta)

static func restore_boris_reload(unit) -> void:
	if unit.special.has("airstrike_cd") or unit._cd_timer <= 0.0: return
	var target = unit.attack_target
	var marking := is_instance_valid(target) and target is Building and is_same(target.special.get("airstrike_mark", {}).get("spotter"), unit)
	var rifle_interval := CombatMath.veteran_cooldown(float(unit._weapon_for_target(null).cooldown), unit.bonuses)
	if marking or unit._cd_timer > rifle_interval:
		set_airstrike_reload(unit, unit._cd_timer)
		unit._cd_timer = 0.0

static func _dispatch_migs(unit, target, jets: Array) -> void:
	var world = unit._battle_world()
	var row := Rules.type_data("BORIS")
	var elite: bool = unit.veteran_level >= 2
	var recharge := float(row.eliteairstrikerechargetime if elite else row.airstrikerechargetime) / TPS
	set_airstrike_reload(unit, recharge / Unit.Training.boris_reload_scale(unit))
	unit.special.airstrike_wing = jets
	var incoming := Vector2.RIGHT if target.position.x < world.map_size * 0.5 else Vector2.LEFT
	var radio_id := str(NativeRules.data().lighting.airstrikeattackvoice)
	var targets:Array=preload("res://scripts/units/boris_sortie.gd").targets(unit,target,int(row.eliteairstriketeam if elite else row.airstriketeam))
	for i in targets.size():
		var origin := Vector2(0 if incoming.x > 0 else world.map_size, clampf(target.position.y + 65.0 * i, 0, world.map_size))
		var jet = world.spawn_unit(str(row.eliteairstriketeamtype if elite else row.airstriketeamtype), unit.side, origin)
		if jet==null:continue
		if elite: jet._grant_veteran(2, false)
		jets.append(jet)
		jet.special.strike_run = {"target":targets[i],"origin":origin,"outbound":false,"spotter":unit,"guided":true,"inbound_speed_factor":Unit.Training.boris_arrival_scale(unit)}
		jet.special.strike_run.ammo = int(GameData.ra2_source_units["BPLN"].extra.get("Ammo",1))
		jet.special.strike_run.wing = jets
		if i == 0 and unit.side == "ally":
			jet.special.strike_run.radio_left = float(GameData.ra2_sound_spec(radio_id).get("delay_ms",1500)) / 1000.0
		jet.logistics.air_lift = 1.0
	preload("res://scripts/units/boris_sortie.gd").configure(unit,target,jets)
	preload("res://scripts/units/boris_fire_control.gd").dispatched(unit,jets)

static func nearest_exit(point: Vector2, map_size: float) -> Vector2:
	var left_right := Vector2(0.0 if point.x <= map_size * 0.5 else map_size, point.y)
	var top_bottom := Vector2(point.x, 0.0 if point.y <= map_size * 0.5 else map_size)
	return left_right if point.distance_squared_to(left_right) <= point.distance_squared_to(top_bottom) else top_bottom

static func fly_mig(jet, delta: float) -> void:
	var run: Dictionary = jet.special.strike_run
	preload("res://scripts/units/boris_sortie.gd").update_target(jet)
	var target = run.target
	if not run.get("boris_independent",false) and not run.outbound and AlliedAbilities.alive(target) and AlliedAbilities.alive(run.spotter) and run.spotter.attack_target != target:
		if redirect_wing(target): target = run.target
	if run.get("ammo",1) == 0: run.outbound = true
	var returning: bool = run.outbound
	if not AlliedAbilities.alive(target) or not AlliedAbilities.alive(run.spotter): run.outbound = true
	if not run.outbound and run.get("guided", false) and not run.get("boris_independent",false):
		var mark: Dictionary = target.special.get("airstrike_mark", {})
		if run.spotter.attack_target != target or not mark.get("jets", []).has(jet): run.outbound = true
	if not returning and run.outbound and jet.side=="ally" and not run.get("abort_announced",false):
		for other in run.get("wing",[jet]):
			if AlliedAbilities.alive(other): other.special.strike_run.abort_announced=true
		Ra2Sfx.play(str(NativeRules.data().lighting.airstrikeabortsound),jet.position,true)
	if not run.outbound and run.has("radio_left"):
		run.radio_left -= delta
		if run.radio_left <= 0.0:
			run.erase("radio_left")
			Ra2Sfx.play(str(NativeRules.data().lighting.airstrikeattackvoice),Vector2.INF,true)
	var dest: Vector2 = nearest_exit(jet.position, jet._battle_world().map_size) if run.outbound else target.position
	jet.hull_angle = jet.position.direction_to(dest).angle()
	jet.position = jet.position.move_toward(dest, jet.move_speed * delta * (float(run.get("inbound_speed_factor",1.0)) if not run.outbound else 1.0))
	var gun: Dictionary = jet._active_weapon()
	if not run.outbound and jet.position.distance_to(dest) <= float(gun.range):
		run.outbound = true
		run.ammo = maxi(0,int(run.get("ammo",1))-1)
		preload("res://scripts/units/boris_fire_control.gd").sortie_fired(jet)
		# BPLN has Ammo=1. Aircraft Mission_Attack fires its entire Burst in one update.
		# artmd [BPLN] PrimaryFireFLH=25,100,0; mirror the lateral offset for shot two.
		var forward := Vector2.from_angle(jet.hull_angle)
		var center := Effects.hit_position(jet)
		var damage := CombatMath.full_damage(gun,target.armor,jet.bonuses,null,target.ra2_armor)
		for index in int(gun.burst):
			var lateral := 100.0 if index % 2 == 0 else -100.0
			var muzzle := center + (forward * 25.0 + forward.orthogonal() * lateral) * (CELL / 256.0)
			var shot := Projectile.new()
			shot.setup(muzzle, target, gun, damage, jet.bonuses, jet.side, jet)
			preload("res://scripts/units/boris_fire_control.gd").prepare_mig(shot,jet)
			jet._battle_world().projectiles_root.add_child(shot)
		Ra2Sfx.play_weapon(gun, jet.position)
	if run.outbound and jet.position.is_equal_approx(nearest_exit(jet.position, jet._battle_world().map_size)):
		preload("res://scripts/units/boris_radio.gd").exited(jet)
		AlliedAbilities.consume(jet)
	jet.queue_redraw()
