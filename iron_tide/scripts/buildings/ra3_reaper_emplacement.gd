extends RefCounted
## A deployed Reaper is a Building. Its private Unit drives the same four
## weapon mounts and native skinned rig, without becoming a second combatant.
static func mount(building):
	var gun=building.get_node_or_null("ReaperMount")
	if gun!=null:return gun
	gun=Unit.new()
	gun.name="ReaperMount"
	gun.setup(GameData.get_unit("R3REAPER").duplicate(true),building.side,building.global_position)
	gun.top_level=true
	building.add_child(gun)
	gun.set_physics_process(false);gun.collision_layer=0;gun.collision_mask=0
	for group in ["combatants","allies","enemies","enemy_targets","ally_targets","ground_units","air_units"]:
		if gun.is_in_group(group):gun.remove_from_group(group)
	gun.set_selected(building.selected)
	gun._deployed=true
	gun.special=building.special
	gun.special.walker_deployed=true
	gun.hull_angle=float(building.special.get("walker_heading",0.0))
	gun._grant_veteran(int(building.special.get("walker_rank",0)),false)
	gun._vet_kills=float(building.special.get("walker_xp",0.0))
	gun._base_max_hp=900
	gun.max_hp=building.max_hp;gun.hp=building.hp
	if gun._ra3_model!=null:
		gun._ra3_model._sample(0)
		gun._ra3_model.sync_pose()
	return gun

static func accepts_order(building,target) -> bool:
	if not AlliedAbilities.alive(building) or building.side!="ally" or building.building_id!="R3REAPERTURRET":return false
	if not AlliedAbilities.alive(target) or target.side==building.side or not building.is_operational() or AlliedAbilities.frozen(building):return false
	if target is Unit and target.is_air_target() and building.position.distance_to(target.position)<30:return false
	return building._valid_weapon_target(target)

static func order(building,target) -> bool:
	if not accepts_order(building,target):return false
	preload("res://scripts/units/ra3_reaper_split.gd").clear(building)
	ForceFire.clear(building)
	building.special.reaper_ordered_target=target
	building.attack_target=target
	return true

static func tick(building,dt:float) -> void:
	if building.special.has("walker_landing_age"):
		building.special.walker_landing_age+=dt
		if building.special.walker_landing_age>=13.0:
			building.special.erase("walker_landing_age")
			building.special.erase("walker_touch_frame")
	var gun=mount(building)
	gun.global_position=building.global_position
	gun.visible=building.is_visible_in_tree()
	gun.special=building.special
	gun.max_hp=building.max_hp;gun.hp=building.hp
	if not building.is_operational() or AlliedAbilities.frozen(building):return
	building._think-=dt
	if building._think<=0:
		building._think=0.25
		var requested=building.special.get("reaper_ordered_target")
		if not is_instance_valid(requested) or requested!=building.attack_target or not accepts_order(building,requested):
			building.special.erase("reaper_ordered_target")
			building._acquire_target()
	gun.attack_target=building.attack_target
	gun.attack_ordered=is_instance_valid(gun.attack_target)
	if gun.attack_ordered:
		gun.turret_angle=gun.position.direction_to(gun.attack_target.position).angle()
		preload("res://scripts/units/ra3_soviet.gd").align_reaper(gun,dt)
		building.special.walker_heading=gun.hull_angle
	preload("res://scripts/units/ra3_soviet.gd").tick(gun,dt)
	preload("res://scripts/units/auto_w.gd").tick(gun,dt)
	preload("res://scripts/units/ra3_soviet.gd").fire(gun)
	building._cd=gun._cd_timer
	building.special.walker_rank=gun.veteran_level
	building.special.walker_xp=gun._vet_kills
	building.hp=gun.hp
	building.max_hp=gun.max_hp
