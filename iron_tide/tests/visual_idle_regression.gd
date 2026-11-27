extends "res://tests/base_recovery_regression.gd"

class FieldWorld extends Node:
	var allied_state := {}
	func position_visible_to(_side, _point) -> bool: return true

var draws := {"orders":0,"fields":0,"hp":0,"power":0,"keepsake":0}
var counts := {}

func watch(item: CanvasItem, key: String) -> void:
	item.draw.connect(func(): draws[key] += 1)

func frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or DisplayServer.get_name()=="headless" or not ProjectSettings.get_setting("application/config/use_custom_user_dir",false):
		get_tree().quit(2)
		return
	BattleRequest.configure_skirmish(MatchRules.EXTENDED, {"starting_funds":8000})
	screen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	battle = screen.battle
	battle.clear_selection()
	watch(battle.move_order_overlay,"orders")
	var world := FieldWorld.new()
	add_child(world)
	var fields=preload("res://scripts/units/expansion_field_visual.gd").new()
	fields.world=world
	add_child(fields)
	watch(fields,"fields")
	var keepsake=preload("res://scripts/expedition/keepsake_orders.gd").new()
	keepsake.world=battle
	keepsake.set_process_input(false)
	add_child(keepsake)
	watch(keepsake,"keepsake")
	var hp:=HpBarControl.new()
	var power:=PowerBarControl.new()
	add_child(hp)
	add_child(power)
	hp.size=Vector2(120,15)
	power.size=Vector2(120,15)
	watch(hp,"hp")
	watch(power,"power")
	hp.set_hp(100,100)
	power.set_power(100,50)
	await frames(5)
	var before:=draws.duplicate()
	for i in 16:
		hp.set_hp(100,100)
		power.set_power(100,50)
		await frames(1)
	for key in draws:
		counts["idle_"+key]=draws[key]-before[key]
		check(draws[key]==before[key],"stable layer retains draw commands "+key,counts["idle_"+key])
	check(not hp.is_processing() and not power.is_processing(),"settled HUD controls sleep")
	before=draws.duplicate()
	var u=battle.spawn_unit("MTNK","ally",battle.player_start()+Vector2(220,120))
	battle.select_unit(u,false)
	u.order_move(u.position+Vector2(180,60))
	world.allied_state.expansion_scraps=[{"point":Vector2(80,100)}]
	keepsake.state.watch_left=1.0
	hp.set_hp(5,100)
	power.set_power(10,50)
	await frames(6)
	for key in draws: check(draws[key]>before[key],"selection movement field damage and power transition repaint "+key)
	check(hp.is_processing() and power.is_processing(),"critical health and low-power pulses stay active")
	battle.clear_selection()
	world.allied_state.expansion_scraps.clear()
	keepsake.state.erase("watch_left")
	hp.set_hp(100,100)
	power.set_power(100,50)
	var clear_from:=draws.duplicate()
	await frames(24)
	check(draws.orders>clear_from.orders and draws.fields>clear_from.fields and draws.keepsake>clear_from.keepsake,"final empty frame clears the previous visuals")
	before=draws.duplicate()
	await frames(8)
	for key in draws:check(draws[key]==before[key],"layer sleeps after clearing "+key)
	var growth=preload("res://scripts/expedition/growth.gd")
	var run={"frozen":{"expedition_unit_levels":{"E1":{"atk":8,"def":12}},"expedition_growth_rates":{"atk":0.05}},"unit_growth":{"E1":{"atk":0}}}
	check(growth.level(run,"E1","atk")==0 and growth.level(run,"E1","def")==2,"explicit zero and missing growth track")
	check(is_equal_approx(growth.rate(run,"atk"),0.05) and growth.rate(run,"def")==float(MetaProgress.get_unit_track("def").effect_per_level),"frozen and missing growth rates")
	var previous=BattleRequest.combat_context
	BattleRequest.combat_context={"unit_bonus":{"MTNK":{"attack_bonus":1.5}}}
	check(BattleRequest.unit_bonus("MTNK")=={"attack_bonus":1.5} and BattleRequest.unit_bonus("E1")==MetaProgress.unit_stat_bonus("E1"),"combat and fallback unit bonus sources")
	BattleRequest.combat_context=previous
	var frame=preload("res://scripts/ui/active_skill_frame.gd").new()
	add_child(frame)
	frame.set_active(true,false)
	await frames(2)
	var phase:float=frame.phase
	frame.set_active(true,false)
	check(frame.visible and frame.is_processing() and frame.phase==phase,"repeated skill frame status preserves animation phase")
	frame.set_active(false)
	check(not frame.visible and not frame.is_processing() and frame.phase==0.0,"inactive frame clears animation")
	var old_angle=Iso.ANGLE
	var old_mirror=Iso.MIRROR
	var old_yaw=Iso.USE_YAW
	for angle in [0.0,PI/4.0,PI/2.0]:
		for mirror in [true,false]:
			for yaw in [true,false]:
				Iso.ANGLE=angle
				Iso.MIRROR=mirror
				Iso.USE_YAW=yaw
				battle._update_depth_order()
				var size_pixels:float=battle.map_size
				var axis:=Vector2.DOWN.rotated(Iso.eff_angle())
				var half_map:=Vector2.ONE*size_pixels*0.5
				var denom:=maxf(1.0,(absf(axis.x)+absf(axis.y))*size_pixels*0.5)
				var sample:Array=[u]+battle.buildings
				for actor in sample:
					var at:Vector2=actor.depth_anchor() if actor is Building else actor.global_position
					var expected:=DepthLayers.DEPTH_OFFSET+roundi(clampf((at-half_map).dot(axis)/denom,-1,1)*DepthLayers.DEPTH_HALF)
					check(actor.z_index==expected,"live camera depth matches original projection")
	Iso.ANGLE=old_angle
	Iso.MIRROR=old_mirror
	Iso.USE_YAW=old_yaw
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"failed":failed,"checks":checks,"counts":counts}))
	get_tree().quit(0 if failed==0 else 1)
