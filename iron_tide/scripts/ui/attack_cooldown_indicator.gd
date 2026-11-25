extends RefCounted
## Presentation only; reads the normal-attack timer, never advances combat.
static var world_batch: MultiMeshInstance2D
const RADIUS := 6.0
const Gunship=preload("res://scripts/units/ra3_gunship_mounts.gd")
const Garrison=preload("res://scripts/units/civilian_orders.gd")
const PALETTE:={"bullet":Color("#ffda61"),"shell":Color("#ffa447"),"rocket":Color("#ff645e"),
	"grenade":Color("#b5ee66"),"tesla":Color("#62cfff"),"prism":Color("#e893ff"),
	"flak":Color("#e895b8"),"melee":Color("#e9dfca"),"acid":Color("#8dd755"),
	"repair":Color("#58e6a3"),"aircraft":Color("#7b9aff"),"temporal":Color("#6df2e7"),
	# Naval sonar and radiation have their own colors even when their carrier uses a generic attack type.
	"sonic":Color("#48b8ab"),"radiation":Color("#8cf04e"),"neutron":Color("#b3b5ff"),"collider":Color("#ff8758"),"harpoon":Color("#d7ff65")}

# Top row: rocket and front grenade. Bottom row: left and right grenade.
const REAPER_SLOTS:=["rocket","grenade1","grenade3","grenade2"]
const MULTI_RADIUS:=4.5
const MULTI_PITCH:=14.0

static func reaper_state(actor,rank:int,operational:bool) -> Dictionary:
	var mounts:Dictionary=actor.special.get("soviet_mounts",{})
	if mounts.is_empty() and not (actor.selected and operational):return {}
	var slots:Array[Dictionary]=[]
	var any_cooling:=false
	for key:String in REAPER_SLOTS:
		var mount:Dictionary=mounts.get(key,{})
		var left:=maxf(0.0,mount.get("left",0.0))
		var duration:=float(mount.get("duration",0.0))
		if left>0 and duration<=0:
			# Pre-four-ring saves contain the magazine counter and remaining time.
			var rounds:Dictionary=preload("res://scripts/units/ra3_reaper_pose.gd").definitions.rounds
			var rule:Dictionary=rounds.rocket if key=="rocket" else rounds.grenade
			var interval:float=rule.reload_seconds if int(mount.used)==0 else rule.shot_interval
			duration=interval/(1.2 if rank>=3 else 1.0)
		slots.append(slot(key,left,duration,PALETTE.rocket if key=="rocket" else PALETTE.grenade))
		any_cooling=any_cooling or left>0
	return {"mounts":slots} if any_cooling or (actor.selected and operational) else {}

static func slot(key:String,left:float,duration:float,color:Color) -> Dictionary:
	return {"key":key,"left":maxf(0,left),"fraction":clampf(left/maxf(0.001,duration),0,1),"color":color}

static func weapon_color(weapon:Dictionary) -> Color:
	var kind:=str(weapon.get("attack_type","bullet"))
	var native_id:=str(weapon.get("ra2_weapon_id",""))
	var id:=str(weapon.get("name","")) if native_id.is_empty() else native_id.to_lower().trim_prefix("yr_cap_")
	var flags:Dictionary=GameData.ra2_weapon(native_id).get("extra",{})
	var warhead:=str(weapon.get("ra2_warhead","")).to_lower()
	if float(weapon.get("damage",0))<0:kind="repair"
	elif "chrono" in warhead:kind="temporal"
	elif GameData._ra2_flag(flags.get("IsElectricBolt")):kind="tesla"
	elif GameData._ra2_flag(flags.get("IsLaser")) or "prism" in id:kind="prism"
	elif GameData._ra2_flag(flags.get("IsSonic")):kind="sonic"
	elif GameData._ra2_flag(flags.get("IsRadBeam")):kind="radiation"
	elif "missile" in id:kind="rocket"
	elif kind=="cannon":kind="shell"
	var color:Color=PALETTE.get(kind,PALETTE.bullet)
	# Stable variations distinguish individual weapons within a family.
	return Color.from_hsv(fposmod(color.h+(float(id.hash()%61)-30.0)/1200.0,1.0),color.s,color.v)

static func ordinary_slot(unit,weapon:Dictionary,key:String) -> Dictionary:
	var duration:=CombatMath.veteran_cooldown(unit.cooldown,unit.bonuses)*(1.0-clampf(unit.buff_value("cooldown"),0,0.85))*Unit.YRTalents.cooldown_multiplier(unit)
	if unit.unit_id in ["DOG", "SOV_DOG"]: duration /= Unit.Training.timing_scale(unit)
	if unit.unit_id in ["V3", "DRED"]: duration = preload("res://scripts/units/soviet_advanced.gd").rack_cycle(unit)
	if unit.unit_id=="APOC":duration=unit.special.get("shared_reload_duration",duration)
	if unit.special.has("focus_reload_duration"):duration=float(unit.special.focus_reload_duration)
	var color:=weapon_color(weapon)
	if unit.unit_id=="R3FUTURE":color=PALETTE.neutron
	return slot(key,unit._cd_timer,duration,color)

static func visible_slots(slots:Array,show_ready:bool) -> Dictionary:
	if slots.is_empty():return {}
	if not show_ready and not slots.any(func(s):return s.left>0):return {}
	return slots[0] if slots.size()==1 else {"mounts":slots}

static func gunship_slots(unit) -> Array:
	var slots:Array=[]
	var mounts:Dictionary=unit.special.get("ra3_mounts",{})
	for key:String in Gunship.active(unit):
		var mount:Dictionary=mounts.get(key,{})
		var left:float=mount.get("remaining",maxf(0,unit._cd_timer))
		var used:int=mount.get("used",unit.special.get("ra3_clip",0))
		var duration:float=mount.get("duration",0.0)
		if duration<=0 and left>0:duration=Gunship.interval(unit,key,used)
		slots.append(slot(key,left,duration,PALETTE.bullet if key=="front" else PALETTE.collider))
	return slots

static func state(unit) -> Dictionary:
	if not AlliedAbilities.alive(unit) or unit.side!="ally" or not unit.is_visible_in_tree():return {}
	if unit is Building:return building_state(unit)
	if unit.embarked_in!=null:return {}
	if unit.unit_id == "BORIS" and is_instance_valid(unit.attack_target) and unit.attack_target is Building:
		return visible_slots([slot("airstrike",unit.special.get("airstrike_cd",0.0),unit.special.get("airstrike_duration",0.0),PALETTE.aircraft)],unit.selected)
	if unit.unit_id=="R3REAPER":return reaper_state(unit,unit.veteran_level,true)
	if unit.unit_id=="R3HARBINGER":return visible_slots(gunship_slots(unit),unit.selected)
	if unit.unit_id in ["R3TESLA","R3APOC"]:
		var electric:bool=unit.unit_id=="R3TESLA"
		var w:Dictionary
		if unit.special.get("soviet_mode",false):
			if electric:w=slot("emp",unit.special.get("emp_left",0.0),1.0,PALETTE.tesla)
			else:
				var contact:float=unit.special.get("crush_contact",0.0)
				var next_pulse:=0.25-fposmod(contact,0.25) if unit.special.has("harpoon_target") and contact>0 else 0.0
				w=slot("harpoon",next_pulse,0.25,PALETTE.harpoon)
		else:
			var mount:Dictionary=unit.special.get("soviet_mounts",{}).get(unit.unit_id,{})
			var interval:float=unit.data.weapon.cooldown if int(mount.get("used",0))==0 else unit.weapon.burst_delay
			w=slot(unit.unit_id,mount.get("left",0.0),mount.get("duration",interval/(1.2 if unit.veteran_level>=3 else 1.0)),PALETTE.tesla if electric else PALETTE.shell)
		return visible_slots([w],unit.selected)
	var has_crew:bool=not unit.logistics.passengers.is_empty() and AlliedAbilities.flag(unit,"OpenTopped")
	var has_deck:bool=not unit.logistics.squadron.is_empty()
	if not unit.selected and unit._cd_timer<=0 and not has_crew and not has_deck:return {}
	var slots:Array=[]
	var weapon:Dictionary=unit._active_weapon()
	if unit.unit_id=="APOC":
		var ground:=ordinary_slot(unit,unit._weapon_for_target(null),"ground")
		slots.append(ground)
		slots.append({"key":"air","left":ground.left,"fraction":ground.fraction,"color":PALETTE.rocket})
	elif not weapon.is_empty() and unit.unit_id!="CARRIER":
		slots.append(ordinary_slot(unit,weapon,"hull"))
	if has_crew:
		for passenger in unit.logistics.passengers:
			if AlliedAbilities.alive(passenger) and passenger.embarked_in==unit:
				var gun:Dictionary=passenger._active_weapon()
				if not gun.is_empty():slots.append(ordinary_slot(passenger,gun,"crew"+str(slots.size())))
	if has_deck:
		for i in unit.logistics.squadron.size():
			var berth:Dictionary=unit.logistics.squadron[i]
			var duration:=float(unit.logistics.source.get("SpawnReloadRate",150) if is_instance_valid(berth.unit) else unit.logistics.source.get("SpawnRegenRate",600))/15.0
			var ring:=slot("deck"+str(i),berth.timer,duration,PALETTE.aircraft)
			if is_instance_valid(berth.unit) and berth.unit.embarked_in!=unit:ring.inactive=true
			slots.append(ring)
	return visible_slots(slots,unit.selected)

static func building_state(building: Building) -> Dictionary:
	if building.under_construction or building._buildup_play>=0.0:return {}
	if building.building_id=="R3REAPERTURRET":return reaper_state(building,int(building.special.get("walker_rank",0)),building.is_operational())
	if building.special.has("occupants"):
		var seats:Array=[]
		for passenger in building.special.occupants:
			if AlliedAbilities.alive(passenger) and passenger.embarked_in==building:
				var gun:=Garrison.weapon(passenger)
				if not gun.is_empty():seats.append(slot("garrison"+str(seats.size()),passenger._cd_timer,passenger.special.get("garrison_reload_duration",gun.cooldown),weapon_color(gun)))
		return visible_slots(seats,building.selected and building.is_operational())
	if building.weapon.is_empty() or (building._cd<=0 and not (building.selected and building.is_operational())):return {}
	return slot("building",building._cd,building.special.get("card_reload_duration",building.cooldown-float(building.data.get("fire_delay",0))),weapon_color(building.weapon))

static func screen_center(unit, canvas: Node2D) -> Vector2:
	var transform := canvas.get_global_transform_with_canvas()
	var camera: Camera2D = unit.get_viewport().get_camera_2d()
	var zoom: float = camera.zoom.x if camera != null else 1.0
	# Match draw_hp_bar's anchor. Rank chevrons occupy the opposite (left) end.
	var half_width: float
	var height: float
	if unit is Building:
		half_width = maxf(50.0, unit.radius * 2.4) * 0.5
		height = -unit.radius * 2.9 + 3.0
	else:
		var bar: Rect2 = unit.hp_bar_rect()
		half_width = bar.end.x
		height = bar.get_center().y
	return transform * canvas.to_local(unit.presentation_position() if unit is Unit else unit.global_position) + Vector2(half_width * zoom + RADIUS + 4.0, height * zoom)

static func paint(unit, canvas: Node2D) -> void:
	var info := state(unit)
	if info.is_empty(): return
	var center := screen_center(unit, canvas)
	if world_batch != null and world_batch.get_parent() == canvas and world_batch.used + info.get("mounts",[info]).size() <= world_batch.multimesh.instance_count:
		if info.has("mounts"):
			for i in info.mounts.size():
				world_batch.append(center+mount_offset(i,info.mounts.size()),MULTI_RADIUS,info.mounts[i])
		else: world_batch.append(center,RADIUS,info)
		return
	canvas.draw_set_transform_matrix(canvas.get_global_transform_with_canvas().affine_inverse())
	if info.has("mounts"):
		for i in info.mounts.size():
			var offset:=mount_offset(i,info.mounts.size())
			paint_ring(canvas,center+offset,MULTI_RADIUS,info.mounts[i])
	else:paint_ring(canvas,center,RADIUS,info)
	Iso.begin(canvas)

static func mount_offset(index:int,count:int) -> Vector2:
	var columns:=3 if count>=5 else 2
	return Vector2(index%columns,floori(float(index)/columns))*MULTI_PITCH

# Cache the screen-space ring face. Only the changing reload arc needs new geometry.
const RING_TRACK := Color(0.25, 0.32, 0.39)
static var _ring_faces: Dictionary = {}

static func _ring_face(radius: float, ink: Color, dot: bool) -> Texture2D:
	var key := Vector3i(roundi(radius * 2), ink.to_rgba32(), int(dot))
	if _ring_faces.has(key):
		return _ring_faces[key]
	var extent := ceili(radius + 2.5)
	var image := Image.create_empty(extent * 2, extent * 2, false, Image.FORMAT_RGBA8)
	var half_stroke := 0.75 if ink == RING_TRACK else 1.0
	for y in image.get_height():
		for x in image.get_width():
			var distance := Vector2(x + 0.5 - extent, y + 0.5 - extent).length()
			var fill := Color(0.015, 0.025, 0.04, 0.92 * clampf(radius + 2.5 - distance, 0, 1))
			var ring := clampf(half_stroke + 0.5 - absf(distance - radius), 0, 1)
			if dot: ring = maxf(ring, clampf(1.75 - distance, 0, 1))
			image.set_pixel(x, y, fill.blend(Color(ink, ink.a * ring)))
	var stamp := ImageTexture.create_from_image(image)
	_ring_faces[key] = stamp
	return stamp

static func paint_ring(canvas:Node2D,center:Vector2,radius:float,info:Dictionary) -> void:
	var ready: bool = info.left <= 0.0
	var inactive: bool = info.get("inactive", false)
	var ink: Color = info.color.darkened(0.55) if inactive else info.color
	var face := _ring_face(radius, ink if ready else RING_TRACK, ready and not inactive)
	canvas.draw_texture(face, center - face.get_size() * 0.5)
	if not ready and info.fraction > 0.001:
		canvas.draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * info.fraction, 32, ink, 2.0, true)
