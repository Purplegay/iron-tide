extends "res://tests/base_recovery_regression.gd"
const Actor = preload("res://tests/heading_redraw_actor.gd")
const Reference = preload("res://tests/chopper_projectile_reference.gd")
var rotor_rows: Array = []
func frame() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	start(MatchRules.EXTENDED)
	var actor = Actor.new()
	actor.setup(GameData.get_unit("SCHP"), "ally", Vector2(1100,1100))
	battle.add_child(actor)
	actor.process_mode = Node.PROCESS_MODE_ALWAYS
	actor.set_physics_process(false)
	actor.set_process(false)
	actor._siege_rotor.set_process(false)
	actor.logistics.air_lift = 1.0
	actor.hull_angle = 0.0
	actor._siege_rotor.clock = 0.0
	for i in 60:
		actor._anim = floorf(float(i+1)/4.0) / 15.0
		actor._siege_rotor._process(1.0/60.0)
		await frame()
		var expected := int(float(i+1)/3.0 + 0.00001) % 2
		check(actor._art_frame / int(actor._ra2.facings) == expected,"real rotor draw at 60 Hz presentation "+str(i))
		rotor_rows.append(actor._art_frame)
	var count: int = actor.draw_count
	actor.logistics.air_lift = 0.0
	actor._siege_rotor._process(0.1)
	await frame()
	check(actor.draw_count == count,"grounded rotor does not request animation redraw")
	actor._dead = true
	actor.logistics.air_lift = 1.0
	actor._siege_rotor._process(0.1)
	await frame()
	check(actor.draw_count == count,"dead rotor does not request animation redraw")
	actor.free()
	var source = battle.spawn_unit("SCHP","ally",Vector2(1000,1000))
	var victim = battle.spawn_unit("HTNK","enemy",Vector2(1450,1000))
	source.logistics.air_lift = 0.0
	for key in ["deployed_weapon","elite_deployed_weapon","weapon"]:
		for hz in [15,60]:
			var weapon: Dictionary = source.data[key]
			var expected: Array = []
			for variant in [false,true]:
				seed(713)
				victim.hp = victim.max_hp
				var shot = Projectile.new() if variant else Reference.new()
				shot.setup(source.position,victim,weapon,weapon.damage,{},"ally",source)
				battle.projectiles_root.add_child(shot)
				if variant:
					check(shot._smooth_siege_shell == (key != "weapon"),"only 160mm shells opt in "+key)
					if key != "weapon": check(shot.is_physics_interpolated_and_enabled(),"shell position interpolation enabled")
				var steps := 0
				while not shot._detonated and not shot.is_queued_for_deletion() and steps < 360:
					shot._physics_process(1.0/hz)
					var state := [shot.global_position,shot._arc_z,shot._arc_t,shot.life,shot._detonated,victim.hp]
					if not variant: expected.append(state)
					else:
						check(steps < expected.size() and state == expected[steps],"exact flight and damage "+str([key,hz,steps]))
						var before := state.duplicate()
						for blend in [0.0,0.25,0.5,0.75,1.0]:
							var lift: float = shot.presentation_lift(blend)
							if shot._smooth_siege_shell: check(is_equal_approx(lift,lerpf(shot._previous_arc_z,shot._arc_z,blend)),"height samples match same interpolation fraction")
						shot._process(1.0/60.0)
						check(before == [shot.global_position,shot._arc_z,shot._arc_t,shot.life,shot._detonated,victim.hp],"presentation cannot advance authoritative flight")
					steps += 1
				if variant: check(steps == expected.size(),"same impact tick "+str([key,hz]))
				shot.free()
	var saved = Projectile.new()
	var gun: Dictionary = source.data.deployed_weapon
	saved.setup(source.position,victim,gun,gun.damage,{},"ally",source)
	battle.projectiles_root.add_child(saved)
	saved._physics_process(1.0/15.0)
	var saved_z: float = saved._arc_z
	var snapshot: Dictionary = BattleSaves.Snapshot.new().capture(battle)
	BattleSaves.Snapshot.new().restore(battle,snapshot)
	await frame()
	var restored: Projectile
	for node in battle.projectiles_root.get_children():
		if node is Projectile and str(node.attacker_bonus.get("impact_weapon","")) == "YR_SOV_160mm": restored=node
	check(restored != null,"in-flight 160mm restored")
	if restored != null:
		check(restored._smooth_siege_shell and restored.is_physics_interpolated_and_enabled(),"restored fields activate interpolation after ready")
		check(restored._arc_z == saved_z and restored._previous_arc_z == saved_z,"restore starts both visual heights at saved authoritative height")
	await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"rotor_frames":rotor_rows},"  "))
	get_tree().quit(0 if failed == 0 else 1)
