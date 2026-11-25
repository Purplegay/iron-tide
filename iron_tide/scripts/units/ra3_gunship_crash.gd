extends RefCounted
## CreateObjectDie -> inert DYING projectile -> ground death weapon -> COL.
static var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ra3_completion_rules.json"))

static func begin(actor) -> void:
	var shot:=Projectile.new()
	shot.owner_side=actor.side;shot._credit_source=weakref(actor)
	shot.position=actor.position;shot.target_point=actor.position
	shot.attacker_bonus={} # Death weapon is not multiplied by the lost unit's rank.
	var rng:=RandomNumberGenerator.new();rng.randomize()
	shot.splinters={"ra3_expansion":"crash","age":0.0,"start":actor.position,"height":maxf(0.0,actor._visual_lift()),
		"velocity":actor.velocity,"heading":actor.hull_angle,"spin":Vector2(rng.randf_range(-50,50),rng.randf_range(-50,50)),"heroic":false}
	actor._battle_world().projectiles_root.add_child(shot)
	visual(shot)

static func visual(shot) -> void:
	if DisplayServer.get_name()=="headless" or shot.has_meta("crash_visual"):return
	shot.set_meta("crash_visual",true)
	var state: Dictionary=shot.splinters
	Ra3Wreck.spawn_from(shot.get_parent().get_parent(),Ra3Expansion.HARBINGER,shot.position,float(state.heading),state.velocity,shot)

static func altitude(state: Dictionary) -> float:
	return maxf(0.0,float(state.height)-0.5*float(rules.adapter.crash_gravity)*pow(float(state.age),2))

static func tick(shot, delta: float) -> void:
	if shot.is_queued_for_deletion():return
	var state: Dictionary=shot.splinters
	state.age=float(state.age)+delta
	var world=shot.get_parent().get_parent()
	shot.position=(state.start as Vector2)+(state.velocity as Vector2)*float(state.age)
	shot.target_point=shot.position
	visual(shot)
	if altitude(state)>0.0:return
	var nugget: Dictionary={}
	for child: Dictionary in rules.crash_weapon.children:
		if child.type=="Nuggets":
			for n: Dictionary in child.children:
				if n.type=="DamageNugget":nugget=n.attrs
	var radius:=float(nugget.Radius)*1.5
	for target in world.units+world.buildings:
		if not AlliedAbilities.alive(target) or (target is Unit and (target.is_air_target() or target.embarked_in!=null)):continue
		if target.position.distance_to(shot.position)>radius:continue
		Ra3Expansion.hit(shot,target,float(nugget.Damage)*(0.5 if target.side==shot.owner_side else 1.0),str(nugget.DamageType))
	preload("res://scripts/units/ra3_meta_impact.gd").apply(world,shot.position,rules.crash_weapon)
	preload("res://scripts/units/ra3_crash_fx.gd").spawn(world,shot.position)
	shot.queue_free()
