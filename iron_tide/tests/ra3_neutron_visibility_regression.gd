extends "res://tests/allied_abilities_regression.gd"
## User regression: a newly arriving unit must not take invisible lingering orb pulses.
func arrive(shot) -> void:
	for i in 150:
		if shot.splinters.get("neutron_stage","node")=="node":return
		Ra3Expansion.tick_shot(shot,1.0/15.0)
	check(false,"neutron flight reaches its target")

func exercise_mode(mode: String) -> void:
	if mode==MatchRules.RA2:return
	setup_logistics_scene(mode,"美国")
	for node in battle.units+battle.buildings:node.free()
	battle.units.clear();battle.buildings.clear()
	if battle.fog!=null:battle.fog.free();battle.fog=null
	var future=actor("R3FUTURE","ally",Vector2(1400,1400))
	var late=actor("R3FUTURE","enemy",Vector2(2200,1400))
	var point:=Vector2(1700,1400)
	var shot=Ra3Expansion.make_shot(future,null,point,"neutron")
	arrive(shot)
	for i in 90:Ra3Expansion.tick_shot(shot,1.0/30.0)
	if shot.has_node("NativeFx"):
		var visual=shot.get_node("NativeFx");visual.set_process(false);visual.age=shot.splinters.age;visual._sample()
		check(not visual.visible,"native orb has disappeared after three seconds")
	late.position=point
	var hp: float=late.hp
	for i in 30:
		if not shot.is_queued_for_deletion():Ra3Expansion.tick_shot(shot,1.0/30.0)
	check(is_equal_approx(late.hp,hp),"unit entering after orb disappeared receives no hidden repeating damage",{"before":hp,"after":late.hp,"age":shot.splinters.age})
	shot.free()
	# XML plus retail update order: seven pre-unpack point hits, 19 expansion queries.
	for dt in [1.0/60.0,1.0/15.0,0.4]:
		late.hp=late.max_hp
		var orb=Ra3Expansion.make_shot(future,late,point,"neutron")
		arrive(orb)
		for i in ceili(3.0/dt):Ra3Expansion.tick_shot(orb,dt)
		check(is_equal_approx(late.max_hp-late.hp,65.1),"source damage is frame-rate independent at delta "+str(dt),late.max_hp-late.hp)
		check(int(orb.splinters.neutron_tick)==19,"expansion stops after 19 native queries")
		orb.free()
	var low=actor("R3HARBINGER","enemy",point)
	var high=actor("R3HARBINGER","enemy",point)
	low.flight.height=120.0/low.flight.HEIGHT_PIXEL;low.logistics.air_lift=1.0
	high.flight.height=600.0/high.flight.HEIGHT_PIXEL;high.logistics.air_lift=1.0
	check(not future._weapon_domain_valid(low),"ordinary weapon does not acquire air targets")
	var ground:=ForceFirePoint.new();ground.global_position=point
	future._fire_shot(ground)
	var forced=battle.projectiles_root.get_child(0)
	arrive(forced)
	var low_hp: float=low.hp;var high_hp: float=high.hp
	for i in 90:Ra3Expansion.tick_shot(forced,1.0/30.0)
	check(low.hp<low_hp,"real forced ground shot sphere reaches low air target")
	check(is_equal_approx(high.hp,high_hp),"ground projection overlap alone cannot hit high air target")
	forced.free()
	remove_actor(low);remove_actor(high)
	late.hp=late.max_hp
	var saved=Ra3Expansion.make_shot(future,late,point,"neutron")
	arrive(saved)
	Ra3Expansion.tick_shot(saved,1.8)
	var codec=preload("res://scripts/save/battle_snapshot.gd").new()
	var snapshot=codec.capture(battle)
	check(not snapshot.is_empty(),"orb phase cursors serialize through real save schema")
	codec.restore(battle,snapshot)
	late=battle.units.filter(func(u):return u.side=="enemy")[0]
	saved=battle.projectiles_root.get_child(0)
	Ra3Expansion.tick_shot(saved,1.2)
	check(is_equal_approx(late.max_hp-late.hp,65.1),"restored expansion never replays or drops damage")
	for field in ["neutron_tick","neutron_pre","neutron_direct"]:saved.splinters.erase(field)
	hp=late.hp;Ra3Expansion.tick_shot(saved,0.5)
	check(is_equal_approx(late.hp,hp),"legacy expired node does not replay historic damage")
	screen.free();await get_tree().process_frame
